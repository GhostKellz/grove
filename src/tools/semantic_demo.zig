const std = @import("std");
const grove = @import("grove");

/// Semantic analysis demonstration tool
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Grove Semantic Analysis Demo ===\n\n", .{});

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <language> [line:column]\n", .{args[0]});
        std.debug.print("Languages: typescript, zig\n", .{});
        std.debug.print("Example: {s} typescript 5:10\n", .{args[0]});
        return;
    }

    const language_name = args[1];
    var target_line: ?u32 = null;
    var target_column: ?u32 = null;

    // Parse optional position argument
    if (args.len >= 3) {
        if (std.mem.indexOf(u8, args[2], ":")) |colon_pos| {
            target_line = std.fmt.parseInt(u32, args[2][0..colon_pos], 10) catch null;
            target_column = std.fmt.parseInt(u32, args[2][colon_pos + 1 ..], 10) catch null;
        }
    }

    // Demo source code based on language
    const demo_result = if (std.mem.eql(u8, language_name, "typescript"))
        try demoTypeScript(allocator, target_line, target_column)
    else if (std.mem.eql(u8, language_name, "zig"))
        try demoZig(allocator, target_line, target_column)
    else {
        std.debug.print("❌ Unsupported language: {s}\n", .{language_name});
        return;
    };

    defer demo_result.cleanup(allocator);

    std.debug.print("✅ Semantic analysis completed successfully!\n");
}

const DemoResult = struct {
    functions: []grove.Semantic.FunctionInfo,
    classes: []grove.Semantic.ClassInfo,

    fn cleanup(self: DemoResult, allocator: std.mem.Allocator) void {
        allocator.free(self.functions);
        allocator.free(self.classes);
    }
};

fn demoTypeScript(allocator: std.mem.Allocator, target_line: ?u32, target_column: ?u32) !DemoResult {
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

    std.debug.print("Language: TypeScript\n", .{});
    std.debug.print("Source ({d} bytes):\n", .{source.len});
    std.debug.print("{s}\n\n", .{source});

    // Parse the source
    var pool = grove.ParserPool.init(allocator, try grove.Languages.typescript.get(), 1) catch return error.ParserPoolFailed;
    defer pool.deinit();

    var lease = pool.acquire() catch return error.AcquireFailed;
    defer lease.release();

    var tree = lease.parserRef().parseUtf8(null, source) catch return error.ParseFailed;
    defer tree.deinit();

    // Create semantic analyzer
    var analyzer = try grove.Semantic.createTypeScriptAnalyzer(allocator);
    defer analyzer.deinit();

    var cursor = analyzer.base.createCursor(tree.rootNode().?);
    defer cursor.deinit();

    // Demonstrate position analysis if coordinates provided
    if (target_line != null and target_column != null) {
        std.debug.print("📍 Position Analysis at {}:{}\n", .{ target_line.?, target_column.? });
        const position_analysis = try grove.Semantic.analyzePosition(allocator, tree.rootNode().?, target_line.?, target_column.?, .typescript);

        std.debug.print("Node type: {s}\n", .{position_analysis.node.kind()});
        std.debug.print("Context: {s}\n", .{@tagName(position_analysis.context)});
        std.debug.print("Path depth: {d}\n", .{position_analysis.path.len});
        std.debug.print("Is global scope: {}\n\n", .{position_analysis.scope.is_global});
    }

    // Find functions
    std.debug.print("🔍 Function Analysis:\n", .{});
    const functions = try analyzer.findFunctions(&cursor);

    for (functions, 0..) |func, i| {
        const name_text = cursor.getCurrentText(source)[func.name_node.startByte()..func.name_node.endByte()];
        std.debug.print("  {d}. Function: {s} (kind: {s})\n", .{ i + 1, name_text, @tagName(func.kind) });

        if (func.params_node) |params| {
            const start = params.startPosition();
            const end = params.endPosition();
            std.debug.print("     Parameters: line {d}:{d} - {d}:{d}\n", .{ start.row, start.column, end.row, end.column });
        }
    }

    // Find classes
    std.debug.print("\n🏛️  Class Analysis:\n", .{});
    const classes = try analyzer.findClasses(&cursor);

    for (classes, 0..) |class, i| {
        const name_text = cursor.getCurrentText(source)[class.name_node.startByte()..class.name_node.endByte()];
        std.debug.print("  {d}. Class: {s}\n", .{ i + 1, name_text });

        if (class.body_node) |body| {
            const start = body.startPosition();
            const end = body.endPosition();
            std.debug.print("     Body: line {d}:{d} - {d}:{d}\n", .{ start.row, start.column, end.row, end.column });
        }
    }

    // Tree traversal demo
    std.debug.print("\n🌳 Tree Traversal Analysis:\n", .{});
    var traversal = grove.Semantic.createTraversal(allocator);

    const stats = traversal.analyzeStructure(tree.rootNode().?);
    std.debug.print("  Total nodes: {d}\n", .{stats.total_nodes});
    std.debug.print("  Max depth: {d}\n", .{stats.max_depth});
    std.debug.print("  Leaf nodes: {d}\n", .{stats.leaf_nodes});
    std.debug.print("  Average children: {d:.2}\n", .{stats.average_children});

    return DemoResult{
        .functions = functions,
        .classes = classes,
    };
}

fn demoZig(allocator: std.mem.Allocator, target_line: ?u32, target_column: ?u32) !DemoResult {
    _ = target_line;
    _ = target_column;

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

    std.debug.print("Language: Zig\n", .{});
    std.debug.print("Source ({d} bytes):\n", .{source.len});
    std.debug.print("{s}\n\n", .{source});

    // Parse the source
    var pool = grove.ParserPool.init(allocator, try grove.Languages.zig.get(), 1) catch return error.ParserPoolFailed;
    defer pool.deinit();

    var lease = pool.acquire() catch return error.AcquireFailed;
    defer lease.release();

    var tree = lease.parserRef().parseUtf8(null, source) catch return error.ParseFailed;
    defer tree.deinit();

    // Create semantic analyzer
    var analyzer = try grove.Semantic.createZigAnalyzer(allocator);
    defer analyzer.deinit();

    var cursor = analyzer.base.createCursor(tree.rootNode().?);
    defer cursor.deinit();

    // Find functions
    std.debug.print("🔍 Function Analysis:\n", .{});
    const functions = try analyzer.findFunctions(&cursor);

    for (functions, 0..) |func, i| {
        const name_text = cursor.getCurrentText(source)[func.name_node.startByte()..func.name_node.endByte()];
        std.debug.print("  {d}. Function: {s}\n", .{ i + 1, name_text });
    }

    // Tree structure analysis
    std.debug.print("\n🌳 Tree Structure:\n", .{});
    var traversal = grove.Semantic.createTraversal(allocator);

    const stats = traversal.analyzeStructure(tree.rootNode().?);
    std.debug.print("  Total nodes: {d}\n", .{stats.total_nodes});
    std.debug.print("  Max depth: {d}\n", .{stats.max_depth});
    std.debug.print("  Leaf nodes: {d}\n", .{stats.leaf_nodes});

    return DemoResult{
        .functions = functions,
        .classes = &.{}, // Zig demo doesn't have classes
    };
}
