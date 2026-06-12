# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.2] - 2026-06-11

- **Fix Lint** — Fix up codegen version
- **Fix License** — Fix license recognition

## [0.0.1] - 2026-06-11

### Added

- **`RopeEditor` widget** — monospace editor with optional line gutter, divider, line wrapping, and syntax highlighting via [re_highlight](https://pub.dev/packages/re_highlight)
- **`RopeEditorController`** — text editing, selection, clipboard, IME support, dirty-state tracking, and async file loading (`loadFromFile` with optional `maxChars` for huge single-line files)
- **`FindController`** — find/replace bar with case-sensitive, regex, and whole-word matching; live highlight updates as the document changes
- **`UndoRedoController`** — undo/redo with compound operation merging for rapid typing bursts
- **Rust-backed text buffer** — Zed-style `zed_rope` + `zed_sum_tree` for O(log n) line and offset queries
- **Batch FFI APIs** — `getLineStartOffsetsBatch`, `getLinesTextBatch`, `getMinimapDensityBatch`, `replaceAndCapture`, `getCursorContext`, and cached `getImeProjection` for low-latency editing and rendering
- **Search APIs** — full-document, line-range, whole-word, and include/exclude range search, all executed in Rust
- **Indentation analysis** — style detection and per-line indent queries
- **Word navigation** — character classes and VS Code-style word boundaries (Ctrl+Arrow, double-click selection)
- **LSP offset helpers** — UTF-16 ↔ byte conversion and line/column mapping
- **Enhanced Dart highlighting** — `langDartEnhanced` mode
- **Platform support** — Android, iOS, Linux, macOS, and Windows via Cargokit FFI plugin
- **Example app** — minimal integration demo under `example/`
- **Documentation** — API guides in `doc/` and Rust build instructions in README

### Changed

- Migrated the text buffer from `ropey` to Zed's rope implementation, eliminating O(n) metrics rebuilds that caused input lag during undo

### License

- Distributed under **GPL-3.0-or-later** because the native library links code adapted from Zed's GPL `rope` crate. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

[0.0.1]: #001---2026-06-11
