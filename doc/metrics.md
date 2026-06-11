# Metrics & Widest Line Tracking

The `RopeMetrics` structure provides comprehensive document statistics in a single FFI call, including tracking of the widest line for efficient horizontal scrolling.

## API

### `getMetrics()` → `RopeMetrics`

Returns all document metrics in one call:

```dart
final metrics = rope.getMetrics();
```

### `RopeMetrics` Structure

| Field | Type | Description |
|-------|------|-------------|
| `byteLen` | `int` | Total document size in bytes (UTF-8) |
| `charLen` | `int` | Total document size in Unicode scalar values |
| `utf16Len` | `int` | Total document size in UTF-16 code units (Dart string length) |
| `lineCount` | `int` | Number of lines in the document |
| `maxLineUtf16Len` | `int` | Length of the widest line in UTF-16 code units |

## Use Cases

### 1. Horizontal Scrollbar Configuration

```dart
void setupHorizontalScrollbar(Rope rope, TextStyle textStyle) {
  final metrics = rope.getMetrics();
  final charWidth = textStyle.fontSize! * 0.6; // Approximate monospace width
  final maxContentWidth = metrics.maxLineUtf16Len * charWidth;
  
  // Set scrollbar extent based on widest line
  horizontalScrollController.position.applyContentDimensions(
    0.0,
    maxContentWidth,
  );
}
```

### 2. Layout Width Estimation

```dart
double estimateMaxLineWidth(Rope rope, double charWidth, double gutterWidth) {
  final metrics = rope.getMetrics();
  return metrics.maxLineUtf16Len * charWidth + gutterWidth + 40;
}
```

### 3. Performance Warnings

```dart
void checkDocumentComplexity(Rope rope) {
  final metrics = rope.getMetrics();
  
  if (metrics.maxLineUtf16Len > 10000) {
    showWarning('Document contains very long lines. '
                'Consider enabling virtual rendering.');
  }
}
```

### 4. Viewport Optimization Decisions

```dart
void optimizeViewport(Rope rope, double viewportWidth) {
  final metrics = rope.getMetrics();
  final estimatedWidth = metrics.maxLineUtf16Len * 8.0;
  
  if (estimatedWidth > viewportWidth * 3) {
    enableHorizontalSlicing(); // Only render visible horizontal portion
  } else {
    enableNormalRendering();
  }
}
```

## Implementation Details

The `maxLineUtf16Len` is computed efficiently during metrics updates:

1. Each line's UTF-16 length is stored in the SumTree
2. The `add_summary()` operation uses `max()` to propagate the widest line upward
3. The result is available in O(1) time from the tree's root summary

### Performance

- **Initial computation:** O(n) where n = number of lines
- **After edits:** O(log n) for incremental updates via SumTree
- **Query time:** O(1) - just reads the root summary
- **No additional allocations** - uses existing SumTree infrastructure
