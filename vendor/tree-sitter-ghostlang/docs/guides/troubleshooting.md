# Troubleshooting

## `tree-sitter` Command Not Found

Install dependencies and use the local CLI:

```bash
npm install
npx tree-sitter --version
```

Repository scripts already use the local CLI through npm:

```bash
npm test
npm run build
```

## Parser Output Does Not Match a Corpus Test

Regenerate the expected tree from a focused sample:

```bash
npx tree-sitter parse path/to/sample.gla
```

Then update the corpus expectation only if the new tree is intentional. If the difference is caused by a grammar regression, fix `grammar.js` instead.

## Generated Files Are Stale

Regenerate Tree-sitter artifacts:

```bash
npx tree-sitter generate
```

Commit `src/parser.c`, `src/grammar.json`, and `src/node-types.json` with the grammar change.

## Highlighting Is Missing in an Editor

Check these in order:

- The file extension is `.gla`
- The editor has registered the language as `ghostlang`
- `queries/highlights.scm` is installed in the editor runtime query path
- The parser was rebuilt after the latest grammar change

See the editor-specific guides under [../editors/](../editors/).

## Grove or GhostLS Cannot Load the Grammar

Confirm downstream tooling points at the generated parser and the current query files. Grove-based integrations should validate the language handle, parse a representative `.gla` sample, and load the query bundle described in [../integration/grove.md](../integration/grove.md).
