import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:rope_editor/src/rope/anchor.dart';

/// A unique identifier for a transaction, using Lamport timestamps.
typedef TransactionId = LamportTimestamp;

/// Represents a single edit operation that can be undone/redone.
sealed class EditOperation {
  final int offset;
  final TextSelection selectionBefore;
  final TextSelection selectionAfter;
  final DateTime timestamp;
  
  /// The Lamport timestamp for this edit (for CRDT ordering).
  final LamportTimestamp? editId;

  EditOperation({
    required this.offset,
    required this.selectionBefore,
    required this.selectionAfter,
    DateTime? timestamp,
    this.editId,
  }) : timestamp = timestamp ?? DateTime.now();

  EditOperation inverse();
  bool canMergeWith(EditOperation other);
  EditOperation mergeWith(EditOperation other);
}

class InsertOperation extends EditOperation {
  final String text;

  InsertOperation({
    required super.offset,
    required this.text,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  });

  @override
  EditOperation inverse() => DeleteOperation(
      offset: offset, text: text, selectionBefore: selectionAfter, selectionAfter: selectionBefore);

  @override
  bool canMergeWith(EditOperation other) {
    if (other is! InsertOperation) return false;
    final timeDiff = other.timestamp.difference(timestamp).inMilliseconds.abs();
    // Group typing bursts within 2.5 seconds
    if (timeDiff > 2500) return false;
    if (other.offset == offset + text.length) {
      if (text.contains('\n') || other.text.contains('\n')) return false;
      final thisEndsWithSpace = text.endsWith(' ') || text.endsWith('\t');
      final otherStartsWithSpace =
          other.text.startsWith(' ') || other.text.startsWith('\t');
      if (thisEndsWithSpace != otherStartsWithSpace &&
          text.isNotEmpty &&
          other.text.isNotEmpty) {
        return false;
      }
      return true;
    }
    return false;
  }

  @override
  EditOperation mergeWith(EditOperation other) {
    if (other is! InsertOperation) return this;
    return InsertOperation(
      offset: offset,
      text: text + other.text,
      selectionBefore: selectionBefore,
      selectionAfter: other.selectionAfter,
      timestamp: other.timestamp,
    );
  }
}

class DeleteOperation extends EditOperation {
  final String text;

  DeleteOperation({
    required super.offset,
    required this.text,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  });

  @override
  EditOperation inverse() => InsertOperation(
      offset: offset, text: text, selectionBefore: selectionAfter, selectionAfter: selectionBefore);

  @override
  bool canMergeWith(EditOperation other) {
    if (other is! DeleteOperation) return false;
    final timeDiff = other.timestamp.difference(timestamp).inMilliseconds.abs();
    // Group deletion bursts within 2.5 seconds
    if (timeDiff > 2500) return false;
    if (text.contains('\n') || other.text.contains('\n')) return false;
    return (other.offset == offset - other.text.length) || (other.offset == offset);
  }

  @override
  EditOperation mergeWith(EditOperation other) {
    if (other is! DeleteOperation) return this;
    if (other.offset == offset - other.text.length) {
      return DeleteOperation(
          offset: other.offset,
          text: other.text + text,
          selectionBefore: selectionBefore,
          selectionAfter: other.selectionAfter,
          timestamp: other.timestamp);
    }
    return DeleteOperation(
        offset: offset,
        text: text + other.text,
        selectionBefore: selectionBefore,
        selectionAfter: other.selectionAfter,
        timestamp: other.timestamp);
  }
}

class ReplaceOperation extends EditOperation {
  final String deletedText;
  final String insertedText;

  ReplaceOperation({
    required super.offset,
    required this.deletedText,
    required this.insertedText,
    required super.selectionBefore,
    required super.selectionAfter,
    super.timestamp,
  });

  @override
  EditOperation inverse() => ReplaceOperation(
      offset: offset,
      deletedText: insertedText,
      insertedText: deletedText,
      selectionBefore: selectionAfter,
      selectionAfter: selectionBefore);

  @override
  bool canMergeWith(EditOperation other) => false;

  @override
  EditOperation mergeWith(EditOperation other) => this;
}

/// A compound operation that groups multiple edits into one undo unit.
class CompoundOperation extends EditOperation {
  final List<EditOperation> operations;

  CompoundOperation({
    required this.operations,
    required super.selectionBefore,
    required super.selectionAfter,
  }) : super(offset: operations.isEmpty ? 0 : operations.first.offset);

  @override
  EditOperation inverse() {
    return CompoundOperation(
      operations: operations.reversed.map((op) => op.inverse()).toList(),
      selectionBefore: selectionAfter,
      selectionAfter: selectionBefore,
    );
  }

  @override
  bool canMergeWith(EditOperation other) => false;

  @override
  EditOperation mergeWith(EditOperation other) => this;
}

class UndoRedoController extends ChangeNotifier {
  final List<HistoryEntry> _undoStack = [];
  final List<HistoryEntry> _redoStack = [];
  final int maxStackSize;

  /// Whether to group rapid sequential edits into single operations
  final bool groupEdits;
  
  /// Time interval for auto-grouping edits (default: 300ms like Zed)
  final Duration groupInterval;

  int _stackPointer = 0;
  int get stackPointer => _stackPointer;

  void Function(EditOperation operation)? _applyEdit;
  bool _isUndoRedoInProgress = false;

  /// When set, the next recorded edit will not be merged into the previous one.
  bool _suppressNextMerge = false;
  
  /// Current transaction nesting depth. 0 means no transaction is active.
  int _transactionDepth = 0;
  
  /// Lamport clock for generating edit IDs.
  final LamportClock _clock;

  UndoRedoController({
    this.maxStackSize = 1000,
    this.groupEdits = true,
    this.groupInterval = const Duration(milliseconds: 300),
    int replicaId = 0,
  }) : _clock = LamportClock(replicaId: replicaId);

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isUndoRedoInProgress => _isUndoRedoInProgress;
  
  /// Whether we're currently inside a transaction.
  bool get isInTransaction => _transactionDepth > 0;

  /// Number of operations in the undo stack.
  int get undoStackSize => _undoStack.length;

  /// Number of operations in the redo stack.
  int get redoStackSize => _redoStack.length;

  void setApplyEditCallback(void Function(EditOperation operation) callback) {
    _applyEdit = callback;
  }
  
  /// Start a new transaction. Transactions can be nested.
  /// Returns the transaction ID if this is the outermost transaction, null otherwise.
  TransactionId? startTransaction() {
    _transactionDepth++;
    if (_transactionDepth == 1) {
      final id = _clock.tick();
      _undoStack.add(HistoryEntry(
        transaction: Transaction(
          id: id,
          editIds: [],
        ),
        firstEditAt: DateTime.now(),
        lastEditAt: DateTime.now(),
        suppressGrouping: false,
      ));
      return id;
    }
    return null;
  }
  
  /// End the current transaction.
  /// Returns the transaction info if this was the outermost transaction.
  (TransactionId, DateTime)? endTransaction() {
    if (_transactionDepth == 0) return null;
    _transactionDepth--;
    
    if (_transactionDepth == 0) {
      if (_undoStack.isEmpty) return null;
      
      final entry = _undoStack.last;
      if (entry.transaction.editIds.isEmpty) {
        // Empty transaction, remove it
        _undoStack.removeLast();
        return null;
      }
      
      _redoStack.clear();
      entry.lastEditAt = DateTime.now();
      _groupTransactions();
      return (entry.transaction.id, entry.lastEditAt);
    }
    return null;
  }
  
  /// Group recent transactions based on time interval.
  void _groupTransactions() {
    int count = 0;
    if (_undoStack.isEmpty) return;
    
    HistoryEntry? entry = _undoStack.last;
    for (int i = _undoStack.length - 2; i >= 0; i--) {
      final prevEntry = _undoStack[i];
      if (!prevEntry.suppressGrouping &&
          entry!.firstEditAt.difference(prevEntry.lastEditAt) < groupInterval) {
        entry = prevEntry;
        count++;
      } else {
        break;
      }
    }
    
    if (count > 0) {
      _mergeLastNTransactions(count);
    }
  }
  
  void _mergeLastNTransactions(int n) {
    final newLen = _undoStack.length - n;
    final entriesToMerge = _undoStack.sublist(newLen);
    final lastEntry = _undoStack[newLen - 1];
    
    for (final entry in entriesToMerge) {
      lastEntry.transaction.editIds.addAll(entry.transaction.editIds);
    }
    
    if (entriesToMerge.isNotEmpty) {
      lastEntry.lastEditAt = entriesToMerge.last.lastEditAt;
    }
    
    _undoStack.removeRange(newLen, _undoStack.length);
  }
  
  /// Suppress grouping for the current transaction (won't be merged with previous).
  void finalizeLastTransaction() {
    if (_undoStack.isNotEmpty) {
      _undoStack.last.suppressGrouping = true;
    }
  }
  
  /// Merge a transaction into another destination transaction.
  void mergeTransactions(TransactionId source, TransactionId destination) {
    HistoryEntry? sourceEntry;
    HistoryEntry? destEntry;
    
    for (final entry in _undoStack) {
      if (entry.transaction.id == source) sourceEntry = entry;
      if (entry.transaction.id == destination) destEntry = entry;
    }
    
    if (sourceEntry != null && destEntry != null) {
      destEntry.transaction.editIds.addAll(sourceEntry.transaction.editIds);
      _undoStack.remove(sourceEntry);
    }
  }

  void recordEdit(EditOperation operation) {
    if (_isUndoRedoInProgress) return;
    
    // Generate edit ID
    final editId = _clock.tick();
    
    // If we're in a transaction, add to the current transaction
    if (_transactionDepth > 0 && _undoStack.isNotEmpty) {
      final entry = _undoStack.last;
      entry.transaction.editIds.add(editId);
      entry.lastEditAt = DateTime.now();
      notifyListeners();
      return;
    }
    
    _redoStack.clear();

    if (groupEdits && _undoStack.isNotEmpty && !_suppressNextMerge) {
      final last = _undoStack.last;
      final lastOp = last.transaction.editIds.isEmpty ? null : _getOperation(last);
      if (lastOp != null && lastOp.canMergeWith(operation)) {
        // Merge into existing entry, updating the stored operation so that
        // undo correctly inverts the full accumulated edit (not just the first).
        last.transaction.operation = lastOp.mergeWith(operation);
        last.transaction.editIds.add(editId);
        last.lastEditAt = DateTime.now();
        _suppressNextMerge = false;
        notifyListeners();
        return;
      }
    }
    _suppressNextMerge = false;

    _undoStack.add(HistoryEntry(
      transaction: Transaction(
        id: editId,
        editIds: [editId],
        operation: operation,
      ),
      firstEditAt: DateTime.now(),
      lastEditAt: DateTime.now(),
      suppressGrouping: false,
    ));
    _stackPointer++;
    if (_undoStack.length > maxStackSize) _undoStack.removeAt(0);
    notifyListeners();
  }
  
  EditOperation? _getOperation(HistoryEntry entry) {
    return entry.transaction.operation;
  }

  bool undo() {
    if (!canUndo || _applyEdit == null) return false;
    final entry = _undoStack.removeLast();
    _isUndoRedoInProgress = true;
    try {
      final op = entry.transaction.operation;
      if (op != null) {
        _applyEdit!(op.inverse());
      }
      _redoStack.add(entry);
      _stackPointer--;
    } finally {
      _isUndoRedoInProgress = false;
    }
    notifyListeners();
    return true;
  }

  bool redo() {
    if (!canRedo || _applyEdit == null) return false;
    final entry = _redoStack.removeLast();
    _isUndoRedoInProgress = true;
    try {
      final op = entry.transaction.operation;
      if (op != null) {
        _applyEdit!(op);
      }
      _undoStack.add(entry);
      _stackPointer++;
    } finally {
      _isUndoRedoInProgress = false;
    }
    notifyListeners();
    return true;
  }
  
  /// Undo a specific transaction by ID.
  bool undoTransaction(TransactionId transactionId) {
    final index = _undoStack.indexWhere((e) => e.transaction.id == transactionId);
    if (index < 0 || _applyEdit == null) return false;
    
    final entry = _undoStack.removeAt(index);
    _isUndoRedoInProgress = true;
    try {
      final op = entry.transaction.operation;
      if (op != null) {
        _applyEdit!(op.inverse());
      }
      _redoStack.add(entry);
    } finally {
      _isUndoRedoInProgress = false;
    }
    notifyListeners();
    return true;
  }
  
  /// Get the transaction for a given ID.
  Transaction? getTransaction(TransactionId transactionId) {
    for (final entry in _undoStack) {
      if (entry.transaction.id == transactionId) {
        return entry.transaction;
      }
    }
    for (final entry in _redoStack) {
      if (entry.transaction.id == transactionId) {
        return entry.transaction;
      }
    }
    return null;
  }
  
  /// Remove a transaction from history without undoing it.
  Transaction? forgetTransaction(TransactionId transactionId) {
    var index = _undoStack.indexWhere((e) => e.transaction.id == transactionId);
    if (index >= 0) {
      return _undoStack.removeAt(index).transaction;
    }
    index = _redoStack.indexWhere((e) => e.transaction.id == transactionId);
    if (index >= 0) {
      return _redoStack.removeAt(index).transaction;
    }
    return null;
  }

  /// Clear all undo/redo history
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    _stackPointer = 0;
    notifyListeners();
  }

  /// Begin a compound operation that should be undone as a single unit.
  CompoundOperationHandle beginCompoundOperation() {
    _suppressNextMerge = true;
    return CompoundOperationHandle._(this);
  }

}

/// A transaction groups multiple edits into one undo unit.
class Transaction {
  final TransactionId id;
  final List<LamportTimestamp> editIds;
  
  /// The combined operation for this transaction (for simple cases).
  EditOperation? operation;
  
  Transaction({
    required this.id,
    required this.editIds,
    this.operation,
  });
}

/// An entry in the undo/redo history.
class HistoryEntry {
  final Transaction transaction;
  final DateTime firstEditAt;
  DateTime lastEditAt;
  bool suppressGrouping;
  
  HistoryEntry({
    required this.transaction,
    required this.firstEditAt,
    required this.lastEditAt,
    required this.suppressGrouping,
  });
  
  TransactionId get transactionId => transaction.id;
}

/// Handle for grouping multiple edits into a single undo operation.
/// Uses the transaction system to combine operations.
class CompoundOperationHandle {
  final UndoRedoController _controller;
  /// The transaction ID for this compound operation, if created.
  final TransactionId? transactionId;
  bool _isActive = true;

  CompoundOperationHandle._(this._controller)
      : transactionId = _controller.startTransaction();

  void end() {
    if (!_isActive) return;
    _isActive = false;
    _controller.endTransaction();
  }
}