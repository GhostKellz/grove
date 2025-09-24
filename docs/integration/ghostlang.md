# Ghostlang Integration

Grove bundles the production Ghostlang Tree-sitter grammar so editors can light up Grim plugin scripts out of the box. This note captures the essentials for downstream consumers.

## Language Handle

- Call `grove.Languages.ghostlang.get()` to obtain the vendored `TSLanguage` wrapper.
- File extensions: `.ghost` and `.gza` map to Ghostlang sources in Grim.
- The parser is built directly from `vendor/grammars/ghostlang/parser.c`.

## Query Assets

`vendor/grammars/ghostlang/queries/` ships the full query suite:

- `highlights.scm` – syntax highlighting with dedicated captures for 40+ editor API calls (`@function.builtin`).
- `locals.scm` – scope and definition tracking for navigation and renaming.
- `textobjects.scm` – smart selections for functions, calls, blocks, strings, and comments.
- `injections.scm` – embedded language detection for JSON, CSS, SQL, and regex payloads inside Ghostlang strings.

Each file is ready to load through `grove.Query` helpers or custom pipelines. Grove does not hardcode queries so consumers may supply theme-specific rule tables.

## Upstream Source

- Repository: [`ghostlang/tree-sitter-ghostlang`](https://github.com/ghostlang/tree-sitter-ghostlang)
- Version: `v0.1.0` (vendored 2025-09-24)
- Local changes: added explicit conflicts for block/object parsing and right-associative `if` to make generation deterministic.

## Testing Tips

- Regenerate the grammar by entering `tree-sitter-ghostlang/` and running:

  ```bash
  npm install
  npx tree-sitter generate
  npx tree-sitter test
  ```

- Grove’s unit tests cover `grove.Languages.ghostlang.get()`; add integration tests by parsing sample `.ghost` fixtures and loading highlight queries through `grove.HighlightEngine`.

For deeper context (plugin examples, theming guidance, etc.) see `tree-sitter-ghostlang/GROVE_INTEGRATION.md` in this repository.
