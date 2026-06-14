# Getting Started

This guide covers the local workflow for building and validating the Ghostlang Tree-sitter grammar.

## Prerequisites

- Node.js and npm
- A C/C++ compiler for native bindings
- The Tree-sitter CLI from this repository's dev dependencies

Install dependencies:

```bash
npm install
```

## Build

Generate the parser and build the Node binding:

```bash
npm run build
```

For grammar-only work, generate parser artifacts directly:

```bash
npx tree-sitter generate
```

Generated files include:

- `src/parser.c`
- `src/grammar.json`
- `src/node-types.json`

## Test

Run the corpus suite:

```bash
npm test
```

Parse the included Ghostlang sample:

```bash
npm run parse -- test_v0.1.gla
```

Parse another file:

```bash
npx tree-sitter parse path/to/file.gla
```

## File Type

Ghostlang source files use the `.gla` extension. The grammar accepts both Lua-style and C-style syntax forms where Ghostlang supports them.

## Next Steps

- Read [development.md](development.md) before changing `grammar.js`
- Read [../api/parser.md](../api/parser.md) for generated artifact details
- Read [../api/queries.md](../api/queries.md) before changing `queries/*.scm`
