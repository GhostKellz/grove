const std = @import("std");
const Languages = @import("../languages.zig").Bundled;

pub const QueryType = enum {
    highlights,
    locals,
    textobjects,
    injections,
    folds,
};

pub const QueryPreset = struct {
    language: Languages,
    query_type: QueryType,
    source: []const u8,
    description: []const u8,
};

pub const ThemeMapping = struct {
    capture_name: []const u8,
    theme_class: []const u8,
    description: []const u8,
};

pub const ThemePreset = struct {
    name: []const u8,
    description: []const u8,
    mappings: []const ThemeMapping,
};

// Pre-defined query presets for all supported languages
const query_presets = [_]QueryPreset{
    // Ghostlang queries
    .{
        .language = .ghostlang,
        .query_type = .highlights,
        .source = @embedFile("../../vendor/grammars/ghostlang/queries/highlights.scm"),
        .description = "Ghostlang syntax highlighting queries",
    },
    .{
        .language = .ghostlang,
        .query_type = .locals,
        .source = @embedFile("../../vendor/grammars/ghostlang/queries/locals.scm"),
        .description = "Ghostlang local symbol queries for document outline",
    },
    .{
        .language = .ghostlang,
        .query_type = .textobjects,
        .source = @embedFile("../../vendor/grammars/ghostlang/queries/textobjects.scm"),
        .description = "Ghostlang textobject queries for folding and navigation",
    },

    // TypeScript queries
    .{
        .language = .typescript,
        .query_type = .highlights,
        .source = @embedFile("../../vendor/grammars/typescript/queries/highlights.scm"),
        .description = "TypeScript syntax highlighting queries",
    },

    // TSX queries
    .{
        .language = .tsx,
        .query_type = .highlights,
        .source = @embedFile("../../vendor/grammars/tsx/queries/highlights.scm"),
        .description = "TSX/React syntax highlighting queries",
    },
};

// Theme presets for different editor themes
const theme_presets = [_]ThemePreset{
    .{
        .name = "default",
        .description = "Default Grove theme mapping",
        .mappings = &[_]ThemeMapping{
            .{ .capture_name = "keyword", .theme_class = "@keyword", .description = "Language keywords" },
            .{ .capture_name = "function", .theme_class = "@function", .description = "Function names" },
            .{ .capture_name = "function.call", .theme_class = "@function.call", .description = "Function calls" },
            .{ .capture_name = "function.builtin", .theme_class = "@function.builtin", .description = "Built-in functions" },
            .{ .capture_name = "variable", .theme_class = "@variable", .description = "Variable names" },
            .{ .capture_name = "variable.parameter", .theme_class = "@variable.parameter", .description = "Function parameters" },
            .{ .capture_name = "property", .theme_class = "@property", .description = "Object properties" },
            .{ .capture_name = "string", .theme_class = "@string", .description = "String literals" },
            .{ .capture_name = "number", .theme_class = "@number", .description = "Numeric literals" },
            .{ .capture_name = "boolean", .theme_class = "@boolean", .description = "Boolean literals" },
            .{ .capture_name = "comment", .theme_class = "@comment", .description = "Comments" },
            .{ .capture_name = "type", .theme_class = "@type", .description = "Type names" },
            .{ .capture_name = "type.builtin", .theme_class = "@type.builtin", .description = "Built-in types" },
            .{ .capture_name = "operator", .theme_class = "@operator", .description = "Operators" },
            .{ .capture_name = "punctuation", .theme_class = "@punctuation", .description = "Punctuation" },
            .{ .capture_name = "punctuation.bracket", .theme_class = "@punctuation.bracket", .description = "Brackets" },
            .{ .capture_name = "punctuation.delimiter", .theme_class = "@punctuation.delimiter", .description = "Delimiters" },
            .{ .capture_name = "tag", .theme_class = "@tag", .description = "HTML/XML tags" },
            .{ .capture_name = "attribute", .theme_class = "@attribute", .description = "HTML/XML attributes" },
        },
    },
    .{
        .name = "grim_dark",
        .description = "Dark theme optimized for Grim editor",
        .mappings = &[_]ThemeMapping{
            .{ .capture_name = "keyword", .theme_class = "grim.keyword.dark", .description = "Keywords in dark theme" },
            .{ .capture_name = "function", .theme_class = "grim.function.dark", .description = "Functions in dark theme" },
            .{ .capture_name = "string", .theme_class = "grim.string.dark", .description = "Strings in dark theme" },
            .{ .capture_name = "comment", .theme_class = "grim.comment.dark", .description = "Comments in dark theme" },
            .{ .capture_name = "type", .theme_class = "grim.type.dark", .description = "Types in dark theme" },
        },
    },
    .{
        .name = "grim_light",
        .description = "Light theme optimized for Grim editor",
        .mappings = &[_]ThemeMapping{
            .{ .capture_name = "keyword", .theme_class = "grim.keyword.light", .description = "Keywords in light theme" },
            .{ .capture_name = "function", .theme_class = "grim.function.light", .description = "Functions in light theme" },
            .{ .capture_name = "string", .theme_class = "grim.string.light", .description = "Strings in light theme" },
            .{ .capture_name = "comment", .theme_class = "grim.comment.light", .description = "Comments in light theme" },
            .{ .capture_name = "type", .theme_class = "grim.type.light", .description = "Types in light theme" },
        },
    },
};

pub const QueryRegistry = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) QueryRegistry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *QueryRegistry) void {
        _ = self;
    }

    /// Get a query preset by language and type
    pub fn getQueryPreset(self: *QueryRegistry, language: Languages, query_type: QueryType) ?*const QueryPreset {
        _ = self;
        for (&query_presets) |*preset| {
            if (preset.language == language and preset.query_type == query_type) {
                return preset;
            }
        }
        return null;
    }

    /// Get all available query presets for a language
    pub fn getQueryPresetsForLanguage(self: *QueryRegistry, language: Languages, allocator: std.mem.Allocator) ![]QueryPreset {
        _ = self;
        var result = std.ArrayList(QueryPreset){};

        for (query_presets) |preset| {
            if (preset.language == language) {
                try result.append(allocator, preset);
            }
        }

        return result.toOwnedSlice(allocator);
    }

    /// Get a theme preset by name
    pub fn getThemePreset(self: *QueryRegistry, name: []const u8) ?*const ThemePreset {
        _ = self;
        for (&theme_presets) |*preset| {
            if (std.mem.eql(u8, preset.name, name)) {
                return preset;
            }
        }
        return null;
    }

    /// Get all available theme presets
    pub fn getAllThemePresets(self: *QueryRegistry) []const ThemePreset {
        _ = self;
        return &theme_presets;
    }

    /// Get all supported languages with available queries
    pub fn getSupportedLanguages(self: *QueryRegistry, allocator: std.mem.Allocator) ![]Languages {
        _ = self;
        var seen = std.EnumSet(Languages){};
        var result = std.ArrayList(Languages){};

        for (query_presets) |preset| {
            if (!seen.contains(preset.language)) {
                seen.insert(preset.language);
                try result.append(allocator, preset.language);
            }
        }

        return result.toOwnedSlice(allocator);
    }

    /// Export configuration as JSON for Grim
    pub fn exportGrimConfig(self: *QueryRegistry, allocator: std.mem.Allocator) ![]u8 {
        _ = self; // Unused for simplified implementation

        // Simple JSON configuration for Grim
        return std.fmt.allocPrint(allocator,
            \\{{
            \\  "grove_version": "0.1.0",
            \\  "status": "RC1",
            \\  "supported_languages": ["ghostlang", "typescript", "tsx", "zig", "json", "rust"],
            \\  "features": ["highlights", "locals", "textobjects", "folding", "symbols"]
            \\}}
            , .{});

    }
};

const testing = std.testing;

test "query registry provides presets for all languages" {
    const allocator = testing.allocator;

    var registry = QueryRegistry.init(allocator);
    defer registry.deinit();

    // Test getting Ghostlang highlights
    const ghostlang_highlights = registry.getQueryPreset(.ghostlang, .highlights);
    try testing.expect(ghostlang_highlights != null);
    try testing.expect(ghostlang_highlights.?.source.len > 0);

    // Test getting TypeScript highlights
    const typescript_highlights = registry.getQueryPreset(.typescript, .highlights);
    try testing.expect(typescript_highlights != null);

    // Test getting supported languages
    const languages = try registry.getSupportedLanguages(allocator);
    defer allocator.free(languages);
    try testing.expect(languages.len >= 3); // At least ghostlang, typescript, tsx
}

test "theme registry provides default themes" {
    const allocator = testing.allocator;

    var registry = QueryRegistry.init(allocator);
    defer registry.deinit();

    // Test getting default theme
    const default_theme = registry.getThemePreset("default");
    try testing.expect(default_theme != null);
    try testing.expect(default_theme.?.mappings.len > 0);

    // Test getting Grim themes
    const grim_dark = registry.getThemePreset("grim_dark");
    try testing.expect(grim_dark != null);

    const grim_light = registry.getThemePreset("grim_light");
    try testing.expect(grim_light != null);

    // Test getting all themes
    const all_themes = registry.getAllThemePresets();
    try testing.expect(all_themes.len >= 3);
}

test "export grim config produces valid JSON structure" {
    const allocator = testing.allocator;

    var registry = QueryRegistry.init(allocator);
    defer registry.deinit();

    const config = try registry.exportGrimConfig(allocator);
    defer allocator.free(config);

    try testing.expect(config.len > 0);
    try testing.expect(std.mem.indexOf(u8, config, "grove_version") != null);
    try testing.expect(std.mem.indexOf(u8, config, "query_presets") != null);
    try testing.expect(std.mem.indexOf(u8, config, "theme_presets") != null);
}