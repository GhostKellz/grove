# Parser Reference

`tree-sitter-ghostlang` provides the Tree-sitter grammar and generated parser for Ghostlang `.gla` files.

## Package Entry Points

- npm package: `tree-sitter-ghostlang`
- Node binding entry: `bindings/node`
- Rust crate library: `bindings/rust/lib.rs`
- Tree-sitter metadata: `tree-sitter.json`

## Generated Artifacts

| File | Purpose |
|------|---------|
| `src/parser.c` | C parser generated from `grammar.js` |
| `src/grammar.json` | Generated grammar metadata |
| `src/node-types.json` | Generated node and field metadata |

Regenerate artifacts with:

```bash
npx tree-sitter generate
```

## Language Scope

- Language name: `ghostlang`
- Scope: `source.ghostlang`
- File type: `.gla`

## Syntax Coverage

The grammar targets Ghostlang v0.1.0 and supports both Lua-style and C-style forms where available.

Core syntax includes:

- Variable declarations with `local` and `var`
- Function declarations and local functions
- `if`, `elseif`, `else`, `while`, `for`, and `repeat` control flow
- `return`, `break`, and `continue`
- Binary and unary expressions
- Function calls and member access
- Table and array constructors
- Lua-style and C-style comments

## Common Node Families

- `source_file` - Root node
- `function_declaration` and `local_function_declaration`
- `variable_declaration` and `local_variable_declaration`
- `if_statement`, `while_statement`, `for_statement`, and `repeat_statement`
- `block_statement` and `lua_block`
- `binary_expression` and `unary_expression`
- `call_expression` and `member_expression`
- `table_constructor` and `array_constructor`

Use `src/node-types.json` as the authoritative node and field reference for integrations.

## Validation

Run the corpus suite:

```bash
npm test
```

Parse a single file:

```bash
npm run parse -- test_v0.1.gla
```
