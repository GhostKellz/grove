# Grove Integration

Grove consumes this repository as the Ghostlang Tree-sitter grammar used by editor and language tooling.

## Integration Surface

Grove-based consumers need:

- The generated parser from `src/parser.c`
- Language metadata for `ghostlang` and `source.ghostlang`
- Query files from `queries/*.scm`
- Representative `.gla` samples for validation

## Expected Flow

```text
tree-sitter-ghostlang
  -> Grove parser wrapper
  -> GhostLS language server helpers
  -> Editors such as Grim, Neovim, Helix, Emacs, and VSCode
```

## Validation Checklist

Before updating Grove to a new grammar revision:

- Run `npm test` in this repository
- Regenerate parser artifacts after grammar changes
- Confirm `src/node-types.json` contains expected public node names
- Load `queries/highlights.scm` successfully
- Parse a Lua-style `.gla` sample
- Parse a C-style `.gla` sample
- Verify folds, locals, and textobjects if Grove exposes them to the editor layer

## Query Bundle

Grove should treat these files as the default Ghostlang query bundle:

- `queries/highlights.scm`
- `queries/locals.scm`
- `queries/folds.scm`
- `queries/indents.scm`
- `queries/textobjects.scm`
- `queries/injections.scm`

If Grove embeds query strings, refresh the embedded copy whenever these files change.
