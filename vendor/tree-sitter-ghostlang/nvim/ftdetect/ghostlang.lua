-- Ghostlang file type detection for Neovim
-- Copy this to ~/.config/nvim/ftdetect/ghostlang.lua

vim.filetype.add({
  extension = {
    gla = "ghostlang",
  },
  pattern = {
    -- Match files like script.gla.bak
    [".*%.gla%..*"] = "ghostlang",
  },
})
