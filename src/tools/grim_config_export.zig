const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <command> [options]\n", .{args[0]});
        std.debug.print("Commands:\n", .{});
        std.debug.print("  config       - Export complete Grim configuration\n", .{});
        std.debug.print("  language <lang> - Export queries for specific language\n", .{});
        std.debug.print("  theme <name>    - Export specific theme configuration\n", .{});
        std.debug.print("  summary         - Generate feature summary\n", .{});
        return;
    }

    var bridge = grove.GrimBridge.init(allocator);
    defer bridge.deinit();

    const command = args[1];

    if (std.mem.eql(u8, command, "config")) {
        const config = try bridge.getGrimConfig();
        defer allocator.free(config);
        std.debug.print("{s}", .{config});
    } else if (std.mem.eql(u8, command, "language")) {
        if (args.len < 3) {
            std.debug.print("Error: language command requires a language name\n", .{});
            std.debug.print("Available: ghostlang, typescript, tsx, zig, json, rust\n", .{});
            return;
        }

        const lang_name = args[2];
        const language = if (std.mem.eql(u8, lang_name, "ghostlang"))
            grove.Languages.ghostlang
        else if (std.mem.eql(u8, lang_name, "typescript"))
            grove.Languages.typescript
        else if (std.mem.eql(u8, lang_name, "tsx"))
            grove.Languages.tsx
        else if (std.mem.eql(u8, lang_name, "zig"))
            grove.Languages.zig
        else if (std.mem.eql(u8, lang_name, "json"))
            grove.Languages.json
        else if (std.mem.eql(u8, lang_name, "rust"))
            grove.Languages.rust
        else {
            std.debug.print("Error: unknown language '{s}'\n", .{lang_name});
            return;
        };

        const queries = try bridge.getLanguageQueries(language);
        defer allocator.free(queries);
        std.debug.print("{s}", .{queries});
    } else if (std.mem.eql(u8, command, "theme")) {
        if (args.len < 3) {
            std.debug.print("Error: theme command requires a theme name\n", .{});
            std.debug.print("Available: default, grim_dark, grim_light\n", .{});
            return;
        }

        const theme_name = args[2];
        const theme_config = try bridge.getThemeConfig(theme_name);
        if (theme_config) |config| {
            defer allocator.free(config);
            std.debug.print("{s}", .{config});
        } else {
            std.debug.print("Error: theme '{s}' not found\n", .{theme_name});
        }
    } else if (std.mem.eql(u8, command, "summary")) {
        const summary = try bridge.getFeatureSummary();
        defer allocator.free(summary);
        std.debug.print("{s}", .{summary});
    } else {
        std.debug.print("Error: unknown command '{s}'\n", .{command});
    }
}