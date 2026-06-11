import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rope_editor/rope_editor.dart';

void main() {
  setUpAll(() async {
    await RustLib.init();
  });

  testWidgets('touch tap re-opens IME after platform closes connection', (WidgetTester tester) async {
    final controller = RopeEditorController(text: 'hello world');

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

    // Caret blink repeats indefinitely; pumpAndSettle would time out.
    await tester.pump();

    final tapTarget = tester.getTopLeft(find.byType(RopeEditor)) + const Offset(14, 14);

    final firstGesture = await tester.startGesture(tapTarget, kind: PointerDeviceKind.touch);
    await firstGesture.up();
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);

    // Platform dismisses the soft keyboard while editor focus remains.
    tester.testTextInput.closeConnection();
    tester.testTextInput.hide();
    await tester.pump();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(controller.focusNode!.hasFocus, isTrue);

    final secondGesture = await tester.startGesture(tapTarget, kind: PointerDeviceKind.touch);
    await secondGesture.up();
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
  });
}
