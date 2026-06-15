import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rope_editor/rope_editor.dart';

void main() {
  setUpAll(() async {
    await RustLib.init();
  });

  Future<void> pumpEditor(WidgetTester tester, RopeEditorController controller) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 220,
            child: RopeEditor(
              controller: controller,
              findController: FindController(controller),
              lineWrap: true,
              enableGutter: false,
              enableGutterDivider: false,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
  }

  testWidgets('double click selects word under cursor', (WidgetTester tester) async {
    final controller = RopeEditorController(text: 'hello world\nsecond line');
    await pumpEditor(tester, controller);

    final editorTopLeft = tester.getTopLeft(find.byType(RopeEditor));
    final wordClick = editorTopLeft + const Offset(24, 14);

    await tester.tapAt(wordClick, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.tapAt(wordClick, kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(controller.selection.isCollapsed, isFalse);
    final selected = controller.text.substring(controller.selection.start, controller.selection.end);
    expect(selected, 'hello');
  });

  testWidgets('triple click selects whole line under cursor', (WidgetTester tester) async {
    final controller = RopeEditorController(text: 'hello world\nsecond line');
    await pumpEditor(tester, controller);

    final editorTopLeft = tester.getTopLeft(find.byType(RopeEditor));
    final lineClick = editorTopLeft + const Offset(80, 14);

    await tester.tapAt(lineClick, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.tapAt(lineClick, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.tapAt(lineClick, kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(controller.selection.isCollapsed, isFalse);
    final selected = controller.text.substring(controller.selection.start, controller.selection.end);
    expect(selected, 'hello world');
  });
}
