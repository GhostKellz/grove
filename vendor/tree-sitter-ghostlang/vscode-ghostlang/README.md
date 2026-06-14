# Ghostlang for Visual Studio Code

Ghostlang language support for Visual Studio Code with syntax highlighting, code snippets, and bracket matching.

## Features

- **Syntax Highlighting**: Full support for Ghostlang's dual syntax (C-style and Lua-style)
- **Code Snippets**: Quick insertion of common patterns
- **Bracket Matching**: Auto-pairing and matching of brackets
- **Comment Toggling**: Toggle comments with `Ctrl+/`
- **Code Folding**: Collapse functions, loops, and blocks

## Supported File Extensions

- `.gla` - Ghostlang source files

## Syntax Examples

Ghostlang supports both C-style and Lua-style syntax:

```ghostlang
// C-style function
function greet(name) {
    return "Hello, " + name;
}

-- Lua-style function
local function sayGoodbye(name)
    return "Goodbye, " .. name
end

// Modern features
var value = user?.profile?.name ?? "Anonymous";
var items = filter(data, function(x) { return x > 0; });
```

## Snippets

| Prefix | Description |
|--------|-------------|
| `func` | Function declaration (C-style) |
| `funcl` | Function declaration (Lua-style) |
| `var` | Variable declaration |
| `local` | Local variable declaration |
| `if` | If statement (C-style) |
| `ifl` | If statement (Lua-style) |
| `for` | For loop (C-style) |
| `forl` | For loop (Lua-style numeric) |
| `forpairs` | For loop with pairs |
| `while` | While loop |
| `repeat` | Repeat-until loop |
| `log` | Log statement |
| `notify` | Notification |

## Installation

### From VSIX

1. Download the `.vsix` file from releases
2. In VSCode: `Ctrl+Shift+P` → "Install from VSIX"
3. Select the downloaded file

### From Source

```bash
cd vscode-ghostlang
npm install -g vsce
vsce package
code --install-extension ghostlang-0.1.0.vsix
```

## Tree-Sitter Integration

For advanced features like incremental parsing and better performance, this extension works with the tree-sitter-ghostlang grammar. See the [tree-sitter-ghostlang](https://github.com/ghostkellz/tree-sitter-ghostlang) repository for details.

## Related Projects

- [Ghostlang](https://github.com/ghostlang/ghostlang) - The Ghostlang scripting language
- [Grove](https://github.com/ghostlang/grove) - Tree-sitter wrapper for Zig
- [Grim](https://github.com/ghostlang/grim) - Text editor with Ghostlang plugin support

## License

MIT License - see LICENSE file for details.
