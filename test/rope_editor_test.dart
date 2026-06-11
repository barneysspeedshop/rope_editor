import 'package:flutter_test/flutter_test.dart';

import 'package:rope_editor/rope_editor.dart';

void main() {
  setUpAll(() async {
    await RustLib.init();
  });

  test('RopeEditorController text manipulation', () {
    final controller = RopeEditorController(text: 'Hello');
    expect(controller.text, 'Hello');
    controller.replaceRange(5, 5, ' World');
    expect(controller.text, 'Hello World');
  });
}
