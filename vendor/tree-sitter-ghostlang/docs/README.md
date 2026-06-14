# tree-sitter-ghostlang Documentation

Documentation for the Ghostlang Tree-sitter grammar, editor queries, generated parser artifacts, and downstream integrations.

## Quick Start

**Parser users:**
1. [Project README](../README.md) - Project overview, install commands, and examples
2. [Getting Started](guides/getting-started.md) - Install dependencies, build the parser, and parse a file
3. [Parser Reference](api/parser.md) - Grammar artifacts, AST surface, and package entry points
4. [Queries Reference](api/queries.md) - Highlight, indent, fold, locals, injection, and textobject queries

**Editor and tooling integrators:**
- [Neovim](editors/neovim.md) - nvim-treesitter parser registration, queries, folds, and textobjects
- [Helix](editors/helix.md) - `languages.toml`, grammar build, and runtime query setup
- [Emacs](editors/emacs.md) - Emacs 29 `treesit` and legacy package setup
- [VSCode](editors/vscode.md) - Bundled TextMate extension and LSP notes
- [Grove Integration](integration/grove.md) - How Grove, GhostLS, and Grim consume this grammar

---

## Documentation Index

### Guides

| Document | Description |
|----------|-------------|
| [guides/getting-started.md](guides/getting-started.md) | Install dependencies, generate the parser, run corpus tests, and parse Ghostlang files |
| [guides/development.md](guides/development.md) | Grammar editing workflow, corpus tests, query updates, and release checklist |
| [guides/troubleshooting.md](guides/troubleshooting.md) | Common build, parse, query, and editor setup issues |

### API

| Document | Description |
|----------|-------------|
| [api/parser.md](api/parser.md) | Generated parser artifacts, Node/Rust bindings, and grammar node overview |
| [api/queries.md](api/queries.md) | Query file responsibilities and downstream editor expectations |

### Editors

| Document | Description |
|----------|-------------|
| [editors/neovim.md](editors/neovim.md) | Neovim and nvim-treesitter setup |
| [editors/helix.md](editors/helix.md) | Helix language and grammar setup |
| [editors/emacs.md](editors/emacs.md) | Emacs tree-sitter setup |
| [editors/vscode.md](editors/vscode.md) | VSCode extension and TextMate grammar setup |

### Integrations

| Document | Description |
|----------|-------------|
| [integration/grove.md](integration/grove.md) | Grove language handle, query bundling, and validation notes |
| [integration/editors.md](integration/editors.md) | Shared editor integration expectations for `.gla` files |

### Roadmap

| Document | Description |
|----------|-------------|
| [roadmap/project-roadmap.md](roadmap/project-roadmap.md) | Parser, query, packaging, and integration priorities |

## Project Resources

- [Contributing](../CONTRIBUTING.md) - Development and contribution guidelines
- [Security](../SECURITY.md) - Vulnerability reporting and security policy
- [Main README](../README.md) - Project overview
