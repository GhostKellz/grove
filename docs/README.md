# Grove Documentation

Documentation for Grove, a Zig-first Tree-sitter wrapper for safe parsing, syntax highlighting, editor integration, and bundled language support.

## Quick Start

**New users:**
1. [Project README](../README.md) - Project overview, status, and build basics
2. [Getting Started](guides/getting-started.md) - Install Grove and parse your first document
3. [Parser API](api/parser.md) - Core parser, tree, node, and language APIs
4. [Architecture](architecture/overview.md) - Layer boundaries and module responsibilities

**Editor and language integrators:**
- [LSP Helpers](api/lsp-helpers.md) - Position, symbol, hover, and range helpers
- [Theme Preset Guide](guides/theme-preset.md) - Query registry and theme bridge notes
- [Ghostlang Integration](integration/ghostlang.md) - Bundled Ghostlang grammar and query support
- [Grim Adapter Branch](integration/grim-adapter-branch.md) - Grim validation playbook

---

## Documentation Index

### Guides

| Document | Description |
|----------|-------------|
| [guides/getting-started.md](guides/getting-started.md) | Install Grove, parse a document, highlight code, and use incremental parsing |
| [guides/error-handling.md](guides/error-handling.md) | Parser, query, allocator, and editor-service error handling patterns |
| [guides/contributing-grammars.md](guides/contributing-grammars.md) | Add and validate a new bundled Tree-sitter grammar |
| [guides/cross-platform-compatibility.md](guides/cross-platform-compatibility.md) | Linux, macOS, Windows, and cross-compilation notes |
| [guides/theme-preset.md](guides/theme-preset.md) | QueryRegistry and ThemePreset usage for editor themes |

### API

| Document | Description |
|----------|-------------|
| [api/parser.md](api/parser.md) | Parser, Tree, Node, Language, and ParseReport reference |
| [api/lsp-helpers.md](api/lsp-helpers.md) | LSP helper functions for editor integrations |
| [api/stability.md](api/stability.md) | Public API surface and stability guarantees |

### Architecture

| Document | Description |
|----------|-------------|
| [architecture/overview.md](architecture/overview.md) | Grove module layers, ownership boundaries, and testing strategy |

### Integrations

| Document | Description |
|----------|-------------|
| [integration/ghostlang.md](integration/ghostlang.md) | Ghostlang language handle, queries, and runtime syntax support |
| [integration/grim-adapter-branch.md](integration/grim-adapter-branch.md) | Grim adapter branch setup and validation checklist |

### Roadmap

| Document | Description |
|----------|-------------|
| [roadmap/project-roadmap.md](roadmap/project-roadmap.md) | Project execution plan and release roadmap |
| [roadmap/mvp-overview.md](roadmap/mvp-overview.md) | MVP scope and shipped parser-wrapper functionality |

### RFCs

| Document | Description |
|----------|-------------|
| [rfcs/index.md](rfcs/index.md) | RFC process for significant Grove changes |
| [rfcs/template.md](rfcs/template.md) | RFC template |

## Project Resources

- [Contributing](../CONTRIBUTING.md) - Development and contribution guidelines
- [Security](../SECURITY.md) - Vulnerability reporting and security policy
- [Changelog](../CHANGELOG.md) - Version history
- [Main README](../README.md) - Project overview
