import 'package:flutter/foundation.dart';

/// Bias determines how an anchor behaves when text is inserted at the anchor's position.
/// - [left]: The anchor stays to the left of the inserted text (before it).
/// - [right]: The anchor moves to the right of the inserted text (after it).
enum Bias { left, right }

/// A unique identifier for a buffer, allowing anchors to reference specific documents.
@immutable
class BufferId {
  final int value;
  
  const BufferId(this.value);
  
  /// Create a new BufferId, ensuring it's non-zero.
  factory BufferId.create(int id) {
    assert(id != 0, 'Buffer id cannot be 0');
    return BufferId(id);
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BufferId && runtimeType == other.runtimeType && value == other.value;
  
  @override
  int get hashCode => value.hashCode;
  
  @override
  String toString() => 'BufferId($value)';
}

/// A Lamport timestamp for ordering operations in a distributed/CRDT context.
/// Even in single-user mode, this enables proper undo/redo tracking.
@immutable
class LamportTimestamp implements Comparable<LamportTimestamp> {
  final int value;
  final int replicaId;
  
  const LamportTimestamp({required this.value, required this.replicaId});
  
  static const LamportTimestamp min = LamportTimestamp(value: 0, replicaId: 0);
  // 2^53 - 1: largest int exactly representable in JavaScript (i64::MAX is not).
  static const LamportTimestamp max = LamportTimestamp(value: 9007199254740991, replicaId: 0x7FFFFFFF);
  
  LamportTimestamp tick() => LamportTimestamp(value: value + 1, replicaId: replicaId);
  
  LamportTimestamp observe(LamportTimestamp other) {
    if (other.value > value) {
      return LamportTimestamp(value: other.value, replicaId: replicaId);
    }
    return this;
  }
  
  @override
  int compareTo(LamportTimestamp other) {
    final valueCmp = value.compareTo(other.value);
    if (valueCmp != 0) return valueCmp;
    return replicaId.compareTo(other.replicaId);
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LamportTimestamp && value == other.value && replicaId == other.replicaId;
  
  @override
  int get hashCode => Object.hash(value, replicaId);
  
  @override
  String toString() => 'Lamport($value:$replicaId)';
}

/// A clock for generating Lamport timestamps for a single replica.
class LamportClock {
  final int replicaId;
  int _value = 0;
  
  LamportClock({required this.replicaId});
  
  /// Generate the next timestamp.
  LamportTimestamp tick() {
    _value++;
    return LamportTimestamp(value: _value, replicaId: replicaId);
  }
  
  /// Update the clock to account for an observed timestamp.
  void observe(LamportTimestamp timestamp) {
    if (timestamp.value > _value) {
      _value = timestamp.value;
    }
  }
  
  LamportTimestamp get current => LamportTimestamp(value: _value, replicaId: replicaId);
}

/// An anchor is a stable reference to a position in a buffer that survives edits.
/// 
/// Unlike raw offsets which become invalid after insertions/deletions,
/// anchors track their position using:
/// - [bufferId]: Which buffer this anchor belongs to
/// - [timestamp]: The Lamport timestamp of the edit that created the text at this position
/// - [offset]: The offset within that insertion fragment
/// - [bias]: Whether to stay left or right when text is inserted at this exact position
/// 
/// Example:
/// ```dart
/// final anchor = buffer.anchorBefore(42);  // Create anchor before position 42
/// buffer.insert(40, "hello ");              // Insert text before anchor
/// final newOffset = buffer.offsetForAnchor(anchor);  // Still points to same logical position
/// ```
@immutable
class Anchor implements Comparable<Anchor> {
  /// The buffer this anchor belongs to.
  final BufferId bufferId;
  
  /// The Lamport timestamp of the insertion that created this text.
  final LamportTimestamp timestamp;
  
  /// The offset within the insertion fragment (0-based).
  final int offset;
  
  /// How this anchor behaves when text is inserted at its position.
  final Bias bias;
  
  const Anchor({
    required this.bufferId,
    required this.timestamp,
    required this.offset,
    required this.bias,
  });
  
  /// Create an anchor at the minimum position (start of buffer).
  factory Anchor.min(BufferId bufferId) => Anchor(
    bufferId: bufferId,
    timestamp: LamportTimestamp.min,
    offset: 0,
    bias: Bias.right,
  );
  
  /// Create an anchor at the maximum position (end of buffer).
  factory Anchor.max(BufferId bufferId) => Anchor(
    bufferId: bufferId,
    timestamp: LamportTimestamp.max,
    offset: 0x7FFFFFFF,
    bias: Bias.right,
  );
  
  bool get isMin => timestamp == LamportTimestamp.min;
  bool get isMax => timestamp == LamportTimestamp.max && offset == 0x7FFFFFFF;
  
  @override
  int compareTo(Anchor other) {
    // First compare by timestamp
    final tsCmp = timestamp.compareTo(other.timestamp);
    if (tsCmp != 0) return tsCmp;
    
    // Then by offset within the same insertion
    final offsetCmp = offset.compareTo(other.offset);
    if (offsetCmp != 0) return offsetCmp;
    
    // Finally by bias (left before right)
    if (bias == Bias.left && other.bias == Bias.right) return -1;
    if (bias == Bias.right && other.bias == Bias.left) return 1;
    
    return 0;
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Anchor &&
          bufferId == other.bufferId &&
          timestamp == other.timestamp &&
          offset == other.offset &&
          bias == other.bias;
  
  @override
  int get hashCode => Object.hash(bufferId, timestamp, offset, bias);
  
  @override
  String toString() => 'Anchor($bufferId, $timestamp, $offset, ${bias.name})';
}

/// A range defined by two anchors, useful for tracking selections, diagnostics, etc.
@immutable
class AnchorRange {
  final Anchor start;
  final Anchor end;
  
  const AnchorRange({required this.start, required this.end});
  
  /// Create a range that stays inside the text (start after, end before).
  factory AnchorRange.inside({required Anchor start, required Anchor end}) {
    return AnchorRange(
      start: Anchor(
        bufferId: start.bufferId,
        timestamp: start.timestamp,
        offset: start.offset,
        bias: Bias.right,
      ),
      end: Anchor(
        bufferId: end.bufferId,
        timestamp: end.timestamp,
        offset: end.offset,
        bias: Bias.left,
      ),
    );
  }
  
  /// Create a range that stays outside the text (start before, end after).
  factory AnchorRange.outside({required Anchor start, required Anchor end}) {
    return AnchorRange(
      start: Anchor(
        bufferId: start.bufferId,
        timestamp: start.timestamp,
        offset: start.offset,
        bias: Bias.left,
      ),
      end: Anchor(
        bufferId: end.bufferId,
        timestamp: end.timestamp,
        offset: end.offset,
        bias: Bias.right,
      ),
    );
  }
  
  bool get isEmpty => start.compareTo(end) >= 0;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnchorRange && start == other.start && end == other.end;
  
  @override
  int get hashCode => Object.hash(start, end);
  
  @override
  String toString() => 'AnchorRange($start..$end)';
}

/// A set of anchors with their payloads, efficiently tracking multiple positions.
/// Useful for diagnostics, bookmarks, breakpoints, etc.
class AnchorSet<T> {
  final Map<Anchor, T> _anchors = {};
  
  void add(Anchor anchor, T payload) {
    _anchors[anchor] = payload;
  }
  
  void remove(Anchor anchor) {
    _anchors.remove(anchor);
  }
  
  T? get(Anchor anchor) => _anchors[anchor];
  
  Iterable<MapEntry<Anchor, T>> get entries => _anchors.entries;
  
  int get length => _anchors.length;
  
  bool get isEmpty => _anchors.isEmpty;
  
  void clear() => _anchors.clear();
}
