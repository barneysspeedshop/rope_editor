import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rope_editor/rope_editor.dart';

void main() {
  setUpAll(() async {
    await RustLib.init();
  });

  test('Performance: Rapid typing simulation', () {
    final stopwatch = Stopwatch()..start();
    
    // Create a document with 10000 lines
    final largeText = List.generate(10000, (i) => 'Line $i with some content').join('\n');
    final controller = RopeEditorController(text: largeText);
    
    if (kDebugMode) {
      print('Initial document created with ${controller.rope.lineCount} lines');
    }
    
    // Simulate rapid typing at the beginning of the document (100 characters)
    final typingStart = Stopwatch()..start();
    for (int i = 0; i < 100; i++) {
      controller.replaceRange(0, 0, 'x');
    }
    typingStart.stop();
    
    if (kDebugMode) {
      print('100 single-char insertions took: ${typingStart.elapsedMilliseconds}ms');
    }
    
    // The key optimization: with lazy metrics update, inserts should be fast
    // because we don't rebuild the SumTree on every keystroke.
    // Only when we query metrics (like getting line count) do we rebuild.
    
    expect(typingStart.elapsedMilliseconds, lessThan(200), 
      reason: 'Typing simulation should complete in under 200ms with lazy metrics');
    
    // Now force metrics rebuild by querying line count
    final queryStart = Stopwatch()..start();
    final lineCount = controller.rope.lineCount;
    queryStart.stop();
    
    if (kDebugMode) {
      print('Querying line count after edits took: ${queryStart.elapsedMilliseconds}ms');
    }
    if (kDebugMode) {
      print('Final line count: $lineCount');
    }
    
    stopwatch.stop();
    if (kDebugMode) {
      print('Total test time: ${stopwatch.elapsedMilliseconds}ms');
    }
    
    expect(controller.text.startsWith('x' * 100), isTrue);
  });

  test('Performance: Paste large text', () {
    final controller = RopeEditorController(text: 'Initial text');
    
    // Simulate pasting a large block of text (1000 lines)
    final largeText = List.generate(1000, (i) => 'Pasted line $i').join('\n');
    
    final pasteStart = Stopwatch()..start();
    controller.replaceRange(0, 0, largeText);
    pasteStart.stop();
    
    if (kDebugMode) {
      print('Pasting 1000 lines took: ${pasteStart.elapsedMilliseconds}ms');
    }
    
    // Even large pastes should be reasonably fast
    expect(pasteStart.elapsedMilliseconds, lessThan(100),
      reason: 'Pasting 1000 lines should complete in under 100ms');
  });

  test('Performance: Mixed operations', () {
    final largeText = List.generate(5000, (i) => 'Line $i').join('\n');
    final controller = RopeEditorController(text: largeText);
    
    final stopwatch = Stopwatch()..start();
    
    // Insert at beginning
    controller.replaceRange(0, 0, 'Start\n');
    
    // Insert in middle
    final midpoint = controller.length ~/ 2;
    controller.replaceRange(midpoint, midpoint, 'Middle\n');
    
    // Insert at end
    controller.replaceRange(controller.length, controller.length, '\nEnd');
    
    // Delete some text
    controller.replaceRange(0, 6, ''); // Remove "Start\n"
    
    stopwatch.stop();
    
    if (kDebugMode) {
      print('Mixed operations on 5000-line document took: ${stopwatch.elapsedMilliseconds}ms');
    }
    
    expect(stopwatch.elapsedMilliseconds, lessThan(50),
      reason: 'Mixed operations should be very fast with lazy metrics');
  });
}
