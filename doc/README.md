# Rope Editor API Documentation

This documentation covers the extended Rust-backed API for `rope_editor`, providing high-performance text editing primitives optimized for large files and wide lines.

## Table of Contents

- [Metrics & Widest Line](metrics.md) - Document metrics including widest line tracking
- [Range-Based Text Access](range-text-access.md) - Efficient text retrieval for viewports
- [Indentation Analysis](indentation.md) - Detect and query indentation styles
- [Search](search.md) - Full-document and range-limited search
- [Word Navigation](word-navigation.md) - Character classes and word boundaries
- [LSP Compatibility](lsp-compatibility.md) - Byte offset conversions for LSP integration
- [Batch Operations](batch-operations.md) - High-performance batch APIs for rendering
s
### Zed upstream reference

Design notes adapted from Zed's editor buffer (not API documentation for this package):

- [rope](zed-docs/rope.md) · [text](zed-docs/text.md) · [search](zed-docs/search.md) · [diff](zed-docs/diff.md)

## Architecture Overview

The rope editor uses a Rust backend powered by:
- **zed_rope** — Chunked rope storage adapted from [Zed](https://github.com/zed-industries/zed) (GPL-3.0-or-later)
- **zed_sum_tree** — Balanced tree for O(log n) metrics queries (UTF-16/byte/char offsets, line counts)
- **flutter_rust_bridge** — Generated FFI bindings to Dart

All APIs are designed to minimize FFI overhead by:
1. Batching related queries into single calls
2. Computing derived data (like minimap density) on the Rust side
3. Using efficient cursor walks instead of repeated tree traversals

## Accessing the `Rope` API

The high-level `RopeEditor` widget uses `Rope` internally. For custom tooling, access it via the controller or construct a standalone instance:

```dart
import 'package:rope_editor/rope_editor.dart';
import 'package:rope_editor/src/rope/rope.dart';

// Via the editor controller (typical)
final rope = controller.rope;

// Standalone instance
final rope = Rope('Hello\nWorld\nThis is a test');

// Get metrics including widest line
final metrics = rope.getMetrics();
print('Lines: ${metrics.lineCount}');
print('Widest line: ${metrics.maxLineUtf16Len} UTF-16 units');

// Efficient batch operations for rendering
final offsets = rope.getLineStartOffsetsBatch(0, 10);
final densities = rope.getMinimapDensityBatch([0, 1, 2, 3, 4]);
```
