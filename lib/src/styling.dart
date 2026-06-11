import 'package:flutter/material.dart';

class MatchHighlightStyle {
  final TextStyle currentMatchStyle;
  final TextStyle otherMatchStyle;

  const MatchHighlightStyle({
    required this.currentMatchStyle,
    required this.otherMatchStyle,
  });
}

class RopeEditorTheme {
  // Define basic theme helpers if needed, otherwise rely on re_highlight maps
}

class SearchHighlight {
  final int start, end;
  final bool isCurrentMatch;
  SearchHighlight({required this.start, required this.end, this.isCurrentMatch = false});
}