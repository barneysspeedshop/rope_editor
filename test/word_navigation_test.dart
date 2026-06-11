import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:rope_editor/rope_editor.dart';

void main() {
  setUpAll(() async {
    await RustLib.init();
  });

  test('Ctrl+Right style movement jumps to next word boundary', () {
    final controller = RopeEditorController(text: 'one two_three, four');

    controller.selection = const TextSelection.collapsed(offset: 0);
    controller.pressRightWordArrowKey();
    expect(controller.selection, const TextSelection.collapsed(offset: 4));

    controller.pressRightWordArrowKey();
    expect(controller.selection, const TextSelection.collapsed(offset: 15));

    controller.pressRightWordArrowKey();
    expect(controller.selection, const TextSelection.collapsed(offset: 19));
  });

  test('Ctrl+Left style movement jumps to previous word boundary', () {
    final controller = RopeEditorController(text: 'one two_three, four');

    controller.selection = const TextSelection.collapsed(offset: 19);
    controller.pressLeftWordArrowKey();
    expect(controller.selection, const TextSelection.collapsed(offset: 15));

    controller.pressLeftWordArrowKey();
    expect(controller.selection, const TextSelection.collapsed(offset: 4));

    controller.pressLeftWordArrowKey();
    expect(controller.selection, const TextSelection.collapsed(offset: 0));
  });

  test('Ctrl+Shift+Arrow expands and contracts selection by word', () {
    final controller = RopeEditorController(text: 'one two_three, four');

    controller.selection = const TextSelection.collapsed(offset: 15);

    controller.pressLeftWordArrowKey(isShiftPressed: true);
    expect(controller.selection.baseOffset, 15);
    expect(controller.selection.extentOffset, 4);
    expect(controller.selection.isCollapsed, isFalse);

    controller.pressRightWordArrowKey(isShiftPressed: true);
    expect(controller.selection.baseOffset, 15);
    expect(controller.selection.extentOffset, 15);
    expect(controller.selection.isCollapsed, isTrue);
  });

  test('Ctrl+Right crosses to next line word from end-of-line', () {
    final controller = RopeEditorController(text: 'alpha\n  beta gamma');

    // Caret at end of first line (just before \n)
    controller.selection = const TextSelection.collapsed(offset: 5);
    controller.pressRightWordArrowKey();

    // Should skip newline + indentation and land on start of "beta"
    expect(controller.selection, const TextSelection.collapsed(offset: 8));
  });

  test('Ctrl+Left crosses to previous line word from start-of-line', () {
    final controller = RopeEditorController(text: 'alpha\nbeta gamma');

    // Caret at beginning of second line
    controller.selection = const TextSelection.collapsed(offset: 6);
    controller.pressLeftWordArrowKey();

    // Should jump to start of "alpha" on previous line
    expect(controller.selection, const TextSelection.collapsed(offset: 0));
  });
}
