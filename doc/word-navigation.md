# Word Navigation

APIs for character classification and word boundary detection, enabling Ctrl+Arrow navigation and double-click word selection.

## API

### `charClassAt(offset)` → `int`

Get the character class at a UTF-16 offset.

```dart
final charClass = rope.charClassAt(offset);

switch (charClass) {
  case Rope.charClassWhitespace:
    print('Whitespace');
  case Rope.charClassWord:
    print('Word character (letter, digit, underscore)');
  case Rope.charClassPunctuation:
    print('Punctuation/symbol');
  case Rope.charClassLineEnding:
    print('Line ending (\\n or \\r)');
}
```

### Character Class Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `Rope.charClassWhitespace` | 0 | Space, tab, etc. (not line endings) |
| `Rope.charClassWord` | 1 | Letters, digits, underscore |
| `Rope.charClassPunctuation` | 2 | Symbols, punctuation |
| `Rope.charClassLineEnding` | 3 | `\n` or `\r` |

### `findWordBoundary(offset, {required forward})` → `int`

Find the next or previous word boundary from a UTF-16 offset.

```dart
// Move to next word (Ctrl+Right)
final nextWord = rope.findWordBoundary(cursorOffset, forward: true);

// Move to previous word (Ctrl+Left)  
final prevWord = rope.findWordBoundary(cursorOffset, forward: false);
```

## Use Cases

### 1. Ctrl+Arrow Navigation

```dart
void handleCtrlArrow(Rope rope, bool forward) {
  final newOffset = rope.findWordBoundary(
    controller.selection.extentOffset,
    forward: forward,
  );
  
  controller.selection = TextSelection.collapsed(offset: newOffset);
}
```

### 2. Ctrl+Shift+Arrow Word Selection

```dart
void handleCtrlShiftArrow(Rope rope, bool forward) {
  final selection = controller.selection;
  final newExtent = rope.findWordBoundary(
    selection.extentOffset,
    forward: forward,
  );
  
  controller.selection = selection.copyWith(extentOffset: newExtent);
}
```

### 3. Double-Click Word Selection

```dart
TextSelection selectWordAt(Rope rope, int offset) {
  // Handle edge cases
  if (offset >= rope.length) {
    return TextSelection.collapsed(offset: rope.length);
  }
  
  final charClass = rope.charClassAt(offset);
  
  // If clicking on whitespace or punctuation, just place cursor
  if (charClass != Rope.charClassWord) {
    return TextSelection.collapsed(offset: offset);
  }
  
  // Find word boundaries
  final start = rope.findWordBoundary(offset, forward: false);
  final end = rope.findWordBoundary(offset, forward: true);
  
  return TextSelection(baseOffset: start, extentOffset: end);
}
```

### 4. Delete Word (Ctrl+Backspace / Ctrl+Delete)

```dart
void deleteWord(Rope rope, RopeEditorController controller, bool forward) {
  final offset = controller.selection.extentOffset;
  final boundary = rope.findWordBoundary(offset, forward: forward);
  
  if (forward) {
    rope.delete(offset, boundary);
  } else {
    rope.delete(boundary, offset);
    controller.selection = TextSelection.collapsed(offset: boundary);
  }
}
```

### 5. Custom Word Boundary Logic

```dart
int findWordStart(Rope rope, int offset) {
  if (offset == 0) return 0;
  
  // Get class at current position
  final currentClass = rope.charClassAt(offset);
  
  // Walk backwards while same class
  var pos = offset;
  while (pos > 0) {
    final prevClass = rope.charClassAt(pos - 1);
    if (prevClass != currentClass) break;
    pos--;
  }
  
  return pos;
}
```

## Word Boundary Algorithm

The `findWordBoundary` function implements VS Code-style word navigation:

### Forward Navigation
1. Skip characters of the current class (word, whitespace, or punctuation)
2. Skip any whitespace (except line endings)
3. Return the position at the start of the next word/punctuation

### Backward Navigation
1. Move back one character
2. Skip whitespace backwards
3. Find the start of the current word/punctuation group
4. Return that position

### Line Ending Behavior
- Line endings act as word boundaries
- Forward navigation stops at line start (doesn't skip the newline)
- This matches standard editor behavior

## Performance

- **Time:** O(log n + k) where k is the distance to the word boundary
- **No string allocation** - works directly on the rope's character iterator
- **Single FFI call** - both character class check and boundary search
