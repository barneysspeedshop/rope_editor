# Range-Based Text Access

Efficient APIs for retrieving text from specific ranges, optimized for viewport rendering of large documents.

## API

### `getLinesTextBatch(lineIndices)` → `List<String>`

Fetch specific (possibly non-contiguous) lines in one FFI call:

```dart
final lines = rope.getLinesTextBatch([0, 5, 10, 15]);
```

Use when you need arbitrary line indices. For consecutive lines, prefer `getLinesTextRange`.

### `getLinesTextRange(startLine, endLine)` → `String`

Get text for a contiguous range of lines in a single FFI call.

```dart
// Get lines 10-20 as a single string (includes newlines)
final text = rope.getLinesTextRange(10, 20);
```

**When to use:**
- Fetching all visible lines for rendering
- Copying a block of lines
- More efficient than `getLinesTextBatch` for consecutive lines

### `getTextChunk(startUtf16, maxLength)` → `String`

Get a text chunk starting at a UTF-16 offset with a maximum length limit.

```dart
// Get up to 5000 characters starting at offset 10000
final chunk = rope.getTextChunk(10000, 5000);
```

**When to use:**
- Slicing very wide lines for horizontal viewport rendering
- Limiting memory usage when only a portion of a line is visible
- Progressive loading of extremely long lines

## Use Cases

### 1. Viewport Text Rendering

```dart
void renderVisibleLines(Rope rope, int firstLine, int lastLine) {
  // Single FFI call for all visible lines
  final text = rope.getLinesTextRange(firstLine, lastLine);
  
  // Split and render
  final lines = text.split('\n');
  for (int i = 0; i < lines.length; i++) {
    renderLine(firstLine + i, lines[i]);
  }
}
```

### 2. Horizontal Slicing for Wide Lines

When a line is extremely wide (e.g., minified JavaScript), only render the visible horizontal portion:

```dart
void renderWideLine(Rope rope, int lineIndex, double hScroll, double viewportWidth) {
  final lineStart = rope.getLineStartOffset(lineIndex);
  final charWidth = 8.0;
  
  // Calculate visible character range with buffer
  final startChar = (hScroll / charWidth).floor() - 100;
  final visibleChars = (viewportWidth / charWidth).ceil() + 200;
  
  // Fetch only the visible portion
  final visibleText = rope.getTextChunk(
    lineStart + startChar.clamp(0, double.infinity).toInt(),
    visibleChars,
  );
  
  // Render with offset
  renderTextAtOffset(visibleText, startChar * charWidth);
}
```

### 3. Copy Selection Spanning Multiple Lines

```dart
String copySelection(Rope rope, int startLine, int endLine, int startCol, int endCol) {
  if (startLine == endLine) {
    final lineStart = rope.getLineStartOffset(startLine);
    return rope.substring(lineStart + startCol, lineStart + endCol);
  }
  
  // For multi-line, get the full range then trim
  final fullText = rope.getLinesTextRange(startLine, endLine + 1);
  // Trim first and last line as needed...
  return trimmedText;
}
```

## Performance Comparison

| Operation | FFI Calls | Time Complexity |
|-----------|-----------|-----------------|
| `getLineText` in loop (n lines) | n | O(n log n) |
| `getLinesTextBatch` (n lines) | 1 | O(n) + allocation per line |
| `getLinesTextRange` (n lines) | 1 | O(n) single allocation |
| `getTextChunk` (k chars) | 1 | O(log n + k) |

## Best Practices

1. **Use `getLinesTextRange` for consecutive lines** - avoids per-line allocation overhead
2. **Use `getTextChunk` for wide lines** - limits memory for 10K+ character lines
3. **Cache results when possible** - text doesn't change between renders unless edited
4. **Consider horizontal slicing threshold** - typically 10,000+ characters per line
