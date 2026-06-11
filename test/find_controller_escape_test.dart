import 'package:flutter_test/flutter_test.dart';
import 'package:rope_editor/rope_editor.dart';

void main() {
  setUpAll(() async {
    await RustLib.init();
  });

  test('find supports escaped newline/tab/carriage-return sequences', () {
    final controller = RopeEditorController(text: 'one\ntwo\tthree\r\nfour');
    final findController = FindController(controller);

    findController.find(r'\n');
    expect(findController.matchCount, 2);

    findController.find(r'\t');
    expect(findController.matchCount, 1);

    findController.find(r'\r');
    expect(findController.matchCount, 1);

    findController.dispose();
    controller.dispose();
  });

  test('replace and replaceAll decode escaped replacement sequences', () {
    final controller = RopeEditorController(text: 'A|B|C');
    final findController = FindController(controller);

    findController.find('|');
    expect(findController.matchCount, 2);
    findController.replaceInputController.text = r'\n';
    findController.replace();
    expect(controller.text, 'A\nB|C');

    findController.find('|');
    findController.replaceInputController.text = r'\t$1';
    findController.replaceAll();
    expect(controller.text, 'A\nB\t\$1C');

    findController.dispose();
    controller.dispose();
  });

  test('regex replaceAll keeps capture groups and decodes escaped newlines', () {
    final controller = RopeEditorController(text: 'a1 b2');
    final findController = FindController(controller);

    findController.isRegex = true;
    findController.find(r'([a-z])(\d)');
    expect(findController.matchCount, 2);

    findController.replaceInputController.text = r'$1:$2\n';
    findController.replaceAll();
    expect(controller.text, 'a:1\n b:2\n');

    findController.dispose();
    controller.dispose();
  });
}
