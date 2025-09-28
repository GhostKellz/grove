const std = @import("std");
const grove = @import("grove");

const BenchmarkResult = struct {
    name: []const u8,
    bytes: usize,
    duration_ns: u64,
    throughput_bytes_per_sec: u64,
};

fn benchmarkLanguage(
    parser: *grove.Parser,
    language: grove.Language,
    name: []const u8,
    source: []const u8,
    iterations: u32,
) !BenchmarkResult {
    try parser.setLanguage(language);

    var total_duration: u64 = 0;
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        var report = try parser.parseUtf8Timed(null, source);
        defer report.tree.deinit();
        total_duration += report.duration_ns;
    }

    const avg_duration_ns = total_duration / iterations;
    const throughput = if (avg_duration_ns == 0) 0 else (source.len * std.time.ns_per_s) / avg_duration_ns;

    return BenchmarkResult{
        .name = name,
        .bytes = source.len,
        .duration_ns = avg_duration_ns,
        .throughput_bytes_per_sec = throughput,
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    const iterations = 5; // Run each test 5 times and average

    // Benchmark all languages
    const zig_small = @embedFile("data/zig_sample.zig");
    const zig_large = @embedFile("data/large_zig_file.zig");
    const zig_lang = try grove.Languages.zig.get();

    const typescript_large = @embedFile("data/large_typescript_file.ts");
    const typescript_lang = try grove.Languages.typescript.get();

    const json_sample =
        \\{
        \\  "name": "test",
        \\  "version": "1.0.0",
        \\  "dependencies": {
        \\    "grove": "latest",
        \\    "tree-sitter": "^0.20.0"
        \\  },
        \\  "scripts": {
        \\    "build": "zig build",
        \\    "test": "zig build test"
        \\  }
        \\}
    ;
    const json_lang = try grove.Languages.json.get();

    const results = [_]BenchmarkResult{
        try benchmarkLanguage(&parser, zig_lang, "Zig (small)", zig_small, iterations),
        try benchmarkLanguage(&parser, zig_lang, "Zig (large)", zig_large, iterations),
        try benchmarkLanguage(&parser, typescript_lang, "TypeScript (large)", typescript_large, iterations),
        try benchmarkLanguage(&parser, json_lang, "JSON", json_sample, iterations),
    };

    // Print results
    std.debug.print("=== Grove Performance Benchmark Results ===\n", .{});
    std.debug.print("{s:<20} {s:>12} {s:>15} {s:>18}\n", .{ "Language", "Size (bytes)", "Time (μs)", "Throughput (MB/s)" });
    std.debug.print("{s}\n", .{"-" ** 70});

    var total_throughput: f64 = 0;
    for (results) |result| {
        const throughput_mb_s = @as(f64, @floatFromInt(result.throughput_bytes_per_sec)) / (1024.0 * 1024.0);
        const duration_us = @as(f64, @floatFromInt(result.duration_ns)) / 1000.0;
        total_throughput += throughput_mb_s;

        std.debug.print("{s:<20} {d:>12} {d:>15.1} {d:>18.2}\n", .{
            result.name,
            result.bytes,
            duration_us,
            throughput_mb_s
        });
    }

    const avg_throughput = total_throughput / @as(f64, @floatFromInt(results.len));
    std.debug.print("{s}\n", .{"-" ** 70});
    std.debug.print("Average throughput: {d:.2} MB/s\n", .{avg_throughput});

    if (avg_throughput >= 10.0) {
        std.debug.print("✅ SUCCESS: Achieved ≥10 MB/s goal!\n", .{});
    } else {
        std.debug.print("❌ NEEDS IMPROVEMENT: Target is ≥10 MB/s\n", .{});
    }
}
