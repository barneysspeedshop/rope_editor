# Search

High-performance search APIs powered by Rust's regex engine, with support for both full-document and range-limited searches.

## API

### `search(pattern, {...})` → `Iterable<Match>`

Search the entire document for a pattern.

```dart
final matches = rope.search(
  'TODO',
  caseSensitive: false,
  isRegex: false,
);

for (final match in matches) {
  print('Found at ${match.start}-${match.end}');
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `pattern` | `String` | required | The search pattern |
| `caseSensitive` | `bool` | `true` | Whether to match case |
| `isRegex` | `bool` | `false` | Whether pattern is a regex |
| `matchWholeWord` | `bool` | `false` | Match whole words only |

### `searchInRange(pattern, {...})` → `Iterable<Match>`

Search only within a specific line range. More efficient for incremental/viewport-limited search.

```dart
final matches = rope.searchInRange(
  'function',
  startLine: firstVisibleLine,
  endLine: lastVisibleLine,
  caseSensitive: true,
  isRegex: false,
);
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `pattern` | `String` | required | The search pattern |
| `startLine` | `int` | required | First line to search (inclusive) |
| `endLine` | `int` | required | Last line to search (exclusive) |
| `caseSensitive` | `bool` | `true` | Whether to match case |
| `isRegex` | `bool` | `false` | Whether pattern is a regex |

## Use Cases

### 1. Find All Occurrences

```dart
void findAll(Rope rope, String query) {
  final matches = rope.search(query, caseSensitive: false);
  
  for (final match in matches) {
    final line = rope.getLineAtOffset(match.start);
    print('Line ${line + 1}: ${rope.getLineText(line)}');
  }
}
```

### 2. Incremental Search (Visible Lines Only)

For large files, search only visible lines for instant feedback:

```dart
void searchVisibleLines(Rope rope, String query, int firstLine, int lastLine) {
  // Fast search for immediate highlighting
  final visibleMatches = rope.searchInRange(
    query,
    startLine: firstLine,
    endLine: lastLine,
    caseSensitive: false,
  );
  
  highlightMatches(visibleMatches);
  
  // Full search in background for total count
  Future(() {
    final allMatches = rope.search(query, caseSensitive: false);
    updateMatchCount(allMatches.length);
  });
}
```

### 3. Regex Search

```dart
void findFunctions(Rope rope) {
  final matches = rope.search(
    r'function\s+(\w+)\s*\(',
    isRegex: true,
  ).toList();
  
  print('Found ${matches.length} function declarations');
}
```

### 4. Search and Replace Preview

```dart
List<SearchResult> previewReplace(Rope rope, String find, String replace) {
  final matches = rope.search(find).toList();
  
  return matches.map((match) {
    final line = rope.getLineAtOffset(match.start);
    final lineText = rope.getLineText(line);
    final preview = lineText.replaceFirst(find, replace);
    
    return SearchResult(
      line: line,
      original: lineText,
      preview: preview,
    );
  }).toList();
}
```

## Performance

### Full Document Search

- **Time:** O(n) where n is document size
- **Powered by:** Rust's `regex` crate (one of the fastest regex engines)
- **UTF-16 conversion:** Results are automatically converted to Dart-compatible offsets

### Range Search

- **Time:** O(m) where m is the size of the searched range
- **Best for:** Visible line highlighting, incremental search
- **Benefit:** Avoids scanning 99% of a large file for viewport-only highlighting

## Best Practices

1. **Use `searchInRange` for viewport highlighting** - instant results for visible lines
2. **Run full searches asynchronously** - don't block the UI for large files
3. **Escape user input** when not using regex mode - the API handles this automatically
4. **Cache search results** - invalidate only when document content changes
