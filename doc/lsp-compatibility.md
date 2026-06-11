# LSP Compatibility

APIs for converting between the rope editor's UTF-16 offsets and the byte offsets/line-column positions used by Language Server Protocol (LSP) servers.

## Background

Different systems use different text encodings:

| System | Offset Type | Example: "Hello 🌍" |
|--------|-------------|---------------------|
| Rope Editor / Dart | UTF-16 code units | Length = 8 (emoji = 2) |
| LSP / Most editors | UTF-16 (line, column) | Line 0, Column 8 |
| Rust / File bytes | UTF-8 bytes | Length = 10 (emoji = 4) |

The rope editor uses UTF-16 internally (matching Dart strings), but LSP servers typically send positions as (line, column) pairs where column is in UTF-16 units, and some tools use byte offsets.

## API

### UTF-16 ↔ Byte Offset Conversion

```dart
// Editor offset to byte offset (for external tools)
final byteOffset = rope.utf16ToByteOffset(cursorOffset);

// Byte offset from external tool to editor offset
final editorOffset = rope.byteToUtf16Offset(byteOffset);
```

### Line-Based Queries

```dart
// Get byte offset at start of a line
final lineStartBytes = rope.getLineStartByteOffset(lineIndex);
```

### LSP Position Conversion

```dart
// Convert LSP Position {line, character} to byte offset
final byteOffset = rope.lineColumnToByteOffset(
  lspPosition.line,
  lspPosition.character,  // UTF-16 column
);

// Convert byte offset to LSP Position
final (line, column) = rope.byteOffsetToLineColumn(byteOffset);
final lspPosition = Position(line: line, character: column);
```

## Use Cases

### 1. Applying LSP Diagnostics

```dart
void applyDiagnostics(Rope rope, List<Diagnostic> diagnostics) {
  for (final diag in diagnostics) {
    // Convert LSP range to editor offsets
    final startOffset = rope.byteToUtf16Offset(
      rope.lineColumnToByteOffset(
        diag.range.start.line,
        diag.range.start.character,
      ),
    );
    final endOffset = rope.byteToUtf16Offset(
      rope.lineColumnToByteOffset(
        diag.range.end.line,
        diag.range.end.character,
      ),
    );
    
    addDiagnosticHighlight(startOffset, endOffset, diag.severity);
  }
}
```

### 2. Sending Cursor Position to LSP

```dart
Position cursorToLspPosition(Rope rope, int cursorOffset) {
  final byteOffset = rope.utf16ToByteOffset(cursorOffset);
  final (line, column) = rope.byteOffsetToLineColumn(byteOffset);
  return Position(line: line, character: column);
}
```

### 3. Go to Definition Response

```dart
void handleGoToDefinition(Rope rope, Location location) {
  // Convert LSP location to editor offset
  final byteOffset = rope.lineColumnToByteOffset(
    location.range.start.line,
    location.range.start.character,
  );
  final editorOffset = rope.byteToUtf16Offset(byteOffset);
  
  // Navigate to the definition
  controller.selection = TextSelection.collapsed(offset: editorOffset);
  scrollToOffset(editorOffset);
}
```

### 4. Code Actions at Cursor

```dart
Future<List<CodeAction>> requestCodeActions(Rope rope, TextSelection selection) async {
  // Convert selection to LSP range
  final startByte = rope.utf16ToByteOffset(selection.start);
  final endByte = rope.utf16ToByteOffset(selection.end);
  
  final (startLine, startCol) = rope.byteOffsetToLineColumn(startByte);
  final (endLine, endCol) = rope.byteOffsetToLineColumn(endByte);
  
  final range = Range(
    start: Position(line: startLine, character: startCol),
    end: Position(line: endLine, character: endCol),
  );
  
  return await lspClient.codeAction(documentUri, range);
}
```

### 5. Applying Text Edits from LSP

```dart
void applyTextEdits(Rope rope, List<TextEdit> edits) {
  // Sort edits in reverse order to apply from end to start
  // (so earlier edits don't shift later offsets)
  edits.sort((a, b) => b.range.start.line.compareTo(a.range.start.line));
  
  for (final edit in edits) {
    final startByte = rope.lineColumnToByteOffset(
      edit.range.start.line,
      edit.range.start.character,
    );
    final endByte = rope.lineColumnToByteOffset(
      edit.range.end.line,
      edit.range.end.character,
    );
    
    final startUtf16 = rope.byteToUtf16Offset(startByte);
    final endUtf16 = rope.byteToUtf16Offset(endByte);
    
    rope.replace(startUtf16, endUtf16, edit.newText);
  }
}
```

## Performance

All conversions use the SumTree for O(log n) lookups:

| Operation | Time Complexity |
|-----------|-----------------|
| `utf16ToByteOffset` | O(log n) |
| `byteToUtf16Offset` | O(log n) |
| `lineColumnToByteOffset` | O(log n) |
| `byteOffsetToLineColumn` | O(log n) |
| `getLineStartByteOffset` | O(log n) |

## Common Pitfalls

1. **Column is UTF-16, not bytes** - LSP uses UTF-16 columns, same as Dart strings
2. **Lines are 0-indexed** - Both LSP and the rope editor use 0-based line numbers
3. **Apply edits in reverse order** - When applying multiple edits, start from the end of the document
4. **Emoji and CJK characters** - These may be 2 UTF-16 code units but 3-4 bytes
