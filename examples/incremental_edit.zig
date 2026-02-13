//! Incremental parsing example
//!
//! Demonstrates:
//! - Initial parse
//! - Applying edits to trees
//! - Reparsing incrementally
//! - Performance comparison

const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    const language = try grove.Languages.json.get();
    try parser.setLanguage(language);

    // Original source
    const original =
        \\{
        \\  "name": "grove",
        \\  "version": 1,
        \\  "enabled": true
        \\}
    ;

    // Initial parse
    var timer = try std.time.Timer.start();
    var tree = try parser.parseUtf8(null, original);
    const initial_ns = timer.read();

    std.debug.print("=== Initial Parse ===\n", .{});
    std.debug.print("Time: {d}us\n", .{initial_ns / 1000});
    printTreeSummary(tree);

    // Simulate editing "version": 1 -> "version": 2
    // The edit is at byte position 33 (the "1")
    const edit_start: u32 = 33;
    const old_text = "1";
    const new_text = "2";

    // Create edit description
    const edit = grove.InputEdit{
        .start_byte = edit_start,
        .old_end_byte = edit_start + @as(u32, @intCast(old_text.len)),
        .new_end_byte = edit_start + @as(u32, @intCast(new_text.len)),
        .start_point = .{ .row = 2, .column = 14 },
        .old_end_point = .{ .row = 2, .column = 15 },
        .new_end_point = .{ .row = 2, .column = 15 },
    };

    // Apply edit to old tree (marks changed regions)
    tree.edit(&edit);

    // New source after edit
    const updated =
        \\{
        \\  "name": "grove",
        \\  "version": 2,
        \\  "enabled": true
        \\}
    ;

    // Incremental reparse
    timer.reset();
    var new_tree = try parser.parseUtf8(&tree, updated);
    defer new_tree.deinit();
    const incremental_ns = timer.read();

    std.debug.print("\n=== Incremental Reparse ===\n", .{});
    std.debug.print("Time: {d}us\n", .{incremental_ns / 1000});
    printTreeSummary(new_tree);

    // Compare with full reparse
    timer.reset();
    var full_tree = try parser.parseUtf8(null, updated);
    defer full_tree.deinit();
    const full_ns = timer.read();

    std.debug.print("\n=== Full Reparse (comparison) ===\n", .{});
    std.debug.print("Time: {d}us\n", .{full_ns / 1000});

    // Speedup calculation
    if (incremental_ns > 0 and full_ns > incremental_ns) {
        const speedup = @as(f64, @floatFromInt(full_ns)) / @as(f64, @floatFromInt(incremental_ns));
        std.debug.print("\nIncremental speedup: {d:.1}x\n", .{speedup});
    }

    tree.deinit();
}

fn printTreeSummary(tree: grove.Tree) void {
    const root = tree.rootNode() orelse return;
    std.debug.print("Root: {s}, children: {d}\n", .{ root.kind(), root.childCount() });
}
