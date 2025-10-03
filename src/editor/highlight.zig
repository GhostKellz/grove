const std = @import("std");
const QueryModule = @import("../core/query.zig");
const Query = QueryModule.Query;
const QueryCursor = QueryModule.QueryCursor;
const NodeModule = @import("../core/node.zig");
const Node = NodeModule.Node;
const Point = NodeModule.Point;
const Language = @import("../language.zig").Language;

pub const HighlightRule = struct {
    capture: []const u8,
    class: []const u8,
};

pub const HighlightSpan = struct {
    class: []const u8,
    capture: []const u8,
    start_byte: u32,
    end_byte: u32,
    start_point: Point,
    end_point: Point,
};

pub const HighlightError = QueryModule.CursorError || std.mem.Allocator.Error;

pub const HighlightEngineInitError = HighlightError || QueryModule.QueryError;

pub const HighlightEngine = struct {
    allocator: std.mem.Allocator,
    query: Query,
    cursor: QueryCursor,
    rules: []HighlightRule,

    pub fn init(
        allocator: std.mem.Allocator,
        language: Language,
        query_source: []const u8,
        rules: []const HighlightRule,
    ) HighlightEngineInitError!HighlightEngine {
        var query = try Query.init(allocator, language, query_source);
        errdefer query.deinit();

        var cursor = try QueryCursor.init();
        errdefer cursor.deinit();

        const rules_copy = try duplicateRules(allocator, rules);
        errdefer freeRules(allocator, rules_copy);

        return .{
            .allocator = allocator,
            .query = query,
            .cursor = cursor,
            .rules = rules_copy,
        };
    }

    pub fn deinit(self: *HighlightEngine) void {
        freeRules(self.allocator, self.rules);
        self.cursor.deinit();
        self.query.deinit();
    }

    pub fn highlight(self: *HighlightEngine, root: Node) HighlightError![]HighlightSpan {
        self.cursor.reset();
        self.cursor.exec(&self.query, root);
        return collectWithCursor(self.allocator, &self.query, &self.cursor, self.rules);
    }
};

pub fn collectHighlights(
    allocator: std.mem.Allocator,
    query: *Query,
    root: Node,
    rules: []const HighlightRule,
) HighlightError![]HighlightSpan {
    var cursor = try QueryCursor.init();
    defer cursor.deinit();
    cursor.exec(query, root);
    return collectWithCursor(allocator, query, &cursor, rules);
}

fn collectWithCursor(
    allocator: std.mem.Allocator,
    query: *Query,
    cursor: *QueryCursor,
    rules: []const HighlightRule,
) HighlightError![]HighlightSpan {
    var list = std.ArrayList(HighlightSpan){};

    while (cursor.nextCapture(query)) |result| {
        const highlight_class = resolveClass(result.capture.name, rules);
        const node = result.capture.node;
        try list.append(allocator, .{
            .class = highlight_class,
            .capture = result.capture.name,
            .start_byte = node.startByte(),
            .end_byte = node.endByte(),
            .start_point = node.startPosition(),
            .end_point = node.endPosition(),
        });
    }

    return list.toOwnedSlice(allocator);
}

fn resolveClass(name: []const u8, rules: []const HighlightRule) []const u8 {
    for (rules) |rule| {
        if (std.mem.eql(u8, rule.capture, name)) {
            return rule.class;
        }
    }
    return name;
}

fn duplicateRules(allocator: std.mem.Allocator, rules: []const HighlightRule) std.mem.Allocator.Error![]HighlightRule {
    if (rules.len == 0) return &[_]HighlightRule{};

    const copy = try allocator.alloc(HighlightRule, rules.len);
    var filled: usize = 0;
    errdefer {
        for (copy[0..filled]) |rule| {
            allocator.free(@constCast(rule.capture));
            allocator.free(@constCast(rule.class));
        }
        allocator.free(copy);
    }

    for (rules, 0..) |rule, idx| {
        const capture_copy = try allocator.dupe(u8, rule.capture);
        const class_copy = allocator.dupe(u8, rule.class) catch |err| {
            allocator.free(capture_copy);
            return err;
        };
        copy[idx] = .{
            .capture = capture_copy,
            .class = class_copy,
        };
        filled = idx + 1;
    }

    return copy;
}

fn freeRules(allocator: std.mem.Allocator, rules: []HighlightRule) void {
    if (rules.len == 0) return;
    for (rules) |rule| {
        allocator.free(@constCast(rule.capture));
        allocator.free(@constCast(rule.class));
    }
    allocator.free(rules);
}

const testing = std.testing;
const Languages = @import("../languages.zig").Bundled;
const Parser = @import("../core/parser.zig").Parser;

const highlight_query_source =
    \\(pair key: (string) @property value: [(string) (true) (false) (null)] @value)
;
const ghost_highlight_query_source = @embedFile("../../vendor/grammars/ghostlang/queries/highlights.scm");
const typescript_highlight_query_source = @embedFile("../../vendor/grammars/typescript/queries/highlights.scm");
const tsx_highlight_query_source = @embedFile("../../vendor/grammars/tsx/queries/highlights.scm");

test "collectHighlights maps captures to highlight classes" {
    const allocator = testing.allocator;
    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const lang = try Languages.json.get();
    try parser.setLanguage(lang);

    var tree = try parser.parseUtf8(null, "{\"hello\": true, \"name\": \"grove\"}");
    defer tree.deinit();

    var query = try Query.init(allocator, lang, highlight_query_source);
    defer query.deinit();

    const rules = [_]HighlightRule{
        .{ .capture = "property", .class = "@property" },
        .{ .capture = "value", .class = "@constant" },
    };

    const root = tree.rootNode() orelse return error.MissingRoot;
    const spans = try collectHighlights(allocator, &query, root, rules);
    defer allocator.free(spans);

    try testing.expect(spans.len >= 3);
    try testing.expect(std.mem.eql(u8, spans[0].class, "@property"));
    try testing.expect(std.mem.eql(u8, spans[1].class, "@constant"));
}

test "highlight engine reuses compiled query" {
    const allocator = testing.allocator;
    const lang = try Languages.json.get();
    const rules = [_]HighlightRule{
        .{ .capture = "property", .class = "@property" },
        .{ .capture = "value", .class = "@constant" },
    };

    var engine = try HighlightEngine.init(allocator, lang, highlight_query_source, rules);
    defer engine.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();
    try parser.setLanguage(lang);

    var tree = try parser.parseUtf8(null, "{\"hello\": true, \"sad\": false}");
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;
    const spans = try engine.highlight(root);
    defer allocator.free(spans);

    try testing.expect(spans.len >= 4);
}

test "ghostlang highlight engine loads vendored queries" {
    const allocator = testing.allocator;
    const lang = try Languages.ghostlang.get();

    const rules = [_]HighlightRule{
        .{ .capture = "keyword", .class = "@keyword" },
        .{ .capture = "function", .class = "@function" },
        .{ .capture = "function.call", .class = "@function.call" },
        .{ .capture = "function.builtin", .class = "@function.builtin" },
        .{ .capture = "variable", .class = "@variable" },
        .{ .capture = "property", .class = "@property" },
        .{ .capture = "number", .class = "@number" },
        .{ .capture = "string", .class = "@string" },
        .{ .capture = "boolean", .class = "@boolean" },
    };

    var engine = try HighlightEngine.init(allocator, lang, ghost_highlight_query_source, rules);
    defer engine.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();
    try parser.setLanguage(lang);

    const source =
        \\// Ghostlang sample script
        \\function plugin() {
        \\  var message = "noop";
        \\  if (getCursorPosition() != null) {
        \\    notify("hi");
        \\  }
        \\  return message;
        \\}
        \\var data = { count: 1 };
        \\data.count = data.count + 1;
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;
    const spans = try engine.highlight(root);
    defer allocator.free(spans);

    try testing.expect(spans.len > 0);

    var has_keyword = false;
    var has_function = false;
    var has_number = false;

    for (spans) |span| {
        if (std.mem.eql(u8, span.capture, "keyword")) has_keyword = true;
        if (std.mem.eql(u8, span.capture, "function")) has_function = true;
        if (std.mem.eql(u8, span.capture, "number")) has_number = true;
    }

    try testing.expect(has_keyword);
    try testing.expect(has_function);
    try testing.expect(has_number);
}

test "typescript highlight engine loads vendored queries" {
    const allocator = testing.allocator;
    const lang = try Languages.typescript.get();

    const rules = [_]HighlightRule{
        .{ .capture = "type", .class = "@type" },
        .{ .capture = "type.builtin", .class = "@type.builtin" },
        .{ .capture = "keyword", .class = "@keyword" },
        .{ .capture = "function", .class = "@function" },
        .{ .capture = "variable.parameter", .class = "@variable.parameter" },
        .{ .capture = "punctuation.bracket", .class = "@punctuation.bracket" },
        .{ .capture = "string", .class = "@string" },
        .{ .capture = "number", .class = "@number" },
    };

    var engine = try HighlightEngine.init(allocator, lang, typescript_highlight_query_source, rules);
    defer engine.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();
    try parser.setLanguage(lang);

    const source =
        \\function greet(name: string): string {
        \\  return "Hello, " + name;
        \\}
        \\
        \\const result: number = 42;
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;
    const spans = try engine.highlight(root);
    defer allocator.free(spans);

    try testing.expect(spans.len > 0);
}

test "tsx highlight engine loads vendored queries" {
    const allocator = testing.allocator;
    const lang = try Languages.tsx.get();

    const rules = [_]HighlightRule{
        .{ .capture = "type", .class = "@type" },
        .{ .capture = "type.builtin", .class = "@type.builtin" },
        .{ .capture = "keyword", .class = "@keyword" },
        .{ .capture = "function", .class = "@function" },
        .{ .capture = "variable.parameter", .class = "@variable.parameter" },
        .{ .capture = "tag", .class = "@tag" },
        .{ .capture = "attribute", .class = "@attribute" },
        .{ .capture = "string", .class = "@string" },
        .{ .capture = "number", .class = "@number" },
    };

    var engine = try HighlightEngine.init(allocator, lang, tsx_highlight_query_source, rules);
    defer engine.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();
    try parser.setLanguage(lang);

    const source =
        \\function Component(props: { name: string }) {
        \\  return <div>Hello, {props.name}</div>;
        \\}
        \\
        \\const element = <Component name="World" />;
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;
    const spans = try engine.highlight(root);
    defer allocator.free(spans);

    try testing.expect(spans.len > 0);
}
