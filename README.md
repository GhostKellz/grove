# Grove

<div align="center">
  <img src="assets/icons/grove.png" alt="Grove" width="175"/>
</div>

![Zig](https://img.shields.io/badge/Built%20with-Zig-yellow?logo=zig)
![Version](https://img.shields.io/badge/Zig-0.16.0--dev-orange?logo=zig)
![Async Runtime](https://img.shields.io/badge/Async-zsync-success?logo=zig)
![LSP Ready](https://img.shields.io/badge/LSP-Ready-brightgreen?logo=visualstudiocode&logoColor=white)

A high-performance Tree-sitter wrapper for Zig, designed to provide safe, ergonomic syntax highlighting and parsing for the Grim text editor.

## Overview

Grove is a modern Zig wrapper around the Tree-sitter parsing library, focusing on:

- **Safety**: RAII resource management with no UB on moved trees
- **Performance**: Zero-copy rope integration and incremental parsing
- **Ergonomics**: Clean Zig API over the proven Tree-sitter runtime
- **Integration**: Purpose-built for text editors with LSP support

## Bundled Grammars

Grove ships with **15 production-ready grammars**, all compiled against tree-sitter 0.25.10 (ABI 15):

- **JSON** – `grove.Languages.json.get()` – Configuration and data files
- **Zig** – `grove.Languages.zig.get()` – Zig programming language
- **Rust** – `grove.Languages.rust.get()` – Rust with scanner support
- **Ghostlang** – `grove.Languages.ghostlang.get()` – Ghostlang scripting (`.ghost`, `.gza`)
- **TypeScript** – `grove.Languages.typescript.get()` – TypeScript with scanner
- **TSX** – `grove.Languages.tsx.get()` – TypeScript + JSX
- **Bash** – `grove.Languages.bash.get()` – Shell scripting
- **JavaScript** – `grove.Languages.javascript.get()` – JavaScript with scanner
- **Python** – `grove.Languages.python.get()` – Python 3.x
- **Markdown** – `grove.Languages.markdown.get()` – Documentation and prose
- **CMake** – `grove.Languages.cmake.get()` – Build system configuration
- **TOML** – `grove.Languages.toml.get()` – Cargo.toml, pyproject.toml, configs
- **YAML** – `grove.Languages.yaml.get()` – CI/CD, Kubernetes, Docker Compose
- **C** – `grove.Languages.c.get()` – C programming language
- **GShell** – `grove.Languages.gshell.get()` – GShell command syntax

### Ghostlang Support Snapshot

- **Parser source**: `vendor/tree-sitter-ghostlang/src/parser.c` (statically linked into Grove builds)
- **Tree-sitter queries**: `vendor/tree-sitter-ghostlang/queries/` covering highlights, locals, textobjects, and injections
- **Phase A features**: `local` variables/functions, generic `for k, v in` loops, anonymous functions, varargs `...`, method call syntax `obj:method()`, `break`/`continue` statements
- **Control flow**: Numeric `for` loops (`for i = 1, 10[, step] do...end`), `repeat...until` blocks, and generic iterator loops
- **File associations**: `.ghost`, `.gza` for Grim plugin and Ghostlang script workflows
- **Grammar tests**: 29/29 tree-sitter corpus tests passing (100% coverage)

## Project Status

Phase 1 foundation work is complete. Grove is now in **Phase 2 – Production Editor Integration**, extending beyond the wrapper to deliver multi-grammar support, performance wins, and Grim-focused editor features over the Tree-sitter C runtime.

### Current Goals

- ✅ Zig wrapper over Tree-sitter C runtime (MIT)
- ✅ Chunked input adapter for incremental edits (`Parser.parseChunks`)
- ✅ Safe parser lifecycle & pooling (`core/pool.zig`)
- ✅ Query, highlight, and editor bridges (`grove.Query`, `grove.Editor`)
- ✅ Benchmark harness with throughput metrics (`zig build bench`)

## Architecture

Grove follows a phased approach:

1. **Phase 1**: Foundation wrapper over C Tree-sitter
2. **Phase 2**: Integration with Grim editor
3. **Phase 3**: Native Zig runtime optimization

## Phase 2 Roadmap (Next 6–8 Weeks)

### Week 1–2 · Grammar Expansion

- ✅ Vendored Zig grammar wired through `Bundled.zig`
- 🔄 Maintain JSON grammar for configuration flows
- ✅ Vendor Rust grammar (scanner support) for Grim plugins
- ✅ Stage Ghostlang grammar and ship `.ghost`/`.gza` highlight queries
- ✅ TypeScript grammar wired into Grove module with highlight regression tests
- 🔄 Prepare Markdown grammar to round out editor coverage

### Week 3–4 · Performance Optimisation

- Parsing throughput target: **≥10 MB/s** versus C Tree-sitter baseline
- Memory ceiling: **<100 MB** while indexing 10 k-file projects
- Incremental latency: **<5 ms** per edit with arena allocators & hot-path tuning
- Focus areas: allocator strategy, parser profiling, incremental diffing, multi-threaded pipelines, grammar cache reuse
- ✅ Added baseline benchmark (`zig build bench`) and parse timing API (`Parser.parseUtf8Timed`)

### Week 5–6 · Editor Integration Features

- ✅ Ship Tree-sitter query helpers and highlight engine (`grove.Query`, `grove.Highlight`)
- ✅ Emit folding ranges, document symbols, and hover metadata through `grove.Editor`
- Enrich diagnostics (error recovery) and Unicode hardening
- Harden Unicode & multi-byte handling for international content

### Week 7–8 · Production Polish

- Guarantee graceful failure modes, bounded memory, and thread-safe parsing
- Add tree serialisation/caching plus a lightweight plugin story for custom grammars
- Expand QA: >1000 regression tests, fuzz harness, memory tooling, and performance benchmarks against the C runtime
- Run real-world import trials on large open-source Zig/Rust/TypeScript projects

### Success Metrics

- ⚡ **Performance**: meet or exceed C Tree-sitter throughput with <10 ms incremental latency and 50 % lower memory footprint
- 🧠 **Grammar Coverage**: ✅ 14 highlighted languages (JSON, Zig, Rust, Ghostlang, TypeScript, TSX, Bash, JavaScript, Python, Markdown, CMake, TOML, YAML, C)
- 🛠️ **Editor Experience**: Complete Grim integration with syntax, folding, symbols, and navigation APIs
- 🌱 **Ecosystem Health**: Publish Grove as a reusable Zig package, attract external grammar contributions, and position Grove as the Zig reference implementation for Tree-sitter

### Integration Timeline Snapshot

- **Week 1–2**: Finish JSON/Rust vendoring → begin Grim smoke tests
- **Week 3–4**: Performance tuning → benchmark head-to-head with C Tree-sitter
- **Week 5–6**: Editor feature rollout → full Grim syntax highlighting and navigation
- **Week 7–8**: Production hardening → public-ready release builds and docs

**End State:** Grove becomes the premier Tree-sitter experience for Zig—faster than the C runtime, tightly integrated with Grim, and ready for community adoption.

## Building

Grove requires Zig 0.16.0-dev or later.

```bash
zig build
```

Run the test suite (includes JSON grammar sanity checks):

```bash
zig build test
```

Run the throughput benchmark harness:

```bash
zig build bench
```

Track incremental latency against the <5 ms target:

```bash
zig build bench-latency
```

### Quick Parse Example

```zig
const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	defer _ = gpa.deinit();

	var parser = try grove.Parser.init(gpa.allocator());
	defer parser.deinit();

	const language = try grove.Languages.json.get();
	try parser.setLanguage(language);

	var tree = try parser.parseUtf8(null, "{\"hello\": true}");
	defer tree.deinit();

	const root = tree.rootNode() orelse return error.EmptyTree;
	std.debug.print("root kind = {s}\n", .{root.kind()});
}
```

## Editor Toolkit

- **Queries**: `grove.Query` and `grove.QueryCursor` wrap Tree-sitter query APIs with Zig safety, capture metadata, and dynamic registry support.
- **Query Validation**: `grove.validateQuery` and `grove.validateQueryFile` check .scm files for errors before runtime.
- **Highlights**: `grove.Highlight.collectHighlights` and `HighlightEngine` map captures to Grim highlight classes.
- **Editor Utilities**: `grove.Editor` exposes `getHighlights`, `getFoldingRanges`, `getDocumentSymbols`, `findDefinition`, and `hover` helpers for LSP plumbing.
- **Error Recovery**: `grove.getSyntaxErrors` extracts ERROR and MISSING nodes with context for diagnostics.
- **Incremental Edits**: `grove.EditBuilder` provides high-level helpers for insertText, deleteRange, and replaceRange operations.
- **Multi-Grammar Support**: `grove.parseWithInjections` handles embedded languages (e.g., code blocks in Markdown, scripts in HTML).
- **Dynamic Grammars**: `grove.LanguageRegistry` registers additional grammars from shared libraries for live grammar swaps.

## Performance Helpers

- **Chunked Input**: `Parser.parseChunks` feeds rope segments or streaming buffers directly into Tree-sitter without concatenation.
- **Timing & Benchmarks**: `Parser.parseUtf8Timed` returns `ParseReport { tree, duration_ns, bytes }` for profiling. `zig build bench` parses bundled Zig sources and prints throughput, while `zig build bench-latency` samples incremental edits.
- **Parser Pooling**: `grove.ParserPool` leases configured parsers across threads, eliminating hot-path reinitialisation overhead.
- **Tree Cloning**: `tree.clone()` creates fast tree copies for undo/redo stacks without re-parsing.

## REPL/Shell Support

Grove includes specialized APIs for interactive shells and REPLs:

- **RealtimeHighlighter**: Sub-5ms highlighting for command-line input with incremental parsing
- **Command Validation**: Validate commands against PATH with custom validator functions
- **Completion Context**: Smart completion context detection (command, flag, file, variable)
- **Error Detection**: Real-time syntax error highlighting as users type

Example usage in a shell:
```zig
const grove = @import("grove");

var highlighter = try grove.RealtimeHighlighter.init(
    allocator,
    try grove.Languages.gshell.get(),
    highlight_query,
);
defer highlighter.deinit();

// Highlight user input in real-time
const spans = try highlighter.highlightLine("ls -la | grep test");

// Validate commands
const validator = struct {
    fn isValid(cmd: []const u8) bool {
        return isInPath(cmd); // Your implementation
    }
}.isValid;

const results = try grove.validateCommands(allocator, root, source, validator);
```

## License

MIT - See LICENSE file for details.

Tree-sitter grammars maintain their original licenses.
