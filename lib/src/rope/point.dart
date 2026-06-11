import 'package:flutter/foundation.dart';

/// A 2D point in the buffer, representing a position by row and column.
/// Row and column are both 0-indexed.
/// 
/// This provides a more intuitive way to work with positions than raw offsets,
/// especially for UI display and user interactions.
@immutable
class Point implements Comparable<Point> {
  /// The 0-based row (line) number.
  final int row;
  
  /// The 0-based column (byte offset within the line).
  final int column;
  
  const Point({required this.row, required this.column});
  
  /// Create a point at the origin (0, 0).
  static const Point zero = Point(row: 0, column: 0);
  
  /// Create a point representing a newline position (increments row, resets column).
  factory Point.newline() => const Point(row: 1, column: 0);
  
  /// Create a point from a row and column.
  factory Point.at(int row, int column) => Point(row: row, column: column);
  
  /// Add another point's row and column to this one.
  /// Useful for computing positions after text insertions.
  Point operator +(Point other) {
    if (other.row == 0) {
      return Point(row: row, column: column + other.column);
    } else {
      // When adding multiple rows, the column resets to the other's column
      return Point(row: row + other.row, column: other.column);
    }
  }
  
  /// Subtract another point from this one.
  /// Useful for computing edit ranges.
  Point operator -(Point other) {
    if (row == other.row) {
      return Point(row: 0, column: column - other.column);
    } else {
      return Point(row: row - other.row, column: column);
    }
  }
  
  @override
  int compareTo(Point other) {
    final rowCmp = row.compareTo(other.row);
    if (rowCmp != 0) return rowCmp;
    return column.compareTo(other.column);
  }
  
  bool operator <(Point other) => compareTo(other) < 0;
  bool operator <=(Point other) => compareTo(other) <= 0;
  bool operator >(Point other) => compareTo(other) > 0;
  bool operator >=(Point other) => compareTo(other) >= 0;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point && row == other.row && column == other.column;
  
  @override
  int get hashCode => Object.hash(row, column);
  
  @override
  String toString() => 'Point($row:$column)';
}

/// A point using UTF-16 code units for the column (matching Dart/Flutter).
@immutable
class PointUtf16 implements Comparable<PointUtf16> {
  final int row;
  final int column;
  
  const PointUtf16({required this.row, required this.column});
  
  static const PointUtf16 zero = PointUtf16(row: 0, column: 0);
  
  PointUtf16 operator +(PointUtf16 other) {
    if (other.row == 0) {
      return PointUtf16(row: row, column: column + other.column);
    } else {
      return PointUtf16(row: row + other.row, column: other.column);
    }
  }
  
  @override
  int compareTo(PointUtf16 other) {
    final rowCmp = row.compareTo(other.row);
    if (rowCmp != 0) return rowCmp;
    return column.compareTo(other.column);
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PointUtf16 && row == other.row && column == other.column;
  
  @override
  int get hashCode => Object.hash(row, column);
  
  @override
  String toString() => 'PointUtf16($row:$column)';
}

/// Summary of a text string, providing aggregated metrics.
/// 
/// This matches the Zed TextSummary structure for comprehensive text analysis.
@immutable
class TextSummary {
  /// Length in bytes.
  final int len;
  
  /// Length in characters (Unicode code points).
  final int chars;
  
  /// Length in UTF-16 code units.
  final int lenUtf16;
  
  /// The point after the last character (row count and last line length).
  final Point lines;
  
  /// Number of characters in the first line.
  final int firstLineChars;
  
  /// Number of characters in the last line.
  final int lastLineChars;
  
  /// UTF-16 code units in the last line.
  final int lastLineLenUtf16;
  
  /// The row index of the longest row.
  final int longestRow;
  
  /// Number of characters in the longest row.
  final int longestRowChars;
  
  const TextSummary({
    required this.len,
    required this.chars,
    required this.lenUtf16,
    required this.lines,
    required this.firstLineChars,
    required this.lastLineChars,
    required this.lastLineLenUtf16,
    required this.longestRow,
    required this.longestRowChars,
  });
  
  static const TextSummary zero = TextSummary(
    len: 0,
    chars: 0,
    lenUtf16: 0,
    lines: Point.zero,
    firstLineChars: 0,
    lastLineChars: 0,
    lastLineLenUtf16: 0,
    longestRow: 0,
    longestRowChars: 0,
  );
  
  /// Create a summary from a string.
  factory TextSummary.fromString(String text) {
    int lenUtf16 = 0;
    int lines = 0;
    int column = 0;
    int firstLineChars = 0;
    int lastLineChars = 0;
    int lastLineLenUtf16 = 0;
    int longestRow = 0;
    int longestRowChars = 0;
    int chars = 0;
    
    for (int i = 0; i < text.length; i++) {
      final c = text[i];
      final codeUnit = text.codeUnitAt(i);
      chars++;
      lenUtf16++;
      
      // Handle surrogate pairs
      if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF && i + 1 < text.length) {
        final next = text.codeUnitAt(i + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          lenUtf16++; // Full surrogate pair
          i++;
        }
      }
      
      if (c == '\n') {
        lines++;
        lastLineLenUtf16 = 0;
        lastLineChars = 0;
      } else {
        column++;
        lastLineLenUtf16++;
        lastLineChars++;
      }
      
      if (lines == 0) {
        firstLineChars = lastLineChars;
      }
      
      if (lastLineChars > longestRowChars) {
        longestRow = lines;
        longestRowChars = lastLineChars;
      }
    }
    
    return TextSummary(
      len: text.length, // In Dart, length is UTF-16 code units
      chars: chars,
      lenUtf16: lenUtf16,
      lines: Point(row: lines, column: column),
      firstLineChars: firstLineChars,
      lastLineChars: lastLineChars,
      lastLineLenUtf16: lastLineLenUtf16,
      longestRow: longestRow,
      longestRowChars: longestRowChars,
    );
  }
  
  /// Get the lines as PointUtf16.
  PointUtf16 get linesUtf16 => PointUtf16(row: lines.row, column: lastLineLenUtf16);
  
  /// Combine two summaries (for appending text).
  TextSummary operator +(TextSummary other) {
    final newLines = lines + other.lines;
    final newLastLineChars = other.lines.row > 0 ? other.lastLineChars : lastLineChars + other.lastLineChars;
    final newLastLineLenUtf16 = other.lines.row > 0 ? other.lastLineLenUtf16 : lastLineLenUtf16 + other.lastLineLenUtf16;
    final newFirstLineChars = lines.row == 0 ? firstLineChars + other.firstLineChars : firstLineChars;
    
    int newLongestRow = longestRow;
    int newLongestRowChars = longestRowChars;
    
    if (other.longestRowChars > longestRowChars) {
      newLongestRow = lines.row + other.longestRow;
      newLongestRowChars = other.longestRowChars;
    }
    
    return TextSummary(
      len: len + other.len,
      chars: chars + other.chars,
      lenUtf16: lenUtf16 + other.lenUtf16,
      lines: newLines,
      firstLineChars: newFirstLineChars,
      lastLineChars: newLastLineChars,
      lastLineLenUtf16: newLastLineLenUtf16,
      longestRow: newLongestRow,
      longestRowChars: newLongestRowChars,
    );
  }
  
  @override
  String toString() => 'TextSummary(len: $len, chars: $chars, lines: $lines, longest: $longestRow:$longestRowChars)';
}

/// Stores information about the indentation of a line.
@immutable
class LineIndent {
  /// Number of leading tab characters.
  final int tabs;
  
  /// Number of leading space characters.
  final int spaces;
  
  /// Whether the line is blank (contains only whitespace).
  final bool lineBlank;
  
  const LineIndent({
    required this.tabs,
    required this.spaces,
    required this.lineBlank,
  });
  
  static const LineIndent zero = LineIndent(tabs: 0, spaces: 0, lineBlank: true);
  
  /// Create from just spaces.
  factory LineIndent.fromSpaces(int spaces) => LineIndent(tabs: 0, spaces: spaces, lineBlank: true);
  
  /// Create from just tabs.
  factory LineIndent.fromTabs(int tabs) => LineIndent(tabs: tabs, spaces: 0, lineBlank: true);
  
  /// Create from a line of text.
  factory LineIndent.fromString(String line) {
    int tabs = 0;
    int spaces = 0;
    bool lineBlank = true;
    
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '\t') {
        tabs++;
      } else if (c == ' ') {
        spaces++;
      } else {
        if (c != '\n') {
          lineBlank = false;
        }
        break;
      }
    }
    
    return LineIndent(tabs: tabs, spaces: spaces, lineBlank: lineBlank);
  }
  
  /// Whether the line is empty (no content at all).
  bool get isLineEmpty => tabs == 0 && spaces == 0 && lineBlank;
  
  /// Total number of raw indentation characters.
  int get rawLen => tabs + spaces;
  
  /// Total visual width considering tab size.
  int len(int tabSize) => tabs * tabSize + spaces;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineIndent && tabs == other.tabs && spaces == other.spaces && lineBlank == other.lineBlank;
  
  @override
  int get hashCode => Object.hash(tabs, spaces, lineBlank);
  
  @override
  String toString() => 'LineIndent(tabs: $tabs, spaces: $spaces, blank: $lineBlank)';
}
