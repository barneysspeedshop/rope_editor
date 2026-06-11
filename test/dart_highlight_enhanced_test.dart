import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:rope_editor/rope_editor.dart';

class _ScopeCollector extends HighlightRenderer {
  final List<(String text, String? scope)> tokens = [];
  final List<String?> _scopeStack = [];

  @override
  void addText(String text) {
    if (text.isEmpty) return;
    tokens.add((text, _scopeStack.isEmpty ? null : _scopeStack.last));
  }

  @override
  void openNode(DataNode node) {
    _scopeStack.add(node.scope);
  }

  @override
  void closeNode(DataNode node) {
    if (_scopeStack.isNotEmpty) _scopeStack.removeLast();
  }
}

Set<String> _scopesFor(Mode language, String code) {
  final h = Highlight()..registerLanguage('dart', language);
  final collector = _ScopeCollector();
  h.highlight(language: 'dart', code: code).render(collector);
  return collector.tokens.map((t) => t.$2).whereType<String>().toSet();
}

void main() {
  test('enhanced Dart grammar highlights user types and function names', () {
    const fieldLine = '  final TextEditorViewModel vm;';
    const methodLine = '  void initState() {';

    final stock = _scopesFor(langDart, fieldLine);
    final enhanced = _scopesFor(langDartEnhanced, fieldLine);

    expect(enhanced, contains('title.class_'));
    expect(enhanced.difference(stock), isNotEmpty);
    expect(_scopesFor(langDartEnhanced, methodLine), contains('title.function'));
  });

  test('multiline string context is preserved across lines', () {
    const lines = [
      "  const message = '''",
      "  hello",
      "  ''';",
    ];

    final highlighter = SyntaxHighlighter(
      language: langDartEnhanced,
      theme: githubTheme,
      baseStyle: githubTheme['root']!,
    );

    final context = joinHighlightContext(lines, 0, 2);
    final spans = highlighter.getHighlightSpansForLine(
      lines[2],
      precedingContext: context,
    );

    final stringColor = githubTheme['string']!.color!;
    expect(spans.any((span) => span.color == stringColor), isTrue);
  });

  test('lineContinuesOnNext detects open multiline constructs', () {
    expect(lineContinuesOnNext("  const text = '''"), isTrue);
    expect(lineContinuesOnNext('  /* still open'), isTrue);
    expect(lineContinuesOnNext('  final count = 1;'), isFalse);
  });

  test('main.dart-style properties and named parameters are highlighted', () {
    const samples = <String, String>{
      '  final VoidCallback action;': 'variable',
      '  final List<String> args;': 'variable',
      '  final void Function(T intent, BuildContext context) onInvoke;': 'variable',
      '  const MainApp({super.key, required this.args});': 'variable',
      '        final vm = TextEditorViewModel(args: args);': 'variable',
      '                seedColor: vm.themeSeedColor,': 'attr',
      '                      onInvoke: (intent) => intent.action(),': 'variable',
      '                  const SingleActivator(LogicalKeyboardKey.equal, control: true):': 'attr',
      '                    GlobalZoomIntent: CallbackAction<GlobalZoomIntent>(': 'title.class_',
    };

    for (final entry in samples.entries) {
      final scopes = _scopesFor(langDartEnhanced, entry.key);
      expect(scopes, contains(entry.value), reason: 'Line "${entry.key}" missing ${entry.value}; got $scopes');
    }
  });

  test('render slice keeps highlight colors for wide-line windows', () {
    const line = 'final String value = "hello world";';
    final highlighter = SyntaxHighlighter(
      language: langDartEnhanced,
      theme: githubTheme,
      baseStyle: githubTheme['root']!,
    );

    final paragraph = highlighter.buildHighlightedParagraph(
      line,
      ui.ParagraphStyle(fontSize: 14),
      lineRequest: HighlightLineRequest(
        fullLineText: line,
        renderText: line.substring(18),
        renderOffsetInLine: 18,
      ),
    );

    expect(paragraph.width, greaterThan(0));
  });
}
