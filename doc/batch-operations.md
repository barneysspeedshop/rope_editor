# Batch Operations

High-performance batch APIs designed to minimize FFI overhead in rendering loops. These APIs are critical for maintaining 60fps rendering in editors with large files.

## The Problem

In a typical editor paint loop, you might need data for 40-80 visible lines. Naive implementations make multiple FFI calls per line:

```dart
// ❌ BAD: 120-240 FFI calls per frame for 40 visible lines
for (int i = firstLine; i < lastLine; i++) {
  final offset = rope.getLineStartOffset(i);      // FFI call 1
  final text = rope.getLineText(i);               // FFI call 2
  final indent = rope.getLineIndentation(i);      // FFI call 3
}
```

Each FFI call has overhead (~1-10μs), which adds up quickly and can cause frame drops.

## API

### `getLineStartOffsetsBatch(startLine, endLine)` → `List<int>`

Returns UTF-16 start offsets for a contiguous range of lines in a single FFI call.

```dart
// ✅ GOOD: 1 FFI call for all visible lines
final offsets = rope.getLineStartOffsetsBatch(firstLine, lastLine);

for (int i = 0; i < offsets.length; i++) {
  final lineIndex = firstLine + i;
  final offset = offsets[i];
  // Use offset for rendering...
}
```

**Complexity:**
- O(n) total using a forward cursor walk on the SumTree
- vs O(n log n) from individual `getLineStartOffset` calls

### `getMinimapDensityBatch(lineIndices)` → `List<MinimapLineDensity>`

Returns minimap density data for multiple lines without transferring full line strings.

```dart
final densities = rope.getMinimapDensityBatch(lineIndices);

for (int i = 0; i < densities.length; i++) {
  final d = densities[i];
  if (!d.isEmpty) {
    drawMinimapLine(
      indent: d.leadingWhitespace,
      width: d.contentLength,
    );
  }
}
```

### `MinimapLineDensity` Structure

| Field | Type | Description |
|-------|------|-------------|
| `leadingWhitespace` | `int` | Number of leading space/tab characters |
| `contentLength` | `int` | Length of non-whitespace content |
| `isEmpty` | `bool` | Whether line is empty or whitespace-only |

## Use Cases

### 1. Optimized Paint Loop

```dart
@override
void paint(PaintingContext context, Offset offset) {
  final firstLine = (scrollOffset / lineHeight).floor();
  final lastLine = ((scrollOffset + viewportHeight) / lineHeight).ceil();
  
  // Single FFI call for all line offsets
  final lineOffsets = rope.getLineStartOffsetsBatch(firstLine, lastLine);
  
  // Render each line
  for (int i = 0; i < lineOffsets.length; i++) {
    final lineIndex = firstLine + i;
    final lineOffset = lineOffsets[i];
    
    // Now use lineOffset for selection highlighting, cursor positioning, etc.
    paintLine(lineIndex, lineOffset);
  }
}
```

### 2. Selection Painting

```dart
void paintSelection(Canvas canvas, TextSelection selection, List<int> lineOffsets, int firstLine) {
  for (int i = 0; i < lineOffsets.length; i++) {
    final lineIndex = firstLine + i;
    final lineStart = lineOffsets[i];
    final lineEnd = i + 1 < lineOffsets.length 
        ? lineOffsets[i + 1] 
        : rope.length;
    
    if (selection.end <= lineStart || selection.start >= lineEnd) continue;
    
    final selStart = max(selection.start, lineStart) - lineStart;
    final selEnd = min(selection.end, lineEnd) - lineStart;
    
    paintSelectionForLine(canvas, lineIndex, selStart, selEnd);
  }
}
```

### 3. Minimap Rendering

```dart
void buildMinimapTasks(Rope rope, int lineCount) {
  // Sample up to 200 lines for minimap
  final sampleCount = min(lineCount, 200);
  final step = lineCount ~/ sampleCount;
  
  final lineIndices = [for (int i = 0; i < lineCount; i += step) i];
  
  // Single FFI call - no string serialization!
  final densities = rope.getMinimapDensityBatch(lineIndices);
  
  for (int i = 0; i < densities.length; i++) {
    final d = densities[i];
    if (!d.isEmpty) {
      minimapTasks.add(MinimapTask(
        line: lineIndices[i],
        indent: d.leadingWhitespace,
        contentWidth: d.contentLength,
      ));
    }
  }
}
```

### 4. Search Highlight Painting

```dart
void paintSearchHighlights(
  Canvas canvas, 
  List<SearchHighlight> highlights,
  List<int> lineOffsets,
  int firstLine,
  int lastLine,
) {
  for (final highlight in highlights) {
    final highlightLine = rope.getLineAtOffset(highlight.start);
    
    if (highlightLine < firstLine || highlightLine >= lastLine) continue;
    
    final lineOffset = lineOffsets[highlightLine - firstLine];
    final startInLine = highlight.start - lineOffset;
    final endInLine = highlight.end - lineOffset;
    
    paintHighlight(canvas, highlightLine, startInLine, endInLine);
  }
}
```

## Performance Comparison

### Line Start Offsets

| Approach | FFI Calls | Time (40 lines) | Time (1000 lines) |
|----------|-----------|-----------------|-------------------|
| Individual `getLineStartOffset` | n | ~400μs | ~15ms |
| `getLineStartOffsetsBatch` | 1 | ~50μs | ~500μs |
| **Speedup** | **40-1000x fewer calls** | **~8x faster** | **~30x faster** |

### Minimap Density

| Approach | FFI Calls | String Bytes | Time (200 lines) |
|----------|-----------|--------------|------------------|
| `getLinesTextBatch` + Dart trim | 1 | ~50KB | ~2ms |
| `getMinimapDensityBatch` | 1 | ~2.4KB | ~200μs |
| **Savings** | Same | **~95% less** | **~10x faster** |

## Best Practices

1. **Fetch offsets once per frame** - Store in a local variable, don't refetch
2. **Use for all line-based operations** - Selection, search highlights, gutter
3. **Combine with `getLinesTextBatch`** - Fetch text and offsets together
4. **Invalidate on content change** - Re-fetch after edits that change line structure

## Edit-Path Batch APIs

For typing and undo paths, prefer these combined calls over separate substring + replace + cursor queries:

| Method | Replaces |
|--------|----------|
| `replaceAndCapture(start, end, text)` | `substring` + `replace` + line/cursor lookups |
| `getCursorContext(offset)` | `getLineAtOffset` + `getLineStartOffset` + column math |
| `getImeProjection(...)` | Windowed text extraction with cache validation |

## Related APIs

- [`getLinesTextBatch`](range-text-access.md) - Batch fetch line text
- [`getLinesTextRange`](range-text-access.md) - Fetch consecutive lines as single string
- [`searchInRange`](search.md) - Search only visible lines
