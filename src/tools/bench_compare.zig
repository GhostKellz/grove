const std = @import("std");
const grove = @import("grove");

/// Performance gate tool for CI/CD
/// Compares current benchmark results against baseline to prevent performance regressions
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Grove Performance Gate ===\n\n", .{});

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <command> [options]\n", .{args[0]});
        std.debug.print("Commands:\n", .{});
        std.debug.print("  baseline    Create performance baseline\n", .{});
        std.debug.print("  compare     Compare current performance against baseline\n", .{});
        std.debug.print("  report      Generate detailed performance report\n", .{});
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "baseline")) {
        try createBaseline(allocator);
    } else if (std.mem.eql(u8, command, "compare")) {
        const threshold = if (args.len >= 3) try std.fmt.parseFloat(f64, args[2]) else 10.0;
        try comparePerformance(allocator, threshold);
    } else if (std.mem.eql(u8, command, "report")) {
        try generateReport(allocator);
    } else {
        std.debug.print("❌ Unknown command: {s}\n", .{command});
        return;
    }
}

const BenchmarkResult = struct {
    name: []const u8,
    throughput_mbps: f64,
    latency_ms: f64,
    memory_mb: f64,
    timestamp: i64,
};

const PerformanceBaseline = struct {
    version: []const u8,
    created: i64,
    benchmarks: []BenchmarkResult,
};

fn createBaseline(allocator: std.mem.Allocator) !void {
    std.debug.print("📊 Creating performance baseline...\n\n", .{});

    // Run benchmarks
    const results = try runBenchmarks(allocator);
    defer allocator.free(results);

    // Save baseline
    const baseline = PerformanceBaseline{
        .version = "RC1",
        .created = std.time.timestamp(),
        .benchmarks = results,
    };

    try saveBaseline(allocator, baseline);

    std.debug.print("✅ Baseline created with {d} benchmarks\n", .{results.len});
    for (results) |result| {
        std.debug.print("  {s}: {d:.2} MB/s, {d:.3} ms latency\n", .{
            result.name, result.throughput_mbps, result.latency_ms
        });
    }
}

fn comparePerformance(allocator: std.mem.Allocator, threshold_percent: f64) !void {
    std.debug.print("🔍 Comparing performance against baseline...\n", .{});
    std.debug.print("Regression threshold: {d:.1}%\n\n", .{threshold_percent});

    // Load baseline
    const baseline = loadBaseline(allocator) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("⚠️  No baseline found. Run 'baseline' command first.\n", .{});
            return;
        }
        return err;
    };
    defer {
        allocator.free(baseline.version);
        // Names from JSON are allocated and need to be freed
        for (baseline.benchmarks) |result| {
            allocator.free(result.name);
        }
        allocator.free(baseline.benchmarks);
    }

    // Run current benchmarks
    const current_results = try runBenchmarks(allocator);
    defer {
        // Names are now string literals, don't need to free them
        allocator.free(current_results);
    }

    // Compare results
    var regressions_found = false;
    var improvements_found = false;

    std.debug.print("Performance Comparison:\n", .{});
    std.debug.print("{s: <25} {s: <12} {s: <12} {s: <12}\n", .{ "Benchmark", "Baseline", "Current", "Change" });
    std.debug.print("----------------------------------------------------------------\n", .{});

    for (current_results) |current| {
        const baseline_result = findBenchmark(baseline.benchmarks, current.name);
        if (baseline_result == null) {
            std.debug.print("{s: <25} {s: <12} {d: <12.2} {s: <12}\n", .{
                current.name, "NEW", current.throughput_mbps, "N/A"
            });
            continue;
        }

        const baseline_throughput = baseline_result.?.throughput_mbps;
        const current_throughput = current.throughput_mbps;
        const change_percent = ((current_throughput - baseline_throughput) / baseline_throughput) * 100.0;

        const change_str = if (change_percent > 0)
            try std.fmt.allocPrint(allocator, "+{d:.1}%", .{change_percent})
        else
            try std.fmt.allocPrint(allocator, "{d:.1}%", .{change_percent});
        defer allocator.free(change_str);

        const status = if (change_percent < -threshold_percent) "🔴" else if (change_percent > 5.0) "🟢" else "⚪";

        std.debug.print("{s} {s: <23} {d: <12.2} {d: <12.2} {s: <12}\n", .{
            status, current.name, baseline_throughput, current_throughput, change_str
        });

        if (change_percent < -threshold_percent) {
            regressions_found = true;
        } else if (change_percent > 5.0) {
            improvements_found = true;
        }
    }

    // Check for missing benchmarks
    for (baseline.benchmarks) |baseline_bench| {
        const current_result = findBenchmark(current_results, baseline_bench.name);
        if (current_result == null) {
            std.debug.print("⚠️  {s: <25} {d: <12.2} {s: <12} {s: <12}\n", .{
                baseline_bench.name, baseline_bench.throughput_mbps, "MISSING", "REMOVED"
            });
            regressions_found = true;
        }
    }

    std.debug.print("\n", .{});

    // Summary
    if (regressions_found) {
        std.debug.print("❌ Performance regressions detected!\n", .{});
        std.debug.print("Benchmarks declined by more than {d:.1}% threshold.\n", .{threshold_percent});
        std.process.exit(1);
    } else if (improvements_found) {
        std.debug.print("🎉 Performance improvements detected!\n", .{});
        std.debug.print("Some benchmarks show significant gains.\n", .{});
    } else {
        std.debug.print("✅ Performance within acceptable range.\n", .{});
        std.debug.print("No significant regressions or improvements.\n", .{});
    }
}

fn generateReport(allocator: std.mem.Allocator) !void {
    std.debug.print("📈 Generating performance report...\n\n", .{});

    // Load baseline
    const baseline = loadBaseline(allocator) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("⚠️  No baseline found. Creating new baseline...\n", .{});
            try createBaseline(allocator);
            return;
        }
        return err;
    };
    defer {
        allocator.free(baseline.version);
        // Names from JSON are allocated and need to be freed
        for (baseline.benchmarks) |result| {
            allocator.free(result.name);
        }
        allocator.free(baseline.benchmarks);
    }

    // Run current benchmarks
    const current_results = try runBenchmarks(allocator);
    defer {
        // Names are now string literals, don't need to free them
        allocator.free(current_results);
    }

    // Generate JSON report
    const report = try generateJsonReport(allocator, baseline, current_results);
    defer allocator.free(report);

    // Write to file
    const file = try std.fs.cwd().createFile("grove-performance-report.json", .{});
    defer file.close();
    try file.writeAll(report);

    std.debug.print("✅ Performance report saved to grove-performance-report.json\n", .{});
}

fn runBenchmarks(allocator: std.mem.Allocator) ![]BenchmarkResult {
    var results = std.ArrayList(BenchmarkResult){};
    defer results.deinit(allocator);

    // Throughput benchmarks
    try results.append(allocator, try benchmarkThroughput(allocator, "TypeScript Large", getTypeScriptLargeSource()));
    try results.append(allocator, try benchmarkThroughput(allocator, "Zig Large", getZigLargeSource()));
    try results.append(allocator, try benchmarkThroughput(allocator, "JSON Medium", getJsonMediumSource()));
    // Rust not available yet
    // try results.append(allocator, try benchmarkThroughput(allocator, "Rust Medium", getRustMediumSource()));

    // Incremental parsing benchmarks
    try results.append(allocator, try benchmarkIncremental(allocator, "TypeScript Incremental"));
    try results.append(allocator, try benchmarkIncremental(allocator, "Zig Incremental"));

    return results.toOwnedSlice(allocator);
}

fn benchmarkThroughput(allocator: std.mem.Allocator, name: []const u8, source: []const u8) !BenchmarkResult {
    const iterations = 100;
    const language = if (std.mem.indexOf(u8, name, "TypeScript") != null)
        try grove.Languages.typescript.get()
    else if (std.mem.indexOf(u8, name, "Zig") != null)
        try grove.Languages.zig.get()
    else if (std.mem.indexOf(u8, name, "JSON") != null)
        try grove.Languages.json.get()
    else if (std.mem.indexOf(u8, name, "Rust") != null)
        try grove.Languages.rust.get()
    else
        try grove.Languages.json.get();

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();
    try parser.setLanguage(language);

    const start_time = std.time.nanoTimestamp();
    var total_bytes: u64 = 0;

    for (0..iterations) |_| {
        var tree = try parser.parseUtf8(null, source);
        tree.deinit();
        total_bytes += source.len;
    }

    const end_time = std.time.nanoTimestamp();
    const duration_ns = @as(f64, @floatFromInt(end_time - start_time));
    const duration_s = duration_ns / 1_000_000_000.0;
    const throughput_bps = @as(f64, @floatFromInt(total_bytes)) / duration_s;
    const throughput_mbps = throughput_bps / (1024.0 * 1024.0);

    return BenchmarkResult{
        .name = name, // Don't dupe, just use the string literal
        .throughput_mbps = throughput_mbps,
        .latency_ms = (duration_s * 1000.0) / @as(f64, @floatFromInt(iterations)),
        .memory_mb = 0.0, // TODO: Add memory tracking
        .timestamp = std.time.timestamp(),
    };
}

fn benchmarkIncremental(allocator: std.mem.Allocator, name: []const u8) !BenchmarkResult {
    const iterations = 1000;
    const base_source = "function test() { return 42; }";
    const edit_source = "function test() { return 24; }";

    const language = if (std.mem.indexOf(u8, name, "TypeScript") != null)
        try grove.Languages.typescript.get()
    else
        try grove.Languages.zig.get();

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();
    try parser.setLanguage(language);

    // Parse initial tree
    var tree = try parser.parseUtf8(null, base_source);
    defer tree.deinit();

    const start_time = std.time.nanoTimestamp();

    for (0..iterations) |_| {
        var new_tree = try parser.parseUtf8(&tree, edit_source);
        new_tree.deinit();
    }

    const end_time = std.time.nanoTimestamp();
    const duration_ns = @as(f64, @floatFromInt(end_time - start_time));
    const duration_s = duration_ns / 1_000_000_000.0;
    const avg_latency_ms = (duration_s * 1000.0) / @as(f64, @floatFromInt(iterations));

    // Estimate throughput based on incremental parsing efficiency
    const source_size = edit_source.len;
    const throughput_mbps = (@as(f64, @floatFromInt(source_size * iterations)) / (1024.0 * 1024.0)) / duration_s;

    return BenchmarkResult{
        .name = name, // Don't dupe, just use the string literal
        .throughput_mbps = throughput_mbps,
        .latency_ms = avg_latency_ms,
        .memory_mb = 0.0,
        .timestamp = std.time.timestamp(),
    };
}

fn findBenchmark(benchmarks: []const BenchmarkResult, name: []const u8) ?BenchmarkResult {
    for (benchmarks) |benchmark| {
        if (std.mem.eql(u8, benchmark.name, name)) {
            return benchmark;
        }
    }
    return null;
}

fn saveBaseline(allocator: std.mem.Allocator, baseline: PerformanceBaseline) !void {
    const json = try generateBaselineJson(allocator, baseline);
    defer allocator.free(json);

    const file = try std.fs.cwd().createFile("grove-performance-baseline.json", .{});
    defer file.close();
    try file.writeAll(json);
}

fn loadBaseline(allocator: std.mem.Allocator) !PerformanceBaseline {
    const file = try std.fs.cwd().openFile("grove-performance-baseline.json", .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const max_size = @min(file_size, 1024 * 1024); // 1MB limit
    const content = try allocator.alloc(u8, max_size);
    defer allocator.free(content);
    _ = try file.readAll(content);

    return parseBaselineJson(allocator, content);
}

fn generateBaselineJson(allocator: std.mem.Allocator, baseline: PerformanceBaseline) ![]u8 {
    var json = std.ArrayList(u8){};
    defer json.deinit(allocator);

    try json.appendSlice(allocator, "{\n");
    try json.appendSlice(allocator, "  \"version\": \"");
    try json.appendSlice(allocator, baseline.version);
    try json.appendSlice(allocator, "\",\n");

    const created_str = try std.fmt.allocPrint(allocator, "  \"created\": {d},\n", .{baseline.created});
    defer allocator.free(created_str);
    try json.appendSlice(allocator, created_str);

    try json.appendSlice(allocator, "  \"benchmarks\": [\n");

    for (baseline.benchmarks, 0..) |bench, i| {
        try json.appendSlice(allocator, "    {\n");

        const name_line = try std.fmt.allocPrint(allocator, "      \"name\": \"{s}\",\n", .{bench.name});
        defer allocator.free(name_line);
        try json.appendSlice(allocator, name_line);

        const throughput_line = try std.fmt.allocPrint(allocator, "      \"throughput_mbps\": {d},\n", .{bench.throughput_mbps});
        defer allocator.free(throughput_line);
        try json.appendSlice(allocator, throughput_line);

        const latency_line = try std.fmt.allocPrint(allocator, "      \"latency_ms\": {d},\n", .{bench.latency_ms});
        defer allocator.free(latency_line);
        try json.appendSlice(allocator, latency_line);

        const memory_line = try std.fmt.allocPrint(allocator, "      \"memory_mb\": {d},\n", .{bench.memory_mb});
        defer allocator.free(memory_line);
        try json.appendSlice(allocator, memory_line);

        const timestamp_line = try std.fmt.allocPrint(allocator, "      \"timestamp\": {d}\n", .{bench.timestamp});
        defer allocator.free(timestamp_line);
        try json.appendSlice(allocator, timestamp_line);

        if (i < baseline.benchmarks.len - 1) {
            try json.appendSlice(allocator, "    },\n");
        } else {
            try json.appendSlice(allocator, "    }\n");
        }
    }

    try json.appendSlice(allocator, "  ]\n");
    try json.appendSlice(allocator, "}\n");

    return json.toOwnedSlice(allocator);
}

fn generateJsonReport(allocator: std.mem.Allocator, baseline: PerformanceBaseline, current: []const BenchmarkResult) ![]u8 {
    var json = std.ArrayList(u8){};
    defer json.deinit(allocator);

    try json.appendSlice(allocator, "{\n");
    try json.appendSlice(allocator, "  \"report_type\": \"performance_comparison\",\n");

    const timestamp_str = try std.fmt.allocPrint(allocator, "  \"generated\": {d},\n", .{std.time.timestamp()});
    defer allocator.free(timestamp_str);
    try json.appendSlice(allocator, timestamp_str);

    try json.appendSlice(allocator, "  \"baseline\": {\n");
    try json.appendSlice(allocator, "    \"version\": \"");
    try json.appendSlice(allocator, baseline.version);
    try json.appendSlice(allocator, "\",\n");

    const baseline_created_str = try std.fmt.allocPrint(allocator, "    \"created\": {d}\n", .{baseline.created});
    defer allocator.free(baseline_created_str);
    try json.appendSlice(allocator, baseline_created_str);

    try json.appendSlice(allocator, "  },\n");
    try json.appendSlice(allocator, "  \"comparisons\": [\n");

    for (current, 0..) |curr, i| {
        const baseline_result = findBenchmark(baseline.benchmarks, curr.name);

        try json.appendSlice(allocator, "    {\n");

        const name_line = try std.fmt.allocPrint(allocator, "      \"name\": \"{s}\",\n", .{curr.name});
        defer allocator.free(name_line);
        try json.appendSlice(allocator, name_line);

        const curr_throughput_line = try std.fmt.allocPrint(allocator, "      \"current_throughput_mbps\": {d},\n", .{curr.throughput_mbps});
        defer allocator.free(curr_throughput_line);
        try json.appendSlice(allocator, curr_throughput_line);

        if (baseline_result) |baseline_bench| {
            const baseline_throughput_line = try std.fmt.allocPrint(allocator, "      \"baseline_throughput_mbps\": {d},\n", .{baseline_bench.throughput_mbps});
            defer allocator.free(baseline_throughput_line);
            try json.appendSlice(allocator, baseline_throughput_line);

            const change_percent = ((curr.throughput_mbps - baseline_bench.throughput_mbps) / baseline_bench.throughput_mbps) * 100.0;
            const change_line = try std.fmt.allocPrint(allocator, "      \"change_percent\": {d}\n", .{change_percent});
            defer allocator.free(change_line);
            try json.appendSlice(allocator, change_line);
        } else {
            try json.appendSlice(allocator, "      \"baseline_throughput_mbps\": null,\n");
            try json.appendSlice(allocator, "      \"change_percent\": null\n");
        }

        if (i < current.len - 1) {
            try json.appendSlice(allocator, "    },\n");
        } else {
            try json.appendSlice(allocator, "    }\n");
        }
    }

    try json.appendSlice(allocator, "  ]\n");
    try json.appendSlice(allocator, "}\n");

    return json.toOwnedSlice(allocator);
}

fn parseBaselineJson(allocator: std.mem.Allocator, content: []const u8) !PerformanceBaseline {
    // Simple JSON parsing - in production use a proper JSON parser
    const version = try extractJsonString(allocator, content, "version");
    const created = try extractJsonNumber(content, "created");

    // Parse benchmarks array
    var benchmarks = std.ArrayList(BenchmarkResult){};
    defer benchmarks.deinit(allocator);

    const benchmarks_start = std.mem.indexOf(u8, content, "\"benchmarks\": [") orelse return error.InvalidFormat;
    const benchmarks_content = content[benchmarks_start..];

    var pos: usize = 0;
    while (pos < benchmarks_content.len) {
        const entry_start = std.mem.indexOfPos(u8, benchmarks_content, pos, "{") orelse break;
        const entry_end = std.mem.indexOfPos(u8, benchmarks_content, entry_start, "}") orelse break;

        const entry_content = benchmarks_content[entry_start..entry_end + 1];

        const name = try extractJsonString(allocator, entry_content, "name");
        const throughput = try extractJsonFloat(entry_content, "throughput_mbps");
        const latency = try extractJsonFloat(entry_content, "latency_ms");
        const memory = try extractJsonFloat(entry_content, "memory_mb");
        const timestamp = try extractJsonNumber(entry_content, "timestamp");

        try benchmarks.append(allocator, BenchmarkResult{
            .name = name,
            .throughput_mbps = throughput,
            .latency_ms = latency,
            .memory_mb = memory,
            .timestamp = timestamp,
        });

        pos = entry_end + 1;
    }

    return PerformanceBaseline{
        .version = version,
        .created = created,
        .benchmarks = try benchmarks.toOwnedSlice(allocator),
    };
}

fn extractJsonString(allocator: std.mem.Allocator, json: []const u8, key: []const u8) ![]u8 {
    const search_pattern = try std.fmt.allocPrint(allocator, "\"{s}\": \"", .{key});
    defer allocator.free(search_pattern);

    const start = std.mem.indexOf(u8, json, search_pattern) orelse return error.KeyNotFound;
    const value_start = start + search_pattern.len;
    const value_end = std.mem.indexOfPos(u8, json, value_start, "\"") orelse return error.InvalidFormat;

    return try allocator.dupe(u8, json[value_start..value_end]);
}

fn extractJsonNumber(json: []const u8, key: []const u8) !i64 {
    const search_pattern = try std.fmt.allocPrint(std.heap.page_allocator, "\"{s}\": ", .{key});
    defer std.heap.page_allocator.free(search_pattern);

    const start = std.mem.indexOf(u8, json, search_pattern) orelse return error.KeyNotFound;
    const value_start = start + search_pattern.len;

    var value_end = value_start;
    while (value_end < json.len and (std.ascii.isDigit(json[value_end]) or json[value_end] == '-')) {
        value_end += 1;
    }

    return try std.fmt.parseInt(i64, json[value_start..value_end], 10);
}

fn extractJsonFloat(json: []const u8, key: []const u8) !f64 {
    const search_pattern = try std.fmt.allocPrint(std.heap.page_allocator, "\"{s}\": ", .{key});
    defer std.heap.page_allocator.free(search_pattern);

    const start = std.mem.indexOf(u8, json, search_pattern) orelse return error.KeyNotFound;
    const value_start = start + search_pattern.len;

    var value_end = value_start;
    while (value_end < json.len and (std.ascii.isDigit(json[value_end]) or json[value_end] == '.' or json[value_end] == '-' or json[value_end] == 'e' or json[value_end] == 'E' or json[value_end] == '+')) {
        value_end += 1;
    }

    return try std.fmt.parseFloat(f64, json[value_start..value_end]);
}

// Sample source code for benchmarks
fn getTypeScriptLargeSource() []const u8 {
    return
        \\interface Calculator {
        \\  value: number;
        \\  add(x: number): number;
        \\  multiply(x: number): number;
        \\  divide(x: number): number;
        \\  subtract(x: number): number;
        \\}
        \\
        \\class ScientificCalculator implements Calculator {
        \\  private _value: number = 0;
        \\
        \\  get value(): number {
        \\    return this._value;
        \\  }
        \\
        \\  add(x: number): number {
        \\    this._value += x;
        \\    return this._value;
        \\  }
        \\
        \\  multiply(x: number): number {
        \\    this._value *= x;
        \\    return this._value;
        \\  }
        \\
        \\  divide(x: number): number {
        \\    if (x === 0) throw new Error("Division by zero");
        \\    this._value /= x;
        \\    return this._value;
        \\  }
        \\
        \\  subtract(x: number): number {
        \\    this._value -= x;
        \\    return this._value;
        \\  }
        \\
        \\  power(exponent: number): number {
        \\    this._value = Math.pow(this._value, exponent);
        \\    return this._value;
        \\  }
        \\
        \\  sqrt(): number {
        \\    this._value = Math.sqrt(this._value);
        \\    return this._value;
        \\  }
        \\}
        \\
        \\function createCalculator(): Calculator {
        \\  return new ScientificCalculator();
        \\}
        \\
        \\const calc = createCalculator();
        \\const result = calc.add(10).multiply(2).subtract(5).divide(3);
        \\console.log(`Result: ${result}`);
    ;
}

fn getZigLargeSource() []const u8 {
    return
        \\const std = @import("std");
        \\
        \\const Point = struct {
        \\    x: f64,
        \\    y: f64,
        \\
        \\    pub fn init(x: f64, y: f64) Point {
        \\        return Point{ .x = x, .y = y };
        \\    }
        \\
        \\    pub fn distance(self: Point, other: Point) f64 {
        \\        const dx = self.x - other.x;
        \\        const dy = self.y - other.y;
        \\        return @sqrt(dx * dx + dy * dy);
        \\    }
        \\
        \\    pub fn add(self: Point, other: Point) Point {
        \\        return Point{ .x = self.x + other.x, .y = self.y + other.y };
        \\    }
        \\
        \\    pub fn scale(self: Point, factor: f64) Point {
        \\        return Point{ .x = self.x * factor, .y = self.y * factor };
        \\    }
        \\};
        \\
        \\const Circle = struct {
        \\    center: Point,
        \\    radius: f64,
        \\
        \\    pub fn init(center: Point, radius: f64) Circle {
        \\        return Circle{ .center = center, .radius = radius };
        \\    }
        \\
        \\    pub fn area(self: Circle) f64 {
        \\        return std.math.pi * self.radius * self.radius;
        \\    }
        \\
        \\    pub fn circumference(self: Circle) f64 {
        \\        return 2.0 * std.math.pi * self.radius;
        \\    }
        \\
        \\    pub fn contains(self: Circle, point: Point) bool {
        \\        return self.center.distance(point) <= self.radius;
        \\    }
        \\};
        \\
        \\pub fn main() void {
        \\    const center = Point.init(0.0, 0.0);
        \\    const circle = Circle.init(center, 5.0);
        \\    const test_point = Point.init(3.0, 4.0);
        \\
        \\    std.debug.print("Circle area: {d}\n", .{circle.area()});
        \\    std.debug.print("Point in circle: {any}\n", .{circle.contains(test_point)});
        \\}
    ;
}

fn getJsonMediumSource() []const u8 {
    return
        \\{
        \\  "name": "grove-performance-test",
        \\  "version": "1.0.0",
        \\  "description": "Performance testing data for Grove parser",
        \\  "keywords": ["parser", "tree-sitter", "performance"],
        \\  "author": {
        \\    "name": "Grove Team",
        \\    "email": "team@grove.dev"
        \\  },
        \\  "dependencies": {
        \\    "tree-sitter": "^0.20.0",
        \\    "typescript": "^4.9.0"
        \\  },
        \\  "devDependencies": {
        \\    "zig": "^0.16.0",
        \\    "eslint": "^8.0.0",
        \\    "prettier": "^2.8.0"
        \\  },
        \\  "scripts": {
        \\    "build": "zig build",
        \\    "test": "zig test",
        \\    "bench": "zig build bench",
        \\    "lint": "eslint .",
        \\    "format": "prettier --write ."
        \\  },
        \\  "repository": {
        \\    "type": "git",
        \\    "url": "https://github.com/grove-team/grove.git"
        \\  },
        \\  "license": "MIT",
        \\  "engines": {
        \\    "node": ">=16.0.0"
        \\  },
        \\  "config": {
        \\    "benchmark": {
        \\      "iterations": 1000,
        \\      "warmup": 100,
        \\      "timeout": 30000
        \\    }
        \\  }
        \\}
    ;
}

fn getRustMediumSource() []const u8 {
    return
        \\use std::collections::HashMap;
        \\
        \\#[derive(Debug, Clone)]
        \\struct Point {
        \\    x: f64,
        \\    y: f64,
        \\}
        \\
        \\impl Point {
        \\    fn new(x: f64, y: f64) -> Self {
        \\        Point { x, y }
        \\    }
        \\
        \\    fn distance(&self, other: &Point) -> f64 {
        \\        let dx = self.x - other.x;
        \\        let dy = self.y - other.y;
        \\        (dx * dx + dy * dy).sqrt()
        \\    }
        \\}
        \\
        \\struct PointManager {
        \\    points: HashMap<String, Point>,
        \\}
        \\
        \\impl PointManager {
        \\    fn new() -> Self {
        \\        PointManager {
        \\            points: HashMap::new(),
        \\        }
        \\    }
        \\
        \\    fn add_point(&mut self, name: String, point: Point) {
        \\        self.points.insert(name, point);
        \\    }
        \\
        \\    fn get_point(&self, name: &str) -> Option<&Point> {
        \\        self.points.get(name)
        \\    }
        \\
        \\    fn calculate_distances(&self) -> Vec<(String, String, f64)> {
        \\        let mut distances = Vec::new();
        \\        let point_names: Vec<_> = self.points.keys().collect();
        \\
        \\        for i in 0..point_names.len() {
        \\            for j in (i + 1)..point_names.len() {
        \\                if let (Some(p1), Some(p2)) = (
        \\                    self.points.get(point_names[i]),
        \\                    self.points.get(point_names[j])
        \\                ) {
        \\                    let dist = p1.distance(p2);
        \\                    distances.push((
        \\                        point_names[i].clone(),
        \\                        point_names[j].clone(),
        \\                        dist
        \\                    ));
        \\                }
        \\            }
        \\        }
        \\
        \\        distances
        \\    }
        \\}
        \\
        \\fn main() {
        \\    let mut manager = PointManager::new();
        \\    manager.add_point("origin".to_string(), Point::new(0.0, 0.0));
        \\    manager.add_point("unit".to_string(), Point::new(1.0, 1.0));
        \\
        \\    let distances = manager.calculate_distances();
        \\    for (p1, p2, dist) in distances {
        \\        println!("Distance from {} to {}: {:.2}", p1, p2, dist);
        \\    }
        \\}
    ;
}