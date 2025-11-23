const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get ZigScript language
    const lang = try grove.Languages.zs.get();

    // Create parser
    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(lang);

    // Read a real ZigScript file
    const file_path = "/data/projects/zigscript/examples/wallet.zs";
    const source = try std.fs.cwd().readFileAlloc(file_path, allocator, @as(std.Io.Limit, @enumFromInt(10 * 1024 * 1024)));
    defer allocator.free(source);

    std.debug.print("Parsing {s}...\n", .{file_path});

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.NoRootNode;
    std.debug.print("Root node: {s}\n", .{root.kind()});
    std.debug.print("Has error: {}\n", .{root.hasError()});
    std.debug.print("Total children: {}\n", .{root.childCount()});

    // Print first few top-level nodes
    const count = @min(root.childCount(), 10);
    std.debug.print("\nFirst {} top-level nodes:\n", .{count});
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        if (root.child(i)) |child| {
            std.debug.print("  [{d}] {s}\n", .{ i, child.kind() });
        }
    }

    std.debug.print("\nParsed ZigScript file successfully!\n", .{});
}
