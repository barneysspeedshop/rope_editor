import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // Caret blink repeats indefinitely; pumpAndSettle would time out.
    await tester.pump();
  }

  testWidgets('Shift+click extends selection from cursor anchor', (WidgetTester tester) async {
    final controller = RopeEditorController(text: 'abcdefghijklmnopqrstuvwxyz');
    await pumpEditor(tester, controller);

    final editorTopLeft = tester.getTopLeft(find.byType(RopeEditor));
    final firstClick = editorTopLeft + const Offset(14, 14);
    final secondClick = editorTopLeft + const Offset(140, 14);

    await tester.tapAt(firstClick, kind: PointerDeviceKind.mouse);
    await tester.pump();

    final int anchor = controller.selection.extentOffset;
    expect(controller.selection.isCollapsed, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(secondClick, kind: PointerDeviceKind.mouse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(controller.selection.isCollapsed, isFalse);
    expect(controller.selection.baseOffset, equals(anchor));
    expect(controller.selection.extentOffset, isNot(equals(anchor)));
  });

  testWidgets('Shift+arrow extends selection from current cursor', (WidgetTester tester) async {
    final controller = RopeEditorController(text: 'abcdefghijklmnopqrstuvwxyz');
    await pumpEditor(tester, controller);

    final editorTopLeft = tester.getTopLeft(find.byType(RopeEditor));
    await tester.tapAt(editorTopLeft + const Offset(14, 14));
    await tester.pump();

    final int anchor = controller.selection.extentOffset;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(controller.selection.isCollapsed, isFalse);
    expect(controller.selection.baseOffset, equals(anchor));
    expect(controller.selection.extentOffset, greaterThan(anchor));
  });

  testWidgets('Selection is synced to IME when focus attaches', (WidgetTester tester) async {
    final controller = RopeEditorController(text: 'abcdefghijklmnopqrstuvwxyz');
    await pumpEditor(tester, controller);

    // Reproduce click-before-focus ordering: selection changes first while
    // there is no active platform connection yet.
    controller.selection = const TextSelection.collapsed(offset: 10);
    await tester.pump();

    controller.focusNode!.requestFocus();
    await tester.pump();

    final setEditingStateCalls = tester.testTextInput.log.where((entry) => entry.method == 'TextInput.setEditingState');
    expect(setEditingStateCalls.isNotEmpty, isTrue);

    final dynamic lastArgs = setEditingStateCalls.last.arguments;
    expect(lastArgs, isA<Map<dynamic, dynamic>>());

    final argsMap = lastArgs as Map<dynamic, dynamic>;
    expect(argsMap['selectionBase'], equals(10));
    expect(argsMap['selectionExtent'], equals(10));
  });
}
