const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get ZigScript language
    const lang = try grove.Languages.zs.get();
    std.debug.print("ZigScript language loaded successfully\n", .{});

    // Create parser
    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(lang);

    // Parse a simple ZigScript program
    const source =
        \\fn add(a: i32, b: i32) -> i32 {
        \\    return a + b;
        \\}
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.NoRootNode;
    std.debug.print("Root node type: {s}\n", .{root.kind()});
    std.debug.print("Root node has error: {}\n", .{root.hasError()});
    std.debug.print("Child count: {}\n", .{root.childCount()});

    if (root.childCount() > 0) {
        const child = root.child(0).?;
        std.debug.print("First child type: {s}\n", .{child.kind()});
    }

    std.debug.print("\nParsed ZigScript successfully!\n", .{});
}
