# VSCode Integration for Ghostlang

This guide covers setting up Ghostlang syntax highlighting in Visual Studio Code.

## Option 1: Install Extension (Recommended)

The `vscode-ghostlang` extension provides:
- Syntax highlighting via TextMate grammar
- Code snippets
- File icons
- Bracket matching

### Install from VSIX

```bash
cd vscode-ghostlang
npm install
npm run package
code --install-extension ghostlang-0.1.0.vsix
```

### Features

After installation, `.gla` files will automatically:
- Have syntax highlighting
- Show proper file icons
- Support bracket matching and auto-closing
- Include common code snippets

## Option 2: Manual TextMate Grammar

If you prefer manual setup:

1. Create extension directory:
```bash
mkdir -p ~/.vscode/extensions/ghostlang
cd ~/.vscode/extensions/ghostlang
```

2. Create `package.json`:
```json
{
  "name": "ghostlang",
  "displayName": "Ghostlang",
  "version": "0.1.0",
  "engines": { "vscode": "^1.75.0" },
  "categories": ["Programming Languages"],
  "contributes": {
    "languages": [{
      "id": "ghostlang",
      "aliases": ["Ghostlang", "ghost"],
      "extensions": [".gla"],
      "configuration": "./language-configuration.json"
    }],
    "grammars": [{
      "language": "ghostlang",
      "scopeName": "source.ghostlang",
      "path": "./syntaxes/ghostlang.tmLanguage.json"
    }]
  }
}
```

3. Create `language-configuration.json`:
```json
{
  "comments": {
    "lineComment": "--",
    "blockComment": ["--[[", "]]"]
  },
  "brackets": [
    ["{", "}"],
    ["[", "]"],
    ["(", ")"]
  ],
  "autoClosingPairs": [
    { "open": "{", "close": "}" },
    { "open": "[", "close": "]" },
    { "open": "(", "close": ")" },
    { "open": "\"", "close": "\"" },
    { "open": "'", "close": "'" }
  ],
  "surroundingPairs": [
    ["{", "}"],
    ["[", "]"],
    ["(", ")"],
    ["\"", "\""],
    ["'", "'"]
  ],
  "folding": {
    "markers": {
      "start": "^\\s*(function|if|for|while|repeat)\\b",
      "end": "^\\s*end\\b"
    }
  }
}
```

4. Copy TextMate grammar:
```bash
mkdir syntaxes
cp /path/to/tree-sitter-ghostlang/vscode-ghostlang/syntaxes/ghostlang.tmLanguage.json syntaxes/
```

5. Reload VSCode

## LSP Integration

For full IDE features (completions, hover, go-to-definition), use ghostls:

1. Install ghostls:
```bash
cd /path/to/ghostls
zig build -Doptimize=ReleaseSafe
sudo cp zig-out/bin/ghostls /usr/local/bin/
```

2. Install a generic LSP client extension (if not using built-in):
   - Search for "Generic LSP Client" in extensions

3. Configure in `settings.json`:
```json
{
  "lsp.serverConfigurations": {
    "ghostls": {
      "command": "ghostls",
      "filetypes": ["ghostlang"]
    }
  }
}
```

Or with the popular "vscode-languageclient" setup in an extension:

```typescript
const serverOptions: ServerOptions = {
  command: 'ghostls',
  args: []
};

const clientOptions: LanguageClientOptions = {
  documentSelector: [{ scheme: 'file', language: 'ghostlang' }]
};

const client = new LanguageClient(
  'ghostls',
  'Ghostlang Language Server',
  serverOptions,
  clientOptions
);

client.start();
```

## Snippets

The extension includes these snippets:

| Prefix | Description |
|--------|-------------|
| `fn` | Function declaration |
| `lfn` | Local function |
| `if` | If statement |
| `ife` | If-else statement |
| `for` | Numeric for loop |
| `fori` | Iterator for loop |
| `while` | While loop |
| `repeat` | Repeat-until loop |
| `local` | Local variable |
| `ret` | Return statement |

## Troubleshooting

### No Syntax Highlighting

1. Check file extension is `.gla`
2. Verify extension is installed: `code --list-extensions | grep ghost`
3. Reload window: `Ctrl+Shift+P` -> "Reload Window"

### LSP Not Working

1. Verify ghostls is in PATH: `which ghostls`
2. Check Output panel: `View` -> `Output` -> select "ghostls"
3. Verify language ID: Status bar should show "Ghostlang"

### Extension Not Loading

1. Check Developer Tools: `Help` -> `Toggle Developer Tools`
2. Look for errors in Console tab
3. Try reinstalling: uninstall, reload, reinstall

## Resources

- [ghostls](https://github.com/ghostkellz/ghostls) - Language Server
- [tree-sitter-ghostlang](https://github.com/ghostkellz/tree-sitter-ghostlang) - Grammar
- [Ghostlang](https://github.com/ghostkellz/ghostlang) - Language
