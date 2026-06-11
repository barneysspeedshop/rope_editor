/// Utilities for preserving multiline syntax-highlighting context across lines.
library;

enum _LineEndState {
  normal,
  inSingleQuote,
  inDoubleQuote,
  inTripleSingle,
  inTripleDouble,
  inBlockComment,
}

/// Returns the earliest line index that must be included as context when
/// highlighting [lineIndex] in [lines].
int findHighlightContextStart(List<String> lines, int lineIndex) {
  if (lineIndex <= 0 || lineIndex >= lines.length) {
    return lineIndex;
  }

  var start = lineIndex;
  for (var i = lineIndex - 1; i >= 0 && lineIndex - i <= 200; i--) {
    if (_lineContinuesOnNext(lines[i])) {
      start = i;
    } else {
      break;
    }
  }
  return start;
}

String joinHighlightContext(List<String> lines, int contextStart, int beforeLineIndex) {
  if (beforeLineIndex <= contextStart) {
    return '';
  }
  return lines.sublist(contextStart, beforeLineIndex).join('\n');
}

bool lineContinuesOnNext(String line) => _lineContinuesOnNext(line);

bool _lineContinuesOnNext(String line) {
  return _scanLineEndState(line) != _LineEndState.normal;
}

_LineEndState _scanLineEndState(String line) {
  var state = _LineEndState.normal;
  var i = 0;

  while (i < line.length) {
    switch (state) {
      case _LineEndState.inBlockComment:
        final end = line.indexOf('*/', i);
        if (end == -1) {
          return _LineEndState.inBlockComment;
        }
        i = end + 2;
        state = _LineEndState.normal;
        continue;

      case _LineEndState.inTripleSingle:
        final end = line.indexOf("'''", i);
        if (end == -1) {
          return _LineEndState.inTripleSingle;
        }
        i = end + 3;
        state = _LineEndState.normal;
        continue;

      case _LineEndState.inTripleDouble:
        final end = line.indexOf('"""', i);
        if (end == -1) {
          return _LineEndState.inTripleDouble;
        }
        i = end + 3;
        state = _LineEndState.normal;
        continue;

      case _LineEndState.inSingleQuote:
        if (line[i] == '\\' && i + 1 < line.length) {
          i += 2;
          continue;
        }
        if (line[i] == "'") {
          state = _LineEndState.normal;
        }
        i++;
        continue;

      case _LineEndState.inDoubleQuote:
        if (line[i] == '\\' && i + 1 < line.length) {
          i += 2;
          continue;
        }
        if (line[i] == '"') {
          state = _LineEndState.normal;
        }
        i++;
        continue;

      case _LineEndState.normal:
        if (line.startsWith('//', i)) {
          return _LineEndState.normal;
        }
        if (line.startsWith('/*', i)) {
          i += 2;
          state = _LineEndState.inBlockComment;
          continue;
        }
        if (line.startsWith("r'''", i)) {
          i += 4;
          state = _LineEndState.inTripleSingle;
          continue;
        }
        if (line.startsWith('r"""', i)) {
          i += 4;
          state = _LineEndState.inTripleDouble;
          continue;
        }
        if (line.startsWith("'''", i)) {
          i += 3;
          state = _LineEndState.inTripleSingle;
          continue;
        }
        if (line.startsWith('"""', i)) {
          i += 3;
          state = _LineEndState.inTripleDouble;
          continue;
        }
        if (line.startsWith("r'", i)) {
          i += 2;
          state = _LineEndState.inSingleQuote;
          continue;
        }
        if (line.startsWith('r"', i)) {
          i += 2;
          state = _LineEndState.inDoubleQuote;
          continue;
        }
        if (line[i] == "'") {
          i++;
          state = _LineEndState.inSingleQuote;
          continue;
        }
        if (line[i] == '"') {
          i++;
          state = _LineEndState.inDoubleQuote;
          continue;
        }
        i++;
        continue;
    }
  }

  return state;
}
