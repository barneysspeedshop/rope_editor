export 'src/editor/editor.dart';
export 'src/controller/controller.dart';
export 'src/styling.dart';
export 'src/syntax/syntax_highlighter.dart';
export 'src/syntax/syntax_highlight_context.dart';
export 'src/syntax/languages/dart_enhanced.dart';
export 'src/controller/find_controller.dart';
export 'src/rope/undo_redo.dart';

// New Zed-style features
export 'src/rope/anchor.dart';
export 'src/rope/point.dart';
export 'src/rope/diff.dart';
export 'src/rope/version.dart';

// Export the generated Rust bridge for initialization in the main app
export 'src/rust/frb_generated.dart' show RustLib;

// Export batch API types
export 'src/rust/api.dart' show MinimapLineDensity;

// Re-export relevant types from re_highlight
export 'package:re_highlight/re_highlight.dart' show Mode;
export 'package:re_highlight/styles/all.dart';
export 'package:re_highlight/languages/all.dart';
