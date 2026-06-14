# Neovim Integration for Ghostlang

This guide covers setting up syntax highlighting, code folding, indentation, and text objects for Ghostlang in Neovim using nvim-treesitter.

## Prerequisites

- Neovim 0.9+ (for tree-sitter support)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- A C compiler (gcc, clang, or zig cc)

## Quick Setup

### 1. Register the Parser

Add this to your Neovim configuration (lua):

```lua
local parser_config = require("nvim-treesitter.parsers").get_parser_configs()

parser_config.ghostlang = {
  install_info = {
    url = "https://github.com/ghostkellz/tree-sitter-ghostlang",
    files = { "src/parser.c" },
    branch = "main",
    generate_requires_npm = false,
    requires_generate_from_grammar = false,
  },
  filetype = "ghostlang",
}
```

### 2. Set Up File Type Detection

Create `~/.config/nvim/ftdetect/ghostlang.lua`:

```lua
vim.filetype.add({
  extension = {
    gla = "ghostlang",
  },
})
```

### 3. Install the Parser

In Neovim, run:
```
:TSInstall ghostlang
```

Or with lazy.nvim:
```lua
{
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = { "ghostlang" },
  },
}
```

### 4. Copy Query Files

Copy the query files from this repository to your Neovim runtime:

```bash
# Create the queries directory
mkdir -p ~/.config/nvim/queries/ghostlang

# Copy query files
cp queries/highlights.scm ~/.config/nvim/queries/ghostlang/
cp queries/folds.scm ~/.config/nvim/queries/ghostlang/
cp queries/indents.scm ~/.config/nvim/queries/ghostlang/
cp queries/locals.scm ~/.config/nvim/queries/ghostlang/
cp queries/textobjects.scm ~/.config/nvim/queries/ghostlang/
```

Or create a symlink:
```bash
ln -s /path/to/tree-sitter-ghostlang/queries ~/.config/nvim/queries/ghostlang
```

## Configuration

### Enable Features

```lua
require("nvim-treesitter.configs").setup({
  highlight = {
    enable = true,
  },
  indent = {
    enable = true,
  },
  fold = {
    enable = true,
  },
})
```

### Code Folding

To enable tree-sitter based folding for Ghostlang files:

```lua
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldenable = false  -- Don't fold by default
vim.opt.foldlevel = 99      -- Start with all folds open
```

Or in a Ghostlang-specific ftplugin (`~/.config/nvim/ftplugin/ghostlang.lua`):

```lua
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt_local.foldlevel = 99
```

### Text Objects (nvim-treesitter-textobjects)

If you use [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects):

```lua
require("nvim-treesitter.configs").setup({
  textobjects = {
    select = {
      enable = true,
      lookahead = true,
      keymaps = {
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@conditional.outer",
        ["ic"] = "@conditional.inner",
        ["al"] = "@loop.outer",
        ["il"] = "@loop.inner",
        ["aa"] = "@parameter.outer",
        ["ia"] = "@parameter.inner",
      },
    },
    move = {
      enable = true,
      set_jumps = true,
      goto_next_start = {
        ["]f"] = "@function.outer",
        ["]c"] = "@conditional.outer",
        ["]l"] = "@loop.outer",
      },
      goto_previous_start = {
        ["[f"] = "@function.outer",
        ["[c"] = "@conditional.outer",
        ["[l"] = "@loop.outer",
      },
    },
  },
})
```

## Complete Example Configuration

Here's a complete lazy.nvim configuration:

```lua
return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local parser_config = require("nvim-treesitter.parsers").get_parser_configs()

      parser_config.ghostlang = {
        install_info = {
          url = "https://github.com/ghostkellz/tree-sitter-ghostlang",
          files = { "src/parser.c" },
          branch = "main",
        },
        filetype = "ghostlang",
      }

      require("nvim-treesitter.configs").setup({
        ensure_installed = { "ghostlang" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-treesitter.configs").setup({
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@conditional.outer",
              ["ic"] = "@conditional.inner",
            },
          },
        },
      })
    end,
  },
}
```

## Highlight Groups

Ghostlang uses standard nvim-treesitter highlight captures that map to your colorscheme:

| Capture | Description | Example Colorscheme Group |
|---------|-------------|---------------------------|
| `@keyword` | Keywords (var, function, if, etc.) | `Keyword` |
| `@keyword.operator` | Logical operators (and, or, not) | `Keyword` |
| `@operator` | Operators (+, -, ==, etc.) | `Operator` |
| `@function` | Function definitions | `Function` |
| `@function.call` | Function calls | `Function` |
| `@function.builtin` | Built-in functions | `Special` |
| `@variable` | Variables | `Identifier` |
| `@parameter` | Function parameters | `Identifier` |
| `@property` | Object properties | `Identifier` |
| `@number` | Number literals | `Number` |
| `@string` | String literals | `String` |
| `@string.escape` | Escape sequences | `SpecialChar` |
| `@boolean` | Boolean literals | `Boolean` |
| `@constant.builtin` | null literal | `Constant` |
| `@comment` | Comments | `Comment` |
| `@punctuation.bracket` | Brackets | `Delimiter` |
| `@punctuation.delimiter` | Delimiters | `Delimiter` |

## Troubleshooting

### Parser Not Found

If you get "parser not found" errors:

1. Check that the parser is installed: `:TSInstallInfo`
2. Try reinstalling: `:TSInstall! ghostlang`
3. Verify compiler availability: `:checkhealth nvim-treesitter`

### No Highlighting

If highlighting doesn't work:

1. Verify highlights.scm exists in queries directory
2. Check `:TSHighlightCapturesUnderCursor` to see what captures are active
3. Run `:TSBufToggle highlight` to toggle highlighting

### Wrong Indentation

If indentation behaves incorrectly:

1. Check that `indent = { enable = true }` is set
2. Verify indents.scm exists in queries directory
3. Try `:TSBufToggle indent` to toggle tree-sitter indentation

### Folding Not Working

1. Ensure foldmethod is set to "expr"
2. Check foldexpr is using nvim_treesitter#foldexpr()
3. Verify folds.scm exists in queries directory

## Local Development

To test changes to the grammar locally:

```bash
# Clone the repository
git clone https://github.com/ghostkellz/tree-sitter-ghostlang
cd tree-sitter-ghostlang

# Generate the parser
npm install
npm run build

# Test with tree-sitter CLI
tree-sitter parse test_v0.1.gla
tree-sitter test

# Point Neovim to local version
parser_config.ghostlang = {
  install_info = {
    url = "/path/to/tree-sitter-ghostlang",
    files = { "src/parser.c" },
  },
  filetype = "ghostlang",
}
```

Then reinstall: `:TSInstall! ghostlang`

## LSP Integration

For full IDE features, Ghostlang works with the Grove parsing library. Stay tuned for the Ghostlang Language Server (gls) which provides:

- Diagnostics
- Go to definition
- Find references
- Hover documentation
- Code completion

## Support

- Report issues: https://github.com/ghostkellz/tree-sitter-ghostlang/issues
- Ghostlang documentation: https://github.com/ghostlang/ghostlang
- Grove parsing library: https://github.com/ghostlang/grove
