import 'dart:convert';
import 'package:flutter/foundation.dart' show TargetPlatform, compute, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:legacy_context_menu/legacy_context_menu.dart';
import 'package:legacy_keyboard_shortcut_decoration/legacy_keyboard_shortcut_decoration.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:rope_editor/src/controller/controller.dart';
import 'package:rope_editor/src/controller/find_controller.dart';
import 'package:rope_editor/src/editor/editor_field.dart';

// Assuming the internal parts are still needed for rendering
// part 'editor_field.dart';

/// Top-level function required by [compute] – must not be a closure or method.
/// Parses [text] as JSON and re-serialises it with 2-space indentation.
/// Returns a record with either a formatted [result] or an [error] message.
({String? result, String? error}) _formatJsonInIsolate(String text) {
  try {
    final dynamic decoded = jsonDecode(text);
    final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
    return (result: formatted, error: null);
  } catch (e) {
    return (result: null, error: 'Invalid JSON: $e');
  }
}

/// Controls JSON formatting for a [RopeEditor].
///
/// Create an instance, pass it to [RopeEditor.jsonFormatterController], and
/// use it however fits your UI — an AppBar button, a FAB, a context menu, etc.
///
/// ```dart
/// final _jsonFormatter = JsonFormatterController();
///
/// // Trigger from any widget:
/// IconButton(
///   icon: const Icon(Icons.auto_fix_high),
///   onPressed: _jsonFormatter.format,
/// );
///
/// // Observe state:
/// ListenableBuilder(
///   listenable: _jsonFormatter,
///   builder: (context, _) {
///     if (_jsonFormatter.isFormatting) return const CircularProgressIndicator();
///     if (_jsonFormatter.lastError != null) return Text(_jsonFormatter.lastError!);
///     return const SizedBox.shrink();
///   },
/// );
/// ```
class JsonFormatterController extends ChangeNotifier {
  bool _isFormatting = false;
  String? _lastError;

  /// Whether a format operation is currently in progress.
  bool get isFormatting => _isFormatting;

  /// The error message from the most recent failed format attempt,
  /// or `null` if the last attempt succeeded or none has been made.
  String? get lastError => _lastError;

  /// Triggers pretty-printing of the JSON content in the attached [RopeEditor].
  /// No-op if formatting is already in progress or no editor is attached.
  Future<void> format() async => _formatImpl?.call();

  /// Clears [lastError].
  void dismissError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  // --- Internal wiring set by _RopeEditorState ---
  Future<void> Function()? _formatImpl;

  void _setFormatting(bool value) {
    if (_isFormatting == value) return;
    _isFormatting = value;
    notifyListeners();
  }

  void _setError(String? error) {
    if (_lastError == error) return;
    _lastError = error;
    notifyListeners();
  }
}

class RopeEditor extends StatefulWidget {
  final RopeEditorController controller;
  final FindController findController;
  final PreferredSizeWidget Function(BuildContext context, FindController findController)? finderBuilder;
  final Map<String, TextStyle>? editorTheme;
  final TextStyle? textStyle;
  final bool lineWrap;
  final bool enableGutter;
  final bool enableGutterDivider;
  final bool enableKeyboardSuggestions;
  final bool autoFocus;
  final ScrollController? verticalScrollController;
  final ScrollController? horizontalScrollController;
  final bool showVerticalScrollbar;
  final Mode? language;
  final String? filePath;
  final int tabSpaces;
  final double mobileSelectionHandleSize;

  /// Optional controller that lets you trigger JSON formatting and observe
  /// its state from outside the editor (e.g. an AppBar button or FAB).
  /// Only active when [language] is set to a JSON [Mode].
  final JsonFormatterController? jsonFormatterController;

  const RopeEditor({
    super.key,
    required this.controller,
    required this.findController,
    this.finderBuilder,
    this.editorTheme,
    this.textStyle,
    this.lineWrap = false,
    this.enableGutter = true,
    this.enableGutterDivider = true,
    this.enableKeyboardSuggestions = true,
    this.autoFocus = false,
    this.verticalScrollController,
    this.horizontalScrollController,
    this.showVerticalScrollbar = true,
    this.language,
    this.filePath,
    this.tabSpaces = 4,
    this.mobileSelectionHandleSize = 56,
    this.jsonFormatterController,
  }) : assert(mobileSelectionHandleSize >= 24);

  @override
  State<RopeEditor> createState() => _RopeEditorState();
}

class _RopeEditorState extends State<RopeEditor> with TickerProviderStateMixin {
  late final ScrollController _vscrollController;
  late final ScrollController _hscrollController;
  late final FocusNode _focusNode;
  late final AnimationController _caretBlinkController;
  final GlobalKey _editorStackKey = GlobalKey();
  final GlobalKey _ropeFieldKey = GlobalKey();
  TextInputConnection? _connection;
  bool _isHovering = false;
  bool _isSelectionBoundaryZoomVisible = false;
  bool _isDraggingStartBoundary = false;
  Offset? _selectionBoundaryZoomGlobalPosition;
  int? _selectionBoundaryZoomOffset;
  /// Opposite handle offset captured at drag start; stays fixed while dragging.
  int? _selectionHandleDragAnchorOffset;

  double? _lastReportedViewportHeight;
  double? _lastReportedViewportWidth;

  // --- JSON formatting state ---
  /// Simple re-entrancy guard. State is owned by [JsonFormatterController].
  bool _isFormattingJson = false;

  /// True when the `language` passed to the widget is JSON.
  bool get _isJsonFile => widget.language?.name == 'JSON';

  /// Threshold in characters above which a confirmation dialog is shown
  /// before formatting (a 500 KB JSON file can expand considerably).
  static const int _jsonLargeFileSizeThreshold = 102400 * 1024;

  bool get _isTouchPlatform => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isAndroidPlatform => defaultTargetPlatform == TargetPlatform.android;

  void _showSelectionBoundaryZoom({
    required bool isStartBoundary,
    required Offset globalPosition,
    required int textOffset,
  }) {
    if (!_isAndroidPlatform || !mounted) return;

    setState(() {
      _isSelectionBoundaryZoomVisible = true;
      _isDraggingStartBoundary = isStartBoundary;
      _selectionBoundaryZoomGlobalPosition = globalPosition;
      _selectionBoundaryZoomOffset = textOffset.clamp(0, widget.controller.length);
    });
  }

  void _updateSelectionBoundaryZoom({
    required bool isStartBoundary,
    required Offset globalPosition,
    required int textOffset,
  }) {
    if (!_isAndroidPlatform || !_isSelectionBoundaryZoomVisible || !mounted) return;

    setState(() {
      _isDraggingStartBoundary = isStartBoundary;
      _selectionBoundaryZoomGlobalPosition = globalPosition;
      _selectionBoundaryZoomOffset = textOffset.clamp(0, widget.controller.length);
    });
  }

  void _hideSelectionBoundaryZoom() {
    if (!_isSelectionBoundaryZoomVisible || !mounted) return;

    setState(() {
      _isSelectionBoundaryZoomVisible = false;
      _selectionBoundaryZoomGlobalPosition = null;
      _selectionBoundaryZoomOffset = null;
    });
  }

  /// Repaints the text field after viewport resizes (keyboard, rotation).
  ///
  /// Scroll listeners may not fire when metrics recover without a pixel change,
  /// which can leave text invisible on Android behind cached RepaintBoundaries.
  void _scheduleRenderFieldRepaintIfViewportChanged(double height, double width) {
    if (_lastReportedViewportHeight == height && _lastReportedViewportWidth == width) {
      return;
    }
    _lastReportedViewportHeight = height;
    _lastReportedViewportWidth = width;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = _ropeFieldKey.currentContext?.findRenderObject();
      if (renderObject is RenderRopeField && renderObject.attached) {
        renderObject.markNeedsPaint();
      }
    });
  }

  String _normalizeZoomPreviewChunk(String chunk) {
    return chunk.replaceAll('\r', '␍').replaceAll('\n', '⏎').replaceAll('\t', '⇥');
  }

  InlineSpan _buildSelectionBoundaryZoomText(int textOffset) {
    final int clampedOffset = textOffset.clamp(0, widget.controller.length);
    final int start = (clampedOffset - 12).clamp(0, widget.controller.length);
    final int end = (clampedOffset + 12).clamp(0, widget.controller.length);
    final String snippet = start < end ? widget.controller.rope.substring(start, end) : '';

    final int caretLocalOffset = (clampedOffset - start).clamp(0, snippet.length);
    final String left = _normalizeZoomPreviewChunk(snippet.substring(0, caretLocalOffset));
    final String right = _normalizeZoomPreviewChunk(snippet.substring(caretLocalOffset));

    return TextSpan(
      children: [
        TextSpan(text: left),
        const TextSpan(
          text: '│',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(text: right),
      ],
    );
  }

  Widget _buildSelectionBoundaryZoom() {
    if (!_isAndroidPlatform || !_isSelectionBoundaryZoomVisible) {
      return const Positioned.fill(child: SizedBox.shrink());
    }

    final Offset? globalPosition = _selectionBoundaryZoomGlobalPosition;
    final int? textOffset = _selectionBoundaryZoomOffset;
    final RenderBox? stackBox = _editorStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (globalPosition == null || textOffset == null || stackBox == null) {
      return const Positioned.fill(child: SizedBox.shrink());
    }

    const Size windowSize = Size(220, 68);
    const double horizontalMargin = 8;
    const double verticalMargin = 8;
    const double verticalGap = 18;

    final Offset local = stackBox.globalToLocal(globalPosition);
    final double left = (local.dx - (windowSize.width / 2)).clamp(
      horizontalMargin,
      (stackBox.size.width - windowSize.width - horizontalMargin).clamp(horizontalMargin, double.infinity),
    );
    final double top = (local.dy - windowSize.height - verticalGap).clamp(
      verticalMargin,
      (stackBox.size.height - windowSize.height - verticalMargin).clamp(verticalMargin, double.infinity),
    );

    final int line = widget.controller.getLineAtOffset(textOffset) + 1;
    final int lineStart = widget.controller.getLineStartOffset(line - 1);
    final int column = (textOffset - lineStart) + 1;
    final String boundaryLabel = _isDraggingStartBoundary ? 'Start boundary' : 'End boundary';

    return Positioned(
      left: left,
      top: top,
      width: windowSize.width,
      height: windowSize.height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: DefaultTextStyle(
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: widget.textStyle?.fontFamily,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$boundaryLabel • Ln $line, Col $column',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: ((widget.textStyle?.fontSize ?? 14.0) * 1.2).clamp(14.0, 22.0),
                        fontFamily: widget.textStyle?.fontFamily,
                      ),
                      children: [
                        _buildSelectionBoundaryZoomText(textOffset),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditorContextMenu(Offset globalPosition) async {
    final RopeEditorController controller = widget.controller;

    await showContextMenu(
      context: context,
      tapPosition: globalPosition,
      menuItems: [
        ContextMenuItem(
          caption: 'Cut',
          leading: const Icon(Icons.content_cut_outlined, size: 18),
          trailing: const LegacyKeyboardShortcut(shortcut: 'Ctrl+X'),
          onTap: controller.cut,
        ),
        ContextMenuItem(
          caption: 'Copy',
          leading: const Icon(Icons.content_copy_outlined, size: 18),
          trailing: const LegacyKeyboardShortcut(shortcut: 'Ctrl+C'),
          onTap: controller.copy,
        ),
        ContextMenuItem(
          caption: 'Paste',
          leading: const Icon(Icons.content_paste_outlined, size: 18),
          trailing: const LegacyKeyboardShortcut(shortcut: 'Ctrl+V'),
          onTap: () {
            controller.paste();
          },
        ),
        ContextMenuItem.divider,
        ContextMenuItem(
          caption: 'Select All',
          leading: const Icon(Icons.select_all_outlined, size: 18),
          trailing: const LegacyKeyboardShortcut(shortcut: 'Ctrl+A'),
          onTap: controller.selectAll,
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _vscrollController = widget.verticalScrollController ?? ScrollController();
    _hscrollController = widget.horizontalScrollController ?? ScrollController();
    _focusNode = widget.controller.focusNode ?? FocusNode();
    widget.controller.focusNode = _focusNode;

    _caretBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    widget.controller.requestCursorReset = _resetCursorBlink;
    widget.controller.setScrollCallback(_scrollToLine);

    _focusNode.addListener(_handleFocusChange);
    widget.controller.onConnectionClosed = _handleConnectionClosed;

    widget.jsonFormatterController?._formatImpl = _prettyPrintJson;

    if (widget.filePath != null && widget.filePath!.isNotEmpty) {
      // Schedule the file opening for the next frame.
      // This prevents the 'setState() or markNeedsBuild() called during build' error
      // that occurs when a controller notifies listeners (like a ViewModel)
      // while the widget tree is still in the middle of a build pass.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.openedFile = widget.filePath;
      });
    }

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    }
  }

  /// Pretty-prints the JSON content in a background isolate so the UI thread
  /// is never blocked. State is surfaced through [JsonFormatterController].
  Future<void> _prettyPrintJson() async {
    if (_isFormattingJson) return;
    final jfc = widget.jsonFormatterController;

    final text = widget.controller.text;

    if (text.length > _jsonLargeFileSizeThreshold) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Large file'),
          content: Text(
            'This file is ${(text.length / 1024).toStringAsFixed(0)} KB. '
            'Formatting may take a moment and use significant memory.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Format Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    _isFormattingJson = true;
    jfc?._setFormatting(true);
    jfc?._setError(null);

    try {
      final result = await compute(_formatJsonInIsolate, text);
      if (!mounted) return;
      if (result.result != null) {
        // replaceRange goes through the undo/redo pipeline, so the format
        // can be undone with Ctrl+Z like any other edit.
        widget.controller.replaceRange(0, widget.controller.length, result.result!);
      } else {
        jfc?._setError(result.error);
      }
    } catch (e) {
      if (mounted) jfc?._setError('Formatting failed: $e');
    } finally {
      _isFormattingJson = false;
      if (mounted) jfc?._setFormatting(false);
    }
  }

  void _resetCursorBlink() {
    if (!mounted) return;
    _caretBlinkController.value = 1.0;
    _caretBlinkController
      ..stop()
      ..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(RopeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle controller change
    if (oldWidget.controller != widget.controller) {
      // Clean up old controller connections
      oldWidget.controller.requestCursorReset = null;
      oldWidget.controller.setScrollCallback(null);
      oldWidget.controller.onConnectionClosed = null;

      // Setup new controller
      widget.controller.focusNode = _focusNode;
      widget.controller.requestCursorReset = _resetCursorBlink;
      widget.controller.setScrollCallback(_scrollToLine);
      widget.controller.onConnectionClosed = _handleConnectionClosed;

      // Update connection if focused
      if (_focusNode.hasFocus) {
        widget.controller.connection = _connection;
      }
    }

    // Handle findController change
    if (oldWidget.findController != widget.findController) {
      if (mounted) setState(() {});
    }

    // Handle jsonFormatterController change
    if (oldWidget.jsonFormatterController != widget.jsonFormatterController) {
      oldWidget.jsonFormatterController?._formatImpl = null;
      widget.jsonFormatterController?._formatImpl = _prettyPrintJson;
    }

    // Handle filePath change
    if (oldWidget.filePath != widget.filePath && widget.filePath != null && widget.filePath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.openedFile = widget.filePath;
      });
    }
  }

  void _scrollToLine(int line, bool center) {
    if (!mounted || widget.controller.suppressAutoScroll) return;

    // PERFORMANCE & SAFETY: Capture the position from the controller's internal list
    // to avoid race conditions during getter evaluation.
    final ScrollPosition? vPos = _vscrollController.positions.isNotEmpty ? _vscrollController.positions.first : null;

    if (vPos == null || !vPos.hasPixels) return;

    // Centering the line in the viewport.
    final style = widget.textStyle ?? const TextStyle(fontSize: 14);
    final double lineHeight = (style.fontSize ?? 14.0) * (style.height ?? 1.2);
    final vViewport = vPos.viewportDimension;
    final vOffset = vPos.pixels;

    final RenderRopeField? field = _getRenderField();
    final double targetY = widget.lineWrap && field != null ? field.lineDocumentTop(line) : line * lineHeight;
    final double lineVisualHeight = widget.lineWrap && field != null ? field.lineDocumentHeight(line) : lineHeight;
    double? vTarget;

    if (center) {
      vTarget = (targetY - (vViewport / 2) + (lineVisualHeight / 2)).clamp(0, vPos.maxScrollExtent);
    } else {
      // Ensure visible with padding (approx 1.5 lines)
      final double vPadding = lineHeight * 1.5;
      if (targetY < vOffset + vPadding) {
        vTarget = (targetY - vPadding).clamp(0, vPos.maxScrollExtent);
      } else if (targetY + lineVisualHeight > vOffset + vViewport - vPadding) {
        vTarget = (targetY - vViewport + lineVisualHeight + vPadding).clamp(0, vPos.maxScrollExtent);
      }
    }

    if (vTarget != null && (vTarget - vOffset).abs() > 1.0) {
      vPos.animateTo(
        vTarget,
        duration: Duration(milliseconds: center ? 300 : 100),
        curve: Curves.easeInOut,
      );
    }

    // Horizontal scrolling: deferred to the next frame so that performLayout()
    // has already run and hPos.maxScrollExtent reflects any newly widened content
    // (e.g. the first character that pushes a line past the viewport edge).
    if (!widget.lineWrap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final hPos2 = _hscrollController.positions.isNotEmpty ? _hscrollController.positions.first : null;
        if (hPos2 == null || !hPos2.hasPixels) return;

        // Re-derive the cursor position from live controller state so this is
        // correct even when multiple edits are batched into one frame.
        final cursorOffset = widget.controller.selection.extentOffset;
        final cursorLine = widget.controller.getLineAtOffset(cursorOffset);
        final charOffset = cursorOffset - widget.controller.getLineStartOffset(cursorLine);

        final charWidth = (style.fontSize ?? 14.0) * 0.6;
        final gutterWidth = widget.enableGutter ? (widget.controller.lineCount.toString().length * charWidth) + 20.0 : 0.0;

        // Estimate caret X position (consistent with editor_field.dart)
        final double caretX = gutterWidth + 10.0 + (charOffset * charWidth * 0.95);

        final hViewport = hPos2.viewportDimension;
        final hOffset = hPos2.pixels;
        final double hPadding = charWidth * 16; // ~4 characters of look-ahead

        double? hTarget;
        if (center) {
          hTarget = (caretX - (hViewport / 2)).clamp(0.0, hPos2.maxScrollExtent);
        } else {
          if (caretX < hOffset + hPadding) {
            hTarget = (caretX - hPadding).clamp(0.0, hPos2.maxScrollExtent);
          } else if (caretX > hOffset + hViewport - hPadding) {
            hTarget = (caretX - hViewport + hPadding).clamp(0.0, hPos2.maxScrollExtent);
          }
        }

        if (hTarget != null && (hTarget - hOffset).abs() > 1.0) {
          hPos2.animateTo(
            hTarget,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _handleConnectionClosed() {
    _connection = null;
  }

  void _openOrShowInputConnection() {
    if (_connection == null || !_connection!.attached) {
      _connection?.close();
      _connection = _attachImeConnection();
      widget.controller.connection = _connection;
    }
    _connection?.show();
    widget.controller.onInputConnectionShown?.call();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _openOrShowInputConnection();
    } else {
      _connection?.close();
      _connection = null;
      widget.controller.connection = null;
    }
    if (mounted) setState(() {});
  }

  TextInputConnection _attachImeConnection() => TextInput.attach(
        widget.controller,
        TextInputConfiguration(
          readOnly: false,
          enableDeltaModel: true,
          enableSuggestions: widget.enableKeyboardSuggestions,
          inputType: TextInputType.multiline,
          inputAction: TextInputAction.newline,
          autocorrect: false,
        ),
      );

  @override
  void dispose() {
    widget.jsonFormatterController?._formatImpl = null;
    widget.controller.onConnectionClosed = null;
    _focusNode.removeListener(_handleFocusChange);
    _caretBlinkController.dispose();
    _connection?.close();
    if (widget.verticalScrollController == null) _vscrollController.dispose();
    if (widget.horizontalScrollController == null) _hscrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.finderBuilder != null && widget.findController.isActive) widget.finderBuilder!(context, widget.findController),
        Expanded(
          child: MouseRegion(
            cursor: _isHovering ? SystemMouseCursors.text : SystemMouseCursors.basic,
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: _buildEditorView(),
          ),
        ),
      ],
    );
  }

  RenderRopeField? _getRenderField() {
    final context = _ropeFieldKey.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    return renderObject is RenderRopeField ? renderObject : null;
  }

  _SelectionHandleGeometry? _calculateSelectionHandleGeometry() {
    final selection = widget.controller.selection;
    if (selection.isCollapsed) return null;

    final RenderRopeField? field = _getRenderField();
    final RenderBox? stackBox = _editorStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (field == null || stackBox == null || !field.hasSize || !stackBox.hasSize) {
      return null;
    }

    final startLocalInField = field.getLocalAnchorForTextOffset(selection.start);
    final endLocalInField = field.getLocalAnchorForTextOffset(selection.end);

    final startGlobal = field.localToGlobal(startLocalInField);
    final endGlobal = field.localToGlobal(endLocalInField);

    return _SelectionHandleGeometry(
      start: stackBox.globalToLocal(startGlobal),
      end: stackBox.globalToLocal(endGlobal),
    );
  }

  void _onSelectionHandleDragUpdate({required bool isStartHandle, required DragUpdateDetails details}) {
    final selection = widget.controller.selection;
    if (selection.isCollapsed) {
      _hideSelectionBoundaryZoom();
      return;
    }

    _autoScrollViewportForHandleDrag(details.globalPosition);

    final RenderRopeField? field = _getRenderField();
    if (field == null) return;

    final localInField = field.globalToLocal(details.globalPosition);
    final int draggedOffset = field.getTextOffsetFromLocalPosition(localInField);

    final int anchorOffset = _selectionHandleDragAnchorOffset ??
        (isStartHandle ? selection.end : selection.start);
    final int clampedOffset = draggedOffset.clamp(0, widget.controller.length);
    widget.controller.selection = TextSelection(
      baseOffset: anchorOffset,
      extentOffset: clampedOffset,
    );
    _updateSelectionBoundaryZoom(
      isStartBoundary: clampedOffset < anchorOffset,
      globalPosition: details.globalPosition,
      textOffset: clampedOffset,
    );
  }

  void _onSelectionHandleDragStart({required bool isStartHandle, required DragStartDetails details}) {
    final RenderRopeField? field = _getRenderField();
    if (field == null) return;

    final TextSelection selection = widget.controller.selection;
    final int anchorOffset = isStartHandle ? selection.end : selection.start;
    _selectionHandleDragAnchorOffset = anchorOffset;

    final Offset localInField = field.globalToLocal(details.globalPosition);
    final int offset = field.getTextOffsetFromLocalPosition(localInField);
    final int clampedOffset = offset.clamp(0, widget.controller.length);
    _showSelectionBoundaryZoom(
      isStartBoundary: clampedOffset < anchorOffset,
      globalPosition: details.globalPosition,
      textOffset: clampedOffset,
    );
  }

  void _onSelectionHandleDragEnd() {
    _selectionHandleDragAnchorOffset = null;
    _hideSelectionBoundaryZoom();
  }

  void _autoScrollViewportForHandleDrag(Offset globalPosition) {
    final RenderBox? stackBox = _editorStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !_vscrollController.hasClients) return;

    final ScrollPosition vPos = _vscrollController.position;
    if (!vPos.hasPixels) return;

    final Offset localInStack = stackBox.globalToLocal(globalPosition);
    final double viewportHeight = stackBox.size.height;
    if (viewportHeight <= 0) return;

    final double lineHeight =
        widget.controller.lineHeight > 0 ? widget.controller.lineHeight : (widget.textStyle?.fontSize ?? 14.0) * (widget.textStyle?.height ?? 1.2);

    // Proactive edge zone: engage within the top/bottom few visible lines.
    final double edgeZone = (lineHeight * 4.0).clamp(64.0, 140.0);
    // Per-update scroll distance. Scales with proximity to the edge.
    final double maxStep = (lineHeight * 2.2).clamp(16.0, 40.0);

    double delta = 0;
    if (localInStack.dy < edgeZone) {
      final double t = (1.0 - (localInStack.dy / edgeZone)).clamp(0.0, 1.0);
      delta = -maxStep * t * t;
    } else if (localInStack.dy > viewportHeight - edgeZone) {
      final double distanceFromBottom = viewportHeight - localInStack.dy;
      final double t = (1.0 - (distanceFromBottom / edgeZone)).clamp(0.0, 1.0);
      delta = maxStep * t * t;
    }

    if (delta == 0) return;

    final double target = (vPos.pixels + delta).clamp(0.0, vPos.maxScrollExtent);
    if ((target - vPos.pixels).abs() < 0.5) return;
    vPos.jumpTo(target);
  }

  Widget _buildMobileSelectionHandles() {
    final Listenable mobileHandleListenable = Listenable.merge([
      widget.controller,
      _vscrollController,
      _hscrollController,
    ]);

    return ListenableBuilder(
      listenable: mobileHandleListenable,
      builder: (context, _) {
        final selection = widget.controller.selection;
        if (selection.isCollapsed) return const SizedBox.shrink();

        final geometry = _calculateSelectionHandleGeometry();
        if (geometry == null) return const SizedBox.shrink();

        return Stack(
          children: [
            _SelectionDragHandle(
              center: geometry.start,
              size: widget.mobileSelectionHandleSize,
              onDragStart: (d) => _onSelectionHandleDragStart(isStartHandle: true, details: d),
              onDragUpdate: (d) => _onSelectionHandleDragUpdate(isStartHandle: true, details: d),
              onDragEnd: (_) => _onSelectionHandleDragEnd(),
              onDragCancel: _onSelectionHandleDragEnd,
            ),
            _SelectionDragHandle(
              center: geometry.end,
              size: widget.mobileSelectionHandleSize,
              onDragStart: (d) => _onSelectionHandleDragStart(isStartHandle: false, details: d),
              onDragUpdate: (d) => _onSelectionHandleDragUpdate(isStartHandle: false, details: d),
              onDragEnd: (_) => _onSelectionHandleDragEnd(),
              onDragCancel: _onSelectionHandleDragEnd,
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditorView() {
    // Implementation of the TwoDimensionalScrollable and CustomViewport
    // similar to code_area.dart but simplified to remove LSP overlays.
    return Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const FindIntent(),
          if (_isJsonFile)
            LogicalKeySet(
              LogicalKeyboardKey.shift,
              LogicalKeyboardKey.alt,
              LogicalKeyboardKey.keyF,
            ): const FormatDocumentIntent(),
        },
        child: Actions(
            actions: <Type, Action<Intent>>{
              FindIntent: CallbackAction<FindIntent>(onInvoke: (intent) => widget.findController.show()),
              if (_isJsonFile)
                FormatDocumentIntent: CallbackAction<FormatDocumentIntent>(
                  onInvoke: (_) => _prettyPrintJson(),
                ),
            },
            child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _handleKeyEvent,
                child: Container(
                  color: widget.editorTheme?['root']?.backgroundColor ?? Colors.white,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Proactively update the viewport height in the controller.
                      // This makes it available to the Minimap during the build phase.
                      widget.controller.viewportHeight = constraints.maxHeight;
                      widget.controller.lineHeight = (widget.textStyle?.fontSize ?? 14.0) * (widget.textStyle?.height ?? 1.2);

                      // Store viewport width so the field can use it as a floor
                      widget.controller.viewportWidth = constraints.maxWidth;
                      _scheduleRenderFieldRepaintIfViewportChanged(constraints.maxHeight, constraints.maxWidth);

                      final ropeField = RopeField(
                        key: _ropeFieldKey,
                        controller: widget.controller,
                        editorTheme: widget.editorTheme ?? {},
                        language: widget.language ?? Mode(),
                        vscrollController: _vscrollController,
                        hscrollController: _hscrollController,
                        focusNode: _focusNode,
                        caretBlinkController: _caretBlinkController,
                        lineWrap: widget.lineWrap,
                        enableGutter: widget.enableGutter,
                        enableGutterDivider: widget.enableGutterDivider,
                        textStyle: widget.textStyle ?? const TextStyle(fontSize: 14, color: Colors.black),
                        onRequestContextMenu: _showEditorContextMenu,
                        onRequestKeyboard: _openOrShowInputConnection,
                      );

                      // When line wrap is on, no horizontal scrolling is needed.
                      // When line wrap is off, wrap in horizontal scroll only.
                      final Widget innerContent = widget.lineWrap
                          ? SizedBox(
                              width: constraints.maxWidth,
                              child: ropeField,
                            )
                          : SingleChildScrollView(
                              controller: _hscrollController,
                              scrollDirection: Axis.horizontal,
                              child: ropeField,
                            );

                      final editorScrollable = Scrollbar(
                        controller: _vscrollController,
                        thumbVisibility: widget.showVerticalScrollbar,
                        child: SingleChildScrollView(
                          controller: _vscrollController,
                          child: innerContent,
                        ),
                      );

                      if (!_isTouchPlatform) {
                        return editorScrollable;
                      }

                      return Stack(
                        key: _editorStackKey,
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(child: editorScrollable),
                          Positioned.fill(child: _buildMobileSelectionHandles()),
                          _buildSelectionBoundaryZoom(),
                        ],
                      );
                    },
                  ),
                ))));
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
      final isWordNavigationModifier = defaultTargetPlatform == TargetPlatform.macOS
          ? HardwareKeyboard.instance.isMetaPressed
          : HardwareKeyboard.instance.isControlPressed;

      if (isCtrl) {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyC:
            widget.controller.copy();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyV:
            widget.controller.paste();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyX:
            widget.controller.cut();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyA:
            widget.controller.selectAll();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyZ:
            widget.controller.undo();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyY:
            widget.controller.redo();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.arrowLeft:
            if (!isWordNavigationModifier) return KeyEventResult.ignored;
            widget.controller.pressLeftWordArrowKey(isShiftPressed: HardwareKeyboard.instance.isShiftPressed);
            return KeyEventResult.handled;
          case LogicalKeyboardKey.arrowRight:
            if (!isWordNavigationModifier) return KeyEventResult.ignored;
            widget.controller.pressRightWordArrowKey(isShiftPressed: HardwareKeyboard.instance.isShiftPressed);
            return KeyEventResult.handled;
        }
      }

      // Navigation and standard editing
      switch (event.logicalKey) {
        case LogicalKeyboardKey.tab:
          if (HardwareKeyboard.instance.isShiftPressed) {
            widget.controller.outdentSelection(widget.tabSpaces);
          } else {
            widget.controller.indentSelection(' ' * widget.tabSpaces);
          }
          return KeyEventResult.handled;
        case LogicalKeyboardKey.backspace:
          widget.controller.backspace();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.delete:
          widget.controller.delete();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowLeft:
          widget.controller.pressLeftArrowKey(isShiftPressed: HardwareKeyboard.instance.isShiftPressed);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
          widget.controller.pressRightArrowKey(isShiftPressed: HardwareKeyboard.instance.isShiftPressed);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowUp:
          widget.controller.pressUpArrowKey(isShiftPressed: HardwareKeyboard.instance.isShiftPressed);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowDown:
          widget.controller.pressDownArrowKey(isShiftPressed: HardwareKeyboard.instance.isShiftPressed);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.pageUp:
          widget.controller.pressPageUpKey(isShiftPressed: HardwareKeyboard.instance.isShiftPressed);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.pageDown:
          widget.controller.pressPageDownKey(isShiftPressed: HardwareKeyboard.instance.isShiftPressed);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.home:
          widget.controller.pressHomeKey(isShiftPressed: HardwareKeyboard.instance.isShiftPressed);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.end:
          widget.controller.pressEndKey(isShiftPressed: HardwareKeyboard.instance.isShiftPressed);
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}

class FindIntent extends Intent {
  const FindIntent();
}

class FormatDocumentIntent extends Intent {
  const FormatDocumentIntent();
}

class _SelectionHandleGeometry {
  final Offset start;
  final Offset end;

  const _SelectionHandleGeometry({required this.start, required this.end});
}

class _SelectionDragHandle extends StatelessWidget {
  final Offset center;
  final double size;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;

  const _SelectionDragHandle({
    required this.center,
    required this.size,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  @override
  Widget build(BuildContext context) {
    final double touchSize = size.clamp(24, 96).toDouble();
    final double knobSize = (touchSize * 0.34).clamp(10, 28).toDouble();
    final double stemHeight = (touchSize * 0.30).clamp(8, 24).toDouble();
    final Color color = Theme.of(context).colorScheme.primary;

    return Positioned(
      left: center.dx - (touchSize / 2),
      top: center.dy - 1,
      width: touchSize,
      height: touchSize,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: onDragStart,
        onPanUpdate: onDragUpdate,
        onPanEnd: onDragEnd,
        onPanCancel: onDragCancel,
        child: Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 2,
                height: stemHeight,
                color: color,
              ),
              Container(
                width: knobSize,
                height: knobSize,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
