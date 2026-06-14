# Helix Editor Integration for Ghostlang

This guide covers setting up Ghostlang support in the Helix editor.

## Prerequisites

- Helix editor (v23.10 or later recommended)
- A C compiler (gcc, clang, or zig cc)

## Setup

### 1. Add Language Configuration

Edit `~/.config/helix/languages.toml`:

```toml
[[language]]
name = "ghostlang"
scope = "source.ghostlang"
file-types = ["gla"]
comment-token = "//"
indent = { tab-width = 2, unit = "  " }
roots = []

[language.auto-pairs]
'(' = ')'
'{' = '}'
'[' = ']'
'"' = '"'
"'" = "'"

[[grammar]]
name = "ghostlang"
source = { git = "https://github.com/ghostkellz/tree-sitter-ghostlang", rev = "main" }
```

### 2. Fetch and Build the Grammar

```bash
hx --grammar fetch
hx --grammar build
```

### 3. Copy Query Files

Create the queries directory and copy files:

```bash
# Create runtime queries directory
mkdir -p ~/.config/helix/runtime/queries/ghostlang

# Clone the repository (if not already)
git clone https://github.com/ghostkellz/tree-sitter-ghostlang /tmp/tree-sitter-ghostlang

# Copy query files
cp /tmp/tree-sitter-ghostlang/queries/highlights.scm ~/.config/helix/runtime/queries/ghostlang/
cp /tmp/tree-sitter-ghostlang/queries/indents.scm ~/.config/helix/runtime/queries/ghostlang/
cp /tmp/tree-sitter-ghostlang/queries/textobjects.scm ~/.config/helix/runtime/queries/ghostlang/
cp /tmp/tree-sitter-ghostlang/queries/locals.scm ~/.config/helix/runtime/queries/ghostlang/
```

Or symlink directly:

```bash
ln -s /path/to/tree-sitter-ghostlang/queries ~/.config/helix/runtime/queries/ghostlang
```

### 4. Verify Installation

Open a `.gla` file in Helix:

```bash
hx test.gla
```

You should see syntax highlighting. Check with `:lang` to verify the language is detected.

## Configuration Options

### Complete languages.toml

```toml
[[language]]
name = "ghostlang"
scope = "source.ghostlang"
file-types = ["gla"]
comment-token = "//"
block-comment-tokens = { start = "/*", end = "*/" }
indent = { tab-width = 2, unit = "  " }
roots = []

# Optional: configure language server when available
# language-servers = ["ghostls"]

[language.auto-pairs]
'(' = ')'
'{' = '}'
'[' = ']'
'"' = '"'
"'" = "'"
'/*' = '*/'

[language.debugger]
# Future: configure debugger when available

[[grammar]]
name = "ghostlang"
source = { git = "https://github.com/ghostkellz/tree-sitter-ghostlang", rev = "main" }
```

### Alternative Comment Styles

For Lua-style comments:

```toml
[[language]]
name = "ghostlang-lua"
scope = "source.ghostlang"
file-types = []  # Use ghostlang for .gla files
comment-token = "--"
# ... rest of config
```

## Text Objects

With the textobjects.scm file, you can use Helix's text object motions:

| Motion | Description |
|--------|-------------|
| `mif` | Select inner function |
| `maf` | Select around function |
| `mic` | Select inner conditional |
| `mac` | Select around conditional |
| `mil` | Select inner loop |
| `mal` | Select around loop |
| `mia` | Select inner argument/parameter |
| `maa` | Select around argument/parameter |

## Troubleshooting

### Grammar Not Building

If grammar build fails:

```bash
# Check for C compiler
cc --version

# Manual build
cd ~/.config/helix/runtime/grammars/sources/ghostlang
tree-sitter generate
cc -shared -fPIC -o ../ghostlang.so src/parser.c -I src
```

### No Syntax Highlighting

1. Check grammar is built: `ls ~/.config/helix/runtime/grammars/ghostlang.so`
2. Check queries exist: `ls ~/.config/helix/runtime/queries/ghostlang/`
3. Reload Helix completely (`:q!` and reopen)

### Wrong Language Detected

Force language with `:set-language ghostlang` or add shebang:

```ghostlang
#!/usr/bin/env ghostlang
// Your code here
```

## LSP Integration (Coming Soon)

When the Ghostlang Language Server (ghostls) is available:

```toml
[language-server.ghostls]
command = "ghostls"
args = ["--stdio"]

[[language]]
name = "ghostlang"
language-servers = ["ghostls"]
# ... rest of config
```

## Resources

- [Helix Documentation](https://docs.helix-editor.com/)
- [tree-sitter-ghostlang](https://github.com/ghostkellz/tree-sitter-ghostlang)
- [Ghostlang](https://github.com/ghostlang/ghostlang)
