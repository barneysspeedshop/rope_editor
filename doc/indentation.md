# Indentation Analysis

APIs for detecting and querying indentation styles in documents, useful for auto-indent, formatting, and editor configuration.

## API

### `detectIndentation()` → `IndentInfo`

Analyzes the document to detect the dominant indentation style.

```dart
final indent = rope.detectIndentation();

print('Uses tabs: ${indent.usesTabs}');
print('Spaces per indent: ${indent.spacesPerIndent}');
print('Mixed indentation: ${indent.mixed}');
```

### `IndentInfo` Structure

| Field | Type | Description |
|-------|------|-------------|
| `usesTabs` | `bool` | Whether the document primarily uses tabs |
| `spacesPerIndent` | `int` | Detected spaces per indent level (2, 4, 8, etc.) |
| `mixed` | `bool` | Whether the document has mixed indentation styles |

### `getLineIndentation(lineIndex)` → `int`

Get the number of leading whitespace characters for a specific line.

```dart
final indent = rope.getLineIndentation(10);
print('Line 10 has $indent leading whitespace characters');
```

## Use Cases

### 1. Auto-Configure Editor Settings

```dart
void configureEditorFromDocument(Rope rope, EditorSettings settings) {
  final indent = rope.detectIndentation();
  
  settings.insertSpaces = !indent.usesTabs;
  settings.tabSize = indent.spacesPerIndent;
  
  if (indent.mixed) {
    showNotification('Mixed indentation detected. Consider normalizing.');
  }
}
```

### 2. Smart Auto-Indent

```dart
String getIndentForNewLine(Rope rope, int currentLine) {
  final indent = rope.detectIndentation();
  final currentIndent = rope.getLineIndentation(currentLine);
  
  // Check if current line ends with a block opener
  final lineText = rope.getLineText(currentLine);
  final opensBlock = lineText.trimRight().endsWith('{') || 
                     lineText.trimRight().endsWith(':');
  
  int targetIndent = currentIndent;
  if (opensBlock) {
    targetIndent += indent.usesTabs ? 1 : indent.spacesPerIndent;
  }
  
  return indent.usesTabs 
      ? '\t' * targetIndent 
      : ' ' * targetIndent;
}
```

### 3. Code Folding Levels

```dart
List<int> computeFoldingLevels(Rope rope) {
  final lineCount = rope.lineCount;
  final levels = <int>[];
  final indent = rope.detectIndentation();
  final indentSize = indent.usesTabs ? 1 : indent.spacesPerIndent;
  
  for (int i = 0; i < lineCount; i++) {
    final whitespace = rope.getLineIndentation(i);
    levels.add(whitespace ~/ indentSize);
  }
  
  return levels;
}
```

### 4. Normalize Indentation

```dart
void showIndentationWarning(Rope rope) {
  final indent = rope.detectIndentation();
  
  if (indent.mixed) {
    final message = indent.usesTabs
        ? 'Document uses tabs but has some spaces. Convert all to tabs?'
        : 'Document uses ${indent.spacesPerIndent}-space indent but has tabs. Convert all to spaces?';
    
    showDialog(message);
  }
}
```

## Implementation Details

### Detection Algorithm

1. **Sampling:** Analyzes up to 1000 lines spread across the document
2. **Classification:** Counts lines starting with tabs vs spaces
3. **Indent Size Detection:** Tracks frequency of common indent sizes (2, 4, 8)
4. **Mixed Detection:** Flags if both tabs and spaces are used significantly (>10% each)

### Performance

- **Detection:** O(min(n, 1000)) - samples at most 1000 lines
- **Line Indentation Query:** O(log n + k) where k is the indent width
- **No string allocation** for `getLineIndentation` - counts in-place
