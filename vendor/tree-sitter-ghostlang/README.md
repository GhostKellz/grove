# tree-sitter-ghostlang

<p align="center">
  <img src="https://img.shields.io/badge/Tree--sitter-6EBF8B?style=for-the-badge&logo=treesitter&logoColor=white" alt="Tree-sitter">
  <img src="https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black" alt="JavaScript">
  <img src="https://img.shields.io/badge/npm-CB3837?style=for-the-badge&logo=npm&logoColor=white" alt="npm">
  <img src="https://img.shields.io/badge/Ghostlang-7FFFD4?style=for-the-badge&logoColor=black" alt="Ghostlang">
</p>

Tree-sitter grammar for [Ghostlang](https://github.com/ghostkellz/ghostlang) v0.1.0 - A dual Lua/C-style scripting language.

## Features

- **Complete Ghostlang v0.1.0 syntax support**
- **Dual syntax modes**: Lua-style and C-style
- **Syntax highlighting** via comprehensive `.scm` query files
- **Code navigation** with textobjects and locals tracking
- **Full test coverage** with corpus tests
- **Used by**: [Grove](https://github.com/ghostkellz/grove), [GhostLS](https://github.com/ghostkellz/ghostls), [Grim IDE](https://github.com/ghostkellz/grim)

## Installation

### npm

```bash
npm install tree-sitter-ghostlang
```

### From source

```bash
git clone https://github.com/ghostkellz/tree-sitter-ghostlang
cd tree-sitter-ghostlang
npm install
npm run build
```

## Usage

### With tree-sitter CLI

```bash
# Parse a file
tree-sitter parse example.gla

# Run tests
tree-sitter test

# Generate highlighting
tree-sitter highlight example.gla
```

### With Neovim (nvim-treesitter)

Add to your nvim-treesitter configuration:

```lua
local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
parser_config.ghostlang = {
  install_info = {
    url = "https://github.com/ghostkellz/tree-sitter-ghostlang",
    files = {"src/parser.c"},
    branch = "main",
  },
  filetype = "ghostlang",
}

-- File type detection
vim.filetype.add({
  extension = {
    gla = "ghostlang",
  },
})
```

For detailed setup including folding, text objects, and ftplugin, see [docs/editors/neovim.md](docs/editors/neovim.md).

**Quick install script:**
```bash
./nvim/install.sh
```

### With Helix

See [docs/editors/helix.md](docs/editors/helix.md) for Helix editor setup.

### With Emacs

See [docs/editors/emacs.md](docs/editors/emacs.md) for Emacs tree-sitter setup.

### With VSCode

A VSCode extension is available in [vscode-ghostlang/](vscode-ghostlang/).

### With Grove (Zig tree-sitter wrapper)

```zig
const grove = @import("grove");

var parser = try grove.Parser.init(allocator);
defer parser.deinit();

const language = try grove.Languages.ghostlang.get();
try parser.setLanguage(language);

const source =
    \\function greet(name)
    \\    print("Hello, " .. name)
    \\end
;

var tree = try parser.parseUtf8(null, source);
defer tree.deinit();
```

## Language Overview

Ghostlang is a dual-syntax scripting language that supports both **Lua-style** and **C-style** syntax.

### Lua-Style Syntax Example

```lua
-- Ghostlang with Lua-style syntax (.gla files)
function factorial(n)
    if n <= 1 then
        return 1
    else
        return n * factorial(n - 1)
    end
end

local result = factorial(5)
print(result)  -- 120
```

### C-Style Syntax Example

```c
// Ghostlang with C-style syntax (.gla files)
function factorial(n) {
    if (n <= 1) {
        return 1;
    } else {
        return n * factorial(n - 1);
    }
}

var result = factorial(5);
print(result);  // 120
```

### Supported Syntax Features

#### Core Language
- **Variables**: `local`, `var`, `const` (with `mut` modifier)
- **Functions**: Named functions, anonymous functions, arrow functions
- **Control flow**: `if/else`, `while`, `for`, `repeat/until`, `switch/case`
- **Operators**: Arithmetic, comparison, logical, bitwise
- **Data types**: `nil`, `boolean`, `number`, `string`, `table`, `array`

#### Advanced Features
- **String interpolation**: `"Hello, ${name}"`
- **Table/object literals**: `{key: value}` or `{key = value}`
- **Array literals**: `[1, 2, 3]`
- **Destructuring**: `local {x, y} = point`
- **Spread operator**: `...args`
- **Optional chaining**: `obj?.prop`
- **Nullish coalescing**: `value ?? default`

#### Comments
- Line comments: `//` or `--`
- Block comments: `/* ... */` or `--[[ ... ]]`

## Query Files

Comprehensive query files for editor integration:

### `queries/highlights.scm`
Syntax highlighting for:
- Keywords (function, if, while, for, return, etc.)
- Types and built-in values
- Functions and methods
- Variables and parameters
- Literals (strings, numbers, booleans)
- Operators and punctuation (including `?.`, `??`, `?[`)
- Comments

### `queries/folds.scm`
Code folding regions:
- Function bodies
- Control flow blocks (if, while, for, repeat)
- Object and array literals
- Multi-line comments

### `queries/indents.scm`
Automatic indentation:
- Indent after `{`, `[`, `(`, `then`, `do`, `repeat`
- Dedent before `}`, `]`, `)`, `end`, `until`, `else`
- Aligned parameters and arguments

### `queries/locals.scm`
Variable scoping and definitions:
- Function scopes
- Block scopes
- Variable definitions and declarations
- Parameter bindings
- References and captures

### `queries/textobjects.scm`
Code navigation objects:
- Functions (outer/inner)
- Blocks (outer/inner)
- Parameters
- Calls
- Conditionals and loops
- Comments

### `queries/injections.scm`
Embedded language support:
- String interpolation expressions
- Template literals
- Inline code blocks

## Testing

```bash
# Run all corpus tests
npm test

# Parse example file
npm run parse test_v0.1.gla

# Generate parser (after grammar changes)
tree-sitter generate
```

## Development

### Grammar Structure

The grammar is defined in `grammar.js` and supports both Lua-style and C-style syntax variants.

Key AST nodes:
- `source_file` - Root node
- `function_declaration` - Function definitions (both styles)
- `local_variable_declaration` - Local variable declarations
- `if_statement`, `while_statement`, `for_statement` - Control flow
- `binary_expression`, `unary_expression` - Expressions
- `table_constructor`, `array_constructor` - Data structures
- `string_interpolation` - String templates

### File Extensions

- **`.gla`** - Ghostlang source files

The `.gla` extension supports both Lua-style and C-style syntax modes.

### Version Compatibility

This grammar targets **Ghostlang v0.1.0**. For version-specific changes, see:
- [docs/roadmap/project-roadmap.md](docs/roadmap/project-roadmap.md) - Parser and integration roadmap
- [Ghostlang Changelog](https://github.com/ghostkellz/ghostlang/blob/main/CHANGELOG.md)

## Integration

### With GhostLS (Language Server)

tree-sitter-ghostlang is used by [GhostLS](https://github.com/ghostkellz/ghostls) via [Grove](https://github.com/ghostkellz/grove) for:

- Real-time syntax highlighting
- Document symbols and outline
- Code navigation (go-to-definition, find references)
- Code folding
- Semantic token highlighting

```
tree-sitter-ghostlang (parser.c)
    ↓
Grove (Zig tree-sitter wrapper)
    ↓
GhostLS (LSP server)
    ↓
Editor (VSCode, Neovim, Grim)
```

See [docs/integration/grove.md](docs/integration/grove.md) for integration details.

### With Grim IDE

Grim IDE uses tree-sitter-ghostlang for syntax highlighting and code intelligence features. The grammar is automatically loaded for `.gla` files.

## Contributing

Contributions welcome! Please:

1. Add tests for new syntax features in `test/corpus/`
2. Update query files (`queries/*.scm`) if adding new node types
3. Run `npm test` to ensure all tests pass
4. Follow the existing code style in `grammar.js`
5. Update documentation for breaking changes

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full development workflow.

### Adding Tests

Add test cases to `test/corpus/*.txt`:

```
==================
Test name
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
    body: (block
      (return_statement
        (binary_expression
          left: (identifier)
          operator: "+"
          right: (identifier))))))
```

## License

MIT - See [LICENSE](LICENSE) for details.

## Links

- [Ghostlang](https://github.com/ghostkellz/ghostlang) - The language runtime
- [Grove](https://github.com/ghostkellz/grove) - Zig tree-sitter wrapper
- [GhostLS](https://github.com/ghostkellz/ghostls) - Language Server Protocol implementation
- [Grim](https://github.com/ghostkellz/grim) - Modal text editor
- [Tree-sitter](https://tree-sitter.github.io/) - Parser generator

## Credits

Developed by the Ghostlang community.

Special thanks to:
- Tree-sitter project for the excellent parser framework
- Lua and JavaScript communities for syntax inspiration
