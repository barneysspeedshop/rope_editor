import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:rope_editor/rope_editor.dart';

void main() {
  setUpAll(() async {
    await RustLib.init();
  });

  group('Undo/Redo System', () {
    late RopeEditorController controller;
    late UndoRedoController undoController;

    setUp(() {
      // Initialize controller with some text and link the undo controller
      controller = RopeEditorController(text: 'The quick brown fox');
      undoController = UndoRedoController();
      controller.setUndoController(undoController);
    });

    test('Basic insertion undo/redo', () {
      // Insert text at the end
      controller.selection = const TextSelection.collapsed(offset: 19);
      controller.replaceRange(19, 19, ' jumps');
      expect(controller.text, 'The quick brown fox jumps');

      controller.undo();
      expect(controller.text, 'The quick brown fox');

      controller.redo();
      expect(controller.text, 'The quick brown fox jumps');
    });

    test('Basic deletion undo/redo', () {
      // Delete "fox"
      controller.selection = const TextSelection(baseOffset: 16, extentOffset: 19);
      controller.replaceRange(16, 19, '');
      expect(controller.text, 'The quick brown ');

      controller.undo();
      expect(controller.text, 'The quick brown fox');
      expect(controller.selection.start, 16);
      expect(controller.selection.end, 19);
    });

    test('Replace range undo/redo', () {
      // Replace "quick" with "slow"
      controller.selection = const TextSelection(baseOffset: 4, extentOffset: 9);
      controller.replaceRange(4, 9, 'slow');
      expect(controller.text, 'The slow brown fox');

      controller.undo();
      expect(controller.text, 'The quick brown fox');
      // Selection should restore to the original replacement range
      expect(controller.selection.start, 4);
      expect(controller.selection.end, 9);
    });

    test('Merging rapid character insertions', () {
      // Simulate typing "!" character by character
      // In tests, these happen within the 500ms window
      controller.replaceRange(19, 19, '!');
      controller.replaceRange(20, 20, '!');
      controller.replaceRange(21, 21, '!');

      expect(controller.text, 'The quick brown fox!!!');
      expect(undoController.undoStackSize, 1, reason: 'Rapid insertions should be merged into one operation');

      controller.undo();
      expect(controller.text, 'The quick brown fox');
    });

    test('Merging rapid backspaces', () {
      // Move cursor to end
      controller.selection = const TextSelection.collapsed(offset: 19);
      
      // Simulate 3 backspaces
      controller.backspace(); // deletes 'x'
      controller.backspace(); // deletes 'o'
      controller.backspace(); // deletes 'f'

      expect(controller.text, 'The quick brown ');
      expect(undoController.undoStackSize, 1, reason: 'Sequential backspaces should be merged');

      controller.undo();
      expect(controller.text, 'The quick brown fox');
    });

    test('Undo restores correct selection', () {
      // Move cursor to middle of "quick"
      controller.selection = const TextSelection.collapsed(offset: 7);
      
      // Perform edit
      controller.replaceRange(7, 7, '-');
      final selectionAfterEdit = controller.selection;
      
      expect(controller.text, 'The qui-ck brown fox');

      controller.undo();
      expect(controller.text, 'The quick brown fox');
      expect(controller.selection.extentOffset, 7, reason: 'Undo should restore the cursor to where it was before the edit');

      controller.redo();
      expect(controller.selection, selectionAfterEdit, reason: 'Redo should restore the cursor to where it was after the edit');
    });

    test('Redo stack clears on fresh edit', () {
      controller.replaceRange(19, 19, '...');
      controller.undo();
      expect(undoController.canRedo, isTrue);

      // New unrelated edit
      controller.replaceRange(0, 3, 'A');
      expect(undoController.canRedo, isFalse, reason: 'Redo stack must clear when a new change is made');
    });
  });
}