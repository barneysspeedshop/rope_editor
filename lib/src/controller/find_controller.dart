import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rope_editor/src/controller/controller.dart';
import 'package:rope_editor/src/styling.dart';

class FindController extends ChangeNotifier {
  final RopeEditorController editorController;

  final TextEditingController findInputController = TextEditingController();
  final TextEditingController replaceInputController = TextEditingController();
  final FocusNode findInputFocusNode = FocusNode();
  final FocusNode replaceInputFocusNode = FocusNode();

  List<Match> _matches = [];
  int _currentMatchIndex = -1;
  bool _isRegex = false;
  bool _caseSensitive = false;
  bool _matchWholeWord = false;
  String _lastQuery = '';
  bool _isActive = false;
  bool _isReplaceMode = false;
  int _lastDocVersion = -1;
  VoidCallback? _controllerListener;
  List<SearchHighlight> _cachedHighlights = [];
  int _lastHighlightedIndex = -1;

  FindController(this.editorController) {
    _lastDocVersion = editorController.documentVersion;
    _controllerListener = _onControllerChanged;
    editorController.addListener(_controllerListener!);
    findInputController.addListener(_onFindInputChanged);

    KeyEventResult onKey(FocusNode node, KeyEvent event) {
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
        isActive = false;
        editorController.focusNode?.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    findInputFocusNode.onKeyEvent = onKey;
    replaceInputFocusNode.onKeyEvent = onKey;
  }

  void _onFindInputChanged() {
    find(findInputController.text);
  }

  void _onControllerChanged() {
    if (!_isActive || _lastQuery.isEmpty) return;
    if (editorController.documentVersion != _lastDocVersion) {
      _lastDocVersion = editorController.documentVersion;
      _reperformSearch();
    }
  }

  bool get isActive => _isActive;
  set isActive(bool value) {
    if (_isActive == value) return;
    _isActive = value;
    if (_isActive) {
      Future.microtask(() => findInputFocusNode.requestFocus());
      if (_lastQuery.isNotEmpty) {
        _reperformSearch();
      }
    } else {
      _clearMatches();
    }
    notifyListeners();
  }

  bool get isReplaceMode => _isReplaceMode;
  set isReplaceMode(bool value) {
    if (_isReplaceMode == value) return;
    _isReplaceMode = value;
    notifyListeners();
  }

  int get matchCount => _matches.length;
  int get currentMatchIndex => _currentMatchIndex;
  bool get caseSensitive => _caseSensitive;
  bool get isRegex => _isRegex;
  bool get matchWholeWord => _matchWholeWord;

  set caseSensitive(bool value) {
    if (_caseSensitive == value) return;
    _caseSensitive = value;
    _reperformSearch();
    notifyListeners();
  }

  set isRegex(bool value) {
    if (_isRegex == value) return;
    _isRegex = value;
    _reperformSearch();
    notifyListeners();
  }

  set matchWholeWord(bool value) {
    if (_matchWholeWord == value) return;
    _matchWholeWord = value;
    _reperformSearch();
    notifyListeners();
  }

  void toggleReplaceMode() => isReplaceMode = !isReplaceMode;
  void toggleActive() => isActive = !isActive;
  void toggleCaseSensitive() => caseSensitive = !caseSensitive;
  void toggleRegex() => isRegex = !isRegex;
  void toggleMatchWholeWord() => matchWholeWord = !matchWholeWord;

  void _reperformSearch() {
    if (_lastQuery.isNotEmpty) {
      find(_lastQuery, scrollToMatch: false, matchesChanged: true);
    }
  }

  String _decodeEscapedSequences(String input) {
    if (!input.contains('\\')) return input;

    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch == '\\' && i + 1 < input.length) {
        final next = input[i + 1];
        switch (next) {
          case 'n':
            buffer.write('\n');
            i++;
            continue;
          case 'r':
            buffer.write('\r');
            i++;
            continue;
          case 't':
            buffer.write('\t');
            i++;
            continue;
          case '\\':
            buffer.write('\\');
            i++;
            continue;
        }
      }
      buffer.write(ch);
    }

    return buffer.toString();
  }

  String _expandRegexReplacement(RegExpMatch match, String template) {
    final buffer = StringBuffer();
    for (int i = 0; i < template.length; i++) {
      final ch = template[i];
      if (ch == r'$' && i + 1 < template.length) {
        final next = template[i + 1];
        if (next == r'$') {
          buffer.write(r'$');
          i++;
          continue;
        }
        if (next == r'&') {
          buffer.write(match.group(0) ?? '');
          i++;
          continue;
        }
        final nextCode = next.codeUnitAt(0);
        if (nextCode >= 0x30 && nextCode <= 0x39) {
          int j = i + 1;
          while (j < template.length) {
            final code = template[j].codeUnitAt(0);
            if (code < 0x30 || code > 0x39) break;
            j++;
          }
          final groupNum = int.parse(template.substring(i + 1, j));
          buffer.write(match.group(groupNum) ?? '');
          i = j - 1;
          continue;
        }
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  void find(String query, {bool scrollToMatch = true, bool matchesChanged = true}) {
    _lastQuery = query;
    if (query.isEmpty) {
      _clearMatches();
      return;
    }

    final normalizedQuery = _decodeEscapedSequences(query);

    try {
      _matches = editorController.rope
          .search(
            normalizedQuery,
            caseSensitive: _caseSensitive,
            isRegex: _isRegex,
            matchWholeWord: _matchWholeWord,
          )
          .toList();
    } catch (e) {
      _matches = [];
      _currentMatchIndex = -1;
      _updateHighlights(matchesChanged: matchesChanged);
      notifyListeners();
      return;
    }

    if (_matches.isEmpty) {
      _currentMatchIndex = -1;
      _updateHighlights(matchesChanged: matchesChanged);
      notifyListeners();
      return;
    }

    final cursor = editorController.selection.start;
    int index = 0;
    bool found = false;
    for (int i = 0; i < _matches.length; i++) {
      if (_matches[i].start >= cursor) {
        index = i;
        found = true;
        break;
      }
    }
    _currentMatchIndex = found ? index : 0;

    _updateHighlights(matchesChanged: matchesChanged);
    if (scrollToMatch) _scrollToCurrentMatch();
    notifyListeners();
  }

  void next() {
    if (_matches.isEmpty) return;
    _currentMatchIndex = (_currentMatchIndex + 1) % _matches.length;
    _scrollToCurrentMatch();
    _updateHighlights();
  }

  void previous() {
    if (_matches.isEmpty) return;
    _currentMatchIndex = (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    _scrollToCurrentMatch();
    _updateHighlights();
  }

  void show() {
    isActive = true;
  }

  void hide() {
    isActive = false;
  }

  void clear() {
    findInputController.clear();
    replaceInputController.clear();
    _lastQuery = '';
    _clearMatches();
  }

  void _clearMatches() {
    _matches = [];
    _currentMatchIndex = -1;
    _cachedHighlights = [];
    _lastHighlightedIndex = -1;
    editorController.searchHighlights = [];
    editorController.searchHighlightsChanged = true;
    editorController.notifyListeners();
    notifyListeners();
  }

  void _scrollToCurrentMatch() {
    if (_currentMatchIndex >= 0 && _currentMatchIndex < _matches.length) {
      final match = _matches[_currentMatchIndex];
      final matchLine = editorController.getLineAtOffset(match.start);
      editorController.setSelectionSilently(TextSelection.collapsed(offset: match.start));
      try {
        editorController.scrollToLine(matchLine, center: true);
      } catch (_) {}
    }
  }

  void _updateHighlights({bool matchesChanged = false}) {
    if (matchesChanged || _cachedHighlights.length != _matches.length) {
      _cachedHighlights = List.generate(_matches.length, (i) {
        final match = _matches[i];
        return SearchHighlight(
          start: match.start,
          end: match.end,
          isCurrentMatch: i == _currentMatchIndex,
        );
      });
    } else {
      // PERFORMANCE: Surgical update of only the changed matches
      if (_lastHighlightedIndex >= 0 && _lastHighlightedIndex < _cachedHighlights.length) {
        final m = _matches[_lastHighlightedIndex];
        _cachedHighlights[_lastHighlightedIndex] = SearchHighlight(start: m.start, end: m.end, isCurrentMatch: false);
      }
      if (_currentMatchIndex >= 0 && _currentMatchIndex < _cachedHighlights.length) {
        final m = _matches[_currentMatchIndex];
        _cachedHighlights[_currentMatchIndex] = SearchHighlight(start: m.start, end: m.end, isCurrentMatch: true);
      }
    }

    _lastHighlightedIndex = _currentMatchIndex;
    editorController.searchHighlights = _cachedHighlights;
    editorController.searchHighlightsChanged = true;
    editorController.notifyListeners();
    notifyListeners();
  }

  void replace() {
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _matches.length) return;
    final match = _matches[_currentMatchIndex];
    final replacement = _decodeEscapedSequences(replaceInputController.text);
    editorController.replaceRange(match.start, match.end, replacement);
  }

  void replaceAll() {
    if (_matches.isEmpty) return;
    final text = editorController.text;
    final normalizedQuery = _decodeEscapedSequences(_lastQuery);
    final replacement = _decodeEscapedSequences(replaceInputController.text);
    String pattern = normalizedQuery;
    if (!_isRegex) pattern = RegExp.escape(normalizedQuery);
    if (_matchWholeWord) pattern = '\\b$pattern\\b';

    try {
      final regExp = RegExp(pattern, caseSensitive: _caseSensitive);
      final newText = _isRegex
          ? text.replaceAllMapped(regExp, (match) => _expandRegexReplacement(match as RegExpMatch, replacement))
          : text.replaceAllMapped(regExp, (_) => replacement);
      editorController.replaceRange(0, text.length, newText);
    } catch (e) {
      debugPrint('FindController: Replace All failed. Error: $e');
    }
  }

  @override
  void dispose() {
    if (_controllerListener != null) {
      editorController.removeListener(_controllerListener!);
    }
    findInputController.removeListener(_onFindInputChanged);
    findInputController.dispose();
    replaceInputController.dispose();
    findInputFocusNode.dispose();
    replaceInputFocusNode.dispose();
    super.dispose();
  }
}
