# Development Guide

Use this workflow when changing Ghostlang grammar behavior, query captures, or package metadata.

## Repository Layout

- `grammar.js` - Source grammar used by Tree-sitter
- `src/parser.c` - Generated parser
- `src/grammar.json` - Generated grammar metadata
- `src/node-types.json` - Generated node type metadata
- `queries/*.scm` - Editor queries for highlighting, locals, folding, indentation, injections, and textobjects
- `test/corpus/*.txt` - Tree-sitter corpus tests
- `bindings/node/` - Node binding entry points
- `bindings/rust/` - Rust crate entry points
- `vscode-ghostlang/` - TextMate-based VSCode extension
- `nvim/` - Neovim filetype and plugin helpers

## Grammar Changes

1. Update `grammar.js`.
2. Add or update focused corpus cases in `test/corpus/`.
3. Regenerate parser artifacts:

```bash
npx tree-sitter generate
```

4. Run tests:

```bash
npm test
```

5. Review generated node changes in `src/node-types.json`. If node names or structure changed, update query files and editor documentation.

## Corpus Tests

Corpus tests live in `test/corpus/*.txt`. Each test contains a name, source sample, and expected syntax tree:

```text
==================
Function declaration
==================

function add(a, b)
  return a + b
end

---

(source_file
  (function_declaration
    name: (identifier)
    parameters: (parameter_list
      (identifier)
      (identifier))
    body: (lua_block
      (return_statement
        (binary_expression
          left: (identifier)
          right: (identifier))))))
```

Keep tests small and targeted. Prefer adding a new case when a syntax edge case could regress independently.

## Query Changes

Update queries when grammar nodes, field names, or capture behavior changes:

- `queries/highlights.scm` for syntax highlighting captures
- `queries/locals.scm` for definitions, scopes, and references
- `queries/folds.scm` for folding ranges
- `queries/indents.scm` for indentation behavior
- `queries/textobjects.scm` for editor selections and movement
- `queries/injections.scm` for embedded languages

Run parser tests after query changes. Then smoke-test at least one editor or downstream integration when capture names change.

## Release Checklist

- `npm test` passes
- `npm run build` succeeds
- Generated artifacts are committed with `grammar.js`
- Query files match the current node names
- `docs/README.md` links remain valid
- `package.json`, `Cargo.toml`, and `tree-sitter.json` metadata reflect the release
