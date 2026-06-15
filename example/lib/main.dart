import 'package:flutter/material.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:rope_editor/rope_editor.dart';

void main() async {
  // Ensure Flutter bindings are initialized before calling RustLib.init()
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the underlying Rust library. 
  // This is required for the Rope implementation to function.
  try {
    await RustLib.init();
  } catch (e) {
    debugPrint('Failed to initialize Rust library: $e');
  }

  runApp(const RopeEditorExampleApp());
}

class RopeEditorExampleApp extends StatelessWidget {
  const RopeEditorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rope Editor Basic Example',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const EditorPage(),
    );
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final RopeEditorController _controller;
  late final FindController _findController;

  @override
  void initState() {
    super.initState();
    // Initialize the controller which manages the text via the Rust rope
    _controller = RopeEditorController();
    _findController = FindController(_controller);

    // Set initial content
    _controller.text = "Hello Rope Editor!\n\n"
        "This is a basic implementation of the editor using a Rust-backed rope data structure.\n"
        "It handles large files efficiently by minimizing FFI overhead.";
  }

  @override
  void dispose() {
    // Always dispose the controller to clean up native resources
    _findController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editorTheme = isDark ? githubDarkTheme : githubTheme;
    final rootStyle = editorTheme['root']!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rope Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () => _controller.undo(),
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: () => _controller.redo(),
          ),
        ],
      ),
      body: RopeEditor(
        controller: _controller,
        findController: _findController,
        editorTheme: editorTheme,
        autoFocus: true,
        textStyle: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: rootStyle.color,
        ),
      ),
    );
  }
}