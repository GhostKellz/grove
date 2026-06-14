-- Neovim parser configuration for Ghostlang
-- This file can be sourced directly or used as a reference

local M = {}

--- Register the Ghostlang parser with nvim-treesitter
function M.setup()
  local ok, parsers = pcall(require, "nvim-treesitter.parsers")
  if not ok then
    vim.notify("nvim-treesitter not found", vim.log.levels.WARN)
    return false
  end

  local parser_config = parsers.get_parser_configs()

  parser_config.ghostlang = {
    install_info = {
      url = "https://github.com/ghostkellz/tree-sitter-ghostlang",
      files = { "src/parser.c" },
      branch = "main",
      generate_requires_npm = false,
      requires_generate_from_grammar = false,
    },
    filetype = "ghostlang",
    maintainers = { "@ghostkellz" },
  }

  -- Register file types
  vim.filetype.add({
    extension = {
      gla = "ghostlang",
    },
    pattern = {
      [".*%.gla%..*"] = "ghostlang",
    },
  })

  return true
end

--- Setup Ghostlang-specific buffer options
--- Call this from ftplugin/ghostlang.lua or an autocmd
function M.setup_buffer()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Tree-sitter based folding
  vim.opt_local.foldmethod = "expr"
  vim.opt_local.foldexpr = "nvim_treesitter#foldexpr()"
  vim.opt_local.foldlevel = 99
  vim.opt_local.foldenable = false

  -- Indentation
  vim.opt_local.tabstop = 2
  vim.opt_local.shiftwidth = 2
  vim.opt_local.expandtab = true
  vim.opt_local.autoindent = true
  vim.opt_local.smartindent = true

  -- Comments (for gcc/gc in normal mode)
  vim.opt_local.commentstring = "// %s"

  -- Highlight matching brackets
  vim.opt_local.showmatch = true
end

--- Get highlight capture under cursor (debugging helper)
function M.show_captures()
  local captures = vim.treesitter.get_captures_at_cursor(0)
  if #captures == 0 then
    print("No captures under cursor")
    return
  end
  for _, capture in ipairs(captures) do
    print("@" .. capture)
  end
end

--- Commands for Ghostlang development
function M.setup_commands()
  vim.api.nvim_create_user_command("GhostShowCaptures", M.show_captures, {
    desc = "Show tree-sitter captures under cursor",
  })

  vim.api.nvim_create_user_command("GhostFoldToggle", function()
    vim.opt_local.foldenable = not vim.opt_local.foldenable:get()
  end, {
    desc = "Toggle code folding",
  })
end

return M
