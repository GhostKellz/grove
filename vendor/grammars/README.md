# Vendored Tree-sitter Grammars

We ship pre-generated Tree-sitter grammars to keep Grove builds deterministic and CI-friendly. All grammars are compiled against **tree-sitter 0.25.10** (ABI version 15).

## Grammar Versions

| Language | Source Repository | Version / Commit | Generated |
| --- | --- | --- | --- |
| JSON | [tree-sitter/tree-sitter-json](https://github.com/tree-sitter/tree-sitter-json) | master | 2025-10-03 |
| Zig | [maxxnino/tree-sitter-zig](https://github.com/maxxnino/tree-sitter-zig) | master | 2025-10-03 |
| Rust | [tree-sitter/tree-sitter-rust](https://github.com/tree-sitter/tree-sitter-rust) | master | 2025-10-03 |
| Ghostlang | [ghostlang/tree-sitter-ghostlang](https://github.com/ghostlang/tree-sitter-ghostlang) | archive/2025-10-03 | 2025-10-03 |
| TypeScript | [tree-sitter/tree-sitter-typescript](https://github.com/tree-sitter/tree-sitter-typescript) | master | 2025-10-03 |
| TSX | [tree-sitter/tree-sitter-typescript](https://github.com/tree-sitter/tree-sitter-typescript) | master | 2025-10-03 |
| Bash | [tree-sitter/tree-sitter-bash](https://github.com/tree-sitter/tree-sitter-bash) | master | 2025-10-03 |
| JavaScript | [tree-sitter/tree-sitter-javascript](https://github.com/tree-sitter/tree-sitter-javascript) | master | 2025-10-03 |
| Python | [tree-sitter/tree-sitter-python](https://github.com/tree-sitter/tree-sitter-python) | master | 2025-10-03 |
| Markdown | [tree-sitter-grammars/tree-sitter-markdown](https://github.com/tree-sitter-grammars/tree-sitter-markdown) | master | 2025-10-03 |
| CMake | [uyha/tree-sitter-cmake](https://github.com/uyha/tree-sitter-cmake) | master | 2025-10-03 |
| TOML | [tree-sitter-grammars/tree-sitter-toml](https://github.com/tree-sitter-grammars/tree-sitter-toml) | master | 2025-10-03 |
| YAML | [tree-sitter-grammars/tree-sitter-yaml](https://github.com/tree-sitter-grammars/tree-sitter-yaml) | master | 2025-10-03 |
| C | [tree-sitter/tree-sitter-c](https://github.com/tree-sitter/tree-sitter-c) | master | 2025-10-03 |

## Tree-sitter Version

**Current:** tree-sitter 0.25.10 (ABI version 15)
**Upgraded:** 2025-10-03

## Update Process

1. Fetch the latest generated sources using the Tree-sitter CLI or by downloading from the upstream repository.
2. Replace the corresponding files under `vendor/grammars/<language>/`.
3. Run `zig build test` to ensure Grove still parses and traverses documents successfully.
4. Update the table above with the new version/commit hash and briefly summarize any upstream changes worth noting.

## Folder Layout

```
vendor/grammars/
  json/
    parser.c
  zig/
    parser.c
  README.md
```

Future grammars should follow the same pattern. Include any additional auxiliary sources (e.g., `scanner.cc`) next to `parser.c`.
