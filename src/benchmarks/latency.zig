const std = @import("std");
const grove = @import("grove");

const Edit = struct {
    offset: usize,
    delete_len: usize,
    insert_text: []const u8,
};

fn applyEdit(allocator: std.mem.Allocator, original: []const u8, edit: Edit) ![]u8 {
    std.debug.assert(edit.offset <= original.len);
    std.debug.assert(edit.offset + edit.delete_len <= original.len);

    const head = original[0..edit.offset];
    const tail = original[(edit.offset + edit.delete_len)..];

    const new_len = head.len + edit.insert_text.len + tail.len;
    var buffer = try allocator.alloc(u8, new_len);
    std.mem.copyForwards(u8, buffer[0..head.len], head);
    std.mem.copyForwards(u8, buffer[head.len .. head.len + edit.insert_text.len], edit.insert_text);
    std.mem.copyForwards(u8, buffer[head.len + edit.insert_text.len ..], tail);
    return buffer;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const language = try grove.Languages.typescript.get();

    const source = @embedFile("data/latency_seed.ts");
    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();
    try parser.setLanguage(language);

    const edits = [_]Edit{
        .{ .offset = 120, .delete_len = 0, .insert_text = "\nconst nextValue = calc.multiply(3);" },
        .{ .offset = 260, .delete_len = 12, .insert_text = "Math.round(result)" },
        .{ .offset = 45, .delete_len = 0, .insert_text = "// hot loop\n" },
        .{ .offset = 320, .delete_len = 0, .insert_text = "\ncalc.reset();" },
    };

    const rounds: usize = 250;
    var samples = try allocator.alloc(f64, edits.len * rounds);
    defer allocator.free(samples);

    var sample_index: usize = 0;

    for (0..rounds) |_| {
    var working_source = try allocator.dupe(u8, source);
    errdefer allocator.free(working_source);

    var working_tree = try parser.parseUtf8(null, working_source);
    errdefer working_tree.deinit();

        for (edits) |edit| {
            const start_time = std.time.nanoTimestamp();
            const updated = try applyEdit(allocator, working_source, edit);
            const new_tree = try parser.parseUtf8(&working_tree, updated);
            const end_time = std.time.nanoTimestamp();

            const duration_ns = @as(f64, @floatFromInt(end_time - start_time));
            samples[sample_index] = duration_ns / 1_000_000.0;
            sample_index += 1;

            allocator.free(working_source);
            working_tree.deinit();
            working_source = updated;
            working_tree = new_tree;
        }

        allocator.free(working_source);
        working_tree.deinit();
    }

    std.sort.block(f64, samples, {}, std.sort.asc(f64));
    const total_samples = samples.len;
    const p50 = samples[total_samples / 2];
    const p95 = samples[(total_samples * 95) / 100];

    var accumulator: f64 = 0.0;
    for (samples) |value| accumulator += value;
    const avg = accumulator / @as(f64, @floatFromInt(samples.len));

    std.debug.print("=== Grove Incremental Latency Benchmark ===\n", .{});
    std.debug.print("Samples: {d}\n", .{samples.len});
    std.debug.print("Average latency: {d:.4} ms\n", .{avg});
    std.debug.print("P50 latency: {d:.4} ms\n", .{p50});
    std.debug.print("P95 latency: {d:.4} ms\n", .{p95});
    std.debug.print("Target (P50 < 5 ms): {s}\n", .{if (p50 < 5.0) "✅ PASS" else "❌ FAIL"});
}
