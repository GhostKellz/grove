# Queries Reference

Query files define editor-facing behavior on top of the Ghostlang syntax tree.

## Query Files

| File | Purpose |
|------|---------|
| `queries/highlights.scm` | Syntax highlighting captures |
| `queries/locals.scm` | Scope, definition, and reference captures |
| `queries/folds.scm` | Foldable syntax ranges |
| `queries/indents.scm` | Indentation and dedentation hints |
| `queries/textobjects.scm` | Function, block, parameter, call, conditional, loop, and comment text objects |
| `queries/injections.scm` | Embedded language injection captures |

## Highlighting

`highlights.scm` captures Ghostlang keywords, functions, parameters, variables, properties, literals, comments, operators, and punctuation.

Downstream editors should load this file for `source.ghostlang` or language name `ghostlang`.

## Locals

`locals.scm` marks lexical scopes, definitions, parameters, and references. Keep this file synchronized with grammar changes that affect declarations, block nodes, or identifier positions.

## Folds and Indents

`folds.scm` and `indents.scm` help editors expose predictable folding and indentation for both syntax styles:

- C-style braces, brackets, and parentheses
- Lua-style `then`, `do`, `repeat`, `end`, `until`, and `else`
- Function and control-flow bodies

## Text Objects

`textobjects.scm` is intended for editors that support Tree-sitter selections and movement. It captures outer and inner ranges for functions, blocks, conditionals, loops, calls, parameters, and comments.

## Injections

`injections.scm` is reserved for embedded language support such as interpolation or inline code regions. Keep injection names conservative so editors do not attempt to load unsupported languages.

## Change Policy

When changing query captures:

1. Confirm the referenced node names exist in `src/node-types.json`.
2. Parse representative `.gla` samples with `npx tree-sitter parse`.
3. Test at least one downstream editor setup when capture names or query responsibilities change.
