# Editor Integration

Ghostlang editor integrations should consistently register `.gla` files as `ghostlang` and load the query files from this repository.

## Shared Settings

- Language name: `ghostlang`
- Scope: `source.ghostlang`
- File extension: `.gla`
- Preferred line comments: `//` and `--`
- Preferred block comments: `/* ... */` and `--[[ ... ]]`

## Query Expectations

Editors with Tree-sitter support should load:

- `highlights.scm` for highlighting
- `indents.scm` for indentation when supported
- `folds.scm` for folding when supported
- `locals.scm` for scope-aware features when supported
- `textobjects.scm` for movement and selection when supported
- `injections.scm` for embedded language support when supported

## Editor Guides

- [Neovim](../editors/neovim.md)
- [Helix](../editors/helix.md)
- [Emacs](../editors/emacs.md)
- [VSCode](../editors/vscode.md)
