import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/re_highlight.dart';

Mode _enhancedClassDeclarationMode(Mode stockClassMode) {
  return Mode(
    className: 'class',
    beginKeywords: stockClassMode.beginKeywords,
    end: stockClassMode.end,
    excludeEnd: stockClassMode.excludeEnd,
    contains: <Mode>[
      Mode(beginKeywords: 'extends implements with on'),
      UNDERSCORE_TITLE_MODE,
      Mode(
        scope: 'title.class_',
        begin: r'[A-Z][\w]*(?:\.[A-Z][\w]*)*\??',
        relevance: 0,
      ),
    ],
  );
}

List<Mode> _enhancedDartContains() {
  final stockContains = langDart.contains! as List<Mode>;
  final contains = <Mode>[
    for (final mode in stockContains)
      if (mode.beginKeywords == 'class interface')
        _enhancedClassDeclarationMode(mode)
      else
        mode,
    // User-defined / imported type names (PascalCase), e.g. TextEditorViewModel.
    Mode(
      scope: 'title.class_',
      begin: r'\b[A-Z][\w]*(?:\.[A-Z][\w]*)*\??',
      relevance: 0,
    ),
    // Method and function declarations, including after annotations/modifiers.
    Mode(
      match: <String>[
        r'(?:@\w+\s+)*(?:static\s+)?(?:async\s+)?(?:external\s+)?',
        r'(?:void|var|dynamic|Never|Null|Future|Stream|Widget|BuildContext|State|Object|Type|bool|int|double|num|String|List|Map|Set|Iterable|Iterator|Symbol|Uri|Duration|DateTime|RegExp|[A-Z]\w*(?:<[^>]*>)?\??)\s+',
        r'([a-z_]\w*)',
        r'\s*\(',
      ],
      scope: <int, String>{3: 'title.function'},
      relevance: 2,
    ),
    // Getters and setters.
    Mode(
      beginKeywords: 'get set',
      keywords: langDart.keywords,
      contains: <Mode>[
        Mode(scope: 'title.function', begin: r'[a-zA-Z_]\w*', relevance: 0),
      ],
    ),
    // Named / const constructors: const MyWidget( ...
    Mode(
      match: <String>[
        r'\b(?:const|factory)\s+',
        r'([A-Z]\w*)',
        r'\s*\(',
      ],
      scope: <int, String>{2: 'title.class_'},
      relevance: 1,
    ),
    // Named arguments: seedColor: value, control: true
    Mode(
      match: <String>[
        r'\b([a-z_]\w*)',
        r'\s*:',
      ],
      scope: <int, String>{1: 'attr'},
      relevance: 1,
    ),
    // Member access: vm.themeSeedColor, intent.action, super.key
    Mode(
      match: <String>[
        r'\.(?!\.)',
        r'([a-z_]\w*)',
      ],
      scope: <int, String>{2: 'variable'},
      relevance: 1,
    ),
    // Field declarations and other lowerCamelCase identifiers.
    Mode(
      scope: 'variable',
      begin: r'\b[a-z_]\w*\b',
      relevance: 0,
    ),
  ];
  return contains;
}

/// Dart syntax mode extending the stock [langDart] grammar with additional rules
/// for user-defined types and function/method names.
final langDartEnhanced = Mode(
  refs: langDart.refs,
  name: langDart.name,
  keywords: langDart.keywords,
  contains: _enhancedDartContains(),
);
