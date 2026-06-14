# Project Roadmap

This roadmap tracks documentation, grammar, query, and integration priorities for `tree-sitter-ghostlang`.

## Current Focus

- Keep the grammar aligned with Ghostlang v0.1.0 syntax
- Maintain generated parser artifacts in sync with `grammar.js`
- Keep editor query files usable across Neovim, Helix, Emacs, VSCode, Grove, GhostLS, and Grim
- Document integration workflows in lowercase, discoverable `docs/` paths

## Parser Priorities

- Expand corpus coverage for mixed Lua-style and C-style syntax
- Add focused tests for optional chaining, nullish coalescing, spread syntax, table literals, and interpolation
- Verify ambiguous expression precedence with representative real-world samples

## Query Priorities

- Keep highlight captures stable for editor themes
- Validate locals captures for parameters, local declarations, and block scopes
- Exercise fold and indent behavior in both syntax styles
- Keep textobjects conservative and predictable for editor movement

## Integration Priorities

- Keep Grove integration notes current
- Maintain editor setup docs under `docs/editors/`
- Align package metadata across npm, Rust, and `tree-sitter.json`

## Release Readiness

A release should include:

- Passing `npm test`
- Successful `npm run build`
- Updated generated artifacts
- Updated documentation for syntax or query changes
- Reviewed package metadata
