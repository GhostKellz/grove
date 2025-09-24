# Grove Architecture Overview

Grove wraps the Tree-sitter C runtime with a Zig-first API that scales toward Grim (editor) and Ghostlang (scripting) integrations. This document explains the layer boundaries introduced in the MVP and how they evolve through Alpha/Beta milestones.

## Layered Design

```
┌─────────────────────────────────────────────────────┐
│ Applications (Grim, Ghostlang, CLI tools)           │
├─────────────────────────────────────────────────────┤
│ Grove Public API (`@import("grove")`)               │
│  • Parser / Tree / Node wrappers                    │
│  • Language handles                                 │
├─────────────────────────────────────────────────────┤
│ Internal Modules                                    │
│  • core/parser.zig  – lifecycle, error mapping      │
│  • core/tree.zig    – RAII over TSTree              │
│  • core/node.zig    – traversal helpers             │
│  • language.zig     – safe `TSLanguage` handles     │
│  • languages.zig    – vendored grammar registry     │
│  • c/tree_sitter.zig – bridge to C headers          │
├─────────────────────────────────────────────────────┤
│ Tree-sitter C Runtime (vendored)                    │
└─────────────────────────────────────────────────────┘
```

### Module Responsibilities
- **`src/root.zig`** re-exports all public types plus the raw C namespace (`grove.c`). Downstream code imports once and gains access to safe wrappers alongside the underlying FFI for advanced scenarios.
- **`src/core/parser.zig`** encapsulates `TSParser` ownership, enforces language configuration, and surfaces typed error sets. Future work adds incremental edit application and async entry points.
- **`src/core/tree.zig`** manages `TSTree` lifetime, providing copy semantics and root node access. Later milestones extend it with edit, range, and change tracking helpers.
- **`src/core/node.zig`** exposes read-only node APIs and point conversions. Highlight/query utilities will build on this type in Alpha.
- **`src/language.zig`** guards against null language pointers.
- **`src/languages.zig`** exposes bundled grammars (JSON today) and will expand as we vendor more languages.
- **`src/c/tree_sitter.zig`** uses `@cImport` to pull in `tree_sitter/api.h`, define `TREE_SITTER_STATIC`, and share the `c` namespace across the crate.

## Build Integration
`build.zig` compiles the vendored C sources (`archive/tree-sitter/lib/src/lib.c`) once and attaches them to the Grove module. Consumers do not need to manage Tree-sitter separately; `zig build` handles header paths and C flags.

Key compile flags:
- `TREE_SITTER_STATIC=1` – link the runtime statically.
- `_DEFAULT_SOURCE` and `_GNU_SOURCE` – expose required libc helpers (`le16toh`, `fdopen`, etc.).

## Data Flow Summary
1. Client allocates a `Parser` using its chosen allocator.
2. Client loads a Tree-sitter language (currently via external symbol) and calls `setLanguage`.
3. Source bytes are parsed through `parseUtf8`, returning a managed `Tree`.
4. `Tree.rootNode()` yields a `Node` used for inspection, traversal, or conversion to S-expressions.

The MVP keeps execution synchronous; Zsync-based scheduling will wrap these APIs with async-aware variants in Alpha.

## Extension Points
- **Language Registry**: `languages.zig` enumerates bundled grammars and will grow with Zig, Ghostlang, and other integrations.
- **Rope Integration**: Upcoming `input/` module (Alpha) will translate Grim rope edits into Tree-sitter edits before invoking `parseUtf8` incrementally.
- **Query Layer**: Planned `query/` module compiles highlight queries using the same C bridge, caching results per language.

## Testing Strategy
- Zig unit tests ensure error surfaces behave as expected (`LanguageNotSet`, null language detection).
- `zig build test` compiles all C dependencies and verifies the wrappers end-to-end.
- Fuzz tests will extend the parser suite once edit translation is implemented (tracked in ROADMAP Alpha tasks).

## Related Documents
- `CODEX.md` – operational handbook and milestone plan.
- `ROADMAP.md` – phase-by-phase deliverables.
- `docs/mvp-overview.md` – shipped MVP functionality.
- `docs/api-parser.md` – detailed parser API reference.
- `docs/integration/ghostlang.md` – Ghostlang language + query integration notes.
