# Contributing to tree-sitter-ghostlang

Thanks for helping improve the Ghostlang Tree-sitter grammar. This project is small, so contributions should stay focused and include tests for grammar behavior changes.

## Development Setup

Install dependencies:

```bash
npm install
```

Build the generated parser and Node binding:

```bash
npm run build
```

Run corpus tests:

```bash
npm test
```

Parse a sample file:

```bash
npm run parse -- test_v0.1.gla
```

## What to Change

- Edit grammar behavior in `grammar.js`
- Add parser tests under `test/corpus/`
- Regenerate parser artifacts with `npx tree-sitter generate`
- Update `queries/*.scm` when node names, fields, or captures change
- Update docs under `docs/` when setup, behavior, or integrations change

Generated files in `src/` should be committed with grammar changes.

## Corpus Tests

Add the smallest test that proves the syntax behavior. Prefer a new focused case when a feature can regress independently.

Run:

```bash
npm test
```

If a tree changes intentionally, update the expected corpus output. If the change is accidental, fix `grammar.js` instead.

## Query Updates

When changing query files, confirm referenced nodes exist in `src/node-types.json`. Query changes can affect multiple editors, Grove, GhostLS, and Grim, so keep captures stable unless there is a clear reason to change them.

## Documentation

Documentation lives under `docs/` with `docs/README.md` as the index. Use lowercase, descriptive Markdown filenames and group related material in folders.

Examples:

- `docs/guides/getting-started.md`
- `docs/api/queries.md`
- `docs/editors/neovim.md`
- `docs/integration/grove.md`

## Pull Request Checklist

- `npm test` passes
- `npm run build` succeeds when generated artifacts changed
- Corpus tests cover grammar behavior changes
- Query files are updated for new or renamed nodes
- Documentation links are valid
- Changes are scoped to the issue being fixed

## Code Style

Follow the existing style in `grammar.js` and query files. Keep grammar rules readable, prefer descriptive node names, and avoid broad rewrites unless they are needed for the feature or fix.
