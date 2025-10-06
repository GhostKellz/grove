## Grove ThemePreset and QueryRegistry Guide for Phantom.grim

**Status**: Phase Theta – Query preset registry + theming bridge
**Consumer**: Phantom.grim editor configuration system
**Module**: `grove.QueryRegistry`, `grove.ThemePreset`

---

## Overview

Grove's **QueryRegistry** and **ThemePreset** system provides dynamic theme loading and syntax highlighting customization for Grim and Phantom.grim. This allows `.gza` configuration files to change themes at runtime without recompiling.

### Architecture

```
┌────────────────────────────────────────────────────────┐
│              Phantom.grim (init.gza)                   │
│  theme.load("tokyonight")  ←─ User configuration       │
└────────────────────────┬───────────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────────────┐
│         Grove QueryRegistry + ThemePreset              │
│  • Loads highlight queries for all languages           │
│  • Maps theme colors to tree-sitter capture names      │
│  • Provides hot-reload capability                      │
└────────────────────────┬───────────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────────────┐
│              Grim Renderer (TUI)                       │
│  • Applies colors to syntax tokens                     │
│  • Renders to terminal with ANSI codes                 │
└────────────────────────────────────────────────────────┘
```

---

## QueryRegistry API

### What is QueryRegistry?

The **QueryRegistry** is a centralized store for tree-sitter queries across all bundled grammars. It provides:

1. **Query loading** – Load highlight, locals, textobjects queries
2. **Language detection** – Automatically find the right query set for a file
3. **Query validation** – Ensure queries are syntactically correct
4. **Caching** – Avoid re-parsing queries on every file open

### Core Types

```zig
// Available in Grove via: @import("grove").QueryRegistry
pub const QueryRegistry = struct {
    allocator: std.mem.Allocator,
    presets: std.StringHashMap(QueryPreset),

    pub fn init(allocator: std.mem.Allocator) QueryRegistry;
    pub fn deinit(self: *QueryRegistry) void;

    /// Register a new query preset for a language
    pub fn register(
        self: *QueryRegistry,
        language_name: []const u8,
        preset: QueryPreset,
    ) !void;

    /// Get query preset for a language
    pub fn get(
        self: *const QueryRegistry,
        language_name: []const u8,
    ) ?QueryPreset;

    /// Load all bundled language queries
    pub fn loadBundled(self: *QueryRegistry) !void;
};

pub const QueryPreset = struct {
    language: Language,
    highlight_query: []const u8,
    locals_query: ?[]const u8,
    textobjects_query: ?[]const u8,
    folds_query: ?[]const u8,
    injections_query: ?[]const u8,
};

pub const QueryType = enum {
    highlights,
    locals,
    textobjects,
    folds,
    injections,
};
```

### Example Usage in Grim/Phantom.grim

#### 1. Initialize QueryRegistry

```zig
// In Grim startup (src/main.zig)
const grove = @import("grove");

var query_registry = grove.QueryRegistry.init(allocator);
defer query_registry.deinit();

// Load all bundled language queries (JSON, Zig, Rust, Ghostlang, etc.)
try query_registry.loadBundled();
```

#### 2. Get Queries for a Specific Language

```zig
// When opening a file, detect language and get queries
const language_name = detectLanguage(file_path); // e.g., "zig", "typescript"

const preset = query_registry.get(language_name) orelse {
    std.debug.print("No query preset for language: {s}\n", .{language_name});
    return error.UnsupportedLanguage;
};

// Now you have access to all queries for that language
const highlight_query = preset.highlight_query;
const folds_query = preset.folds_query;
```

#### 3. Use Queries for Syntax Highlighting

```zig
// Parse file with grove
var parser = try grove.Parser.init(allocator);
defer parser.deinit();

try parser.setLanguage(preset.language);
var tree = try parser.parseUtf8(null, source_code);
defer tree.deinit();

// Create query from preset
var query = try grove.Query.init(preset.language, highlight_query);
defer query.deinit();

// Collect highlights
const highlights = try grove.getHighlights(
    allocator,
    &query,
    tree.rootNode().?,
    theme_rules, // See ThemePreset section below
);
defer allocator.free(highlights);

// Render to TUI
for (highlights) |hl| {
    renderSpan(hl.start_byte, hl.end_byte, hl.color);
}
```

---

## ThemePreset API

### What is ThemePreset?

A **ThemePreset** maps tree-sitter capture names (e.g., `@function`, `@keyword`) to terminal colors or RGB values. Grim loads themes dynamically from `.gza` files.

### Core Types

```zig
pub const ThemePreset = struct {
    name: []const u8,
    mappings: []ThemeMapping,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) ThemePreset;
    pub fn addMapping(self: *ThemePreset, mapping: ThemeMapping) !void;
    pub fn getColor(self: *const ThemePreset, capture_name: []const u8) ?Color;
};

pub const ThemeMapping = struct {
    capture_name: []const u8,  // e.g., "function", "keyword.control"
    color: Color,
    modifiers: []Modifier = &.{},
};

pub const Color = union(enum) {
    rgb: struct { r: u8, g: u8, b: u8 },
    ansi: u8,              // ANSI 256-color code
    named: []const u8,      // e.g., "cyan", "brightred"
};

pub const Modifier = enum {
    bold,
    italic,
    underline,
    strikethrough,
};
```

### Example: Defining Themes in Phantom.grim

#### Ghostlang Theme Configuration (`.gza` file)

```ghostlang
-- ~/.config/grim/themes/tokyonight.gza

local theme = {
    name = "tokyonight-phantom",

    -- Map tree-sitter captures to colors
    colors = {
        -- Syntax
        ["function"] = { rgb = { r = 0x88, g = 0xaf, b = 0xf0 }, bold = true },
        ["function.call"] = { rgb = { r = 0x7a, g = 0xa2, b = 0xf7 } },
        ["keyword"] = { rgb = { r = 0x9a, g = 0x0a, b = 0xde }, bold = true },
        ["keyword.control"] = { rgb = { r = 0xbb, g = 0x9a, b = 0xf7 } },
        ["string"] = { rgb = { r = 0x66, g = 0xd9, b = 0xef } },
        ["comment"] = { rgb = { r = 0x56, g = 0x5f, b = 0x89 }, italic = true },
        ["variable"] = { rgb = { r = 0xc0, g = 0xca, b = 0xf5 } },
        ["constant"] = { rgb = { r = 0xff, g = 0x9e, b = 0x64 } },
        ["type"] = { rgb = { r = 0x2a, g = 0xc3, b = 0xde } },
        ["operator"] = { rgb = { r = 0x89, g = 0xdd, b = 0xff } },

        -- Grim-specific (custom extensions)
        ["grim.motion.harvest"] = { rgb = { r = 0x7f, g = 0xff, b = 0xd4 }, bold = true },
        ["grim.selection"] = { ansi = 236, bold = true },  -- Dark gray background

        -- Markdown
        ["markup.heading"] = { rgb = { r = 0x7a, g = 0xa2, b = 0xf7 }, bold = true },
        ["markup.link"] = { rgb = { r = 0x73, g = 0xda, b = 0xca }, underline = true },
        ["markup.code"] = { rgb = { r = 0xe0, g = 0xaf, b = 0x68 } },
    }
}

return theme
```

#### Loading Theme in Grim (Zig side)

```zig
// Grim loads .gza theme and converts to Grove ThemePreset
const grove = @import("grove");

pub fn loadTheme(allocator: std.mem.Allocator, theme_path: []const u8) !grove.ThemePreset {
    // Parse .gza theme file using Ghostlang runtime
    const theme_data = try ghostlang.loadFile(allocator, theme_path);
    defer theme_data.deinit();

    var preset = grove.ThemePreset.init(allocator, theme_data.name);

    // Convert .gza color definitions to ThemeMappings
    for (theme_data.colors) |color_def| {
        const mapping = grove.ThemeMapping{
            .capture_name = color_def.name,
            .color = if (color_def.rgb) |rgb|
                grove.Color{ .rgb = .{ .r = rgb.r, .g = rgb.g, .b = rgb.b } }
            else if (color_def.ansi) |ansi|
                grove.Color{ .ansi = ansi }
            else
                grove.Color{ .named = color_def.named orelse "white" },
            .modifiers = color_def.modifiers orelse &.{},
        };

        try preset.addMapping(mapping);
    }

    return preset;
}

// Use theme for highlighting
pub fn highlightFile(file: []const u8, theme: grove.ThemePreset) !void {
    const preset = query_registry.get(detectLanguage(file)) orelse return error.NoPreset;

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(preset.language);
    var tree = try parser.parseUtf8(null, file_content);
    defer tree.deinit();

    var query = try grove.Query.init(preset.language, preset.highlight_query);
    defer query.deinit();

    // Convert ThemePreset to HighlightRules
    var rules = std.ArrayList(grove.HighlightRule).init(allocator);
    defer rules.deinit();

    for (theme.mappings) |mapping| {
        try rules.append(.{
            .capture_name = mapping.capture_name,
            .class = mapping.color,  // Adapt based on your Color type
        });
    }

    const highlights = try grove.getHighlights(
        allocator,
        &query,
        tree.rootNode().?,
        rules.items,
    );
    defer allocator.free(highlights);

    // Render highlights with theme colors
    renderWithTheme(highlights, theme);
}
```

---

## Hot-Reload Themes

Phantom.grim can support **runtime theme switching** without restarting Grim:

```ghostlang
-- In Grim command mode or .gza config

-- Switch theme dynamically
theme.load("gruvbox")

-- Or toggle between light/dark variants
theme.toggle()  -- tokyonight-night ↔ tokyonight-day

-- Custom theme reloading
if file_changed("~/.config/grim/themes/custom.gza") then
    theme.reload("custom")
end
```

### Implementation

```zig
// Grim theme manager
pub const ThemeManager = struct {
    current_theme: grove.ThemePreset,
    theme_cache: std.StringHashMap(grove.ThemePreset),

    pub fn load(self: *ThemeManager, theme_name: []const u8) !void {
        // Check cache first
        if (self.theme_cache.get(theme_name)) |cached| {
            self.current_theme = cached;
            return;
        }

        // Load from .gza file
        const theme_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/.config/grim/themes/{s}.gza",
            .{ std.os.getenv("HOME") orelse "/root", theme_name }
        );
        defer self.allocator.free(theme_path);

        const new_theme = try loadTheme(self.allocator, theme_path);
        try self.theme_cache.put(theme_name, new_theme);

        self.current_theme = new_theme;

        // Trigger UI redraw
        self.notifyThemeChanged();
    }

    pub fn reload(self: *ThemeManager, theme_name: []const u8) !void {
        // Clear cache entry
        _ = self.theme_cache.remove(theme_name);
        try self.load(theme_name);
    }
};
```

---

## Bundled Themes in Phantom.grim

Phantom.grim ships with these default themes:

1. **tokyonight** (default) – Dark theme with pastel colors
2. **gruvbox** – Retro warm contrast theme
3. **catppuccin** – Soothing pastel colors
4. **dracula** – Dark with vibrant accent colors
5. **nord** – Arctic-inspired palette
6. **onedark** – Atom One Dark port
7. **solarized-dark/light** – Classic Solarized theme

Users can create custom themes by copying and modifying any `.gza` theme file.

---

## Query Registry: Full Language Support

Grove's QueryRegistry supports all 14 bundled grammars:

| Language | Highlight | Locals | Textobjects | Folds | Injections |
|----------|-----------|--------|-------------|-------|------------|
| JSON | ✅ | ❌ | ❌ | ✅ | ❌ |
| Zig | ✅ | ✅ | ✅ | ✅ | ❌ |
| Rust | ✅ | ✅ | ✅ | ✅ | ❌ |
| Ghostlang | ✅ | ✅ | ✅ | ✅ | ❌ |
| TypeScript | ✅ | ✅ | ✅ | ✅ | ✅ |
| TSX | ✅ | ✅ | ✅ | ✅ | ✅ |
| Bash | ✅ | ✅ | ❌ | ✅ | ❌ |
| JavaScript | ✅ | ✅ | ✅ | ✅ | ✅ |
| Python | ✅ | ❌ | ❌ | ✅ | ❌ |
| Markdown | ✅ | ❌ | ❌ | ✅ | ✅ |
| CMake | ✅ | ❌ | ❌ | ✅ | ❌ |
| TOML | ✅ | ❌ | ❌ | ✅ | ❌ |
| YAML | ✅ | ❌ | ❌ | ✅ | ❌ |
| C | ✅ | ✅ | ✅ | ✅ | ❌ |

---

## Testing Theme Presets

```zig
test "load tokyonight theme" {
    const allocator = std.testing.allocator;

    var registry = grove.QueryRegistry.init(allocator);
    defer registry.deinit();

    try registry.loadBundled();

    // Load theme
    var theme = grove.ThemePreset.init(allocator, "tokyonight");
    defer theme.deinit();

    try theme.addMapping(.{
        .capture_name = "function",
        .color = .{ .rgb = .{ .r = 0x88, .g = 0xaf, .b = 0xf0 } },
        .modifiers = &.{.bold},
    });

    const color = theme.getColor("function").?;
    try std.testing.expect(color == .rgb);
    try std.testing.expectEqual(@as(u8, 0x88), color.rgb.r);
}
```

---

## Next Steps for Phantom.grim Integration

1. **Create Ghostlang Theme Loader** – Parse `.gza` theme files
2. **Implement ThemeManager in Grim** – Handle runtime theme switching
3. **Expose `:GrimTheme` command** – Let users change themes interactively
4. **Add Theme Picker UI** – Fuzzy-find themes like Telescope in Neovim
5. **Document Custom Theme Creation** – Tutorial for users to create themes

---

## References

- [Tree-sitter Query Documentation](https://tree-sitter.github.io/tree-sitter/using-parsers#pattern-matching-with-queries)
- [Grim Editor Architecture](../docs/DESIGN.md)
- [Phantom.grim Plugin System](../../grim/docs/phantom-architecture.md)
- [Ghostlang Language Spec](https://github.com/ghostkellz/ghostlang)

---

**Status**: ✅ Complete – Ready for Phantom.grim integration
