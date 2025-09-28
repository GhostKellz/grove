const std = @import("std");
const QueryRegistry = @import("query_registry.zig").QueryRegistry;
const Languages = @import("../languages.zig").Bundled;
const AllLanguages = @import("all_languages.zig");
const EditorServices = AllLanguages.EditorServices;

/// Grim-specific configuration and utilities
pub const GrimBridge = struct {
    allocator: std.mem.Allocator,
    query_registry: QueryRegistry,
    editor_services: EditorServices,

    pub fn init(allocator: std.mem.Allocator) GrimBridge {
        return .{
            .allocator = allocator,
            .query_registry = QueryRegistry.init(allocator),
            .editor_services = EditorServices.init(allocator),
        };
    }

    pub fn deinit(self: *GrimBridge) void {
        self.query_registry.deinit();
        self.editor_services.deinit();
    }

    /// Get the complete Grim configuration as JSON
    pub fn getGrimConfig(self: *GrimBridge) ![]u8 {
        return self.query_registry.exportGrimConfig(self.allocator);
    }

    /// Get queries for a specific language in Grim-compatible format
    pub fn getLanguageQueries(self: *GrimBridge, language: Languages) ![]u8 {
        return std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "language": "{s}",
            \\  "supported_queries": ["highlights", "locals", "textobjects"],
            \\  "status": "available"
            \\}}
            , .{@tagName(language)});
    }

    /// Get theme configuration for Grim
    pub fn getThemeConfig(self: *GrimBridge, theme_name: []const u8) !?[]u8 {
        const theme = self.query_registry.getThemePreset(theme_name) orelse return null;

        const result = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "name": "{s}",
            \\  "description": "{s}",
            \\  "type": "grove_theme"
            \\}}
            , .{ theme.name, theme.description });
        return result;
    }

    /// Generate a summary of all available features for Grim documentation
    pub fn getFeatureSummary(self: *GrimBridge) ![]u8 {
        return std.fmt.allocPrint(self.allocator,
            \\# Grove Features for Grim
            \\
            \\## Supported Languages
            \\
            \\- **ghostlang**: highlights, locals, textobjects
            \\- **typescript**: highlights, locals, textobjects
            \\- **tsx**: highlights, locals, textobjects
            \\- **zig**: highlights, locals, textobjects
            \\- **json**: highlights, locals, textobjects
            \\- **rust**: highlights, locals, textobjects
            \\
            \\## Available Themes
            \\
            \\- **default**: Default Grove theme
            \\- **grim_dark**: Dark theme optimized for Grim
            \\- **grim_light**: Light theme optimized for Grim
            \\
            \\## Editor Features
            \\
            \\- **Syntax Highlighting**: Tree-sitter powered highlighting with customizable themes
            \\- **Document Symbols**: Extract functions, classes, variables for outline view
            \\- **Code Folding**: Intelligent folding based on syntax structure
            \\- **Query Registry**: Pre-configured queries for all supported languages
            \\- **Theme Bridge**: Easy integration with Grim's theming system
            \\
            \\## Integration Guide
            \\
            \\1. **Setup**: Initialize `GrimBridge` in your Grim editor
            \\2. **Queries**: Use `getLanguageQueries()` to get syntax queries for a file
            \\3. **Themes**: Use `getThemeConfig()` to apply Grove themes in Grim
            \\4. **Editor Services**: Use `EditorServices` for document symbols and folding
            \\
            , .{});
    }
};

const testing = std.testing;

test "grim bridge provides complete configuration" {
    const allocator = testing.allocator;

    var bridge = GrimBridge.init(allocator);
    defer bridge.deinit();

    // Test getting complete Grim config
    const config = try bridge.getGrimConfig();
    defer allocator.free(config);

    try testing.expect(config.len > 0);
    try testing.expect(std.mem.indexOf(u8, config, "grove_version") != null);
}

test "grim bridge provides language-specific queries" {
    const allocator = testing.allocator;

    var bridge = GrimBridge.init(allocator);
    defer bridge.deinit();

    // Test getting Ghostlang queries
    const ghostlang_queries = try bridge.getLanguageQueries(.ghostlang);
    defer allocator.free(ghostlang_queries);

    try testing.expect(ghostlang_queries.len > 0);
    try testing.expect(std.mem.indexOf(u8, ghostlang_queries, "ghostlang") != null);
    try testing.expect(std.mem.indexOf(u8, ghostlang_queries, "highlights") != null);
}

test "grim bridge provides theme configurations" {
    const allocator = testing.allocator;

    var bridge = GrimBridge.init(allocator);
    defer bridge.deinit();

    // Test getting default theme
    const default_theme = try bridge.getThemeConfig("default");
    try testing.expect(default_theme != null);
    defer if (default_theme) |theme| allocator.free(theme);

    if (default_theme) |theme| {
        try testing.expect(std.mem.indexOf(u8, theme, "default") != null);
    }

    // Test getting non-existent theme
    const missing_theme = try bridge.getThemeConfig("nonexistent");
    try testing.expect(missing_theme == null);
}

test "grim bridge generates feature summary" {
    const allocator = testing.allocator;

    var bridge = GrimBridge.init(allocator);
    defer bridge.deinit();

    const summary = try bridge.getFeatureSummary();
    defer allocator.free(summary);

    try testing.expect(summary.len > 0);
    try testing.expect(std.mem.indexOf(u8, summary, "Grove Features for Grim") != null);
    try testing.expect(std.mem.indexOf(u8, summary, "Supported Languages") != null);
    try testing.expect(std.mem.indexOf(u8, summary, "Available Themes") != null);
}