#!/bin/bash
# Ghostlang Neovim integration installer
# Installs query files, ftplugin, and ftdetect for Ghostlang

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
NVIM_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

echo "Ghostlang Neovim Integration Installer"
echo "======================================="
echo

# Check for nvim-treesitter
if ! nvim --headless -c 'lua print(pcall(require, "nvim-treesitter"))' -c 'qa' 2>/dev/null | grep -q "true"; then
    echo "Warning: nvim-treesitter not detected. Install it first:"
    echo "  https://github.com/nvim-treesitter/nvim-treesitter"
    echo
fi

# Create directories
echo "Creating directories..."
mkdir -p "$NVIM_CONFIG/queries/ghostlang"
mkdir -p "$NVIM_CONFIG/ftplugin"
mkdir -p "$NVIM_CONFIG/ftdetect"

# Copy query files
echo "Installing query files..."
for file in highlights.scm folds.scm indents.scm locals.scm textobjects.scm; do
    if [ -f "$REPO_DIR/queries/$file" ]; then
        cp "$REPO_DIR/queries/$file" "$NVIM_CONFIG/queries/ghostlang/"
        echo "  Copied $file"
    fi
done

# Optional: Copy injections.scm if it exists
if [ -f "$REPO_DIR/queries/injections.scm" ]; then
    cp "$REPO_DIR/queries/injections.scm" "$NVIM_CONFIG/queries/ghostlang/"
    echo "  Copied injections.scm"
fi

# Copy ftplugin
echo "Installing ftplugin..."
cp "$SCRIPT_DIR/ftplugin/ghostlang.lua" "$NVIM_CONFIG/ftplugin/"
echo "  Copied ftplugin/ghostlang.lua"

# Copy ftdetect
echo "Installing ftdetect..."
cp "$SCRIPT_DIR/ftdetect/ghostlang.lua" "$NVIM_CONFIG/ftdetect/"
echo "  Copied ftdetect/ghostlang.lua"

echo
echo "Installation complete!"
echo
echo "Next steps:"
echo "1. Add the parser configuration to your Neovim config:"
echo
cat << 'EOF'
   local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
   parser_config.ghostlang = {
     install_info = {
       url = "https://github.com/ghostkellz/tree-sitter-ghostlang",
       files = { "src/parser.c" },
       branch = "main",
     },
     filetype = "ghostlang",
   }
EOF
echo
echo "2. Install the parser in Neovim:"
echo "   :TSInstall ghostlang"
echo
echo "3. Open a .ghost or .gza file to test highlighting!"
