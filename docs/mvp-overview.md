# Grove MVP Overview

Grove's MVP (v0.1.0) delivers a safe Zig wrapper around the Tree-sitter C runtime so downstream consumers (Grim, Ghostlang, third-party tools) can start embedding Grove today.

## ✅ What Shipped
- **Tree-sitter integration** through the Zig build system. The vendored C sources at `archive/tree-sitter` plus bundled grammars under `vendor/grammars` are compiled automatically; consumers only need `@import("grove")`.
- **Bundled JSON grammar** for instant smoke tests. `grove.Languages.json.get()` returns a ready-to-use `Language`, so downstreams can parse JSON without extra tooling. (Zig grammar lands next.)
- **Core safe wrappers**:
  - `Parser` with RAII `init/deinit`, language management, `parseUtf8`, and reset helpers.
  - `Tree` wrapper with deterministic destruction, copying, and root accessors.
  - `Node` and `Point` helpers exposing common Tree-sitter APIs (kind, byte/point ranges, traversal utilities, S-expression export).
  - `Language` wrapper enforcing non-null `TSLanguage` pointers plus `Languages` enum for vendored registry access.
- **Allocator-aware API design**: `Parser.init` accepts an allocator and passes it through to future features. `Node.toSExpression` allocates using the caller-provided allocator.
- **Tests** validating parser lifecycle, language preconditions, and module wiring (`zig build test`).
- **CLI update** demonstrating parser setup in `src/main.zig`.

## 🧪 Usage Snapshot
```zig
const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

  var parser = try grove.Parser.init(gpa.allocator());
    defer parser.deinit();

  const language = try grove.Languages.json.get();
  try parser.setLanguage(language);

  var tree = try parser.parseUtf8(null, "{\"hello\": true}");
  defer tree.deinit();

  const root = tree.rootNode() orelse return error.EmptyTree;
  std.debug.print("root kind = {s}\n", .{root.kind()});
}
```

> ℹ️ Grove now bundles JSON, Zig, Rust, and Ghostlang grammars. Additional grammars (including TypeScript and Markdown) will join the registry as we validate them.

## 🧭 What’s Next
- Rope adapters, incremental parsing, and highlight prototype (Alpha milestone).
- Vendored Zig grammar and registry expansion.
- Async scheduling via Zsync and integration with Grim + Ghostlang.

Consult `ROADMAP.md` for milestone-level planning and `CODEX.md` for project operations.
