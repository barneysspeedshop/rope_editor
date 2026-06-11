import 'package:flutter/foundation.dart';
import 'package:rope_editor/src/rope/anchor.dart';
import 'package:rope_editor/src/rope/point.dart';

/// Represents a diff hunk - a contiguous change in the document.
@immutable
class DiffHunk {
  /// The range in the old document (before the edit).
  final AnchorRange oldRange;
  
  /// The range in the new document (after the edit).
  final AnchorRange newRange;
  
  /// The type of change.
  final DiffHunkKind kind;
  
  /// The starting line in the old document (0-indexed).
  final int oldStartLine;
  
  /// The ending line (exclusive) in the old document.
  final int oldEndLine;
  
  /// The starting line in the new document (0-indexed).
  final int newStartLine;
  
  /// The ending line (exclusive) in the new document.
  final int newEndLine;
  
  const DiffHunk({
    required this.oldRange,
    required this.newRange,
    required this.kind,
    required this.oldStartLine,
    required this.oldEndLine,
    required this.newStartLine,
    required this.newEndLine,
  });
  
  @override
  String toString() => 'DiffHunk($kind, old: $oldRange, new: $newRange)';
}

/// The kind of change in a diff hunk.
enum DiffHunkKind {
  /// Text was added.
  added,
  /// Text was removed.
  removed,
  /// Text was modified.
  modified,
}

/// A buffer diff tracks differences between a base text and current text.
/// 
/// This is similar to Zed's BufferDiff, supporting:
/// - Real-time diff updates as edits occur
/// - Hunk detection for visual gutters
/// - Range queries for visible regions
class BufferDiff {
  /// The original (base) text.
  final String _baseText;
  
  /// The current snapshot text.
  String _currentText;
  
  /// Cached hunks - invalidated on edits.
  List<DiffHunk>? _cachedHunks;
  
  /// The buffer ID this diff belongs to.
  final BufferId bufferId;
  
  BufferDiff({
    required String baseText,
    required this.bufferId,
    String? currentText,
  }) : _baseText = baseText,
       _currentText = currentText ?? baseText;
  
  /// The original text before any edits.
  String get baseText => _baseText;
  
  /// The current text after edits.
  String get currentText => _currentText;
  
  /// Whether there are any differences.
  bool get hasDifferences => _baseText != _currentText;
  
  /// Update the current text snapshot.
  void updateSnapshot(String newText) {
    _currentText = newText;
    _cachedHunks = null;
  }
  
  /// Get all diff hunks between base and current.
  List<DiffHunk> get hunks {
    _cachedHunks ??= _computeHunks();
    return _cachedHunks!;
  }
  
  /// Get hunks that intersect a given point range.
  /// 
  /// A hunk intersects the range if its new document lines overlap with
  /// the given [start] and [end] points.
  List<DiffHunk> hunksIntersectingRange(Point start, Point end) {
    return hunks.where((hunk) {
      // Check if the hunk's range in the new document intersects with the query range.
      // Two ranges [a, b) and [c, d) intersect if a < d && c < b.
      final hunkStart = hunk.newStartLine;
      final hunkEnd = hunk.newEndLine;
      final queryStart = start.row;
      final queryEnd = end.row + 1; // Make end inclusive by adding 1
      
      return hunkStart < queryEnd && queryStart < hunkEnd;
    }).toList();
  }
  
  /// Compute diff hunks using a simple line-based diff algorithm.
  List<DiffHunk> _computeHunks() {
    final baseLines = _baseText.split('\n');
    final currentLines = _currentText.split('\n');
    
    final hunks = <DiffHunk>[];
    
    // Simple LCS-based diff
    final lcs = _computeLCS(baseLines, currentLines);
    
    int baseIdx = 0;
    int currentIdx = 0;
    int lcsIdx = 0;
    
    while (baseIdx < baseLines.length || currentIdx < currentLines.length) {
      if (lcsIdx < lcs.length && 
          baseIdx < baseLines.length && 
          currentIdx < currentLines.length &&
          baseLines[baseIdx] == lcs[lcsIdx] &&
          currentLines[currentIdx] == lcs[lcsIdx]) {
        // Lines match - no diff
        baseIdx++;
        currentIdx++;
        lcsIdx++;
      } else {
        // Found a difference
        final hunkStartBase = baseIdx;
        final hunkStartCurrent = currentIdx;
        
        // Skip until we find the next LCS line
        while (baseIdx < baseLines.length && 
               (lcsIdx >= lcs.length || baseLines[baseIdx] != lcs[lcsIdx])) {
          baseIdx++;
        }
        while (currentIdx < currentLines.length && 
               (lcsIdx >= lcs.length || currentLines[currentIdx] != lcs[lcsIdx])) {
          currentIdx++;
        }
        
        // Determine hunk kind
        final deletedLines = baseIdx - hunkStartBase;
        final addedLines = currentIdx - hunkStartCurrent;
        
        DiffHunkKind kind;
        if (deletedLines > 0 && addedLines > 0) {
          kind = DiffHunkKind.modified;
        } else if (deletedLines > 0) {
          kind = DiffHunkKind.removed;
        } else {
          kind = DiffHunkKind.added;
        }
        
        hunks.add(DiffHunk(
          oldRange: AnchorRange(
            start: Anchor.min(bufferId),
            end: Anchor.max(bufferId),
          ),
          newRange: AnchorRange(
            start: Anchor.min(bufferId),
            end: Anchor.max(bufferId),
          ),
          kind: kind,
          oldStartLine: hunkStartBase,
          oldEndLine: baseIdx,
          newStartLine: hunkStartCurrent,
          newEndLine: currentIdx,
        ));
      }
    }
    
    return hunks;
  }
  
  /// Compute Longest Common Subsequence of lines.
  List<String> _computeLCS(List<String> a, List<String> b) {
    final m = a.length;
    final n = b.length;
    
    // DP table
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }
    
    // Backtrack to find LCS
    final lcs = <String>[];
    int i = m, j = n;
    while (i > 0 && j > 0) {
      if (a[i - 1] == b[j - 1]) {
        lcs.add(a[i - 1]);
        i--;
        j--;
      } else if (dp[i - 1][j] > dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }
    
    return lcs.reversed.toList();
  }
}

/// A pending diff that updates incrementally as edits occur.
class PendingDiff {
  final BufferDiff _diff;
  
  /// Ranges that have been revealed/processed.
  final List<AnchorRange> revealedRanges = [];
  
  PendingDiff({
    required String baseText,
    required BufferId bufferId,
  }) : _diff = BufferDiff(baseText: baseText, bufferId: bufferId);
  
  BufferDiff get diff => _diff;
  
  /// Update with new text content.
  void update(String newText) {
    _diff.updateSnapshot(newText);
  }
  
  /// Reveal a range for processing (e.g., visible viewport).
  void revealRange(AnchorRange range) {
    revealedRanges.add(range);
  }
  
  /// Finalize the diff, creating an immutable snapshot.
  FinalizedDiff finalize() {
    return FinalizedDiff(
      baseText: _diff.baseText,
      currentText: _diff.currentText,
      hunks: _diff.hunks,
      bufferId: _diff.bufferId,
    );
  }
}

/// A finalized diff that represents a fixed snapshot.
@immutable
class FinalizedDiff {
  final String baseText;
  final String currentText;
  final List<DiffHunk> hunks;
  final BufferId bufferId;
  
  const FinalizedDiff({
    required this.baseText,
    required this.currentText,
    required this.hunks,
    required this.bufferId,
  });
  
  bool get hasDifferences => baseText != currentText;
  
  /// Get a markdown representation of the diff.
  String toMarkdown({String? path}) {
    final buffer = StringBuffer();
    buffer.writeln('Diff: ${path ?? "untitled"}');
    buffer.writeln('```');
    buffer.writeln(currentText);
    buffer.writeln('```');
    return buffer.toString();
  }
}

/// A patch represents a set of edits that can be applied to text.
@immutable
class Patch<D> {
  final List<Edit<D>> edits;
  
  const Patch(this.edits);
  
  static Patch<D> empty<D>() => Patch<D>(const []);
  
  bool get isEmpty => edits.isEmpty;
  bool get isNotEmpty => edits.isNotEmpty;
  
  /// Combine two patches.
  Patch<D> combine(Patch<D> other) {
    return Patch([...edits, ...other.edits]);
  }
}

/// A single edit operation in a patch.
@immutable
class Edit<D> {
  /// The range in the old document.
  final (D start, D end) old;
  
  /// The range in the new document.
  final (D start, D end) newRange;
  
  const Edit({required this.old, required this.newRange});
  
  bool get isEmpty => old.$1 == old.$2 && newRange.$1 == newRange.$2;
}
