# Grove Integration with the Grim Ecosystem

**Version:** Phase Theta (Complete)
**Last Updated:** 2025-10-06
**Status:** ✅ Production Ready

---

## Overview

This document explains how **Grove** (Tree-sitter wrapper) integrates with the **Grim ecosystem** components:

- **Grim** – Text editor (like Neovim, but in Zig)
- **Ghostls** – Language Server for Ghostlang (`.gza`, `.ghost` files)
- **Phantom.grim** – Configuration framework (like LazyVim, but for Grim)
- **Ghostlang** – Scripting language for Grim plugins and configuration

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Grim Editor                             │
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │   TUI Renderer  │  │ LSP Client   │  │  Plugin Manager   │  │
│  │   (Phantom)     │  │ (JSON-RPC)   │  │  (Ghostlang Host) │  │
│  └────────┬────────┘  └──────┬───────┘  └─────────┬─────────┘  │
└───────────┼────────────────────┼───────────────────┼────────────┘
            │                    │                   │
            ▼                    ▼                   ▼
  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────────┐
  │  Grove Parser   │  │ Ghostls Server  │  │ Ghostlang Runtime  │
  │  ├─ Syntax HL   │  │ ├─ grove.lsp    │  │ ├─ .gza execution  │
  │  ├─ Folding     │  │ ├─ Diagnostics  │  │ ├─ Plugin API      │
  │  ├─ Symbols     │  │ ├─ Completions  │  │ └─ Theme loading   │
  │  └─ Queries     │  │ └─ Hover/Goto   │  │                    │
  └─────────────────┘  └─────────────────┘  └────────────────────┘
            │                    │                   │
            └────────────────────┴───────────────────┘
                         Tree-sitter Runtime
                      (14 bundled grammars)
```

---

## Component Integration Details

### 1. **Grove** ↔ **Grim** Integration

**What Grim Needs from Grove:**

| Feature | Grove API | Grim Usage |
|---------|-----------|------------|
| **Syntax Highlighting** | `grove.getHighlights()` | Render colored tokens in TUI |
| **Code Folding** | `grove.getFoldingRanges()` | Collapse functions/blocks |
| **Document Symbols** | `grove.getDocumentSymbols()` | Show file outline/breadcrumbs |
| **Theme Loading** | `grove.QueryRegistry` | Dynamic theme switching |
| **Multi-Language** | `grove.Languages.*` | Support 14 languages out-of-the-box |

#### Example: Grim Syntax Highlighting

```zig
// grim/src/syntax/highlight.zig
const grove = @import("grove");

pub fn highlightBuffer(buffer: *Buffer, theme: ThemePreset) !void {
    // 1. Detect language from file extension
    const language_name = detectLanguage(buffer.file_path);
    const language = try grove.Languages.get(language_name);

    // 2. Parse buffer content
    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();
    try parser.setLanguage(language);

    var tree = try parser.parseUtf8(null, buffer.content);
    defer tree.deinit();

    // 3. Load highlight queries from registry
    var registry = grove.QueryRegistry.init(allocator);
    defer registry.deinit();
    try registry.loadBundled();

    const preset = registry.get(language_name) orelse return error.NoPreset;
    var query = try grove.Query.init(language, preset.highlight_query);
    defer query.deinit();

    // 4. Get highlights with theme rules
    const highlights = try grove.getHighlights(
        allocator,
        &query,
        tree.rootNode().?,
        theme.toHighlightRules(),
    );
    defer allocator.free(highlights);

    // 5. Render to TUI
    for (highlights) |hl| {
        buffer.setSpanColor(hl.start_byte, hl.end_byte, hl.color);
    }
}
```

#### Example: Grim Code Folding

```zig
// grim/src/syntax/folding.zig
const grove = @import("grove");

pub fn computeFolds(buffer: *Buffer) ![]FoldRegion {
    const language = try grove.Languages.get(detectLanguage(buffer.file_path));

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();
    try parser.setLanguage(language);

    var tree = try parser.parseUtf8(null, buffer.content);
    defer tree.deinit();

    // Use Grove's LSP folding helper
    const folds = try grove.lsp.LanguageServer.foldingRanges(tree, buffer.content);
    defer allocator.free(folds);

    // Convert to Grim's internal FoldRegion format
    var regions = std.ArrayList(FoldRegion).init(allocator);
    for (folds) |fold| {
        try regions.append(.{
            .start_line = fold.start_line,
            .end_line = fold.end_line,
            .folded = false,
        });
    }

    return try regions.toOwnedSlice();
}
```

---

### 2. **Grove** ↔ **Ghostls** Integration

**What Ghostls Needs from Grove:**

| LSP Feature | Grove API | Ghostls Implementation |
|-------------|-----------|------------------------|
| **Diagnostics** | `grove.lsp.getDiagnostics()` | `textDocument/publishDiagnostics` |
| **Hover** | `grove.lsp.getHover()` | `textDocument/hover` |
| **Go to Definition** | `grove.lsp.findDefinition()` | `textDocument/definition` |
| **Completions** | `grove.lsp.completion()` | `textDocument/completion` |
| **Document Symbols** | `grove.lsp.getDocumentSymbols()` | `textDocument/documentSymbol` |
| **Position Conversion** | `grove.lsp.Utils.*` | Convert LSP positions ↔ byte offsets |

#### Example: Ghostls Using grove.lsp

```zig
// ghostls/src/handlers/hover.zig
const grove = @import("grove");

pub fn handleHover(
    self: *Server,
    params: lsp.HoverParams,
) !?lsp.Hover {
    const uri = params.textDocument.uri;
    const document = self.documents.get(uri) orelse return null;

    // Parse with Grove
    var parser = try grove.Parser.init(self.allocator);
    defer parser.deinit();

    const language = try grove.Languages.ghostlang.get();
    try parser.setLanguage(language);

    var tree = try parser.parseUtf8(null, document.text);
    defer tree.deinit();

    // Load locals query for symbol lookup
    var query = try grove.Query.init(
        language,
        @embedFile("../../vendor/tree-sitter-ghostlang/queries/locals.scm"),
    );
    defer query.deinit();

    // Use Grove's LSP helper to get hover info
    const position = grove.lsp.Position{
        .line = params.position.line,
        .character = params.position.character,
    };

    const hover_info = try grove.lsp.getHover(
        &query,
        tree.rootNode().?,
        document.text,
        position,
    ) orelse return null;

    // Return LSP-compliant hover response
    return lsp.Hover{
        .contents = .{
            .kind = .markdown,
            .value = hover_info.contents.value,
        },
        .range = hover_info.range,
    };
}
```

#### Example: Ghostls Diagnostics

```zig
// ghostls/src/handlers/diagnostics.zig
const grove = @import("grove");

pub fn computeDiagnostics(
    self: *Server,
    uri: []const u8,
) ![]lsp.Diagnostic {
    const document = self.documents.get(uri) orelse return &.{};

    var parser = try grove.Parser.init(self.allocator);
    defer parser.deinit();

    const language = try grove.Languages.ghostlang.get();
    try parser.setLanguage(language);

    var tree = try parser.parseUtf8(null, document.text);
    defer tree.deinit();

    // Use Grove's diagnostic extraction
    const grove_diagnostics = try grove.lsp.getDiagnostics(
        self.allocator,
        &tree,
        document.text,
    );
    defer grove.lsp.freeDiagnostics(self.allocator, grove_diagnostics);

    // Convert to LSP protocol format
    var lsp_diagnostics = std.ArrayList(lsp.Diagnostic).init(self.allocator);
    for (grove_diagnostics) |diag| {
        try lsp_diagnostics.append(.{
            .range = .{
                .start = .{
                    .line = diag.range.start.line,
                    .character = diag.range.start.character,
                },
                .end = .{
                    .line = diag.range.end.line,
                    .character = diag.range.end.character,
                },
            },
            .severity = switch (diag.severity) {
                .@"error" => 1,
                .warning => 2,
                .information => 3,
                .hint => 4,
            },
            .source = "ghostls",
            .message = diag.message,
        });
    }

    return try lsp_diagnostics.toOwnedSlice();
}
```

---

### 3. **Grove** ↔ **Phantom.grim** Integration

**What Phantom.grim Needs from Grove:**

| Feature | Grove API | Phantom.grim Usage |
|---------|-----------|---------------------|
| **Theme Registry** | `grove.QueryRegistry` | Load `.gza` theme files dynamically |
| **Theme Presets** | `grove.ThemePreset` | Map captures to colors |
| **Query Validation** | `grove.validateQuery()` | Ensure custom queries are valid |
| **Language Registry** | `grove.Languages.*` | Detect and configure parsers |

#### Example: Phantom.grim Theme Loading

```ghostlang
-- ~/.config/grim/init.gza (Phantom.grim configuration)

-- Load theme dynamically using Grove's QueryRegistry
local theme = require("phantom.theme")

theme.load("tokyonight", {
    -- Override default colors (Grove ThemePreset API)
    overrides = {
        ["function"] = { rgb = { r = 0x88, g = 0xaf, b = 0xf0 }, bold = true },
        ["keyword"] = { rgb = { r = 0x9a, g = 0x0a, b = 0xde } },
        ["grim.motion.harvest"] = { rgb = { r = 0x7f, g = 0xff, b = 0xd4 } },
    },

    -- Hot-reload on file change
    auto_reload = true,
})

-- Command to switch themes
register_command("GrimTheme", function(args)
    theme.load(args[1])
end)

-- Keybinding to toggle light/dark
register_keymap("n", "<leader>tt", ":GrimThemeToggle<CR>", {
    desc = "Toggle light/dark theme"
})
```

#### Implementation in Grim (Zig Side)

```zig
// grim/src/phantom/theme_loader.zig
const grove = @import("grove");
const ghostlang = @import("ghostlang");

pub fn loadPhantomTheme(
    allocator: std.mem.Allocator,
    theme_name: []const u8,
) !grove.ThemePreset {
    // 1. Load .gza theme file using Ghostlang runtime
    const theme_path = try std.fmt.allocPrint(
        allocator,
        "{s}/.config/grim/themes/{s}.gza",
        .{ std.os.getenv("HOME") orelse "/root", theme_name },
    );
    defer allocator.free(theme_path);

    var theme_vm = try ghostlang.VM.init(allocator);
    defer theme_vm.deinit();

    const theme_table = try theme_vm.loadFile(theme_path);

    // 2. Convert .gza theme to Grove ThemePreset
    var preset = grove.ThemePreset.init(allocator, theme_name);

    const colors = theme_table.get("colors") orelse return error.NoColors;
    var it = colors.iterator();

    while (it.next()) |entry| {
        const capture_name = entry.key;
        const color_def = entry.value;

        const mapping = grove.ThemeMapping{
            .capture_name = capture_name,
            .color = if (color_def.get("rgb")) |rgb|
                grove.Color{
                    .rgb = .{
                        .r = @intCast(rgb.get("r").?.asInt()),
                        .g = @intCast(rgb.get("g").?.asInt()),
                        .b = @intCast(rgb.get("b").?.asInt()),
                    },
                }
            else if (color_def.get("ansi")) |ansi|
                grove.Color{ .ansi = @intCast(ansi.asInt()) }
            else
                grove.Color{ .named = color_def.get("named").?.asString() },
            .modifiers = parseModifiers(color_def),
        };

        try preset.addMapping(mapping);
    }

    return preset;
}
```

---

## Integration Checklist

### For **Grim** Developers

- [x] **Syntax Highlighting**: Use `grove.getHighlights()` with `QueryRegistry`
- [x] **Code Folding**: Use `grove.getFoldingRanges()` or `grove.lsp.foldingRanges()`
- [x] **Document Outline**: Use `grove.getDocumentSymbols()`
- [x] **Theme System**: Integrate `grove.ThemePreset` with Phantom.grim themes
- [ ] **Performance**: Use `grove.ParserPool` for multi-file parsing
- [ ] **Incremental Updates**: Use `tree.edit()` for rope-based edits

### For **Ghostls** Developers

- [x] **Parse Ghostlang**: Use `grove.Languages.ghostlang.get()`
- [x] **Diagnostics**: Use `grove.lsp.getDiagnostics()`
- [x] **Hover**: Use `grove.lsp.getHover()` with locals query
- [x] **Go to Definition**: Use `grove.lsp.findDefinition()`
- [x] **Completions**: Use `grove.lsp.completion()` or custom query traversal
- [x] **Position Conversion**: Use `grove.lsp.Utils.positionToByteOffset()`
- [ ] **Example Integration**: See `grove/examples/lsp_server.zig`

### For **Phantom.grim** Developers

- [x] **Theme Loading**: Use `grove.QueryRegistry` and `grove.ThemePreset`
- [x] **Query Validation**: Use `grove.validateQuery()` before applying
- [x] **Hot-Reload**: Watch `.gza` theme files and reload via Grove API
- [ ] **Custom Queries**: Allow users to override highlight queries in config
- [ ] **Language Detection**: Use Grove's language registry for auto-detection

---

## Common Integration Patterns

### Pattern 1: Parsing a File

```zig
const grove = @import("grove");

pub fn parseFile(allocator: std.mem.Allocator, file_path: []const u8) !grove.Tree {
    // 1. Detect language
    const language_name = detectLanguageFromPath(file_path);
    const language = try grove.Languages.get(language_name);

    // 2. Read file content
    const content = try std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024);
    defer allocator.free(content);

    // 3. Parse with Grove
    var parser = try grove.Parser.init(allocator);
    errdefer parser.deinit();
    try parser.setLanguage(language);

    return try parser.parseUtf8(null, content);
}
```

### Pattern 2: Running a Tree-sitter Query

```zig
const grove = @import("grove");

pub fn findFunctions(tree: grove.Tree, source: []const u8) ![][]const u8 {
    var query = try grove.Query.init(
        tree.language(),
        "(function_declaration name: (identifier) @function.name)",
    );
    defer query.deinit();

    var cursor = try grove.QueryCursor.init();
    defer cursor.deinit();

    cursor.exec(&query, tree.rootNode().?);

    var functions = std.ArrayList([]const u8).init(allocator);
    while (cursor.nextMatch()) |match| {
        for (match.captures) |capture| {
            const node = capture.node;
            const name = node.text(source) orelse continue;
            try functions.append(name);
        }
    }

    return try functions.toOwnedSlice();
}
```

### Pattern 3: LSP Server Integration

```zig
const grove = @import("grove");

pub const MyLSPServer = struct {
    allocator: std.mem.Allocator,
    language_server: grove.lsp.LanguageServer,

    pub fn init(allocator: std.mem.Allocator, language: grove.Language) !MyLSPServer {
        return .{
            .allocator = allocator,
            .language_server = try grove.lsp.LanguageServer.init(allocator, language),
        };
    }

    pub fn deinit(self: *MyLSPServer) void {
        self.language_server.deinit();
    }

    pub fn handleTextDocumentHover(
        self: *MyLSPServer,
        params: lsp.HoverParams,
    ) !?lsp.Hover {
        const position = grove.lsp.Position{
            .line = params.position.line,
            .character = params.position.character,
        };

        const hover_text = try self.language_server.hover(document.text, position);
        defer if (hover_text) |text| self.allocator.free(text);

        if (hover_text) |text| {
            return lsp.Hover{
                .contents = .{ .kind = .markdown, .value = text },
            };
        }

        return null;
    }
};
```

---

## Dependency Graph

```
Grim (Editor)
 ├─→ Grove (Tree-sitter parsing, syntax highlighting)
 ├─→ Phantom.grim (Configuration framework)
 │    └─→ Grove.QueryRegistry (Theme loading)
 ├─→ Ghostls (LSP client connection)
 │    └─→ Grove.lsp (LSP helpers)
 └─→ Ghostlang (Plugin runtime)
      └─→ Grove (Parse .gza files for syntax highlighting)

Ghostls (LSP Server)
 ├─→ Grove.lsp (Diagnostics, hover, goto-definition)
 ├─→ Grove.Languages.ghostlang (Parse Ghostlang)
 └─→ Ghostlang Runtime (Semantic analysis)

Phantom.grim (Config Framework)
 ├─→ Grove.QueryRegistry (Load highlight queries)
 ├─→ Grove.ThemePreset (Theme definitions)
 └─→ Ghostlang (Execute .gza config files)
```

---

## Version Compatibility

| Grove Version | Grim Version | Ghostls Version | Phantom.grim Version |
|---------------|--------------|-----------------|----------------------|
| **v0.1.0+** (Beta) | v0.2.8+ | v0.1.0+ | v0.1.0+ (planned) |
| **Phase Theta** ✅ | ✅ Ready | ✅ Ready | 🔄 In Development |

---

## Testing Integration

### Integration Test Example (Grim + Grove)

```zig
test "grim syntax highlighting integration" {
    const allocator = std.testing.allocator;

    // Simulate Grim loading a file
    const ghostlang_source = "local x = 42\nfunction foo() end";

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    const language = try grove.Languages.ghostlang.get();
    try parser.setLanguage(language);

    var tree = try parser.parseUtf8(null, ghostlang_source);
    defer tree.deinit();

    // Get highlights
    var registry = grove.QueryRegistry.init(allocator);
    defer registry.deinit();
    try registry.loadBundled();

    const preset = registry.get("ghostlang").?;
    var query = try grove.Query.init(language, preset.highlight_query);
    defer query.deinit();

    // Minimal theme rules
    const rules = [_]grove.HighlightRule{
        .{ .capture_name = "keyword", .class = "keyword" },
        .{ .capture_name = "function", .class = "function" },
    };

    const highlights = try grove.getHighlights(
        allocator,
        &query,
        tree.rootNode().?,
        &rules,
    );
    defer allocator.free(highlights);

    try std.testing.expect(highlights.len > 0);
}
```

---

## Troubleshooting

### Issue: Grove not finding language

**Symptom:** `error.UnsupportedLanguage` when calling `grove.Languages.get()`

**Solution:**
```zig
// Make sure language is in the bundled enum
const language = switch (language_name) {
    "ghostlang", "gza", "ghost" => grove.Languages.ghostlang,
    "zig" => grove.Languages.zig,
    "typescript", "ts" => grove.Languages.typescript,
    // ... etc
    else => return error.UnsupportedLanguage,
};
```

### Issue: Query compilation fails

**Symptom:** `error.QueryError` when creating a query

**Solution:**
```zig
// Validate query before using
const is_valid = grove.validateQuery(language, query_source);
if (!is_valid) {
    std.debug.print("Invalid query: {s}\n", .{query_source});
    return error.InvalidQuery;
}
```

### Issue: Ghostls not getting diagnostics

**Symptom:** No diagnostics appear in Grim

**Solution:**
```zig
// Ensure tree is parsed correctly
if (tree.rootNode()) |root| {
    if (std.mem.eql(u8, root.kind(), "ERROR")) {
        // Entire file is an error
        std.debug.print("Parse failed completely\n", .{});
    }
}

// Check if diagnostics are being computed
const diagnostics = try grove.lsp.getDiagnostics(allocator, &tree, source);
std.debug.print("Found {d} diagnostics\n", .{diagnostics.len});
```

---

## Next Steps

1. **Grim Integration** – Use Grove for syntax highlighting (remove fallback)
2. **Ghostls Integration** – Adopt `grove.lsp` for all LSP features
3. **Phantom.grim** – Implement `.gza` theme loading with `QueryRegistry`
4. **Performance Testing** – Benchmark Grove in real Grim workflows
5. **Documentation** – Expand API docs for ecosystem consumers

---

## Resources

- **Grove Documentation**: `docs/` folder in Grove repository
- **LSP Helper Guide**: `docs/THEME_PRESET_GUIDE.md`
- **Example LSP Server**: `examples/lsp_server.zig`
- **Grim Architecture**: `/data/projects/grim/docs/phantom-architecture.md`
- **Ghostls Requirements**: `/data/projects/ghostls/LSP_REQS.md`

---

**Maintainer Contact**: GhostKellz Ecosystem Team
**Last Updated**: 2025-10-06 (Phase Theta Complete)
