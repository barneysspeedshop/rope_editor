import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rope_editor/rope_editor.dart';

void main() {
  setUpAll(() async {
    await RustLib.init();
  });

  test('indentSelection inserts spaces on a single line', () {
    final controller = RopeEditorController(text: 'alpha');
    controller.selection = const TextSelection.collapsed(offset: 0);

    controller.indentSelection('  ');

    expect(controller.text, '  alpha');
    expect(controller.selection, const TextSelection.collapsed(offset: 2));
  });

  test('indentSelection indents every selected line together', () {
    final controller = RopeEditorController(text: 'one\ntwo\nthree');
    controller.selection = const TextSelection(baseOffset: 1, extentOffset: 7);

    controller.indentSelection('  ');

    expect(controller.text, '  one\n  two\nthree');
    expect(
      controller.selection,
      const TextSelection(baseOffset: 3, extentOffset: 11),
    );
  });

  test('indentSelection preserves partial-line selection anchors', () {
    final controller = RopeEditorController(text: 'one\ntwo\nthree');
    controller.selection = const TextSelection(baseOffset: 2, extentOffset: 6);

    controller.indentSelection('  ');

    expect(controller.text, '  one\n  two\nthree');
    expect(
      controller.selection,
      const TextSelection(baseOffset: 4, extentOffset: 10),
    );
  });

  test('outdentSelection removes one indent level from selected lines', () {
    final controller = RopeEditorController(text: '    one\n    two\nthree');
    controller.selection = const TextSelection(baseOffset: 6, extentOffset: 14);

    controller.outdentSelection(2);

    expect(controller.text, '  one\n  two\nthree');
    expect(
      controller.selection,
      const TextSelection(baseOffset: 4, extentOffset: 10),
    );
  });

  test('outdentSelection removes a tab from the current line', () {
    final controller = RopeEditorController(text: '\talpha');
    controller.selection = const TextSelection.collapsed(offset: 2);

    controller.outdentSelection(2);

    expect(controller.text, 'alpha');
    expect(controller.selection, const TextSelection.collapsed(offset: 1));
  });

  test('indentSelection does not indent lines above or below the selection', () {
    final controller = RopeEditorController(text: 'one\ntwo\nthree\nfour');
    // Select "two" through "three" only.
    controller.selection = const TextSelection(baseOffset: 4, extentOffset: 14);

    controller.indentSelection('  ');

    expect(controller.text, 'one\n  two\n  three\nfour');
  });

  test('indentSelection ignores boundary newline before first selected line', () {
    final controller = RopeEditorController(text: 'one\ntwo\nthree\nfour');
    // Selection starts on the newline after "one".
    controller.selection = const TextSelection(baseOffset: 3, extentOffset: 14);

    controller.indentSelection('  ');

    expect(controller.text, 'one\n  two\n  three\nfour');
  });

  test('indentSelection includes line below when selection reaches its content', () {
    final controller = RopeEditorController(text: 'one\ntwo\nthree\nfour');
    controller.selection = const TextSelection(baseOffset: 4, extentOffset: 15);

    controller.indentSelection('  ');

    expect(controller.text, 'one\n  two\n  three\n  four');
  });

  test('indentSelection block-indents a line that includes its trailing newline', () {
    final controller = RopeEditorController(text: 'one\ntwo\nthree');
    controller.selection = const TextSelection(baseOffset: 4, extentOffset: 8);

    controller.indentSelection('  ');

    expect(controller.text, 'one\n  two\nthree');
  });

  test('indentSelection does not indent line below when selection ends mid-line', () {
    final controller = RopeEditorController(text: 'one\ntwo\nthree\nfour');
    // Select from "wo" on line two through "thr" on line three.
    controller.selection = const TextSelection(baseOffset: 5, extentOffset: 12);

    controller.indentSelection('  ');

    expect(controller.text, 'one\n  two\n  three\nfour');
  });
}
