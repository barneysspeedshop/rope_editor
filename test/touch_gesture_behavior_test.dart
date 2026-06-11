import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rope_editor/rope_editor.dart';

void main() {
  setUpAll(() async {
    await RustLib.init();
  });

  testWidgets('touch drag pans editor instead of selecting text', (WidgetTester tester) async {
    final controller = RopeEditorController(
      text: List.generate(300, (i) => 'line $i').join('\n'),
    );
    final vScrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: RopeEditor(
              controller: controller,
              findController: FindController(controller),
              lineWrap: true,
              verticalScrollController: vScrollController,
            ),
          ),
        ),
      ),
    );

    // Caret blink repeats indefinitely; pumpAndSettle would time out.
    await tester.pump();

    final editorCenter = tester.getCenter(find.byType(RopeEditor));
    final gesture = await tester.startGesture(editorCenter, kind: PointerDeviceKind.touch);
    await gesture.moveBy(const Offset(0, -140));
    await gesture.up();
    await tester.pump();

    expect(vScrollController.offset, greaterThan(0));
    expect(controller.selection.isCollapsed, isTrue);
  });

  testWidgets('touch long-press drag starts word selection', (WidgetTester tester) async {
    final controller = RopeEditorController(text: 'hello world\nsecond line');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: RopeEditor(
              controller: controller,
              findController: FindController(controller),
              lineWrap: true,
              enableGutter: false,
              enableGutterDivider: false,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    final editorTopLeft = tester.getTopLeft(find.byType(RopeEditor));
    final gesture = await tester.startGesture(
      editorTopLeft + const Offset(16, 14),
      kind: PointerDeviceKind.touch,
    );

    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(70, 0));
    await gesture.up();
    await tester.pump();

    expect(controller.selection.isCollapsed, isFalse);
    final selected = controller.text.substring(controller.selection.start, controller.selection.end);
    expect(selected.contains('hello'), isTrue);
  });

  testWidgets('touch pan keeps existing selection while viewport scrolls', (WidgetTester tester) async {
    final controller = RopeEditorController(
      text: List.generate(300, (i) => 'line $i').join('\n'),
    );
    final vScrollController = ScrollController();
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: RopeEditor(
              controller: controller,
              findController: FindController(controller),
              lineWrap: true,
              verticalScrollController: vScrollController,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    const initialSelection = TextSelection(baseOffset: 0, extentOffset: 5);
    final editorCenter = tester.getCenter(find.byType(RopeEditor));
    final gesture = await tester.startGesture(editorCenter, kind: PointerDeviceKind.touch);
    await gesture.moveBy(const Offset(0, -140));
    await gesture.up();
    await tester.pump();

    expect(vScrollController.offset, greaterThan(0));
    expect(controller.selection, initialSelection);
  });

  testWidgets('touch tap clears existing selection when there is no pan', (WidgetTester tester) async {
    final controller = RopeEditorController(
      text: List.generate(80, (i) => 'line $i').join('\n'),
    );
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: RopeEditor(
              controller: controller,
              findController: FindController(controller),
              lineWrap: true,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    final tapTarget = tester.getCenter(find.byType(RopeEditor));
    final gesture = await tester.startGesture(tapTarget, kind: PointerDeviceKind.touch);
    await gesture.up();
    await tester.pump();

    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.start, isNot(equals(0)));
  });
}
