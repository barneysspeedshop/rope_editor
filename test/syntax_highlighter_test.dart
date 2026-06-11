import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:rope_editor/rope_editor.dart';
import 'package:rope_editor/src/editor/editor_field.dart';

void main() {
  setUpAll(() async {
    await RustLib.init();
  });

  test('getHighlightSpans returns multiple colored spans for JSON', () {
    final highlighter = SyntaxHighlighter(
      language: langJson,
      theme: {
        'attr': const TextStyle(color: Color(0xFFFF0000)),
        'string': const TextStyle(color: Color(0xFF00FF00)),
        'key': const TextStyle(color: Color(0xFFFF0000)),
        'punctuation': const TextStyle(color: Color(0xFF888888)),
        'root': const TextStyle(color: Color(0xFF000000)),
      },
      baseStyle: const TextStyle(fontSize: 14, color: Color(0xFF000000)),
    );

    final spans = highlighter.getHighlightSpans('{"key": "value"}');
    expect(spans, isNotEmpty);
    expect(spans.any((span) => span.color != const Color(0xFF000000)), isTrue);
    expect(spans.first.start, 0);
    expect(spans.last.end, '{"key": "value"}'.length);
  });

  test('getHighlightSpans returns empty list for oversized lines', () {
    final highlighter = SyntaxHighlighter(
      language: langJson,
      theme: const {'root': TextStyle(color: Color(0xFF000000))},
      baseStyle: const TextStyle(fontSize: 14, color: Color(0xFF000000)),
    );

    expect(
      highlighter.getHighlightSpans('a' * (SyntaxHighlighter.maxHighlightLength + 1)),
      isEmpty,
    );
  });

  testWidgets('RopeEditor renders and populates paragraph cache with highlighting', (WidgetTester tester) async {
    final controller = RopeEditorController(text: '{"syntax": "works"}');
    
    // Simple theme to verify color application logic
    final theme = {
      'attr': const TextStyle(color: Color(0xFFFF0000)), // Red for keys
      'string': const TextStyle(color: Color(0xFF00FF00)), // Green for values
      'key': const TextStyle(color: Color(0xFFFF0000)), // Alias for keys
      'punctuation': const TextStyle(color: Color(0xFF888888)), // Braces/colons
      'root': const TextStyle(color: Color(0xFF000000), backgroundColor: Color(0xFFFFFFFF)),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 500,
            child: RopeEditor(
              controller: controller,
              findController: FindController(controller),
              language: langJson,
              editorTheme: theme,
              textStyle: const TextStyle(fontSize: 14, fontFamily: 'Courier'),
            ),
          ),
        ),
      ),
    );

    // Trigger a frame to ensure the RenderRopeField paints and builds paragraphs.
    await tester.pump(const Duration(milliseconds: 100));

    // Find the RenderObject
    final RenderRopeField renderObject = tester.allRenderObjects.whereType<RenderRopeField>().first;
    
    // 1. Verify that the paragraph cache was populated for the visible line
    expect(renderObject.paragraphCache.containsKey(0), isTrue, 
        reason: 'The renderer should have cached the paragraph for the first line.');

    // 2. Verify that the paragraph has a non-zero width/height
    expect(renderObject.paragraphCache[0]!.height, greaterThan(0));
    expect(renderObject.paragraphCache[0]!.width, greaterThan(0));

    // 3. Verify that the highlighter actually applied colors.
    // If colors are working, the style cache should contain the base style 
    // plus the styles for "attr" (red) and "string" (green).
    expect(renderObject.highlighter.debugStyleCacheSize, greaterThan(1),
        reason: 'The highlighter should have applied and cached multiple styles for the JSON tokens.');
  });

  testWidgets('Long single-line horizontal scroll back keeps left-edge text interactive', (WidgetTester tester) async {
    final controller = RopeEditorController(text: 'a' * 30000);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 220,
            child: RopeEditor(
              controller: controller,
              findController: FindController(controller),
              language: langJson,
              textStyle: const TextStyle(fontSize: 14, fontFamily: 'Courier'),
              enableGutter: false,
              enableGutterDivider: false,
            ),
          ),
        ),
      ),
    );

    // Caret blink repeats indefinitely; pumpAndSettle would time out.
    await tester.pump();

    final horizontalScrollFinder = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScrollFinder, findsOneWidget);

    // Move far enough right so long-line slicing uses a non-zero start char,
    // then return left to exercise cache invalidation correctness.
    await tester.drag(horizontalScrollFinder, const Offset(-2400, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(horizontalScrollFinder, const Offset(2400, 0));
    await tester.pump(const Duration(milliseconds: 100));

    final editorTopLeft = tester.getTopLeft(find.byType(RopeEditor));
    await tester.tapAt(editorTopLeft + const Offset(12, 12));
    await tester.pump();

    expect(
      controller.selection.extentOffset,
      lessThan(10),
      reason: 'Clicking near the left edge after scrolling back should place the cursor near the start of the line.',
    );
  });

  testWidgets('Editor keeps paragraph cache after viewport resize', (WidgetTester tester) async {
    final controller = RopeEditorController(text: 'hello\nworld\nline three');

    Future<void> pumpWithHeight(double height) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: height,
              child: RopeEditor(
                controller: controller,
                findController: FindController(controller),
                language: langJson,
                textStyle: const TextStyle(fontSize: 14, fontFamily: 'Courier'),
              ),
            ),
          ),
        ),
      );
      // Caret blink repeats indefinitely; pumpAndSettle would time out.
      await tester.pump();
    }

    await pumpWithHeight(220);

    final RenderRopeField renderObject = tester.allRenderObjects.whereType<RenderRopeField>().first;
    expect(renderObject.paragraphCache.containsKey(0), isTrue);

    // Mimics Android soft-keyboard / inset resize without a scroll pixel change.
    await pumpWithHeight(120);

    expect(renderObject.paragraphCache.containsKey(0), isTrue);
    expect(renderObject.paragraphCache[0]!.height, greaterThan(0));
  });
}