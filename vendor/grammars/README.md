# Vendored Tree-sitter Grammars

We ship pre-generated Tree-sitter grammars to keep Grove builds deterministic and CI-friendly.

## Grammar Versions

| Language | Source Repository | Version / Commit |
| --- | --- | --- |
| JSON | [tree-sitter/tree-sitter-json](https://github.com/tree-sitter/tree-sitter-json) | master (retrieved 2024-09-24) |
| Zig | [maxxnino/tree-sitter-zig](https://github.com/maxxnino/tree-sitter-zig) | a80a6e9 (2024-10-13) |
| Ghostlang | [ghostlang/tree-sitter-ghostlang](https://github.com/ghostlang/tree-sitter-ghostlang) | v0.1.0 (vendored 2025-09-24, local precedence fixes) |

> **Note:** We will pin specific tagged releases as we evaluate stability. JSON is temporarily tracking the `master` branch until we validate a pinned tag (target: v0.20.0 or newer).

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
