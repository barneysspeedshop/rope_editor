import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:rope_editor/src/controller/controller.dart';
import 'package:rope_editor/src/syntax/syntax_highlighter.dart';
import 'package:rope_editor/src/syntax/syntax_highlight_context.dart';

class RopeField extends LeafRenderObjectWidget {
  final RopeEditorController controller;
  final Map<String, TextStyle> editorTheme;
  final Mode language;
  final ScrollController vscrollController, hscrollController;
  final FocusNode focusNode;
  final AnimationController caretBlinkController;
  final bool lineWrap, enableGutter, enableGutterDivider;
  final TextStyle textStyle;
  final ValueChanged<Offset>? onRequestContextMenu;
  final VoidCallback? onRequestKeyboard;

  const RopeField({
    super.key,
    required this.controller,
    required this.editorTheme,
    required this.language,
    required this.vscrollController,
    required this.hscrollController,
    required this.focusNode,
    required this.caretBlinkController,
    required this.lineWrap,
    required this.enableGutter,
    required this.enableGutterDivider,
    required this.textStyle,
    this.onRequestContextMenu,
    this.onRequestKeyboard,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => RenderRopeField(
        controller: controller,
        editorTheme: editorTheme,
        language: language,
        vscrollController: vscrollController,
        hscrollController: hscrollController,
        focusNode: focusNode,
        caretBlinkController: caretBlinkController,
        lineWrap: lineWrap,
        enableGutter: enableGutter,
        enableGutterDivider: enableGutterDivider,
        textStyle: textStyle,
        onRequestContextMenu: onRequestContextMenu,
        onRequestKeyboard: onRequestKeyboard,
      );

  @override
  void updateRenderObject(BuildContext context, covariant RenderRopeField renderObject) {
    renderObject
      ..controller = controller
      ..language = language
      ..lineWrap = lineWrap
      ..focusNode = focusNode
      ..enableGutter = enableGutter
      ..enableGutterDivider = enableGutterDivider
      ..textStyle = textStyle
      ..onRequestContextMenu = onRequestContextMenu
      ..onRequestKeyboard = onRequestKeyboard;
  }
}

class RenderRopeField extends RenderBox {
  @override
  bool get isRepaintBoundary => true;

  RopeEditorController _controller;
  RopeEditorController get controller => _controller;
  set controller(RopeEditorController value) {
    if (_controller == value) return;

    _controller.removeListener(_handleControllerNotification);
    _controller = value;
    _controller.addListener(_handleControllerNotification);
    _paragraphCache.clear();
    _paragraphCharOffsets.clear();
    _invalidateLineLayout();
    markNeedsLayout();
  }

  Mode _language;
  set language(Mode v) {
    _language = v;
    _updateHighlighter();
  }

  TextStyle _textStyle;
  set textStyle(TextStyle v) {
    _textStyle = v;
    _updateHighlighter();
  }

  Map<String, TextStyle> _editorTheme;
  set editorTheme(Map<String, TextStyle> v) {
    _editorTheme = v;
    _updateHighlighter();
  }

  static final RegExp _wordCharRegExp = RegExp(r'[A-Za-z0-9_]');

  bool _draggingSelection = false;
  bool _mouseDragMoved = false;
  bool _touchSelectionMode = false;
  int? _activeDragPointer;
  Offset? _lastDragGlobalPosition;
  Timer? _selectionAutoScrollTimer;
  int _autoScrollDirection = 0;
  int? _activeTouchPointer;
  Offset? _touchDownLocalPosition;
  int? _touchDownTextOffset;
  bool _touchMovedDuringGesture = false;
  bool _hadSelectionOnTouchDown = false;
  Timer? _touchLongPressTimer;

  FocusNode _focusNode;
  FocusNode get focusNode => _focusNode;
  set focusNode(FocusNode value) {
    if (_focusNode == value) return;
    _focusNode = value;
    markNeedsPaint();
  }

  bool _lineWrap, _enableGutter, _enableGutterDivider;
  ValueChanged<Offset>? _onRequestContextMenu;
  VoidCallback? _onRequestKeyboard;

  set onRequestContextMenu(ValueChanged<Offset>? value) {
    _onRequestContextMenu = value;
  }

  set onRequestKeyboard(VoidCallback? value) {
    _onRequestKeyboard = value;
  }

  set lineWrap(bool v) {
    if (_lineWrap == v) return;
    _lineWrap = v;
    _paragraphCache.clear();
    _paragraphCharOffsets.clear();
    _invalidateLineLayout();
    markNeedsLayout();
  }

  set enableGutter(bool v) {
    _enableGutter = v;
    markNeedsLayout();
  }

  set enableGutterDivider(bool v) {
    _enableGutterDivider = v;
    markNeedsLayout();
  }

  late SyntaxHighlighter _highlighter;
  final ScrollController vscrollController, hscrollController;
  final AnimationController caretBlinkController;

  @visibleForTesting
  SyntaxHighlighter get highlighter => _highlighter;

  @visibleForTesting
  Map<int, ui.Paragraph> get paragraphCache => _paragraphCache;
  final Map<int, ui.Paragraph> _paragraphCache = {};
  // For wide lines rendered as horizontal slices, track the char offset
  // so we know where to draw the paragraph
  final Map<int, int> _paragraphCharOffsets = {};

  double _lineHeight = 0;
  double _gutterWidth = 0;
  double _availableTextWidth = double.infinity;
  double _lastLayoutTextWidth = -1;
  final List<double> _lineTops = [];
  final List<double> _lineHeights = [];

  /// Document Y coordinate where [lineIndex] starts (accounts for wrap height).
  double lineDocumentTop(int lineIndex) => _lineDocumentTop(lineIndex);

  /// Visual height of [lineIndex] in document coordinates.
  double lineDocumentHeight(int lineIndex) => _lineDocumentHeight(lineIndex);

  RenderRopeField({
    required RopeEditorController controller,
    required Map<String, TextStyle> editorTheme,
    required Mode language,
    required this.vscrollController,
    required this.hscrollController,
    required FocusNode focusNode,
    required this.caretBlinkController,
    required bool lineWrap,
    required bool enableGutter,
    required bool enableGutterDivider,
    required TextStyle textStyle,
    ValueChanged<Offset>? onRequestContextMenu,
    VoidCallback? onRequestKeyboard,
  })  : _controller = controller,
        _editorTheme = editorTheme,
        _language = language,
        _focusNode = focusNode,
        _lineWrap = lineWrap,
        _enableGutter = enableGutter,
        _enableGutterDivider = enableGutterDivider,
        _textStyle = textStyle,
        _onRequestContextMenu = onRequestContextMenu,
        _onRequestKeyboard = onRequestKeyboard {
    _controller.addListener(_handleControllerNotification);
    vscrollController.addListener(markNeedsPaint);
    hscrollController.addListener(markNeedsPaint);
    caretBlinkController.addListener(markNeedsPaint);
    _updateHighlighter();
  }

  void _handleControllerNotification() {
    if (_controller.lineStructureChanged) {
      _paragraphCache.clear();
      _paragraphCharOffsets.clear();
      _invalidateLineLayout();
      markNeedsLayout();
    } else if (_controller.dirtyLine != null) {
      _paragraphCache.remove(_controller.dirtyLine);
      _paragraphCharOffsets.remove(_controller.dirtyLine);
      if (_lineWrap && _controller.dirtyLine! < _lineTops.length) {
        _lineTops.removeRange(_controller.dirtyLine!, _lineTops.length);
        _lineHeights.removeRange(_controller.dirtyLine!, _lineHeights.length);
        markNeedsLayout();
      }
    }
    markNeedsPaint();
  }

  void _invalidateLineLayout() {
    _lineTops.clear();
    _lineHeights.clear();
  }

  double _lineDocumentTop(int lineIndex) {
    if (!_lineWrap) return lineIndex * _lineHeight;
    _ensureLineLayoutThrough(lineIndex);
    return _lineTops[lineIndex];
  }

  double _lineDocumentHeight(int lineIndex) {
    if (!_lineWrap) return _lineHeight;
    _ensureLineLayoutThrough(lineIndex);
    return _lineHeights[lineIndex];
  }

  double _totalContentHeight() {
    if (controller.lineCount <= 0) return 0;
    if (!_lineWrap) return controller.lineCount * _lineHeight;
    _ensureLineLayoutThrough(controller.lineCount - 1);
    return _lineTops.last + _lineHeights.last;
  }

  void _ensureLineLayoutThrough(int throughLine) {
    if (!_lineWrap || throughLine < 0) return;

    while (_lineTops.length <= throughLine && _lineTops.length < controller.lineCount) {
      final int i = _lineTops.length;
      final String lineText = controller.getLineText(i);
      final ui.Paragraph paragraph = _paragraphCache[i] ?? _buildLine(fullLineText: lineText, lineIndex: i);
      if (!_paragraphCache.containsKey(i)) {
        _paragraphCache[i] = paragraph;
      }
      final double height = _paragraphLayoutHeight(paragraph, lineText);
      final double top = _lineTops.isEmpty ? 0.0 : _lineTops.last + _lineHeights.last;
      _lineTops.add(top);
      _lineHeights.add(height);
    }
  }

  /// Height reserved for a laid-out line in document coordinates.
  ///
  /// [Paragraph.computeLineMetrics] often reports a spurious extra line for
  /// single-row paragraphs under width constraints, which doubles vertical
  /// spacing between logical lines. Count distinct glyph rows instead.
  double _paragraphLayoutHeight(ui.Paragraph paragraph, String text) {
    final int measureEnd = text.isEmpty ? 1 : text.length;
    final boxes = paragraph.getBoxesForRange(0, measureEnd);
    if (boxes.isEmpty) return _lineHeight;

    final List<double> tops = boxes.map((b) => b.top).toList()..sort();
    int rowCount = 1;
    double lastTop = tops.first;
    for (final double top in tops) {
      if (top - lastTop > _lineHeight * 0.45) {
        rowCount++;
        lastTop = top;
      }
    }
    return rowCount * _lineHeight;
  }

  ui.ParagraphStyle _paragraphStyleForLine() {
    final double fontSize = _textStyle.fontSize ?? 14.0;
    final double heightMultiplier = _textStyle.height ?? 1.2;
    return ui.ParagraphStyle(
      fontSize: fontSize,
      fontFamily: _textStyle.fontFamily,
      height: heightMultiplier,
      textDirection: ui.TextDirection.ltr,
    );
  }

  int _lineIndexAtY(double y) {
    if (controller.lineCount <= 0) return 0;
    if (!_lineWrap) {
      return (y / _lineHeight).floor().clamp(0, controller.lineCount - 1);
    }

    _ensureLineLayoutThrough(controller.lineCount - 1);
    if (y <= _lineTops.first) return 0;

    int lo = 0;
    int hi = controller.lineCount - 1;
    while (lo < hi) {
      final int mid = (lo + hi + 1) >> 1;
      if (_lineTops[mid] <= y) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  ({int first, int last}) _visibleLineRange(double scrollTop, double viewportHeight) {
    if (controller.lineCount <= 0) return (first: 0, last: 0);
    if (!_lineWrap) {
      return (
        first: (scrollTop / _lineHeight).floor().clamp(0, controller.lineCount),
        last: ((scrollTop + viewportHeight) / _lineHeight).ceil().clamp(0, controller.lineCount),
      );
    }

    _ensureLineLayoutThrough(controller.lineCount - 1);
    final double scrollBottom = scrollTop + viewportHeight;

    int first = 0;
    int lo = 0;
    int hi = controller.lineCount - 1;
    while (lo <= hi) {
      final int mid = (lo + hi) >> 1;
      final double lineBottom = _lineTops[mid] + _lineHeights[mid];
      if (lineBottom <= scrollTop) {
        lo = mid + 1;
      } else {
        first = mid;
        hi = mid - 1;
      }
    }

    int last = controller.lineCount;
    lo = first;
    hi = controller.lineCount - 1;
    while (lo <= hi) {
      final int mid = (lo + hi) >> 1;
      if (_lineTops[mid] < scrollBottom) {
        last = mid + 1;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    return (
      first: first.clamp(0, controller.lineCount),
      last: last.clamp(0, controller.lineCount),
    );
  }

  void _updateHighlighter() {
    _lineHeight = (_textStyle.fontSize ?? 14.0) * (_textStyle.height ?? 1.2);

    // Ensure the base style has a visible color from the theme or a default.
    final Color defaultColor = _editorTheme['root']?.color ?? Colors.black;
    final TextStyle effectiveStyle = _textStyle.copyWith(
      color: _textStyle.color ?? defaultColor,
    );

    _highlighter = SyntaxHighlighter(
      language: _language,
      theme: _editorTheme,
      baseStyle: effectiveStyle,
    );
    _paragraphCache.clear();
    _paragraphCharOffsets.clear();
    _invalidateLineLayout();
    markNeedsPaint();
  }

  @override
  void performLayout() {
    final lineCount = controller.lineCount;

    if (_enableGutter) {
      final charWidth = (_textStyle.fontSize ?? 14.0) * 0.6;
      _gutterWidth = (lineCount.toString().length * charWidth) + 20.0;
    } else {
      _gutterWidth = 0;
    }

    double width;
    if (_lineWrap) {
      // When line wrap is enabled, we MUST have bounded width
      // If unbounded, use a reasonable default
      width = constraints.hasBoundedWidth ? constraints.maxWidth : 800.0;
    } else if (!constraints.hasBoundedWidth) {
      // If horizontal scrolling is enabled, we need to report a wide enough width.
      width = _estimateMaxLineWidth(lineCount);
    } else {
      width = constraints.maxWidth;
    }

    final double newAvailableTextWidth = _lineWrap ? (width - _gutterWidth - 20.0).clamp(100.0, double.infinity) : double.infinity;
    if (_lineWrap && (_lastLayoutTextWidth - newAvailableTextWidth).abs() > 0.5) {
      _lastLayoutTextWidth = newAvailableTextWidth;
      _paragraphCache.clear();
      _paragraphCharOffsets.clear();
      _invalidateLineLayout();
    }
    _availableTextWidth = newAvailableTextWidth;

    // When inside a SingleChildScrollView, height constraints are often infinite.
    // We report our total content height so the scroll view knows the scroll extent.
    // Use the controller's viewport height as a floor so the field always fills
    // the visible area, ensuring clicks and scrolls in empty space are captured.
    final double contentHeight = _lineWrap ? _totalContentHeight() : lineCount * _lineHeight;
    final double viewportMin = controller.viewportHeight > 0 ? controller.viewportHeight : 0;
    final double height = constraints.hasBoundedHeight ? max(constraints.maxHeight, contentHeight) : max(viewportMin, contentHeight);

    size = constraints.constrain(Size(width, height));
  }

  double _estimateMaxLineWidth(int lineCount) {
    // Use the viewport width as the floor so we never report narrower than
    // the visible area, but also never wider unless content actually exceeds it.
    final double viewportW = controller.viewportWidth > 0 ? controller.viewportWidth : 800.0;
    final charWidth = (_textStyle.fontSize ?? 14.0) * 0.6;

    // Single FFI call to get the widest line length across the entire document.
    final int maxLineLen = controller.rope.getMetrics().maxLineUtf16Len;
    final double contentW = maxLineLen * charWidth + _gutterWidth + 40;

    return max(viewportW, contentW);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    final bool isTouchEvent = event.kind == PointerDeviceKind.touch;
    final bool isSecondaryPointerDown = event is PointerDownEvent && (event.buttons & kSecondaryMouseButton) != 0;

    if (event is PointerDownEvent) {
      if (!focusNode.hasFocus) {
        focusNode.requestFocus();
      } else if (isTouchEvent) {
        // Android/iOS can dismiss the soft keyboard while focus remains. A
        // subsequent tap must re-open the IME connection explicitly.
        _onRequestKeyboard?.call();
      }

      if (!isTouchEvent && isSecondaryPointerDown) {
        final int offset = _getTextOffsetFromPosition(event.localPosition);
        final TextSelection currentSelection = controller.selection;
        final bool pointerInsideSelection = !currentSelection.isCollapsed && offset >= currentSelection.start && offset < currentSelection.end;

        // Preserve selected range when right-clicking inside it.
        if (!pointerInsideSelection) {
          controller.selection = TextSelection.collapsed(offset: offset);
        }

        _touchLongPressTimer?.cancel();
        _draggingSelection = false;
        _mouseDragMoved = false;
        _touchSelectionMode = false;
        _activeDragPointer = null;
        _lastDragGlobalPosition = null;
        _autoScrollDirection = 0;
        _stopSelectionAutoScroll();

        _onRequestContextMenu?.call(event.position);
        return;
      }

      if (isTouchEvent) {
        // For touch input, allow drag gestures to be used for scrolling by default.
        // Selection drag only starts after a long-press.
        if (_activeTouchPointer != null) return;

        final offset = _getTextOffsetFromPosition(event.localPosition);
        _activeTouchPointer = event.pointer;
        _touchDownLocalPosition = event.localPosition;
        _touchDownTextOffset = offset;
        _touchMovedDuringGesture = false;
        _hadSelectionOnTouchDown = !controller.selection.isCollapsed;
        _touchSelectionMode = false;
        _draggingSelection = false;
        _touchLongPressTimer?.cancel();
        _touchLongPressTimer = Timer(kLongPressTimeout, () {
          if (_activeTouchPointer != event.pointer) return;
          if (_touchMovedDuringGesture) return;

          final int pressOffset = _getTextOffsetFromPosition(event.localPosition);
          final TextSelection currentSelection = controller.selection;
          final bool pointerInsideSelection = !currentSelection.isCollapsed && pressOffset >= currentSelection.start && pressOffset < currentSelection.end;

          if (pointerInsideSelection) {
            _onRequestContextMenu?.call(event.position);
          } else {
            _selectWordAtOffset(pressOffset);
          }

          _touchSelectionMode = true;
          _draggingSelection = false;
        });
      } else {
        // Mouse/stylus keep immediate drag-to-select behavior.
        final offset = _getTextOffsetFromPosition(event.localPosition);
        final bool extendSelection = HardwareKeyboard.instance.isShiftPressed;
        if (extendSelection) {
          controller.selection = controller.selection.copyWith(extentOffset: offset);
        } else {
          controller.selection = TextSelection.collapsed(offset: offset);
        }
        _touchSelectionMode = false;
        _draggingSelection = true;
        _mouseDragMoved = false;
        _activeDragPointer = event.pointer;
        _lastDragGlobalPosition = event.position;
      }
    } else if (event is PointerMoveEvent && _draggingSelection) {
      if (isTouchEvent && _activeTouchPointer == event.pointer && !_touchSelectionMode) {
        final down = _touchDownLocalPosition;
        if (down != null && (event.localPosition - down).distance > kTouchSlop) {
          _touchMovedDuringGesture = true;
          _touchLongPressTimer?.cancel();
        }
        return;
      }

      // Interactive drag selection
      if (!isTouchEvent && _activeDragPointer == event.pointer) {
        _mouseDragMoved = true;
        _lastDragGlobalPosition = event.position;
      }
      _updateSelectionExtentForGlobalPosition(event.position);
      _updateSelectionAutoScrollState();
    } else if (event is PointerMoveEvent && isTouchEvent && _activeTouchPointer == event.pointer && !_touchSelectionMode) {
      final down = _touchDownLocalPosition;
      if (down != null && (event.localPosition - down).distance > kTouchSlop) {
        _touchMovedDuringGesture = true;
        _touchLongPressTimer?.cancel();
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (isTouchEvent && _activeTouchPointer == event.pointer) {
        if (event is PointerUpEvent && !_touchSelectionMode && !_touchMovedDuringGesture) {
          final int tapOffset = _getTextOffsetFromPosition(event.localPosition);
          if (_hadSelectionOnTouchDown) {
            controller.selection = TextSelection.collapsed(offset: tapOffset);
          } else {
            controller.selection = TextSelection.collapsed(offset: _touchDownTextOffset ?? tapOffset);
          }
        }

        _touchLongPressTimer?.cancel();
        _touchLongPressTimer = null;
        _activeTouchPointer = null;
        _touchDownLocalPosition = null;
        _touchDownTextOffset = null;
        _touchMovedDuringGesture = false;
        _hadSelectionOnTouchDown = false;
      }
      _draggingSelection = false;
      _mouseDragMoved = false;
      _touchSelectionMode = false;
      if (!isTouchEvent && _activeDragPointer == event.pointer) {
        _activeDragPointer = null;
        _lastDragGlobalPosition = null;
      }
      _autoScrollDirection = 0;
      _stopSelectionAutoScroll();
    }
  }

  void _updateSelectionExtentForPosition(Offset localPosition) {
    final int offset = _getTextOffsetFromPosition(localPosition);
    controller.selection = controller.selection.copyWith(
      extentOffset: offset,
    );
  }

  void _updateSelectionAutoScrollState() {
    if (!_draggingSelection || !_mouseDragMoved || _touchSelectionMode || _activeDragPointer == null || _lastDragGlobalPosition == null) {
      _stopSelectionAutoScroll();
      return;
    }

    final ScrollPosition? vPos = vscrollController.positions.isNotEmpty ? vscrollController.positions.first : null;
    if (vPos == null || !vPos.hasPixels) {
      _stopSelectionAutoScroll();
      return;
    }

    final int outsideDirection = _getPointerAutoScrollDirectionGlobal(
      _lastDragGlobalPosition!,
      vPos,
    );
    final bool shouldAutoScroll = outsideDirection != 0;

    if (!shouldAutoScroll) {
      _autoScrollDirection = 0;
      _stopSelectionAutoScroll();
      return;
    }

    _autoScrollDirection = outsideDirection;

    _selectionAutoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _performSelectionAutoScrollStep(),
    );
  }

  void _performSelectionAutoScrollStep() {
    if (!_draggingSelection || !_mouseDragMoved || _touchSelectionMode || _activeDragPointer == null || _lastDragGlobalPosition == null) {
      _stopSelectionAutoScroll();
      return;
    }

    final ScrollPosition? vPos = vscrollController.positions.isNotEmpty ? vscrollController.positions.first : null;
    if (vPos == null || !vPos.hasPixels) {
      _stopSelectionAutoScroll();
      return;
    }

    final int liveDirection = _getPointerAutoScrollDirectionGlobal(
      _lastDragGlobalPosition!,
      vPos,
    );
    if (liveDirection == 0) {
      _autoScrollDirection = 0;
      _stopSelectionAutoScroll();
      return;
    }

    _autoScrollDirection = liveDirection;

    final double? delta = _getAutoScrollDeltaFromGlobalY(
      _lastDragGlobalPosition!.dy,
      vPos,
    );
    if (delta == null || delta.abs() < 0.01) return;

    final double oldPixels = vPos.pixels;
    final double target = (oldPixels + delta).clamp(0.0, vPos.maxScrollExtent);
    final double appliedDelta = target - oldPixels;
    if (appliedDelta.abs() < 0.01) {
      _clampSelectionAtDocumentBoundaryForDirection(_autoScrollDirection);
      _autoScrollDirection = 0;
      _stopSelectionAutoScroll();
      return;
    }

    vPos.jumpTo(target);
    _updateSelectionExtentForGlobalPosition(_lastDragGlobalPosition!);

    if (target <= 0.0 || (vPos.maxScrollExtent - target).abs() < 0.01) {
      _clampSelectionAtDocumentBoundaryForDirection(_autoScrollDirection);
      _autoScrollDirection = 0;
      _stopSelectionAutoScroll();
    }
  }

  int _getPointerAutoScrollDirectionGlobal(
    Offset globalPosition,
    ScrollPosition vPos,
  ) {
    final double lineHeight = (_textStyle.fontSize ?? 14.0) * (_textStyle.height ?? 1.2);
    final double edgeZone = (lineHeight * 4.0).clamp(64.0, 160.0);
    final ({double top, double bottom})? viewportBounds = _getViewportGlobalBounds(vPos);
    if (viewportBounds == null) return 0;

    final double viewportGlobalTop = viewportBounds.top;
    final double viewportGlobalBottom = viewportBounds.bottom;

    if (globalPosition.dy < viewportGlobalTop + edgeZone) return -1;
    if (globalPosition.dy > viewportGlobalBottom - edgeZone) return 1;
    return 0;
  }

  double? _getAutoScrollDeltaFromGlobalY(
    double globalY,
    ScrollPosition vPos,
  ) {
    final double lineHeight = (_textStyle.fontSize ?? 14.0) * (_textStyle.height ?? 1.2);
    final double edgeZone = (lineHeight * 4.0).clamp(64.0, 160.0);
    final double minStep = (lineHeight * 1.6).clamp(14.0, 32.0);
    final double maxStep = (lineHeight * 3.6).clamp(32.0, 120.0);
    final double rampDistance = (lineHeight * 12.0).clamp(120.0, 420.0);
    final ({double top, double bottom})? viewportBounds = _getViewportGlobalBounds(vPos);
    if (viewportBounds == null) return null;

    final double viewportGlobalTop = viewportBounds.top;
    final double viewportGlobalBottom = viewportBounds.bottom;
    final double upperTrigger = viewportGlobalTop + edgeZone;
    final double lowerTrigger = viewportGlobalBottom - edgeZone;

    if (globalY < upperTrigger) {
      final double activeDistance = upperTrigger - globalY;
      final double t = (activeDistance / (edgeZone + rampDistance)).clamp(0.0, 1.0);
      final double step = minStep + (maxStep - minStep) * t;
      return -step;
    }

    if (globalY > lowerTrigger) {
      final double activeDistance = globalY - lowerTrigger;
      final double t = (activeDistance / (edgeZone + rampDistance)).clamp(0.0, 1.0);
      final double step = minStep + (maxStep - minStep) * t;
      return step;
    }

    return null;
  }

  ({double top, double bottom})? _getViewportGlobalBounds(ScrollPosition vPos) {
    if (!vPos.hasPixels || vPos.viewportDimension <= 0) return null;

    final double topGlobal = localToGlobal(Offset(0, vPos.pixels)).dy;
    final double bottomGlobal = localToGlobal(
      Offset(0, vPos.pixels + vPos.viewportDimension),
    ).dy;

    return (
      top: min(topGlobal, bottomGlobal),
      bottom: max(topGlobal, bottomGlobal),
    );
  }

  void _clampSelectionAtDocumentBoundaryForDirection(int direction) {
    if (direction < 0) {
      controller.selection = controller.selection.copyWith(extentOffset: 0);
    } else if (direction > 0) {
      controller.selection = controller.selection.copyWith(extentOffset: controller.length);
    }
  }

  void _updateSelectionExtentForGlobalPosition(Offset globalPosition) {
    final Offset local = globalToLocal(globalPosition);
    _updateSelectionExtentForPosition(local);
  }

  void _stopSelectionAutoScroll() {
    _selectionAutoScrollTimer?.cancel();
    _selectionAutoScrollTimer = null;
  }

  void _selectWordAtOffset(int globalOffset) {
    if (controller.length <= 0) {
      controller.selection = const TextSelection.collapsed(offset: 0);
      return;
    }

    final int clampedOffset = globalOffset.clamp(0, controller.length);
    final int lineIndex = controller.getLineAtOffset(clampedOffset).clamp(0, controller.lineCount - 1);
    final int lineStart = controller.getLineStartOffset(lineIndex);
    String lineText = controller.getLineText(lineIndex);

    if (lineText.endsWith('\n')) {
      lineText = lineText.substring(0, lineText.length - 1);
    }

    if (lineText.isEmpty) {
      controller.selection = TextSelection.collapsed(offset: lineStart);
      return;
    }

    final int localOffset = (clampedOffset - lineStart).clamp(0, lineText.length - 1);
    if (!_isWordCharacter(lineText[localOffset])) {
      controller.selection = TextSelection.collapsed(offset: clampedOffset);
      return;
    }

    int start = localOffset;
    while (start > 0 && _isWordCharacter(lineText[start - 1])) {
      start--;
    }

    int end = localOffset;
    while (end < lineText.length && _isWordCharacter(lineText[end])) {
      end++;
    }

    controller.selection = TextSelection(
      baseOffset: lineStart + start,
      extentOffset: lineStart + end,
    );
  }

  bool _isWordCharacter(String char) => _wordCharRegExp.hasMatch(char);

  /// Converts a local position in this render box to a document UTF-16 offset.
  int getTextOffsetFromLocalPosition(Offset localPosition) {
    return _getTextOffsetFromPosition(localPosition);
  }

  /// Returns a local anchor point (near the text baseline) for a given
  /// document UTF-16 offset.
  Offset getLocalAnchorForTextOffset(int textOffset) {
    if (controller.lineCount <= 0) {
      return Offset(_gutterWidth + 10.0, 0);
    }

    final int clampedOffset = textOffset.clamp(0, controller.length);
    final int lineIndex = controller.getLineAtOffset(clampedOffset).clamp(0, controller.lineCount - 1);
    final int lineStart = controller.getLineStartOffset(lineIndex);
    final int lineEnd = (lineIndex < controller.lineCount - 1) ? controller.getLineStartOffset(lineIndex + 1) : controller.length;
    final int lineLen = max(0, lineEnd - lineStart - (lineIndex < controller.lineCount - 1 ? 1 : 0));
    final int localCharOffset = (clampedOffset - lineStart).clamp(0, lineLen);

    final lineText = controller.getLineText(lineIndex);
    final ui.Paragraph paragraph = _paragraphCache[lineIndex] ?? _buildLine(fullLineText: lineText, lineIndex: lineIndex);

    double x = _gutterWidth + 10.0;
    double y = _lineDocumentTop(lineIndex);

    if (localCharOffset > 0 && localCharOffset <= lineText.length) {
      final boxes = paragraph.getBoxesForRange(0, localCharOffset);
      if (boxes.isNotEmpty) {
        x += boxes.last.right;
        y += boxes.last.bottom;
        return Offset(x, y);
      }
    }

    y += _lineHeight;
    return Offset(x, y);
  }

  int _getTextOffsetFromPosition(Offset position) {
    // position.dy is already in document/content coordinates.
    // RenderRopeField lives inside SingleChildScrollView widgets (vertical and
    // horizontal).  Flutter's hit-test machinery transforms the global pointer
    // position through every ancestor's scroll offset before delivering it here
    // as localPosition, so no manual scroll adjustment is needed.
    final int lineIndex = _lineIndexAtY(position.dy).clamp(0, max(0, controller.lineCount - 1));
    final lineText = controller.getLineText(lineIndex);
    final double textX = _gutterWidth + 10.0;
    final ui.Paragraph paragraph = _paragraphCache[lineIndex] ?? _buildLine(fullLineText: lineText, lineIndex: lineIndex);

    // For sliced wide lines, account for the character offset of the slice.
    // position.dx is also already in document coordinates (horizontal scroll
    // has been factored in by the enclosing horizontal SingleChildScrollView).
    final int sliceOffset = _paragraphCharOffsets[lineIndex] ?? 0;
    final double charWidth = (_textStyle.fontSize ?? 14.0) * 0.6;
    final double sliceX = sliceOffset * charWidth;
    final double relativeX = position.dx - textX - sliceX;
    final double relativeY = position.dy - _lineDocumentTop(lineIndex);

    final tp = paragraph.getPositionForOffset(Offset(relativeX, relativeY));
    // Add slice offset to the paragraph's local offset to get the full line offset
    return (controller.getLineStartOffset(lineIndex) + sliceOffset + tp.offset).clamp(0, controller.length);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // PERFORMANCE & SAFETY: Access the positions list directly. This is safer than
    // the .position getter which can throw StateErrors if clients are detached
    // between ticks.
    final ScrollPosition? vPosition = vscrollController.positions.isNotEmpty ? vscrollController.positions.first : null;

    // Scroll metrics can be temporarily unavailable on Android when the soft
    // keyboard opens/closes or the viewport is resized. Never skip painting in
    // that state — doing so leaves a blank frame cached by RepaintBoundary and
    // text may not return until an unrelated scroll event triggers a repaint.
    if (vPosition == null) return;

    final canvas = context.canvas;

    // SAFETY: Accessing viewportDimension on a ScrollPosition before it has been
    // fully initialized by the layout engine throws "Null check operator used on a null value".
    // We use contentHeight as a proxy for the height constraints when the position isn't ready.
    double viewport = 0;
    if (vPosition.hasPixels) {
      try {
        viewport = vPosition.viewportDimension;
      } catch (_) {
        // Fallback to a zero-height until the scroll position is measured.
      }
    }

    if (viewport <= 0) {
      // Use a reasonable fallback from the controller or parent size
      viewport = controller.viewportHeight > 0 ? controller.viewportHeight : size.height;
    }
    final double scrollOffset = vPosition.hasPixels ? vPosition.pixels : 0.0;

    // Update the controller's viewport info so external widgets (like minimaps) can read it safely.
    controller.viewportHeight = viewport;

    final Color bgColor = _editorTheme['root']?.backgroundColor ?? Colors.white;
    final Color textColor = _editorTheme['root']?.color ?? Colors.black;

    // 1. Draw Background
    canvas.drawRect(offset & size, Paint()..color = bgColor);

    // 2. Viewport Calculation
    final visibleLines = _visibleLineRange(scrollOffset, viewport);
    final firstLine = visibleLines.first;
    final lastLine = visibleLines.last;

    // PERFORMANCE: Prune the cache for lines that are far from the viewport
    _pruneParagraphCache(firstLine, lastLine);

    // Get horizontal scroll info for viewport-based rendering of wide lines
    final ScrollPosition? hPos = hscrollController.positions.isNotEmpty ? hscrollController.positions.first : null;
    final double hScroll = (hPos != null && hPos.hasPixels) ? hPos.pixels : 0.0;
    final double hViewport = (hPos != null && hPos.hasPixels) ? (hPos.viewportDimension > 0 ? hPos.viewportDimension : size.width) : size.width;

    // PERFORMANCE: Batch-fetch all line start offsets for the visible range
    // in a single FFI call (O(n) cursor walk) instead of per-line calls (O(n log n)).
    // Request one extra line to compute line lengths via offset subtraction.
    final int batchEnd = min(lastLine + 1, controller.lineCount);
    final List<int> lineOffsets = controller.getLineStartOffsetsBatch(firstLine, batchEnd);

    // PERFORMANCE: Ensure all visible paragraphs are built before drawing any
    // background layers (Selection/Search) so they can query layout boxes.
    // For very long lines (>10K chars), only fetch and build the visible
    // horizontal window to avoid huge FFI copies and paragraph layout.
    final double charWidth = (_textStyle.fontSize ?? 14.0) * 0.6;
    for (int i = firstLine; i < lastLine; i++) {
      final int localIdx = i - firstLine;
      final int lineStart = lineOffsets[localIdx];
      // Compute line length from the batch offsets
      final int lineLen = (localIdx + 1 < lineOffsets.length) ? lineOffsets[localIdx + 1] - lineStart - 1 : controller.length - lineStart;
      if (!_lineWrap && lineLen > 10000) {
        // Calculate the visible char window
        final int startChar = max(0, (hScroll / charWidth).floor() - 200);
        final int endChar = min(lineLen, ((hScroll + hViewport) / charWidth).ceil() + 200);

        // Invalidate if scroll moved outside the cached range
        final cachedOffset = _paragraphCharOffsets[i];
        // Important correctness rule:
        // - If user scrolls LEFT (startChar decreases), we must rebuild immediately.
        //   Reusing a slice that starts to the right causes leading characters to
        //   disappear until another repaint path invalidates the cache.
        // - If user scrolls RIGHT, we can tolerate a small delta to reduce churn.
        final bool movedLeftOfCachedSlice = cachedOffset != null && startChar < cachedOffset;
        final bool movedTooFarRight = cachedOffset != null && (startChar - cachedOffset) > 50;
        if (cachedOffset == null || movedLeftOfCachedSlice || movedTooFarRight) {
          _paragraphCache.remove(i);
        }

        if (!_paragraphCache.containsKey(i)) {
          final fullLineText = controller.getLineText(i);
          final visibleText = fullLineText.substring(startChar, min(endChar, fullLineText.length));
          _paragraphCharOffsets[i] = startChar;
          _paragraphCache[i] = _buildLine(
            fullLineText: fullLineText,
            renderText: visibleText,
            renderOffsetInLine: startChar,
            lineIndex: i,
          );
        }
      } else if (!_paragraphCache.containsKey(i)) {
        final fullLineText = controller.getLineText(i);
        _paragraphCache[i] = _buildLine(fullLineText: fullLineText, lineIndex: i);
      }
    }

    // 2.2 Draw Text Selection (Background layer)
    _paintSelection(canvas, offset, firstLine, lastLine, lineOffsets);

    // 2.5 Draw Search Highlights (Background layer)
    _paintSearchHighlights(canvas, offset, firstLine, lastLine, lineOffsets);

    // 3. Draw Gutter
    if (_enableGutter) {
      _paintGutter(canvas, offset, firstLine, lastLine, textColor);
    }

    // 4. Draw Text
    final double textX = _gutterWidth + 10.0;

    for (int i = firstLine; i < lastLine; i++) {
      final paragraph = _paragraphCache[i]!;

      // PERFORMANCE & LOGIC: In nested ScrollViews, the canvas is already translated.
      // We draw lines at their absolute document coordinates (relative to the box origin).
      final double lineY = _lineDocumentTop(i);
      // For sliced wide lines, offset the paragraph to where it belongs
      final int sliceOffset = _paragraphCharOffsets[i] ?? 0;
      final double sliceX = sliceOffset * charWidth;
      canvas.drawParagraph(paragraph, offset + Offset(textX + sliceX, lineY));
    }

    // 5. Draw Caret
    if (caretBlinkController.value > 0.5) {
      _paintCaret(canvas, offset);
    }

    // Consume dirty flags so we don't repeatedly clear the same lines
    controller.clearDirtyRegion();
  }

  ui.Paragraph _buildLine({
    required String fullLineText,
    required int lineIndex,
    String? renderText,
    int renderOffsetInLine = 0,
  }) {
    final paraStyle = _paragraphStyleForLine();

    return _highlighter.buildHighlightedParagraph(
      fullLineText,
      paraStyle,
      lineIndex: lineIndex,
      width: _availableTextWidth,
      lineRequest: HighlightLineRequest(
        fullLineText: fullLineText,
        precedingContext: _precedingContextForLine(lineIndex),
        renderText: renderText,
        renderOffsetInLine: renderOffsetInLine,
      ),
    );
  }

  String _precedingContextForLine(int lineIndex) {
    if (lineIndex <= 0) return '';

    final contextLines = <String>[];
    var i = lineIndex - 1;
    while (i >= 0 && lineIndex - i <= 200) {
      final line = controller.getLineText(i);
      contextLines.insert(0, line);
      if (!lineContinuesOnNext(line)) {
        break;
      }
      i--;
    }

    if (contextLines.isEmpty) {
      return '';
    }
    return contextLines.join('\n');
  }

  void _paintSelection(Canvas canvas, Offset offset, int startLine, int endLine, List<int> lineOffsets) {
    final selection = controller.selection;
    if (selection.isCollapsed) return;

    final Color selectionColor = _editorTheme['selection']?.backgroundColor ?? Colors.blue.withValues(alpha: 0.3);
    final paint = Paint()..color = selectionColor;
    final double textX = _gutterWidth + 10.0;

    final int selStart = selection.start;
    final int selEnd = selection.end;

    for (int i = startLine; i < endLine; i++) {
      final int localIdx = i - startLine;
      final int lineStart = lineOffsets[localIdx];
      // Compute line end from batch offsets
      final int lineEnd = (localIdx + 1 < lineOffsets.length)
          ? lineOffsets[localIdx + 1] - 1 // subtract newline
          : controller.length;
      final int lineLen = lineEnd - lineStart;

      // Check if this line is part of the selection
      if (selStart > lineEnd || selEnd < lineStart) continue;

      final int localStart = (selStart - lineStart).clamp(0, lineLen);
      final int localEnd = (selEnd - lineStart).clamp(0, lineLen);
      if (localStart >= localEnd) continue;

      final paragraph = _paragraphCache[i];
      if (paragraph == null) continue;

      final int sliceOffset = _paragraphCharOffsets[i] ?? 0;
      final double charWidth = (_textStyle.fontSize ?? 14.0) * 0.6;
      int paraStart = localStart;
      int paraEnd = localEnd;
      double sliceX = 0;

      // Paragraph text may be a horizontal slice of a very long unwrapped line.
      if (sliceOffset > 0) {
        paraStart = localStart - sliceOffset;
        paraEnd = localEnd - sliceOffset;
        if (paraEnd <= 0) continue;
        paraStart = max(0, paraStart);

        final ScrollPosition? hPos = hscrollController.positions.isNotEmpty ? hscrollController.positions.first : null;
        final double hScroll = (hPos != null && hPos.hasPixels) ? hPos.pixels : 0.0;
        final double hViewport = (hPos != null && hPos.hasPixels)
            ? (hPos.viewportDimension > 0 ? hPos.viewportDimension : size.width)
            : size.width;
        final int sliceEndChar = min(lineLen, ((hScroll + hViewport) / charWidth).ceil() + 200);
        final int sliceLength = sliceEndChar - sliceOffset;
        if (sliceLength <= 0 || paraStart >= sliceLength) continue;
        paraEnd = min(paraEnd, sliceLength);
        sliceX = sliceOffset * charWidth;
      }

      if (paraStart >= paraEnd) continue;

      // Draw full line selection for multi-line blocks (including newline)
      final bool includeNewline = selEnd > lineEnd && i < controller.lineCount - 1;

      final boxes = paragraph.getBoxesForRange(paraStart, paraEnd);
      for (final box in boxes) {
        final rect = Rect.fromLTWH(
          offset.dx + textX + sliceX + box.left,
          offset.dy + _lineDocumentTop(i) + box.top,
          box.right - box.left,
          box.bottom - box.top,
        );
        canvas.drawRect(rect, paint);
      }

      if (includeNewline) {
        final rect = Rect.fromLTWH(
          offset.dx + textX + sliceX + paragraph.width,
          offset.dy + _lineDocumentTop(i),
          10.0,
          _lineHeight,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  void _paintGutter(Canvas canvas, Offset offset, int start, int end, Color textColor) {
    final Color gutterBg = _editorTheme['gutter']?.backgroundColor ?? _editorTheme['root']?.backgroundColor?.withValues(alpha: 0.8) ?? Colors.grey[100]!;

    final gutterRect = Rect.fromLTWH(offset.dx, offset.dy, _gutterWidth, size.height);
    canvas.drawRect(gutterRect, Paint()..color = gutterBg);

    if (_enableGutterDivider) {
      canvas.drawLine(
        Offset(offset.dx + _gutterWidth, offset.dy),
        Offset(offset.dx + _gutterWidth, offset.dy + size.height),
        Paint()..color = Colors.grey[300]!,
      );
    }

    for (int i = start; i < end; i++) {
      final Color numColor = _editorTheme['gutter']?.color ?? textColor.withValues(alpha: 0.5);
      final tp = TextPainter(
        text: TextSpan(text: '${i + 1}', style: _textStyle.copyWith(color: numColor, fontSize: (_textStyle.fontSize ?? 14) * 0.8)),
        textDirection: TextDirection.ltr,
      )..layout();

      final y = offset.dy + _lineDocumentTop(i) + (_lineHeight - tp.height) / 2;
      tp.paint(canvas, Offset(offset.dx + _gutterWidth - tp.width - 8, y));
    }
  }

  void _paintCaret(Canvas canvas, Offset offset) {
    // Don't draw the caret if the field doesn't have focus
    if (!_focusNode.hasFocus) return;

    final selection = controller.selection;
    if (!selection.isCollapsed) return;

    // Clamp line index to valid range - when cursor is at the very end of a
    // document ending with newline, getLineAtOffset may return lineCount
    final int rawLineIndex = controller.getLineAtOffset(selection.extentOffset);
    final int lineIndex = rawLineIndex.clamp(0, controller.lineCount - 1);
    final lineStart = controller.getLineStartOffset(lineIndex);
    final charOffset = selection.extentOffset - lineStart;

    final Color caretColor = _editorTheme['cursor']?.color ?? _editorTheme['root']?.color ?? Colors.blue;

    // Ensure the paragraph exists and is properly constrained
    final lineText = controller.getLineText(lineIndex);
    final paragraph = _paragraphCache[lineIndex] ?? _buildLine(fullLineText: lineText, lineIndex: lineIndex);

    // Get the horizontal and vertical position for the cursor within the line
    // paragraph. When line wrap is enabled, a logical line can span multiple
    // visual rows; box.top/bottom match selection and search highlight painting.
    double caretXPos = 0;
    double caretYPos = 0;
    double caretHeight = _lineHeight - 4;

    if (charOffset > 0 && charOffset <= lineText.length) {
      final boxes = paragraph.getBoxesForRange(0, charOffset);
      if (boxes.isNotEmpty) {
        final box = boxes.last;
        caretXPos = box.right;
        caretYPos = box.top;
        caretHeight = max(2.0, box.bottom - box.top - 4);
      }
    }

    final x = offset.dx + _gutterWidth + 10.0 + caretXPos;
    final y = offset.dy + _lineDocumentTop(lineIndex) + caretYPos;

    canvas.drawRect(
      Rect.fromLTWH(x, y + 2, 2, caretHeight),
      Paint()..color = caretColor,
    );
  }

  void _paintSearchHighlights(Canvas canvas, Offset offset, int startLine, int endLine, List<int> lineOffsets) {
    final highlights = controller.searchHighlights;
    if (highlights.isEmpty) return;

    // PERFORMANCE: Use pre-fetched batch offsets for viewport boundaries.
    final int viewportStartOffset = lineOffsets.isNotEmpty ? lineOffsets.first : 0;
    // endLine offset: use the extra offset we fetched (lastLine+1), or fall back to doc length
    final int viewportEndOffset = (endLine - startLine < lineOffsets.length) ? lineOffsets[endLine - startLine] : controller.length;

    // Binary search for the first highlight that could be visible.
    int low = 0;
    int high = highlights.length;
    while (low < high) {
      final int mid = low + ((high - low) >> 1);
      if (highlights[mid].end < viewportStartOffset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final int firstIndex = low;

    final paint = Paint()..style = PaintingStyle.fill;
    final double textX = offset.dx + _gutterWidth + 10.0;

    for (int idx = firstIndex; idx < highlights.length; idx++) {
      final highlight = highlights[idx];

      // Only paint if the match starts before the viewport ends
      if (highlight.start > viewportEndOffset) break;

      final int matchStartLine = controller.getLineAtOffset(highlight.start);
      final int matchEndLine = controller.getLineAtOffset(highlight.end);

      paint.color = highlight.isCurrentMatch ? Colors.blue.withValues(alpha: 0.4) : Colors.yellow.withValues(alpha: 0.3);

      for (int i = max(startLine, matchStartLine); i <= min(endLine, matchEndLine); i++) {
        // Use batch offsets when the line is in our pre-fetched range
        final int localIdx = i - startLine;
        final int lineStart = (localIdx >= 0 && localIdx < lineOffsets.length) ? lineOffsets[localIdx] : controller.getLineStartOffset(i);
        final int lineEnd = (localIdx + 1 < lineOffsets.length) ? lineOffsets[localIdx + 1] - 1 : controller.length;
        final int lineLen = lineEnd - lineStart;

        final int localStart = (highlight.start - lineStart).clamp(0, lineLen);
        final int localEnd = (highlight.end - lineStart).clamp(0, lineLen);

        if (localStart >= localEnd) continue;

        final paragraph = _paragraphCache[i];
        if (paragraph == null) continue;

        final boxes = paragraph.getBoxesForRange(localStart, localEnd);
        for (final box in boxes) {
          final rect = Rect.fromLTWH(textX + box.left, offset.dy + _lineDocumentTop(i) + box.top, box.right - box.left, box.bottom - box.top);
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  void _pruneParagraphCache(int firstVisible, int lastVisible) {
    // Keep a buffer of 100 lines above and below to prevent flickering on fast scrolls
    if (_paragraphCache.length > 500) {
      _paragraphCache.removeWhere((line, _) => line < firstVisible - 100 || line > lastVisible + 100);
      _paragraphCharOffsets.removeWhere((line, _) => line < firstVisible - 100 || line > lastVisible + 100);
    }
  }

  @override
  void detach() {
    _stopSelectionAutoScroll();
    _touchLongPressTimer?.cancel();
    _controller.removeListener(_handleControllerNotification);
    vscrollController.removeListener(markNeedsPaint);
    hscrollController.removeListener(markNeedsPaint);
    caretBlinkController.removeListener(markNeedsPaint);
    super.detach();
  }
}
