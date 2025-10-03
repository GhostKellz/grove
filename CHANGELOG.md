# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2025-10-03

### Fixed
- **Rust grammar now packaged correctly** - Added `vendor/tree-sitter-rust` to `build.zig.zon` `.paths` so Grim and other consumers receive the Rust parser/scanner files when fetching Grove as a dependency
- Resolved build failures in downstream projects attempting to compile with Rust language support

## [0.1.0] - 2025-10-03

### 🎉 First Official Release - Grim Integration Ready

This release makes Grove **consumable as a Zig package** via `zig fetch --save`, fixing the critical packaging issue that blocked Grim's `-Dghostlang=true` build.

### Fixed
- **Package manifest now includes vendored dependencies** - Added `vendor/tree-sitter` and `vendor/grammars` to `build.zig.zon` `.paths` so consumers get the tree-sitter runtime (lib.c) and all prebuilt grammar parsers/scanners
- Grim can now successfully build with Grove as a dependency without missing lib.c errors

### Added
- **14 bundled grammars** compiled against tree-sitter 0.25.10 (ABI 15):
  - Bash, C, CMake, Ghostlang, JavaScript, JSON, Markdown, Python, Rust, TOML, TSX, TypeScript, YAML, Zig
- **Complete editor utilities** for all grammars (document symbols, folding ranges, highlights)
- **Query validation helpers** (`validateQuery`, `validateQueryFile`) - Check .scm files for errors before runtime
- **EditBuilder** - High-level wrapper for incremental edits (insertText, deleteRange, replaceRange)
- **Syntax error recovery** (`getSyntaxErrors`) - Extract ERROR and MISSING nodes with context
- **Tree cloning** (`tree.clone()`) - Fast tree copies for undo/redo without re-parsing
- **Multi-grammar support** (`parseWithInjections`, `findInjections`) - Handle embedded languages (e.g., code blocks in Markdown)
- Incremental latency benchmark (`zig build bench-latency`) for <5ms P50 tracking
- Tree-sitter runtime vendored at v0.25.10 with full ABI 15 support
- GRIMREAPER.md - Integration guide for Grim maintainers
- Comprehensive test coverage for all bundled grammars and new features

### Changed
- Bumped tree-sitter runtime to ABI version 15
- Enhanced performance documentation with throughput and latency targets

## [Unreleased]

### Pending
- Additional language support expansion
- Performance optimizations for multi-threaded parsing
- Tree serialization/caching layer
