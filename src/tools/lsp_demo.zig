const std = @import("std");
const grove = @import("grove");

/// LSP capabilities demonstration tool
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Grove LSP Helper Demo ===\n\n", .{});

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <language>\n", .{args[0]});
        std.debug.print("Languages: typescript, zig, json, rust, ghostlang\n", .{});
        std.debug.print("Example: {s} typescript\n", .{args[0]});
        return;
    }

    const language_name = args[1];
    std.debug.print("Language: {s}\n", .{language_name});

    // Create language server factory
    const factory = grove.LSP.LanguageServerFactory.init(allocator);

    // Create language server for the specified language
    var server = factory.createServer(language_name) catch |err| {
        std.debug.print("❌ Failed to create server for {s}: {}\n", .{ language_name, err });
        return;
    };
    defer server.deinit();

    std.debug.print("✅ Created {s} language server\n\n", .{language_name});

    // Demo source code based on language
    const demo_result = if (std.mem.eql(u8, language_name, "typescript"))
        try demoTypeScript(&server, allocator)
    else if (std.mem.eql(u8, language_name, "zig"))
        try demoZig(&server, allocator)
    else if (std.mem.eql(u8, language_name, "json"))
        try demoJSON(&server, allocator)
    else if (std.mem.eql(u8, language_name, "rust"))
        try demoRust(&server, allocator)
    else if (std.mem.eql(u8, language_name, "ghostlang"))
        try demoGhostlang(&server, allocator)
    else {
        std.debug.print("❌ Unsupported language for demo: {s}\n", .{language_name});
        return;
    };

    defer demo_result.cleanup(allocator);

    std.debug.print("✅ LSP demo completed successfully!\n");
}

const DemoResult = struct {
    symbols: []grove.LSP.DocumentSymbol,
    folding_ranges: []grove.LSP.FoldingRange,
    diagnostics: []grove.LSP.Diagnostic,

    fn cleanup(self: DemoResult, allocator: std.mem.Allocator) void {
        allocator.free(self.symbols);
        allocator.free(self.folding_ranges);
        allocator.free(self.diagnostics);
    }
};

fn demoTypeScript(server: *grove.LSP.LanguageServer, allocator: std.mem.Allocator) !DemoResult {
    const source =
        \\class Calculator {
        \\  private value: number = 0;
        \\
        \\  add(x: number): number {
        \\    this.value += x;
        \\    return this.value;
        \\  }
        \\
        \\  multiply(x: number): number {
        \\    this.value *= x;
        \\    return this.value;
        \\  }
        \\
        \\  getValue(): number {
        \\    return this.value;
        \\  }
        \\}
        \\
        \\function createCalculator() {
        \\  return new Calculator();
        \\}
        \\
        \\const calc = createCalculator();
        \\const result = calc.add(5).multiply(2);
    ;

    return demoLanguage(server, allocator, source, "TypeScript");
}

fn demoZig(server: *grove.LSP.LanguageServer, allocator: std.mem.Allocator) !DemoResult {
    const source =
        \\const std = @import("std");
        \\
        \\const Point = struct {
        \\    x: f32,
        \\    y: f32,
        \\
        \\    pub fn init(x: f32, y: f32) Point {
        \\        return Point{ .x = x, .y = y };
        \\    }
        \\
        \\    pub fn distance(self: Point, other: Point) f32 {
        \\        const dx = self.x - other.x;
        \\        const dy = self.y - other.y;
        \\        return @sqrt(dx * dx + dy * dy);
        \\    }
        \\};
        \\
        \\pub fn main() void {
        \\    const p1 = Point.init(0, 0);
        \\    const p2 = Point.init(3, 4);
        \\    const dist = p1.distance(p2);
        \\    std.debug.print("Distance: {d}\n", .{dist});
        \\}
    ;

    return demoLanguage(server, allocator, source, "Zig");
}

fn demoJSON(server: *grove.LSP.LanguageServer, allocator: std.mem.Allocator) !DemoResult {
    const source =
        \\{
        \\  "name": "grove-demo",
        \\  "version": "1.0.0",
        \\  "description": "Grove LSP demo",
        \\  "author": "Grove Team",
        \\  "dependencies": {
        \\    "typescript": "^4.0.0",
        \\    "tree-sitter": "^0.20.0"
        \\  },
        \\  "scripts": {
        \\    "build": "zig build",
        \\    "test": "zig test"
        \\  }
        \\}
    ;

    return demoLanguage(server, allocator, source, "JSON");
}

fn demoRust(server: *grove.LSP.LanguageServer, allocator: std.mem.Allocator) !DemoResult {
    const source =
        \\#[derive(Debug)]
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
        \\fn main() {
        \\    let p1 = Point::new(0.0, 0.0);
        \\    let p2 = Point::new(3.0, 4.0);
        \\    println!("Distance: {}", p1.distance(&p2));
        \\}
    ;

    return demoLanguage(server, allocator, source, "Rust");
}

fn demoGhostlang(server: *grove.LSP.LanguageServer, allocator: std.mem.Allocator) !DemoResult {
    const source =
        \\// Ghostlang demo - syntax may vary
        \\struct Point {
        \\    x: f32,
        \\    y: f32
        \\}
        \\
        \\fn Point.init(x: f32, y: f32) -> Point {
        \\    return Point { x: x, y: y }
        \\}
        \\
        \\fn Point.distance(self, other: Point) -> f32 {
        \\    let dx = self.x - other.x
        \\    let dy = self.y - other.y
        \\    return sqrt(dx * dx + dy * dy)
        \\}
        \\
        \\fn main() {
        \\    let p1 = Point.init(0.0, 0.0)
        \\    let p2 = Point.init(3.0, 4.0)
        \\    print("Distance: ", p1.distance(p2))
        \\}
    ;

    return demoLanguage(server, allocator, source, "Ghostlang");
}

fn demoLanguage(server: *grove.LSP.LanguageServer, allocator: std.mem.Allocator, source: []const u8, _: []const u8) !DemoResult {
    std.debug.print("Source ({d} bytes):\n", .{source.len});
    std.debug.print("{s}\n\n", .{source});

    // Test document symbols
    std.debug.print("📋 Document Symbols:\n", .{});
    const symbols = server.documentSymbols(source) catch |err| {
        std.debug.print("  ⚠️  Symbol extraction failed: {}\n", .{err});
        return DemoResult{
            .symbols = &.{},
            .folding_ranges = &.{},
            .diagnostics = &.{},
        };
    };

    if (symbols.len == 0) {
        std.debug.print("  No symbols found\n", .{});
    } else {
        for (symbols, 0..) |symbol, i| {
            std.debug.print("  {d}. {s} ({s}) at {}:{}-{}:{}\n", .{
                i + 1,
                symbol.name,
                @tagName(symbol.kind),
                symbol.range.start.line,
                symbol.range.start.character,
                symbol.range.end.line,
                symbol.range.end.character,
            });
        }
    }

    // Test folding ranges
    std.debug.print("\n📁 Folding Ranges:\n", .{});
    const folding_ranges = server.foldingRanges(source) catch |err| {
        std.debug.print("  ⚠️  Folding range extraction failed: {}\n", .{err});
        return DemoResult{
            .symbols = symbols,
            .folding_ranges = &.{},
            .diagnostics = &.{},
        };
    };

    if (folding_ranges.len == 0) {
        std.debug.print("  No folding ranges found\n", .{});
    } else {
        for (folding_ranges, 0..) |range, i| {
            const kind_str = if (range.kind) |k| @tagName(k) else "code";
            std.debug.print("  {d}. {s}: lines {d}-{d}\n", .{
                i + 1,
                kind_str,
                range.start_line,
                range.end_line,
            });
        }
    }

    // Test hover at different positions
    std.debug.print("\n🔍 Hover Information:\n", .{});
    const test_positions = [_]grove.LSP.Position{
        .{ .line = 0, .character = 6 }, // First word
        .{ .line = 2, .character = 10 }, // Middle of code
    };

    for (test_positions, 0..) |pos, i| {
        const hover_text = server.hover(source, pos) catch |err| {
            std.debug.print("  {d}. Position {}:{} - Error: {}\n", .{ i + 1, pos.line, pos.character, err });
            continue;
        };

        if (hover_text) |text| {
            defer allocator.free(text);
            std.debug.print("  {d}. Position {}:{} - {s}\n", .{ i + 1, pos.line, pos.character, text });
        } else {
            std.debug.print("  {d}. Position {}:{} - No hover info\n", .{ i + 1, pos.line, pos.character });
        }
    }

    // Test diagnostics
    std.debug.print("\n🩺 Diagnostics:\n", .{});
    const diagnostics = server.diagnostics(source) catch |err| {
        std.debug.print("  ⚠️  Diagnostic extraction failed: {}\n", .{err});
        return DemoResult{
            .symbols = symbols,
            .folding_ranges = folding_ranges,
            .diagnostics = &.{},
        };
    };

    if (diagnostics.len == 0) {
        std.debug.print("  ✅ No syntax errors found\n", .{});
    } else {
        for (diagnostics, 0..) |diagnostic, i| {
            std.debug.print("  {d}. {s}: {s} at {}:{}-{}:{}\n", .{
                i + 1,
                @tagName(diagnostic.severity),
                diagnostic.message,
                diagnostic.range.start.line,
                diagnostic.range.start.character,
                diagnostic.range.end.line,
                diagnostic.range.end.character,
            });
        }
    }

    // Test utility functions
    std.debug.print("\n🔧 Utility Functions:\n", .{});
    const test_position = grove.LSP.Position{ .line = 1, .character = 5 };
    const byte_offset = grove.LSP.Utils.positionToByteOffset(source, test_position);
    const back_to_position = grove.LSP.Utils.byteOffsetToPosition(source, byte_offset);

    std.debug.print("  Position {}:{} -> byte offset {} -> position {}:{}\n", .{
        test_position.line,
        test_position.character,
        byte_offset,
        back_to_position.line,
        back_to_position.character,
    });

    return DemoResult{
        .symbols = symbols,
        .folding_ranges = folding_ranges,
        .diagnostics = diagnostics,
    };
}
