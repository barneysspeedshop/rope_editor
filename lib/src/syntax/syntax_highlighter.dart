import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:re_highlight/re_highlight.dart';

/// Options for highlighting a single editor line with optional preceding context.
class HighlightLineRequest {
  const HighlightLineRequest({
    required this.fullLineText,
    this.precedingContext = '',
    this.renderText,
    this.renderOffsetInLine = 0,
  });

  /// The complete text of the line being highlighted.
  final String fullLineText;

  /// Previous lines joined with `\n` when multiline strings/comments need context.
  final String precedingContext;

  /// Text to render in the paragraph. Defaults to a slice of [fullLineText].
  final String? renderText;

  /// Character offset within [fullLineText] where [renderText] begins.
  final int renderOffsetInLine;

  String get effectiveRenderText =>
      renderText ?? fullLineText.substring(renderOffsetInLine.clamp(0, fullLineText.length));

  String get _highlightInput =>
      precedingContext.isEmpty ? fullLineText : '$precedingContext\n$fullLineText';

  int get _lineStartInInput => precedingContext.isEmpty ? 0 : precedingContext.length + 1;

  int get renderStartInInput => _lineStartInInput + renderOffsetInLine;

  int get renderEndInInput => renderStartInInput + effectiveRenderText.length;
}

/// A contiguous character range with a syntax-highlight color.
class HighlightSpan {
  const HighlightSpan({
    required this.start,
    required this.end,
    required this.color,
  });

  final int start;
  final int end;
  final Color color;
}

class SyntaxHighlighter {
  /// Lines longer than this skip syntax highlighting (matches editor paint loop).
  static const int maxHighlightLength = 10000;
  static final Highlight _sharedHighlight = Highlight();
  static final Set<String> _registeredLanguages = {};

  final Map<String, TextStyle> _theme;
  final TextStyle _baseStyle;
  final Mode _language;
  final String _langId;

  late final ui.TextStyle _cachedBaseUiStyle;
  // PERFORMANCE: Cache converted ui.TextStyles to avoid repeated object 
  // allocation and Paint creation during paragraph building.
  final Map<TextStyle, ui.TextStyle> _convertedCache = {};

  // PERFORMANCE: Cache theme lookups for class names.
  final Map<String, TextStyle> _styleLookupCache = {};

  /// Returns the number of unique styles currently cached.
  @visibleForTesting
  int get debugStyleCacheSize => _convertedCache.length;

  SyntaxHighlighter({
    required Mode language,
    required Map<String, TextStyle> theme,
    required TextStyle baseStyle,
  })  : _language = language,
        _langId = _getStableId(language),
        _theme = theme,
        _baseStyle = baseStyle {
    _cachedBaseUiStyle = _convertTextStyle(_baseStyle);
    
    // PERFORMANCE: Ensure the language is registered. Some grammars use lazy 
    // initialization, so we register if it hasn't been seen yet, regardless 
    // of the 'contains' property.
    _registerLanguage();
  }

  static String _getStableId(Mode mode) {
    // PERFORMANCE: Lowercase the ID. re_highlight/highlight.js engines are 
    // case-sensitive but internally prefer lowercase for cross-references and aliases.
    return mode.name?.isNotEmpty == true ? mode.name!.toLowerCase() : 'idx_${identityHashCode(mode)}';
  }

  void _registerLanguage() {
    // Check both the local set and the engine's internal state to ensure registration
    _sharedHighlight.registerLanguage(_langId, _language);
    _registeredLanguages.add(_langId);
  }

  TextStyle _getStyleFromTheme(String className) {
    return _styleLookupCache.putIfAbsent(className, () {
      // Handle composite class names (e.g. "string attr") often found in re_highlight
      TextStyle style = const TextStyle();
      final classes = className.split(' ');

      for (final part in classes) {
        // Robust lookup with dotted scope fallback (standard HLJS behavior).
        // e.g. "string.quoted.double" matches "string.quoted.double", then "string.quoted", then "string".
        TextStyle? themeStyle;
        String current = part;
        while (true) {
          themeStyle = _theme[current] ?? 
                       _theme['hljs-$current'] ?? 
                       _theme[current.replaceFirst('hljs-', '')];
          if (themeStyle != null) break;
          
          final int lastDot = current.lastIndexOf('.');
          if (lastDot == -1) break;
          current = current.substring(0, lastDot);
        }

        if (themeStyle != null) {
          style = style.merge(themeStyle);
        }
      }
      return style;
    });
  }

  ui.TextStyle _convertTextStyle(TextStyle style) {
    return _convertedCache.putIfAbsent(style, () {
      return ui.TextStyle(
      color: style.color,
      fontSize: style.fontSize,
      fontFamily: style.fontFamily,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      letterSpacing: style.letterSpacing,
      wordSpacing: style.wordSpacing,
      height: style.height,
      decoration: style.decoration,
      decorationColor: style.decorationColor,
      decorationStyle: style.decorationStyle,
      background: style.backgroundColor != null ? (Paint()..color = style.backgroundColor!) : null,
      foreground: style.foreground,
    );
    });
  }

  /// Disposes resources.
  void dispose() {}

  ui.Paragraph buildHighlightedParagraph(
    String text,
    ui.ParagraphStyle paragraphStyle, {
    int lineIndex = 0,
    double? width,
    HighlightLineRequest? lineRequest,
  }) {
    final request = lineRequest ??
        HighlightLineRequest(fullLineText: text, renderText: text);
    final builder = ui.ParagraphBuilder(paragraphStyle);
    builder.pushStyle(_cachedBaseUiStyle);

    final renderText = request.effectiveRenderText;
    if (renderText.isEmpty) {
      builder.addText(' ');
      final p = builder.build();
      p.layout(ui.ParagraphConstraints(width: width ?? double.infinity));
      return p;
    }

    if (request._highlightInput.length > maxHighlightLength) {
      builder.addText(renderText);
      final p = builder.build();
      p.layout(ui.ParagraphConstraints(width: width ?? double.infinity));
      return p;
    }

    final HighlightResult result =
        _sharedHighlight.highlight(language: _langId, code: request._highlightInput);

    final renderer = _ParagraphRenderer(
      builder: builder,
      highlighter: this,
      baseStyle: _baseStyle,
      renderStart: request.renderStartInInput,
      renderEnd: request.renderEndInInput,
    );

    result.render(renderer);

    final p = builder.build();
    p.layout(ui.ParagraphConstraints(width: width ?? double.infinity));
    return p;
  }

  /// Returns syntax-highlighted character spans for a single line, optionally
  /// using [precedingContext] for multiline strings and block comments.
  List<HighlightSpan> getHighlightSpansForLine(
    String fullLineText, {
    String precedingContext = '',
  }) {
    return getHighlightSpans(
      fullLineText,
      lineRequest: HighlightLineRequest(
        fullLineText: fullLineText,
        precedingContext: precedingContext,
      ),
    );
  }

  /// Returns syntax-highlighted character spans for minimap and other compact views.
  ///
  /// Returns an empty list for empty text or lines exceeding [maxHighlightLength].
  List<HighlightSpan> getHighlightSpans(
    String text, {
    HighlightLineRequest? lineRequest,
  }) {
    final request = lineRequest ?? HighlightLineRequest(fullLineText: text);
    if (request.fullLineText.isEmpty || request._highlightInput.length > maxHighlightLength) {
      return const [];
    }

    final HighlightResult result =
        _sharedHighlight.highlight(language: _langId, code: request._highlightInput);
    final collector = _SpanCollector(
      highlighter: this,
      baseStyle: _baseStyle,
      renderStart: request.renderStartInInput,
      renderEnd: request.renderEndInInput,
    );
    result.render(collector);
    return collector.spans;
  }
}

/// A high-performance bridge between re_highlight and Flutter's ParagraphBuilder.
class _ParagraphRenderer extends HighlightRenderer {
  final ui.ParagraphBuilder builder;
  final SyntaxHighlighter highlighter;
  final List<TextStyle> _styleStack;
  final int renderStart;
  final int renderEnd;
  int _inputOffset = 0;

  _ParagraphRenderer({
    required this.builder,
    required this.highlighter,
    required TextStyle baseStyle,
    this.renderStart = 0,
    this.renderEnd = 1 << 30,
  }) : _styleStack = [baseStyle];

  @override
  void addText(String text) {
    if (text.isEmpty) return;

    final textStart = _inputOffset;
    final textEnd = textStart + text.length;
    _inputOffset = textEnd;

    final visibleStart = textStart < renderStart ? renderStart : textStart;
    final visibleEnd = textEnd > renderEnd ? renderEnd : textEnd;
    if (visibleStart >= visibleEnd) return;

    builder.addText(text.substring(visibleStart - textStart, visibleEnd - textStart));
  }

  @override
  void openNode(DataNode node) {
    final scope = node.scope;
    final parentStyle = _styleStack.last;

    if (scope == null) {
      _styleStack.add(parentStyle);
      return;
    }

    // PERFORMANCE: highlighter._getStyleFromTheme handles caching of the 
    // merged theme styles and dotted scope fallbacks.
    final TextStyle themeStyle = highlighter._getStyleFromTheme(scope);
    
    // Optimization: If the scope adds no styling, don't create a new TextStyle object.
    if (themeStyle == const TextStyle()) {
      _styleStack.add(parentStyle);
      return;
    }

    final effectiveStyle = parentStyle.merge(themeStyle);
    _styleStack.add(effectiveStyle);
    
    builder.pushStyle(highlighter._convertTextStyle(effectiveStyle));
  }

  @override
  void closeNode(DataNode node) {
    final lastStyle = _styleStack.removeLast();
    final parentStyle = _styleStack.last;
    
    // Only pop if this group actually pushed a new style.
    if (lastStyle != parentStyle) {
      builder.pop();
    }
  }
}

/// Collects contiguous character ranges and their effective highlight colors.
class _SpanCollector extends HighlightRenderer {
  final SyntaxHighlighter highlighter;
  final List<TextStyle> _styleStack;
  final List<HighlightSpan> spans = [];
  final int renderStart;
  final int renderEnd;
  int _inputOffset = 0;

  _SpanCollector({
    required this.highlighter,
    required TextStyle baseStyle,
    this.renderStart = 0,
    this.renderEnd = 1 << 30,
  }) : _styleStack = [baseStyle];

  Color get _currentColor {
    for (int i = _styleStack.length - 1; i >= 0; i--) {
      final color = _styleStack[i].color;
      if (color != null) return color;
    }
    return highlighter._baseStyle.color ?? const Color(0xFF000000);
  }

  @override
  void addText(String text) {
    if (text.isEmpty) return;

    final textStart = _inputOffset;
    final textEnd = textStart + text.length;
    _inputOffset = textEnd;

    final visibleStart = textStart < renderStart ? renderStart : textStart;
    final visibleEnd = textEnd > renderEnd ? renderEnd : textEnd;
    if (visibleStart >= visibleEnd) return;

    final outputStart = visibleStart - renderStart;
    final outputEnd = visibleEnd - renderStart;
    final Color color = _currentColor;

    if (spans.isNotEmpty &&
        spans.last.end == outputStart &&
        spans.last.color == color) {
      final last = spans.last;
      spans[spans.length - 1] = HighlightSpan(
        start: last.start,
        end: outputEnd,
        color: color,
      );
      return;
    }

    spans.add(HighlightSpan(start: outputStart, end: outputEnd, color: color));
  }

  @override
  void openNode(DataNode node) {
    final scope = node.scope;
    final parentStyle = _styleStack.last;

    if (scope == null) {
      _styleStack.add(parentStyle);
      return;
    }

    final TextStyle themeStyle = highlighter._getStyleFromTheme(scope);
    if (themeStyle == const TextStyle()) {
      _styleStack.add(parentStyle);
      return;
    }

    _styleStack.add(parentStyle.merge(themeStyle));
  }

  @override
  void closeNode(DataNode node) {
    _styleStack.removeLast();
  }
}
