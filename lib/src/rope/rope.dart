import 'package:flutter/services.dart';
import 'package:rope_editor/src/rust/api.dart' as api;
import 'package:rope_editor/src/rope/point.dart';

class Rope {
  late final api.RopeInstance _instance;

  Rope(String content) {
    _instance = api.createRopeInstance(text: content);
  }

  /// Private constructor for async initialization
  Rope._internal(this._instance);

  /// Async factory constructor that creates Rope without blocking UI
  static Future<Rope> createAsync(String content) async {
    final instance = await api.createRopeInstanceAsync(text: content);
    return Rope._internal(instance);
  }

  /// Load rope directly from a file path - most efficient for large files.
  /// The Rust layer streams the file without materializing it in Dart first
  /// and doesn't load the entire content into memory first.
  /// 
  /// For single-line files, pass maxChars to limit loading (e.g., 50000 chars
  /// for viewport buffering). Pass null to load the entire file.
  static Future<Rope> fromFile(String path, {int? maxChars}) async {
    final instance = await api.createRopeInstanceFromFile(
      path: path,
      maxChars: maxChars,
    );
    return Rope._internal(instance);
  }

  String getText() => api.getText(instance: _instance);
  
  /// Get hash of content efficiently without copying the entire text
  int getContentHash() => api.getContentHash(instance: _instance);
  
  /// Get comprehensive metrics including document size and widest line
  /// Useful for viewport calculations and horizontal scrolling
  api.RopeMetrics getMetrics() => api.getMetrics(instance: _instance);
  
  int get length {
    // OPTIMIZATION: Direct API call instead of computing from line offsets
    return api.getLengthUtf16(instance: _instance);
  }

  void insert(int offset, String text) {
    api.insert(instance: _instance, offsetUtf16: offset, text: text);
  }

  void delete(int start, int end) {
    api.delete(instance: _instance, startUtf16: start, endUtf16: end);
  }

  /// Combined replace operation - much faster than separate delete+insert
  /// because it only rebuilds metrics once instead of twice.
  void replace(int start, int end, String text) {
    api.replace(instance: _instance, startUtf16: start, endUtf16: end, text: text);
  }

  String substring(int start, int end) => api.getTextRange(instance: _instance, startUtf16: start, endUtf16: end);

  void setSelection(TextSelection selection) {
  }

  /// Returns the 0-based line index for the given character offset.
  int getLineAtOffset(int offset) {
    return api.getLineAtOffsetUtf16(instance: _instance, offsetUtf16: offset);
  }

  /// Returns the character offset where the given 0-based line index starts.
  int getLineStartOffset(int lineIndex) {
    return api.getLineStartOffsetUtf16(instance: _instance, lineIndex: lineIndex);
  }

  /// Batch API: Returns UTF-16 start offsets for a contiguous range of lines.
  /// This is O(n) total using a forward cursor walk instead of O(n log n)
  /// from individual getLineStartOffset calls.
  /// Dramatically reduces FFI overhead for rendering loops (paragraph builder,
  /// selection painter, search-highlight painter).
  List<int> getLineStartOffsetsBatch(int startLine, int endLine) {
    return api.getLineStartOffsetsBatch(instance: _instance, startLine: startLine, endLine: endLine);
  }

  /// Returns the text of a specific line without the newline character.
  String getLineText(int lineIndex) {
    return api.getLineText(instance: _instance, lineIndex: lineIndex);
  }

  /// Batch API: Returns multiple lines in a single FFI call.
  /// Use this instead of calling getLineText in a loop for better performance.
  List<String> getLinesTextBatch(List<int> lineIndices) {
    return api.getLinesTextBatch(instance: _instance, lineIndices: lineIndices);
  }

  /// Batch API: Returns minimap density data for multiple lines.
  /// Eliminates string serialization overhead for minimap rendering.
  /// For each line, computes leading whitespace, content length, and emptiness
  /// directly on the Rust side without transferring full line strings.
  List<api.MinimapLineDensity> getMinimapDensityBatch(List<int> lineIndices) {
    return api.getMinimapDensityBatch(instance: _instance, lineIndices: lineIndices);
  }

  /// Get text for a contiguous range of lines in a single FFI call.
  /// More efficient than getLinesTextBatch for consecutive lines.
  String getLinesTextRange(int startLine, int endLine) {
    return api.getLinesTextRange(instance: _instance, startLine: startLine, endLine: endLine);
  }

  /// Get a text chunk starting at a UTF-16 offset with a maximum length.
  /// Useful for slicing wide lines for viewport rendering.
  String getTextChunk(int startUtf16, int maxLength) {
    return api.getTextChunk(instance: _instance, startUtf16: startUtf16, maxLength: maxLength);
  }

  int get lineCount => api.getLineCount(instance: _instance);

  String charAt(int offset) => api.getTextRange(instance: _instance, startUtf16: offset, endUtf16: offset + 1);

  /// Searches the rope for the given [pattern].
  Iterable<Match> search(String pattern, {bool caseSensitive = true, bool isRegex = false, bool matchWholeWord = false}) {
    if (pattern.isEmpty) return [];
    
    // PERFORMANCE: Use the Rust search engine to avoid cloning the 
    // entire rope into a Dart string.
    final offsets = api.search(
      instance: _instance,
      pattern: pattern,
      caseSensitive: caseSensitive,
      isRegex: isRegex || matchWholeWord,
    );

    // Rust returns a flat list of UTF-16 [start, end, start, end...] mapped via SumTree
    final List<_RopeMatch> matches = [];
    for (int i = 0; i < offsets.length; i += 2) {
      matches.add(_RopeMatch(offsets[i], offsets[i + 1], pattern));
    }
    return matches;
  }

  /// Search for a pattern only within a specific line range.
  /// More efficient than full document search when you only need results
  /// for visible lines.
  Iterable<Match> searchInRange(
    String pattern, {
    required int startLine,
    required int endLine,
    bool caseSensitive = true,
    bool isRegex = false,
  }) {
    if (pattern.isEmpty) return [];
    
    final offsets = api.searchInRange(
      instance: _instance,
      pattern: pattern,
      startLine: startLine,
      endLine: endLine,
      caseSensitive: caseSensitive,
      isRegex: isRegex,
    );

    final List<_RopeMatch> matches = [];
    for (int i = 0; i < offsets.length; i += 2) {
      matches.add(_RopeMatch(offsets[i], offsets[i + 1], pattern));
    }
    return matches;
  }

  // ===========================================================================
  // Indentation Analysis
  // ===========================================================================

  /// Detect the dominant indentation style in the document.
  api.IndentInfo detectIndentation() {
    return api.detectIndentation(instance: _instance);
  }

  /// Get the indentation level (number of leading whitespace characters) for a line.
  int getLineIndentation(int lineIndex) {
    return api.getLineIndentation(instance: _instance, lineIndex: lineIndex);
  }

  // ===========================================================================
  // Character Class Queries (Word Navigation)
  // ===========================================================================

  /// Character class constants
  static const int charClassWhitespace = 0;
  static const int charClassWord = 1;
  static const int charClassPunctuation = 2;
  static const int charClassLineEnding = 3;

  /// Get the character class at a UTF-16 offset.
  /// Returns charClassWhitespace, charClassWord, charClassPunctuation, or charClassLineEnding.
  int charClassAt(int offset) {
    return api.charClassAt(instance: _instance, offsetUtf16: offset);
  }

  /// Find the next word boundary from a UTF-16 offset.
  /// If forward is true, finds the start of the next word.
  /// If forward is false, finds the start of the previous word.
  int findWordBoundary(int offset, {required bool forward}) {
    return api.findWordBoundary(instance: _instance, offsetUtf16: offset, forward: forward);
  }

  // ===========================================================================
  // Byte Offset Support (LSP Compatibility)
  // ===========================================================================

  /// Convert a UTF-16 offset to a byte offset.
  /// Useful for interfacing with LSP servers.
  int utf16ToByteOffset(int offsetUtf16) {
    return api.utf16ToByteOffset(instance: _instance, offsetUtf16: offsetUtf16);
  }

  /// Convert a byte offset to a UTF-16 offset.
  /// Useful for converting positions from LSP servers back to editor coordinates.
  int byteToUtf16Offset(int byteOffset) {
    return api.byteToUtf16OffsetPub(instance: _instance, byteOffset: byteOffset);
  }

  /// Get the byte offset for the start of a line.
  int getLineStartByteOffset(int lineIndex) {
    return api.getLineStartByteOffset(instance: _instance, lineIndex: lineIndex);
  }

  /// Convert line and UTF-16 column to byte offset.
  /// This is the format LSP uses for positions.
  int lineColumnToByteOffset(int line, int columnUtf16) {
    return api.lineColumnToByteOffset(instance: _instance, line: line, columnUtf16: columnUtf16);
  }

  /// Convert byte offset to line and UTF-16 column.
  /// Returns (line, column) for LSP position conversion.
  (int line, int column) byteOffsetToLineColumn(int byteOffset) {
    final result = api.byteOffsetToLineColumn(instance: _instance, byteOffset: byteOffset);
    return (result[0], result[1]);
  }

  // ===========================================================================
  // Bidirectional Iteration
  // ===========================================================================

  /// Get characters in reverse starting from a UTF-16 offset.
  /// Returns up to maxChars characters as a string (in forward order after reversal).
  String reversedCharsAt(int offsetUtf16, {int maxChars = 100}) {
    return api.reversedCharsAt(instance: _instance, offsetUtf16: offsetUtf16, maxChars: maxChars);
  }

  /// Get text in reverse within a UTF-16 range.
  String reversedTextInRange(int startUtf16, int endUtf16) {
    return api.reversedTextInRange(instance: _instance, startUtf16: startUtf16, endUtf16: endUtf16);
  }

  /// Get the UTF-16 offset of the start of the previous line.
  int prevLineStart(int offsetUtf16) {
    return api.prevLineStart(instance: _instance, offsetUtf16: offsetUtf16);
  }

  /// Get the UTF-16 offset of the start of the next line.
  int nextLineStart(int offsetUtf16) {
    return api.nextLineStart(instance: _instance, offsetUtf16: offsetUtf16);
  }

  // ===========================================================================
  // Batch Line Indent API
  // ===========================================================================

  /// Get line indentation info for a contiguous range of lines.
  List<LineIndent> getLineIndentsRange(int startLine, int endLine) {
    final results = api.getLineIndentsRange(instance: _instance, startLine: startLine, endLine: endLine);
    return results.map((r) => LineIndent(
      tabs: r.tabs,
      spaces: r.spaces,
      lineBlank: r.lineBlank,
    )).toList();
  }

  /// Get line indentation info in reverse order.
  List<LineIndent> getReversedLineIndentsRange(int startLine, int endLine) {
    final results = api.getReversedLineIndentsRange(instance: _instance, startLine: startLine, endLine: endLine);
    return results.map((r) => LineIndent(
      tabs: r.tabs,
      spaces: r.spaces,
      lineBlank: r.lineBlank,
    )).toList();
  }

  // ===========================================================================
  // Enhanced Search
  // ===========================================================================

  /// Search with whole word matching.
  Iterable<Match> searchWholeWord(String pattern, {bool caseSensitive = true}) {
    if (pattern.isEmpty) return [];
    
    final offsets = api.searchWholeWord(
      instance: _instance,
      pattern: pattern,
      caseSensitive: caseSensitive,
      wholeWord: true,
    );

    final List<_RopeMatch> matches = [];
    for (int i = 0; i < offsets.length; i += 2) {
      matches.add(_RopeMatch(offsets[i], offsets[i + 1], pattern));
    }
    return matches;
  }

  /// Search with include/exclude line ranges.
  /// [includeLines] - List of (start, end) line ranges to search within.
  /// [excludeLines] - List of (start, end) line ranges to skip.
  Iterable<Match> searchWithRanges(
    String pattern, {
    bool caseSensitive = true,
    bool isRegex = false,
    bool wholeWord = false,
    List<(int, int)>? includeLines,
    List<(int, int)>? excludeLines,
  }) {
    if (pattern.isEmpty) return [];
    
    final offsets = api.searchWithRanges(
      instance: _instance,
      pattern: pattern,
      caseSensitive: caseSensitive,
      isRegex: isRegex,
      wholeWord: wholeWord,
      includeLines: includeLines,
      excludeLines: excludeLines,
    );

    final List<_RopeMatch> matches = [];
    for (int i = 0; i < offsets.length; i += 2) {
      matches.add(_RopeMatch(offsets[i], offsets[i + 1], pattern));
    }
    return matches;
  }

  // ===========================================================================
  // Point Utilities
  // ===========================================================================

  /// Convert a UTF-16 offset to a Point (row, column in bytes).
  Point offsetToPoint(int offsetUtf16) {
    final result = api.offsetToPoint(instance: _instance, offsetUtf16: offsetUtf16);
    return Point(row: result[0], column: result[1]);
  }

  /// Convert a Point (row, column in bytes) to a UTF-16 offset.
  int pointToOffset(Point point) {
    return api.pointToOffset(instance: _instance, row: point.row, columnBytes: point.column);
  }

  /// Clip a point to valid bounds.
  /// [bias] - Bias.left (0) or Bias.right (1) for character boundary clipping.
  Point clipPoint(Point point, {bool biasRight = false}) {
    final result = api.clipPoint(
      instance: _instance, 
      row: point.row, 
      columnBytes: point.column, 
      bias: biasRight ? 1 : 0,
    );
    return Point(row: result[0], column: result[1]);
  }

  // ===========================================================================
  // Comprehensive Text Summary
  // ===========================================================================

  /// Get comprehensive text metrics including longest line info.
  TextSummary getTextSummary() {
    final summary = api.getTextSummary(instance: _instance);
    return TextSummary(
      len: summary.len,
      chars: summary.chars,
      lenUtf16: summary.lenUtf16,
      lines: Point(row: summary.lines, column: summary.lastLineColumn),
      firstLineChars: summary.firstLineChars,
      lastLineChars: summary.lastLineChars,
      lastLineLenUtf16: summary.lastLineLenUtf16,
      longestRow: summary.longestRow,
      longestRowChars: summary.longestRowChars,
    );
  }

  // ===========================================================================
  // HIGH-PERFORMANCE BATCH EDIT API
  // ===========================================================================
  // These APIs minimize FFI overhead by combining operations that are always
  // performed together during text editing. This eliminates ~82% of CPU time
  // spent in FFI calls during typing operations.

  /// Combined replace operation that returns all edit context in a single FFI call.
  /// 
  /// This is the HIGH-PERFORMANCE replacement for the pattern:
  /// ```dart
  /// deletedText = rope.substring(start, end);  // FFI call 1 - EXPENSIVE
  /// rope.replace(start, end, text);            // FFI call 2
  /// line = rope.getLineAtOffset(newCursor);    // FFI call 3 - EXPENSIVE
  /// ```
  /// 
  /// Now becomes:
  /// ```dart
  /// result = rope.replaceAndCapture(start, end, text);  // Single FFI call
  /// ```
  ///
  /// Returns [EditResult] containing:
  /// - The deleted text (for undo recording)
  /// - New cursor position and line/column info
  /// - Document length and line count
  EditResult replaceAndCapture(int start, int end, String text) {
    final result = api.replaceAndCapture(
      instance: _instance,
      startUtf16: start,
      endUtf16: end,
      text: text,
    );
    return EditResult(
      deletedText: result.deletedText,
      newLength: result.newLength,
      newCursor: result.newCursor,
      cursorLine: result.cursorLine,
      cursorColumn: result.cursorColumn,
      lineStartOffset: result.lineStartOffset,
      lineLength: result.lineLength,
      lineCountChanged: result.lineCountChanged,
      newLineCount: result.newLineCount,
    );
  }

  /// Get complete cursor context in a single FFI call.
  /// 
  /// Replaces multiple calls to getLineAtOffset(), getLineStartOffset(), etc.
  /// 
  /// This is the HIGH-PERFORMANCE replacement for the pattern:
  /// ```dart
  /// line = rope.getLineAtOffset(offset);       // FFI call 1
  /// lineStart = rope.getLineStartOffset(line); // FFI call 2
  /// column = offset - lineStart;               // computation
  /// ```
  /// 
  /// Now becomes:
  /// ```dart
  /// ctx = rope.getCursorContext(offset);       // Single FFI call
  /// ```
  CursorContext getCursorContext(int offsetUtf16) {
    final ctx = api.getCursorContext(instance: _instance, offsetUtf16: offsetUtf16);
    return CursorContext(
      line: ctx.line,
      column: ctx.column,
      lineStartOffset: ctx.lineStartOffset,
      lineEndOffset: ctx.lineEndOffset,
      lineLength: ctx.lineLength,
      totalLines: ctx.totalLines,
      totalLength: ctx.totalLength,
    );
  }

  /// Get or update the IME projection window with smart caching.
  /// 
  /// This is a SMART API that:
  /// 1. Checks if the cursor is still within the cached window
  /// 2. Only extracts text if the window needs to shift
  /// 3. Returns an empty string if the cached window is still valid
  ///
  /// The [cachedWindowStart] and [cachedWindowEnd] parameters should be
  /// the boundaries of your current cached IME window. If the cursor is
  /// still within this window (with margin), the API returns quickly
  /// without extracting any text.
  ///
  /// Returns [ImeProjection] with [windowChanged]=false if cache is valid.
  ImeProjection getImeProjection({
    required int caretOffset,
    required int selectionBase,
    required int selectionExtent,
    required int maxWindowSize,
    required int cachedWindowStart,
    required int cachedWindowEnd,
  }) {
    final result = api.getImeProjection(
      instance: _instance,
      caretOffset: caretOffset,
      selectionBase: selectionBase,
      selectionExtent: selectionExtent,
      maxWindowSize: maxWindowSize,
      cachedWindowStart: cachedWindowStart,
      cachedWindowEnd: cachedWindowEnd,
    );
    return ImeProjection(
      windowChanged: result.windowChanged,
      windowStart: result.windowStart,
      text: result.text,
      selectionBase: result.selectionBase,
      selectionExtent: result.selectionExtent,
    );
  }

  /// Quick check if IME window needs refresh without extracting text.
  /// Returns true if the cached window is still valid for the given cursor position.
  bool isImeWindowValid({
    required int caretOffset,
    required int maxWindowSize,
    required int cachedWindowStart,
    required int cachedWindowEnd,
  }) {
    return api.isImeWindowValid(
      instance: _instance,
      caretOffset: caretOffset,
      maxWindowSize: maxWindowSize,
      cachedWindowStart: cachedWindowStart,
      cachedWindowEnd: cachedWindowEnd,
    );
  }

  /// Returns contextual text around a UTF-16 range for agent prompts.
  RangeContext getContextForRange(
    int startUtf16,
    int endUtf16, {
    int contextLines = 5,
    List<api.FileReference> relatedFiles = const [],
  }) {
    final ctx = api.getContextForRange(
      instance: _instance,
      startUtf16: startUtf16,
      endUtf16: endUtf16,
      contextLines: contextLines,
      relatedFiles: relatedFiles,
    );
    return RangeContext(
      startUtf16: ctx.startUtf16,
      endUtf16: ctx.endUtf16,
      selectedText: ctx.selectedText,
      contextBefore: ctx.contextBefore,
      contextAfter: ctx.contextAfter,
      contextLines: ctx.contextLines,
      startLine: ctx.startLine,
      endLine: ctx.endLine,
      totalLines: ctx.totalLines,
      totalLength: ctx.totalLength,
      relatedFiles: ctx.relatedFiles,
    );
  }

  /// Underlying Rust rope handle for advanced FFI (e.g. agent orchestration).
  api.RopeInstance get instance => _instance;

  /// Applies agent edits atomically on the Rust rope.
  AgentEditResult applyAgentEdit(List<EditorAction> actions) {
    final result = api.applyAgentEdit(
      instance: _instance,
      actions: actions
          .map((action) => api.EditorAction(
                kind: action.kind,
                startUtf16: action.startUtf16,
                endUtf16: action.endUtf16,
                text: action.text,
              ))
          .toList(),
    );
    return AgentEditResult(
      newLength: result.newLength,
      newLineCount: result.newLineCount,
      lineCountChanged: result.lineCountChanged,
      appliedCount: result.appliedCount,
    );
  }
}

// ===========================================================================
// High-Performance Result Types
// ===========================================================================

/// Result of a replace operation with all context needed for undo/redo and UI updates.
/// This eliminates the need for separate FFI calls to get deleted text, cursor position, etc.
class EditResult {
  /// The text that was deleted (for undo recording).
  final String deletedText;
  
  /// The new document length in UTF-16 code units.
  final int newLength;
  
  /// The new cursor position in UTF-16 code units.
  final int newCursor;
  
  /// The line number where the cursor now sits.
  final int cursorLine;
  
  /// The column within the line (in UTF-16 code units).
  final int cursorColumn;
  
  /// Start offset of the current line (for IME projection).
  final int lineStartOffset;
  
  /// Length of the current line (excluding newline).
  final int lineLength;
  
  /// Whether the edit changed the number of lines in the document.
  final bool lineCountChanged;
  
  /// The new line count.
  final int newLineCount;

  const EditResult({
    required this.deletedText,
    required this.newLength,
    required this.newCursor,
    required this.cursorLine,
    required this.cursorColumn,
    required this.lineStartOffset,
    required this.lineLength,
    required this.lineCountChanged,
    required this.newLineCount,
  });
}

/// Cursor context providing all information needed for cursor positioning.
class CursorContext {
  /// The 0-based line index.
  final int line;
  
  /// The column within the line in UTF-16 code units.
  final int column;
  
  /// UTF-16 offset where the current line starts.
  final int lineStartOffset;
  
  /// UTF-16 offset where the current line ends (before newline).
  final int lineEndOffset;
  
  /// Length of the current line in UTF-16 code units (excluding newline).
  final int lineLength;
  
  /// Total number of lines in the document.
  final int totalLines;
  
  /// Total document length in UTF-16 code units.
  final int totalLength;

  const CursorContext({
    required this.line,
    required this.column,
    required this.lineStartOffset,
    required this.lineEndOffset,
    required this.lineLength,
    required this.totalLines,
    required this.totalLength,
  });
}

/// IME projection window state.
class ImeProjection {
  /// Whether a new window was computed (false means use cached).
  final bool windowChanged;
  
  /// Start offset of the window in the document (UTF-16).
  final int windowStart;
  
  /// The text content of the window (empty if windowChanged is false).
  final String text;
  
  /// Selection base offset relative to windowStart.
  final int selectionBase;
  
  /// Selection extent offset relative to windowStart.
  final int selectionExtent;

  const ImeProjection({
    required this.windowChanged,
    required this.windowStart,
    required this.text,
    required this.selectionBase,
    required this.selectionExtent,
  });
}

/// Context window around a UTF-16 range for agent prompts.
class RangeContext {
  final int startUtf16;
  final int endUtf16;
  final String selectedText;
  final String contextBefore;
  final String contextAfter;
  final String contextLines;
  final int startLine;
  final int endLine;
  final int totalLines;
  final int totalLength;
  final List<api.FileReference> relatedFiles;

  const RangeContext({
    required this.startUtf16,
    required this.endUtf16,
    required this.selectedText,
    required this.contextBefore,
    required this.contextAfter,
    required this.contextLines,
    required this.startLine,
    required this.endLine,
    required this.totalLines,
    required this.totalLength,
    this.relatedFiles = const [],
  });
}

/// Result of applying a batch of agent edits atomically.
class AgentEditResult {
  final int newLength;
  final int newLineCount;
  final bool lineCountChanged;
  final int appliedCount;

  const AgentEditResult({
    required this.newLength,
    required this.newLineCount,
    required this.lineCountChanged,
    required this.appliedCount,
  });
}

/// A single agent edit action targeting UTF-16 offsets in the document.
class EditorAction {
  final api.EditorActionKind kind;
  final int startUtf16;
  final int endUtf16;
  final String text;

  const EditorAction({
    required this.kind,
    required this.startUtf16,
    required this.endUtf16,
    this.text = '',
  });

  factory EditorAction.insert(int offset, String text) => EditorAction(
        kind: api.EditorActionKind.insert,
        startUtf16: offset,
        endUtf16: offset,
        text: text,
      );

  factory EditorAction.delete(int start, int end) => EditorAction(
        kind: api.EditorActionKind.delete,
        startUtf16: start,
        endUtf16: end,
      );

  factory EditorAction.replace(int start, int end, String text) => EditorAction(
        kind: api.EditorActionKind.replace,
        startUtf16: start,
        endUtf16: end,
        text: text,
      );
}

class _RopeMatch implements Match {
  @override
  final int start;
  @override
  final int end;
  final String _pattern;

  _RopeMatch(this.start, this.end, this._pattern);

  @override
  String? group(int group) => group == 0 ? _pattern : null;
  @override
  String operator [](int group) => group == 0 ? _pattern : '';
  @override
  int get groupCount => 0;
  @override
  List<String?> groups(List<int> groupIndices) => [_pattern];
  @override
  String get input => ''; // Not required for editor highlights
  @override
  Pattern get pattern => RegExp(_pattern);
}