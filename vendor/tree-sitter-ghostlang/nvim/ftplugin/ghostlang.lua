-- Ghostlang ftplugin for Neovim
-- Copy this to ~/.config/nvim/ftplugin/ghostlang.lua

-- Indentation settings
vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.expandtab = true
vim.opt_local.autoindent = true
vim.opt_local.smartindent = true

-- Comment string for vim-commentary/Comment.nvim
vim.opt_local.commentstring = "// %s"

-- Tree-sitter based folding
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt_local.foldlevel = 99
vim.opt_local.foldenable = false

-- Highlight matching brackets
vim.opt_local.showmatch = true

-- File-specific settings
vim.opt_local.suffixesadd:append({ ".gla" })
