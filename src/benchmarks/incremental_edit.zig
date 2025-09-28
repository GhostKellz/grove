const std = @import("std");
const grove = @import("grove");

const EditOp = enum {
    insert,
    delete,
    replace,
};

const Edit = struct {
    op: EditOp,
    start_byte: u32,
    old_end_byte: u32,
    new_end_byte: u32,
    text: []const u8,
};

fn generateTypicalEdits(allocator: std.mem.Allocator) ![]Edit {
    // Simulate typical editing operations: inserting characters, deleting text, replacing words
    const edits = [_]Edit{
        // Insert a character
        .{ .op = .insert, .start_byte = 10, .old_end_byte = 10, .new_end_byte = 11, .text = "x" },
        // Insert a word
        .{ .op = .insert, .start_byte = 20, .old_end_byte = 20, .new_end_byte = 25, .text = "hello" },
        // Delete a few characters
        .{ .op = .delete, .start_byte = 30, .old_end_byte = 33, .new_end_byte = 30, .text = "" },
        // Replace a word
        .{ .op = .replace, .start_byte = 40, .old_end_byte = 45, .new_end_byte = 48, .text = "function" },
        // Insert newline and indentation
        .{ .op = .insert, .start_byte = 50, .old_end_byte = 50, .new_end_byte = 55, .text = "\n    " },
        // Delete a line
        .{ .op = .delete, .start_byte = 60, .old_end_byte = 80, .new_end_byte = 60, .text = "" },
    };

    const result = try allocator.alloc(Edit, edits.len);
    @memcpy(result, &edits);
    return result;
}

fn applyEdit(source: []const u8, allocator: std.mem.Allocator, edit: Edit) ![]u8 {
    switch (edit.op) {
        .insert => {
            var result = try allocator.alloc(u8, source.len + edit.text.len);
            @memcpy(result[0..edit.start_byte], source[0..edit.start_byte]);
            @memcpy(result[edit.start_byte..edit.start_byte + edit.text.len], edit.text);
            @memcpy(result[edit.start_byte + edit.text.len..], source[edit.start_byte..]);
            return result;
        },
        .delete => {
            var result = try allocator.alloc(u8, source.len - (edit.old_end_byte - edit.start_byte));
            @memcpy(result[0..edit.start_byte], source[0..edit.start_byte]);
            @memcpy(result[edit.start_byte..], source[edit.old_end_byte..]);
            return result;
        },
        .replace => {
            const old_len = edit.old_end_byte - edit.start_byte;
            const new_len = edit.text.len;
            var result = try allocator.alloc(u8, source.len - old_len + new_len);
            @memcpy(result[0..edit.start_byte], source[0..edit.start_byte]);
            @memcpy(result[edit.start_byte..edit.start_byte + new_len], edit.text);
            @memcpy(result[edit.start_byte + new_len..], source[edit.old_end_byte..]);
            return result;
        },
    }
}

fn benchmarkIncrementalEdits(
    allocator: std.mem.Allocator,
    parser: *grove.Parser,
    language: grove.Language,
    source: []const u8,
    edits: []const Edit,
) ![]u64 {
    try parser.setLanguage(language);

    var durations = try allocator.alloc(u64, edits.len);
    var current_source = try allocator.dupe(u8, source);
    defer allocator.free(current_source);

    // Parse initial source
    var tree = try parser.parseUtf8(null, current_source);
    defer tree.deinit();

    for (edits, 0..) |edit, i| {
        // Apply the edit to get new source
        const new_source = try applyEdit(current_source, allocator, edit);
        defer allocator.free(new_source);
        allocator.free(current_source);
        current_source = try allocator.dupe(u8, new_source);

        // Create TSInputEdit for Tree-sitter
        const input_edit = grove.c.TSInputEdit{
            .start_byte = edit.start_byte,
            .old_end_byte = edit.old_end_byte,
            .new_end_byte = edit.new_end_byte,
            .start_point = .{ .row = 0, .column = edit.start_byte },
            .old_end_point = .{ .row = 0, .column = edit.old_end_byte },
            .new_end_point = .{ .row = 0, .column = edit.new_end_byte },
        };

        // Time the incremental parse
        const start_time = std.time.nanoTimestamp();
        if (tree.raw()) |raw_tree| {
            grove.c.ts_tree_edit(raw_tree, &input_edit);
        }
        const new_tree = try parser.parseUtf8(&tree, new_source);
        const end_time = std.time.nanoTimestamp();

        durations[i] = @intCast(end_time - start_time);

        // Update tree for next iteration
        tree.deinit();
        tree = new_tree;
    }

    return durations;
}

fn calculatePercentile(durations: []u64, percentile: f64) u64 {
    var sorted_durations = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer sorted_durations.deinit();

    const sorted = sorted_durations.allocator().dupe(u64, durations) catch return 0;
    std.mem.sort(u64, sorted, {}, std.sort.asc(u64));

    const index = @as(usize, @intFromFloat(@as(f64, @floatFromInt(sorted.len - 1)) * percentile / 100.0));
    return sorted[index];
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    const iterations = 100; // Run many iterations to get good P50 measurement

    // Test with TypeScript since it's a complex language
    const typescript_lang = try grove.Languages.typescript.get();
    const typescript_source = @embedFile("data/large_typescript_file.ts");

    std.debug.print("=== Grove Incremental Edit Latency Benchmark ===\n", .{});
    std.debug.print("Testing with TypeScript source ({d} bytes)\n", .{typescript_source.len});
    std.debug.print("Iterations: {d}\n", .{iterations});
    std.debug.print("----------------------------------------------\n", .{});

    // For simplicity, let's use a fixed-size array for now
    var all_durations_array = [_]u64{0} ** (iterations * 6); // 6 edits per iteration
    var duration_count: usize = 0;

    // Run multiple iterations
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        const edits = try generateTypicalEdits(allocator);
        defer allocator.free(edits);

        const durations = try benchmarkIncrementalEdits(
            allocator,
            &parser,
            typescript_lang,
            typescript_source,
            edits
        );
        defer allocator.free(durations);

        for (durations) |duration| {
            if (duration_count < all_durations_array.len) {
                all_durations_array[duration_count] = duration;
                duration_count += 1;
            }
        }
    }

    const all_durations = all_durations_array[0..duration_count];

    // Calculate statistics
    const p50 = calculatePercentile(all_durations, 50.0);
    const p90 = calculatePercentile(all_durations, 90.0);
    const p99 = calculatePercentile(all_durations, 99.0);

    const p50_ms = @as(f64, @floatFromInt(p50)) / 1_000_000.0;
    const p90_ms = @as(f64, @floatFromInt(p90)) / 1_000_000.0;
    const p99_ms = @as(f64, @floatFromInt(p99)) / 1_000_000.0;

    std.debug.print("Incremental Edit Latency Results:\n", .{});
    std.debug.print("  P50: {d:.2} ms\n", .{p50_ms});
    std.debug.print("  P90: {d:.2} ms\n", .{p90_ms});
    std.debug.print("  P99: {d:.2} ms\n", .{p99_ms});
    std.debug.print("  Total edits: {d}\n", .{all_durations.len});

    if (p50_ms < 5.0) {
        std.debug.print("✅ SUCCESS: P50 < 5 ms goal achieved!\n", .{});
    } else {
        std.debug.print("❌ NEEDS IMPROVEMENT: P50 should be < 5 ms\n", .{});
    }
}