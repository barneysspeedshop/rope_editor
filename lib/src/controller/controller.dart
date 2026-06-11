import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rope_editor/src/rope/rope.dart';
import 'package:rope_editor/src/rust/api.dart' show MinimapLineDensity;
import 'package:rope_editor/src/styling.dart';
import 'package:rope_editor/src/rope/undo_redo.dart';

class RopeEditorController extends ChangeNotifier implements DeltaTextInputClient {
  static const _imeProjectionMaxChars = 4096;

  Rope _rope = Rope('');

  bool _isDisposed = false;

  /// Whether the controller has been disposed.
  bool get isDisposed => _isDisposed;

  // PERFORMANCE: Cache length to avoid FFI calls on every keystroke
  int _cachedLength = 0;

  TextSelection _selection = const TextSelection.collapsed(offset: 0);
  FocusNode? focusNode;

  /// When true, [scrollToLine] is suppressed. Used while restoring a saved viewport.
  bool suppressAutoScroll = false;

  /// Called when the platform closes the IME connection (e.g. Android back
  /// dismisses the soft keyboard while focus remains on the editor).
  VoidCallback? onConnectionClosed;

  /// Called when the soft keyboard input connection is opened or re-shown.
  VoidCallback? onInputConnectionShown;

  TextInputConnection? _connection;
  TextInputConnection? get connection => _connection;
  set connection(TextInputConnection? value) {
    if (identical(_connection, value)) return;
    _connection = value;

    // On first focus after a pointer click, selection may already have moved
    // before the platform connection is attached. Push the latest projection
    // immediately so the first typed character lands at the visible caret.
    if (_connection != null && _connection!.attached) {
      _imeProjectionDirty = true;
      _syncToConnection();
    }
  }

  String? _openedFile;

  UndoRedoController? _undoController;

  // High performance state tracking
  int _version = 0;
  int _lastSavedStackPointer = 0;
  int? _lastSavedHash;
  int? _cachedHash;
  int? _cachedHashVersion;

  /// Stores the offset of the most recently modified location.
  /// The line number is computed lazily via dirtyLine getter to avoid expensive FFI call.
  int? _dirtyOffset;

  /// The index of the line that was most recently modified.
  /// Computed lazily from _dirtyOffset to avoid FFI call on every keystroke.
  int? get dirtyLine => _dirtyOffset != null ? _rope.getLineAtOffset(_dirtyOffset!) : null;

  /// Cache the last cursor line to avoid redundant scroll calls
  int? _lastCursorLine;
  int? _lastCursorOffset;

  /// Whether the line count or structure changed (e.g. newline inserted/deleted).
  bool lineStructureChanged = false;

  String _imeProjectionText = '';
  int _imeProjectionStartOffset = 0;
  bool _imeProjectionDirty = true;
  bool _suppressImeSync = false;
  TextSelection _imeProjectionSelection = const TextSelection.collapsed(offset: 0);

  /// Stores the preferred horizontal column index during vertical navigation.
  /// This is reset when the user moves the cursor horizontally or modifies text.
  int? _verticalColumnMemory;

  /// List of search highlights to display in the editor.
  List<SearchHighlight> searchHighlights = [];

  /// Whether the search highlights have changed and need repaint.
  bool searchHighlightsChanged = false;

  void Function(int line, bool center)? _scrollToLineCallback;

  /// Callback to reset the cursor blink animation.
  VoidCallback? requestCursorReset;

  /// Exposes the underlying rope data structure.
  Rope get rope => _rope;

  /// The current version of the document content.
  int get documentVersion => _version;

  double _viewportHeight = 0;

  /// The current visible height of the editor viewport.
  double get viewportHeight => _viewportHeight;

  set viewportHeight(double value) {
    if (value <= 0 || (_viewportHeight - value).abs() < 1.0) return;
    _viewportHeight = value;
    // PERFORMANCE: Defer notification to ensure we don't trigger rebuilds
    // while the framework is in the middle of a layout or build pass.
    Future.microtask(() {
      if (!isDisposed) notifyListeners();
    });
  }

  double _lineHeight = 1.0;

  /// The current height of a single line of text, used for page navigation.
  double get lineHeight => _lineHeight;
  set lineHeight(double value) {
    if (value > 0) _lineHeight = value;
  }

  double _viewportWidth = 0;

  /// The current visible width of the editor viewport.
  double get viewportWidth => _viewportWidth;
  set viewportWidth(double value) {
    if (value <= 0 || (_viewportWidth - value).abs() < 1.0) return;
    _viewportWidth = value;
  }

  RopeEditorController({String text = '', UndoRedoController? undoController}) {
    _rope = Rope(text);
    _cachedLength = text.length;
    // PERFORMANCE & UX: Ensure undo/redo is available by default.
    _undoController = undoController ?? UndoRedoController();
    _undoController!.setApplyEditCallback(_applyUndoRedoOperation);
  }

  String get text => _rope.getText();
  set text(String value) {
    _rope = Rope(value);
    _cachedLength = value.length;
    _version++;
    // Signal to the renderer to flush the entire cache for the new content.
    lineStructureChanged = true;
    _dirtyOffset = null;
    searchHighlights = [];
    searchHighlightsChanged = true;
    _selection = const TextSelection.collapsed(offset: 0);
    _imeProjectionDirty = true;
    notifyListeners();
  }

  /// Async version of text setter that doesn't block UI thread
  /// When loading a file, also clears undo history and marks as clean
  Future<void> setTextAsync(String value, {bool isFileLoad = false}) async {
    _rope = await Rope.createAsync(value);
    _cachedLength = value.length;
    _version++;
    lineStructureChanged = true;
    _dirtyOffset = null;
    searchHighlights = [];
    searchHighlightsChanged = true;
    _selection = const TextSelection.collapsed(offset: 0);
    _imeProjectionDirty = true;

    if (isFileLoad) {
      // Clear history when loading files to prevent corrupting text
      // by applying edits from a previous document.
      _undoController?.clear();
      _lastSavedStackPointer = 0;
      _lastSavedHash = _calculateHash();
    }

    notifyListeners();
  }

  /// Load content directly from a file path without reading into Dart first.
  /// Most efficient method for large files, especially single-line files.
  /// Streams the file through the Rust backend without loading it into Dart first.
  ///
  /// For single-line files, pass maxChars to limit loading (viewport buffering).
  Future<void> loadFromFile(String path, {int? maxChars}) async {
    _rope = await Rope.fromFile(path, maxChars: maxChars);
    _cachedLength = _rope.length;
    _version++;
    lineStructureChanged = true;
    _dirtyOffset = null;
    searchHighlights = [];
    searchHighlightsChanged = true;
    _selection = const TextSelection.collapsed(offset: 0);
    _imeProjectionDirty = true;

    // Clear history when loading files
    _undoController?.clear();
    _lastSavedStackPointer = 0;
    _lastSavedHash = _calculateHash();
    _openedFile = path;

    notifyListeners();
  }

  TextSelection get selection => _selection;
  set selection(TextSelection value) {
    _updateSelection(value, clearColumnMemory: true);
  }

  void _updateSelection(TextSelection value, {bool clearColumnMemory = true}) {
    if (clearColumnMemory) _verticalColumnMemory = null;
    _selection = value;
    _rope.setSelection(value);
    _imeProjectionDirty = true;
    _syncToConnection();

    scrollToLine(getLineAtOffset(value.extentOffset));

    // PERFORMANCE: Use requestCursorReset to sync animations
    // and notifyListeners to trigger the renderer's paint loop.
    requestCursorReset?.call();
    notifyListeners();
  }

  /// The total length of the document in characters.
  int get length => _cachedLength;

  /// The total number of lines in the document.
  int get lineCount => _rope.lineCount;

  /// Gets the text content of a specific line.
  String getLineText(int lineIndex) => _rope.getLineText(lineIndex);

  /// Batch API: Gets the text content of multiple lines in a single FFI call.
  /// This is much more efficient than calling getLineText in a loop.
  List<String> getLinesTextBatch(List<int> lineIndices) => _rope.getLinesTextBatch(lineIndices);

  /// Batch API: Returns UTF-16 start offsets for a contiguous range of lines.
  /// O(n) total using a forward cursor walk instead of O(n log n) from
  /// individual getLineStartOffset calls. Critical for paint loop performance.
  List<int> getLineStartOffsetsBatch(int startLine, int endLine) => _rope.getLineStartOffsetsBatch(startLine, endLine);

  /// Batch API: Returns minimap density data for multiple lines without
  /// serializing full line strings. Computes leading whitespace, content
  /// length, and emptiness directly on the Rust side.
  List<MinimapLineDensity> getMinimapDensityBatch(List<int> lineIndices) => _rope.getMinimapDensityBatch(lineIndices);

  /// Gets the line number for a character offset.
  int getLineAtOffset(int charOffset) => _rope.getLineAtOffset(charOffset);

  /// Gets the character offset where a line starts.
  int getLineStartOffset(int lineIndex) => _rope.getLineStartOffset(lineIndex);

  /// Sets the selection immediately and syncs with the platform.
  void setSelectionSilently(TextSelection newSelection) {
    if (_selection == newSelection) return;
    _selection = newSelection;
    _imeProjectionDirty = true;
    _syncToConnection();
    scrollToLine(getLineAtOffset(newSelection.extentOffset));
    notifyListeners();
  }

  /// Scrolls the editor to the specified line.
  void scrollToLine(int line, {bool center = false}) {
    if (suppressAutoScroll) return;
    _scrollToLineCallback?.call(line, center);
    _lastCursorLine = line;
  }

  /// HIGH-PERFORMANCE: Scroll to cursor using pre-computed line from batch API.
  /// Eliminates separate getLineAtOffset() FFI call during text editing.
  void _maybeScrollToCursorWithContext(int cursorLine) {
    final currentOffset = _selection.extentOffset;
    // Always scroll when the cursor moves — even within the same line — so
    // the horizontal viewport tracks the cursor when typing long lines.
    if (cursorLine != _lastCursorLine || currentOffset != _lastCursorOffset) {
      scrollToLine(cursorLine);
    }
    _lastCursorOffset = currentOffset;
  }

  /// Efficiently scroll to cursor position, only if line changed.
  /// Used for navigation operations that don't have pre-computed context.
  // ignore: unused_element - Kept for future navigation operations
  void _maybeScrollToCursor() {
    // OPTIMIZATION: Only compute line number if offset changed significantly
    final offset = _selection.extentOffset;

    // If offset barely changed (typing on same line), skip expensive computation
    if (_lastCursorOffset != null && (offset - _lastCursorOffset!).abs() < 80) {
      // Likely same line, no scroll needed
      return;
    }

    // Offset changed significantly, compute line and scroll if different
    final line = _rope.getLineAtOffset(offset);
    if (line != _lastCursorLine) {
      scrollToLine(line);
    }
    _lastCursorOffset = offset;
  }

  void setScrollCallback(void Function(int line, bool center)? scrollToLine) {
    _scrollToLineCallback = scrollToLine;
  }

  bool get isDirty {
    // Shortcut: If we are at the same position in history, we are likely clean.
    if ((_undoController?.stackPointer ?? 0) == _lastSavedStackPointer) {
      // PERFORMANCE: Only compute hash if stack pointer matches (rare case)
      // Most of the time we return true without FFI call
      return _calculateHash() != _lastSavedHash;
    }
    // Stack pointer differs, definitely dirty - no hash needed
    return true;
  }

  int _calculateHash() {
    if (_cachedHashVersion != _version) {
      // PERFORMANCE: Compute hash on Rust side to avoid copying
      // large text content to Dart just for dirty checking.
      _cachedHash = _rope.getContentHash();
      _cachedHashVersion = _version;
    }
    return _cachedHash!;
  }

  void recordSavedState() {
    _lastSavedStackPointer = _undoController?.stackPointer ?? 0;
    _lastSavedHash = _calculateHash();
    notifyListeners();
  }

  String? get openedFile => _openedFile;

  set openedFile(String? path) {
    _openedFile = path;
    if (path != null && !path.startsWith('content://')) {
      text = File(path).readAsStringSync();
      // Clear history when switching files to prevent corrupting text
      // by applying edits from a previous document.
      _undoController?.clear();
      _lastSavedStackPointer = 0;
      _lastSavedHash = _calculateHash();
      notifyListeners();
    }
  }

  /// Disposes of the controller and releases input resources.
  @override
  void dispose() {
    _isDisposed = true;
    connection?.close();
    connection = null;
    super.dispose();
  }

  /// Sets the undo controller and registers the mutation callback.
  void setUndoController(UndoRedoController? controller) {
    _undoController = controller;
    controller?.setApplyEditCallback(_applyUndoRedoOperation);
  }

  void _applyUndoRedoOperation(EditOperation operation) {
    void apply(EditOperation op) {
      switch (op) {
        case InsertOperation(:final offset, :final text):
          _rope.insert(offset, text);
          _cachedLength += text.length;
        case DeleteOperation(:final offset, :final text):
          _rope.delete(offset, offset + text.length);
          _cachedLength -= text.length;
        case ReplaceOperation(:final offset, :final deletedText, :final insertedText):
          _rope.delete(offset, offset + deletedText.length);
          _rope.insert(offset, insertedText);
          _cachedLength = _cachedLength - deletedText.length + insertedText.length;
        case CompoundOperation(:final operations):
          for (final subOp in operations) {
            apply(subOp);
          }
      }
    }

    bool affectsMultipleLines(EditOperation op) {
      return switch (op) {
        InsertOperation(:final text) => text.contains('\n'),
        DeleteOperation(:final text) => text.contains('\n'),
        ReplaceOperation(:final deletedText, :final insertedText) => deletedText.contains('\n') || insertedText.contains('\n'),
        CompoundOperation(:final operations) => operations.any(affectsMultipleLines),
      };
    }

    final int oldLineCount = _rope.lineCount;
    _version++;
    apply(operation);

    // Signal to the renderer that content changed
    lineStructureChanged = _rope.lineCount != oldLineCount || affectsMultipleLines(operation);
    _dirtyOffset = lineStructureChanged ? null : operation.offset;
    searchHighlightsChanged = true;

    _selection = operation.selectionAfter;
    _imeProjectionDirty = true;
    _syncToConnection();
    // PERFORMANCE: Skip scroll during typing, only scroll on explicit navigation
    // _maybeScrollToCursor();
    notifyListeners();
  }

  // --- Text Operations ---

  void replaceRange(int start, int end, String replacement, {TextSelection? selectionAfter}) {
    final TextSelection selectionBefore = _selection;
    final int oldLineCount = _rope.lineCount;
    _verticalColumnMemory = null;
    // OPTIMIZATION: Store offset instead of computing line number
    // The line number will be computed lazily only when cache invalidation needs it
    _dirtyOffset = start;

    // HIGH-PERFORMANCE: Single FFI call combines:
    // - replace operation
    // - capturing deleted text for undo
    // - computing cursor context (line, column, offsets)
    // This eliminates the expensive substring() call that was 82% of CPU time.
    final result = _rope.replaceAndCapture(start, end, replacement);
    final String deletedText = result.deletedText;

    // Update cached length from result (already computed in Rust)
    _cachedLength = result.newLength;

    final newSelection = selectionAfter ?? TextSelection.collapsed(offset: start + replacement.length);
    _selection = newSelection;

    // Record edit for undo/redo
    if (!(_undoController?.isUndoRedoInProgress ?? false)) {
      if (deletedText.isNotEmpty && replacement.isNotEmpty) {
        _undoController?.recordEdit(ReplaceOperation(
          offset: start,
          deletedText: deletedText,
          insertedText: replacement,
          selectionBefore: selectionBefore,
          selectionAfter: newSelection,
        ));
      } else if (deletedText.isNotEmpty) {
        _undoController?.recordEdit(DeleteOperation(
          offset: start,
          text: deletedText,
          selectionBefore: selectionBefore,
          selectionAfter: newSelection,
        ));
      } else if (replacement.isNotEmpty) {
        _undoController?.recordEdit(InsertOperation(
          offset: start,
          text: replacement,
          selectionBefore: selectionBefore,
          selectionAfter: newSelection,
        ));
      }
    }

    lineStructureChanged = (_rope.lineCount != oldLineCount) || deletedText.contains('\n') || replacement.contains('\n');
    _version++;
    _imeProjectionDirty = true;

    // HIGH-PERFORMANCE: Use cursor line from replaceAndCapture result
    // instead of computing it separately. Avoids extra getLineAtOffset call.
    _maybeScrollToCursorWithContext(result.cursorLine);

    // Sync with IME to ensure the OS keyboard knows where the caret moved.
    _syncToConnection();
    notifyListeners();
  }

  /// Consumes the dirty flags after they have been processed by the renderer.
  void clearDirtyRegion() {
    _dirtyOffset = null;
    lineStructureChanged = false;
    searchHighlightsChanged = false;
  }

  void backspace() {
    if (_selection.start > 0 || !_selection.isCollapsed) {
      final start = _selection.isCollapsed ? _selection.start - 1 : _selection.start;
      replaceRange(start, _selection.end, '');
    }
  }

  void delete() {
    if (_selection.start < _rope.length || !_selection.isCollapsed) {
      final end = _selection.isCollapsed ? _selection.start + 1 : _selection.end;
      replaceRange(_selection.start, end, '');
    }
  }

  // --- Clipboard ---

  void copy() {
    if (!_selection.isCollapsed) {
      Clipboard.setData(ClipboardData(text: _rope.substring(_selection.start, _selection.end)));
    }
  }

  void cut() {
    copy();
    replaceRange(_selection.start, _selection.end, '');
  }

  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      replaceRange(_selection.start, _selection.end, data!.text!);
    }
  }

  void selectAll() {
    selection = TextSelection(baseOffset: 0, extentOffset: _rope.length);
  }

  /// Inserts [indent] at the cursor, or indents every selected line when the
  /// selection spans multiple lines.
  void indentSelection(String indent) {
    if (indent.isEmpty) return;

    final (startLine, lastLine) = _meaningfulSelectedLineRange();
    final selectedText = _selection.isCollapsed
        ? ''
        : _rope.substring(_selection.start, _selection.end);
    final useBlockIndent = startLine != lastLine || selectedText.contains('\n');
    if (!useBlockIndent) {
      replaceRange(_selection.start, _selection.end, indent);
      return;
    }

    final rangeStart = _rope.getLineStartOffset(startLine);
    final rangeEnd = lastLine < lineCount - 1
        ? _rope.getLineStartOffset(lastLine + 1)
        : _cachedLength;
    final oldText = _rope.substring(rangeStart, rangeEnd);
    final newText = _indentBlockText(oldText, indent);
    final newSelection = TextSelection(
      baseOffset: _adjustOffsetForBlockIndent(
        _selection.baseOffset,
        rangeStart,
        rangeEnd,
        oldText,
        indent.length,
      ),
      extentOffset: _adjustOffsetForBlockIndent(
        _selection.extentOffset,
        rangeStart,
        rangeEnd,
        oldText,
        indent.length,
      ),
    );
    replaceRange(rangeStart, rangeEnd, newText, selectionAfter: newSelection);
  }

  /// Removes one indent level from the current line, or from every selected
  /// line when the selection spans multiple lines.
  void outdentSelection(int tabSpaces) {
    if (tabSpaces <= 0) return;

    final (startLine, lastLine) = _meaningfulSelectedLineRange();
    if (startLine == lastLine) {
      final lineStart = _rope.getLineStartOffset(startLine);
      final lineEnd = startLine < lineCount - 1
          ? _rope.getLineStartOffset(startLine + 1)
          : _cachedLength;
      final lineText = _rope.substring(lineStart, lineEnd);
      final hasTrailingNewline = lineText.endsWith('\n');
      final content = hasTrailingNewline ? lineText.substring(0, lineText.length - 1) : lineText;
      final prefix = _leadingIndentToRemove(content, tabSpaces);
      if (prefix.isEmpty) return;

      final newLineText = content.substring(prefix.length) + (hasTrailingNewline ? '\n' : '');
      final newSelection = TextSelection(
        baseOffset: _adjustOffsetForBlockOutdent(
          _selection.baseOffset,
          lineStart,
          lineEnd,
          lineText,
          [prefix.length],
        ),
        extentOffset: _adjustOffsetForBlockOutdent(
          _selection.extentOffset,
          lineStart,
          lineEnd,
          lineText,
          [prefix.length],
        ),
      );
      replaceRange(lineStart, lineEnd, newLineText, selectionAfter: newSelection);
      return;
    }

    final rangeStart = _rope.getLineStartOffset(startLine);
    final rangeEnd = lastLine < lineCount - 1
        ? _rope.getLineStartOffset(lastLine + 1)
        : _cachedLength;
    final oldText = _rope.substring(rangeStart, rangeEnd);
    final (newText, removedPerLine) = _outdentBlockText(oldText, tabSpaces);
    if (newText == oldText) return;

    final newSelection = TextSelection(
      baseOffset: _adjustOffsetForBlockOutdent(
        _selection.baseOffset,
        rangeStart,
        rangeEnd,
        oldText,
        removedPerLine,
      ),
      extentOffset: _adjustOffsetForBlockOutdent(
        _selection.extentOffset,
        rangeStart,
        rangeEnd,
        oldText,
        removedPerLine,
      ),
    );
    replaceRange(rangeStart, rangeEnd, newText, selectionAfter: newSelection);
  }

  /// Returns the first and last line numbers whose non-newline content overlaps
  /// the current selection. Lines that only touch the selection through a
  /// boundary newline are excluded.
  (int startLine, int lastLine) _meaningfulSelectedLineRange() {
    final selStart = _selection.start;
    final selEnd = _selection.end;
    int? firstLine;
    int? lastLine;

    for (var line = 0; line < lineCount; line++) {
      if (!_lineHasMeaningfulSelectionOverlap(line, selStart, selEnd)) continue;
      firstLine ??= line;
      lastLine = line;
    }

    if (firstLine == null) {
      final line = _rope.getLineAtOffset(selStart);
      return (line, line);
    }
    return (firstLine, lastLine!);
  }

  bool _lineHasMeaningfulSelectionOverlap(int line, int selStart, int selEnd) {
    final lineStart = _rope.getLineStartOffset(line);
    final lineEnd = line < lineCount - 1
        ? _rope.getLineStartOffset(line + 1)
        : _cachedLength;

    final overlapStart = selStart > lineStart ? selStart : lineStart;
    final overlapEnd = selEnd < lineEnd ? selEnd : lineEnd;
    if (overlapStart >= overlapEnd) return false;

    // Ignore overlaps that only cover the line's trailing newline.
    final contentEnd = line < lineCount - 1 && lineEnd > lineStart
        ? lineEnd - 1
        : lineEnd;
    return overlapStart < contentEnd;
  }

  String _indentBlockText(String text, String indent) {
    final buffer = StringBuffer();
    var pos = 0;
    // Only start a new line while there is still text to indent. Without this
    // guard, block text ending in '\n' would get a stray indent written after
    // the final newline (i.e. at the start of the next document line).
    while (pos < text.length) {
      buffer.write(indent);
      final newlineIndex = text.indexOf('\n', pos);
      if (newlineIndex == -1) {
        buffer.write(text.substring(pos));
        break;
      }
      buffer.write(text.substring(pos, newlineIndex + 1));
      pos = newlineIndex + 1;
    }
    return buffer.toString();
  }

  (String text, List<int> removedPerLine) _outdentBlockText(String text, int tabSpaces) {
    final removedPerLine = <int>[];
    final buffer = StringBuffer();
    var pos = 0;
    while (true) {
      final newlineIndex = text.indexOf('\n', pos);
      final lineEnd = newlineIndex == -1 ? text.length : newlineIndex;
      final line = text.substring(pos, lineEnd);
      final prefix = _leadingIndentToRemove(line, tabSpaces);
      removedPerLine.add(prefix.length);
      buffer.write(line.substring(prefix.length));
      if (newlineIndex == -1) break;
      buffer.write('\n');
      pos = newlineIndex + 1;
    }
    return (buffer.toString(), removedPerLine);
  }

  String _leadingIndentToRemove(String line, int tabSpaces) {
    if (line.isEmpty) return '';
    if (line.startsWith('\t')) return '\t';

    var spaces = 0;
    while (spaces < tabSpaces && spaces < line.length && line[spaces] == ' ') {
      spaces++;
    }
    return spaces > 0 ? line.substring(0, spaces) : '';
  }

  int _adjustOffsetForBlockIndent(
    int offset,
    int rangeStart,
    int rangeEnd,
    String oldText,
    int indentLength,
  ) {
    if (offset < rangeStart) return offset;

    final linesAffected = '\n'.allMatches(oldText).length + 1;
    if (offset >= rangeEnd) return offset + indentLength * linesAffected;

    final localOffset = offset - rangeStart;
    final lineIndex = '\n'.allMatches(oldText.substring(0, localOffset)).length;
    return offset + indentLength * (lineIndex + 1);
  }

  int _adjustOffsetForBlockOutdent(
    int offset,
    int rangeStart,
    int rangeEnd,
    String oldText,
    List<int> removedPerLine,
  ) {
    if (offset < rangeStart) return offset;

    final totalRemoved = removedPerLine.fold<int>(0, (sum, removed) => sum + removed);
    if (offset >= rangeEnd) return offset - totalRemoved;

    final localOffset = offset - rangeStart;
    final lineIndex = '\n'.allMatches(oldText.substring(0, localOffset)).length;

    var removedBefore = 0;
    for (var i = 0; i < lineIndex; i++) {
      removedBefore += removedPerLine[i];
    }

    final lineStartInOld = lineIndex == 0 ? 0 : oldText.lastIndexOf('\n', localOffset - 1) + 1;
    final offsetInLine = localOffset - lineStartInOld;
    final currentRemoved = removedPerLine[lineIndex];

    if (offsetInLine <= currentRemoved) {
      return offset - removedBefore - offsetInLine;
    }
    return offset - removedBefore - currentRemoved;
  }

  // --- Navigation ---

  /// Moves the cursor vertically by a specific number of lines.
  ///
  /// [lineDelta] can be positive (down) or negative (up).
  void _moveCursorVertically(int lineDelta, bool isShiftPressed) {
    final int currentExtent = _selection.extentOffset;
    final int currentLine = _rope.getLineAtOffset(currentExtent);
    final int targetLine = (currentLine + lineDelta).clamp(0, lineCount - 1);

    // Handle edge cases: pressing up on first line goes to start,
    // pressing down on last line goes to end of that line
    if (targetLine == currentLine && lineDelta != 0) {
      int newOffset;
      if (lineDelta < 0) {
        // Pressing up on line 0: go to position 0
        newOffset = 0;
      } else {
        // Pressing down on last line: go to end of line
        final int lineEnd = (currentLine < lineCount - 1) ? _rope.getLineStartOffset(currentLine + 1) : _rope.length;
        newOffset = lineEnd;
        // Don't land on the newline character if present
        if (newOffset > 0 && currentLine < lineCount - 1) {
          final lastChar = _rope.substring(newOffset - 1, newOffset);
          if (lastChar == '\n') newOffset--;
        }
      }
      _updateSelection(
        isShiftPressed ? _selection.copyWith(extentOffset: newOffset) : TextSelection.collapsed(offset: newOffset),
        clearColumnMemory: true,
      );
      return;
    }

    // Initialize column memory if we're starting a vertical movement sequence
    if (_verticalColumnMemory == null) {
      final int currentLineStart = _rope.getLineStartOffset(currentLine);
      _verticalColumnMemory = currentExtent - currentLineStart;
    }

    final int targetLineStart = _rope.getLineStartOffset(targetLine);
    final int targetLineEnd = (targetLine < lineCount - 1) ? _rope.getLineStartOffset(targetLine + 1) : _rope.length;

    // Efficiently calculate max column without allocating a string.
    // We subtract 1 if the line ends in a newline to avoid landing on it.
    int maxColumn = targetLineEnd - targetLineStart;
    if (maxColumn > 0 && targetLine < lineCount - 1) {
      final lastChar = _rope.substring(targetLineEnd - 1, targetLineEnd);
      if (lastChar == '\n') maxColumn--;
    }

    final int newOffset = targetLineStart + _verticalColumnMemory!.clamp(0, maxColumn);

    _updateSelection(
      isShiftPressed ? _selection.copyWith(extentOffset: newOffset) : TextSelection.collapsed(offset: newOffset),
      clearColumnMemory: false,
    );
  }

  void pressLeftArrowKey({bool isShiftPressed = false}) {
    final newOffset = (_selection.extentOffset - 1).clamp(0, _rope.length);
    _updateSelection(
      isShiftPressed ? _selection.copyWith(extentOffset: newOffset) : TextSelection.collapsed(offset: newOffset),
      clearColumnMemory: true,
    );
  }

  void pressRightArrowKey({bool isShiftPressed = false}) {
    final newOffset = (_selection.extentOffset + 1).clamp(0, _rope.length);
    _updateSelection(
      isShiftPressed ? _selection.copyWith(extentOffset: newOffset) : TextSelection.collapsed(offset: newOffset),
      clearColumnMemory: true,
    );
  }

  void pressLeftWordArrowKey({bool isShiftPressed = false}) {
    final int currentOffset = _selection.extentOffset.clamp(0, _rope.length);
    int newOffset = _rope.findWordBoundary(currentOffset, forward: false).clamp(0, _rope.length);

    // The rope boundary API intentionally treats line endings as hard boundaries.
    // If we are at the beginning of a line, it may return the same offset.
    // For editor UX, Ctrl/Cmd+Left should continue to the previous word.
    if (newOffset == currentOffset && currentOffset > 0) {
      int probe = currentOffset - 1;

      // Skip backwards across newline and whitespace so we land on content
      // from the previous word run.
      while (probe > 0) {
        final int charClass = _rope.charClassAt(probe);
        if (charClass == Rope.charClassLineEnding || charClass == Rope.charClassWhitespace) {
          probe--;
          continue;
        }
        break;
      }

      newOffset = _rope.findWordBoundary(probe, forward: false).clamp(0, _rope.length);
    }

    _updateSelection(
      isShiftPressed ? _selection.copyWith(extentOffset: newOffset) : TextSelection.collapsed(offset: newOffset),
      clearColumnMemory: true,
    );
  }

  void pressRightWordArrowKey({bool isShiftPressed = false}) {
    final int currentOffset = _selection.extentOffset.clamp(0, _rope.length);
    int newOffset = _rope.findWordBoundary(currentOffset, forward: true).clamp(0, _rope.length);

    // The rope boundary API intentionally stops at line endings.
    // If we are at end-of-line, continue to the next line's first word.
    if (newOffset == currentOffset && currentOffset < _rope.length) {
      int probe = currentOffset + 1;

      // Skip newline and indentation whitespace to reach the next token start.
      while (probe < _rope.length) {
        final int charClass = _rope.charClassAt(probe);
        if (charClass == Rope.charClassLineEnding || charClass == Rope.charClassWhitespace) {
          probe++;
          continue;
        }
        break;
      }

      newOffset = probe.clamp(0, _rope.length);
    }

    _updateSelection(
      isShiftPressed ? _selection.copyWith(extentOffset: newOffset) : TextSelection.collapsed(offset: newOffset),
      clearColumnMemory: true,
    );
  }

  void pressUpArrowKey({bool isShiftPressed = false}) => _moveCursorVertically(-1, isShiftPressed);
  void pressDownArrowKey({bool isShiftPressed = false}) => _moveCursorVertically(1, isShiftPressed);

  void pressHomeKey({bool isShiftPressed = false}) {
    final currentLine = _rope.getLineAtOffset(_selection.extentOffset);
    final newOffset = _rope.getLineStartOffset(currentLine);
    _updateSelection(
      isShiftPressed ? _selection.copyWith(extentOffset: newOffset) : TextSelection.collapsed(offset: newOffset),
      clearColumnMemory: true,
    );
  }

  void pressEndKey({bool isShiftPressed = false}) {
    final currentLine = _rope.getLineAtOffset(_selection.extentOffset);
    final int lineEnd = (currentLine < lineCount - 1) ? _rope.getLineStartOffset(currentLine + 1) : _cachedLength;

    int newOffset = lineEnd;
    if (currentLine < lineCount - 1 && _rope.substring(lineEnd - 1, lineEnd) == '\n') {
      newOffset--;
    }

    _updateSelection(
      isShiftPressed ? _selection.copyWith(extentOffset: newOffset) : TextSelection.collapsed(offset: newOffset),
      clearColumnMemory: true,
    );
  }

  void pressPageUpKey({required bool isShiftPressed}) {
    final int jump = (_viewportHeight / _lineHeight).floor().clamp(1, lineCount);
    _moveCursorVertically(-jump, isShiftPressed);
  }

  void pressPageDownKey({required bool isShiftPressed}) {
    final int jump = (_viewportHeight / _lineHeight).floor().clamp(1, lineCount);
    _moveCursorVertically(jump, isShiftPressed);
  }

  // --- Undo/Redo ---
  void undo() {
    _undoController?.undo();
  }

  void redo() {
    _undoController?.redo();
  }

  // --- TextInputClient Overrides ---

  @override
  void connectionClosed() {
    connection = null;
    onConnectionClosed?.call();
  }

  @override
  void didChangeInputControl(TextInputControl? oldControl, TextInputControl? newControl) {}

  @override
  void insertContent(KeyboardInsertedContent content) {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void performAction(TextInputAction action) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void performSelector(String selectorName) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void showToolbar() {}

  @override
  void updateEditingValue(TextEditingValue value) {}

  @override
  bool onFocusReceived() => true;

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  AutofillScope? get currentAutofillScope => null;

  void _syncToConnection() {
    if (_suppressImeSync) return;
    if (connection != null && connection!.attached) {
      _ensureImeProjection();
      final safeSelection = _clampSelectionToText(
        _imeProjectionSelection,
        _imeProjectionText.length,
      );
      connection!.setEditingState(TextEditingValue(
        text: _imeProjectionText,
        selection: safeSelection,
      ));
    }
  }

  TextSelection _clampSelectionToText(TextSelection selection, int textLength) {
    return TextSelection(
      baseOffset: selection.baseOffset.clamp(0, textLength),
      extentOffset: selection.extentOffset.clamp(0, textLength),
    );
  }

  void _ensureImeProjection() {
    if (!_imeProjectionDirty) return;

    // OPTIMIZATION: Use cached length to avoid FFI call
    final documentLength = _cachedLength;
    if (documentLength == 0) {
      _imeProjectionStartOffset = 0;
      _imeProjectionText = '';
      _imeProjectionSelection = const TextSelection.collapsed(offset: 0);
      _imeProjectionDirty = false;
      return;
    }

    // HIGH-PERFORMANCE: Use Rust-side cached IME window.
    // The Rust side checks if cursor is still within the cached window and
    // only re-extracts text when the window needs to shift. This eliminates
    // the expensive substring() call on every keystroke when typing within
    // the same region of text.
    final caretOffset = _selection.extentOffset.clamp(0, documentLength);
    final cachedEnd = _imeProjectionStartOffset + _imeProjectionText.length;

    final projection = _rope.getImeProjection(
      caretOffset: caretOffset,
      selectionBase: _selection.baseOffset.clamp(0, documentLength),
      selectionExtent: caretOffset,
      maxWindowSize: _imeProjectionMaxChars,
      cachedWindowStart: _imeProjectionStartOffset,
      cachedWindowEnd: cachedEnd,
    );

    // Only update cached text if the window actually changed
    if (projection.windowChanged) {
      _imeProjectionStartOffset = projection.windowStart;
      _imeProjectionText = projection.text;
    }

    _imeProjectionSelection = _clampSelectionToText(
      TextSelection(
        baseOffset: projection.selectionBase,
        extentOffset: projection.selectionExtent,
      ),
      _imeProjectionText.length,
    );
    _imeProjectionDirty = false;
  }

  int _localImeOffsetToGlobal(int localOffset) {
    _ensureImeProjection();
    // Some platforms may report selection/delta offsets beyond the projected
    // window length. Clamp against the full document length, not the local
    // projection window, so large selections are preserved correctly.
    return (_imeProjectionStartOffset + localOffset).clamp(0, _cachedLength);
  }

  @override
  TextEditingValue? get currentTextEditingValue => TextEditingValue(
        text: text,
        selection: selection,
      );

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    if (openedFile != null && text.isEmpty) return; // Guard for uninitialized state

    _suppressImeSync = true;
    _ensureImeProjection();
    bool selectionChangedFromDelta = false;

    for (final delta in textEditingDeltas) {
      final TextSelection selectionBeforeDelta = _selection;
      bool selectionHandledByController = false;

      if (delta is TextEditingDeltaInsertion) {
        if (!selectionBeforeDelta.isCollapsed) {
          // Replace the actual editor selection (which may be much larger than
          // the IME projection window) with the typed text.
          replaceRange(selectionBeforeDelta.start, selectionBeforeDelta.end, delta.textInserted);
          selectionHandledByController = true;
        } else {
          final insertionOffset = _localImeOffsetToGlobal(delta.insertionOffset);
          replaceRange(insertionOffset, insertionOffset, delta.textInserted);
        }
      } else if (delta is TextEditingDeltaDeletion) {
        replaceRange(_localImeOffsetToGlobal(delta.deletedRange.start), _localImeOffsetToGlobal(delta.deletedRange.end), '');
      } else if (delta is TextEditingDeltaReplacement) {
        if (!selectionBeforeDelta.isCollapsed) {
          // On large selections, IME replacement ranges can be truncated to the
          // projection window. Use the full controller selection as source.
          replaceRange(selectionBeforeDelta.start, selectionBeforeDelta.end, delta.replacementText);
          selectionHandledByController = true;
        } else {
          replaceRange(
            _localImeOffsetToGlobal(delta.replacedRange.start),
            _localImeOffsetToGlobal(delta.replacedRange.end),
            delta.replacementText,
          );
        }
      } else if (delta is TextEditingDeltaNonTextUpdate) {
        // Just a selection or composing change
      }

      // Update selection based on the delta's reported selection
      if (!selectionHandledByController && delta.selection.isValid) {
        final base = delta.selection.baseOffset;
        final extent = delta.selection.extentOffset;
        _selection = TextSelection(
          baseOffset: _localImeOffsetToGlobal(base),
          extentOffset: _localImeOffsetToGlobal(extent),
        );
        selectionChangedFromDelta = true;
      }
    }

    if (selectionChangedFromDelta) {
      final int cursorLine = _rope.getLineAtOffset(_selection.extentOffset);
      _maybeScrollToCursorWithContext(cursorLine);
    }

    _suppressImeSync = false;
    _syncToConnection();
    notifyListeners();
  }
}
