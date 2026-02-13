//! Basic parsing and highlighting example
//!
//! Demonstrates:
//! - Parser initialization
//! - Language selection
//! - Tree traversal
//! - Syntax highlighting

const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize parser
    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    // Set language to Zig
    const language = try grove.Languages.zig.get();
    try parser.setLanguage(language);

    // Parse source code
    const source =
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    std.debug.print("Hello, Grove!\n", .{});
        \\}
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse {
        std.debug.print("Empty tree\n", .{});
        return;
    };

    // Print tree structure
    std.debug.print("=== Syntax Tree ===\n", .{});
    printNode(root, 0);

    // Get highlights if query is available
    std.debug.print("\n=== Parse Info ===\n", .{});
    std.debug.print("Root kind: {s}\n", .{root.kind()});
    std.debug.print("Child count: {d}\n", .{root.childCount()});
    std.debug.print("Byte range: {d}-{d}\n", .{ root.startByte(), root.endByte() });
}

fn printNode(node: grove.Node, depth: usize) void {
    // Indent
    for (0..depth) |_| std.debug.print("  ", .{});

    // Node info
    std.debug.print("{s}", .{node.kind()});
    if (node.isNamed()) {
        const start = node.startPoint();
        const end = node.endPoint();
        std.debug.print(" [{d}:{d}-{d}:{d}]", .{ start.row, start.column, end.row, end.column });
    }
    std.debug.print("\n", .{});

    // Children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            printNode(child, depth + 1);
        }
    }
}
