const std = @import("std");
const QueryModule = @import("../core/query.zig");
const Query = QueryModule.Query;
const QueryCursor = QueryModule.QueryCursor;
const NodeModule = @import("../core/node.zig");
const Node = NodeModule.Node;
const Point = NodeModule.Point;
const Tree = @import("../core/tree.zig").Tree;

pub const Range = struct {
    start: Point,
    end: Point,
};

pub const FoldingRangeKind = enum {
    region,
    comment,
    imports,
};

pub const FoldingRange = struct {
    start_line: u32,
    start_character: u32,
    end_line: u32,
    end_character: u32,
    kind: ?FoldingRangeKind = null,
};

pub const FoldingOptions = struct {
    min_line_span: u32 = 1,
    max_ranges: ?usize = null,
};

pub fn collectFoldingRanges(
    allocator: std.mem.Allocator,
    root: Node,
    options: FoldingOptions,
) std.mem.Allocator.Error![]FoldingRange {
    var result = std.ArrayList(FoldingRange).init(allocator);
    errdefer result.deinit();

    var stack = std.ArrayList(Node).init(allocator);
    defer stack.deinit();
    try stack.append(root);

    while (stack.popOrNull()) |node| {
        const start = node.startPosition();
        const end = node.endPosition();
        if (end.row > start.row and (end.row - start.row) >= options.min_line_span) {
            const range = FoldingRange{
                .start_line = start.row,
                .start_character = start.column,
                .end_line = end.row,
                .end_character = end.column,
                .kind = null,
            };
            try result.append(range);
            if (options.max_ranges) |limit| {
                if (result.items.len >= limit) break;
            }
        }

        var remaining = node.childCount();
        while (remaining > 0) {
            remaining -= 1;
            if (node.child(remaining)) |child| {
                try stack.append(child);
            }
        }
    }

    return result.toOwnedSlice();
}

pub const SymbolKind = enum(u8) {
    file = 1,
    module = 2,
    namespace = 3,
    package = 4,
    class = 5,
    method = 6,
    property = 7,
    field = 8,
    constructor = 9,
    enum_member = 22,
    function = 12,
    variable = 13,
    constant = 14,
    string = 15,
    number = 16,
    boolean = 17,
    array = 18,
};

pub const DocumentSymbol = struct {
    name: []const u8,
    detail: ?[]const u8,
    kind: SymbolKind,
    range: Range,
    selection_range: Range,
    children: []DocumentSymbol = &[_]DocumentSymbol{},
};

pub const SymbolRule = struct {
    symbol_capture: []const u8,
    name_capture: []const u8,
    detail_capture: ?[]const u8 = null,
    kind: SymbolKind,
};

pub const SymbolError = QueryModule.CursorError || std.mem.Allocator.Error;

pub fn collectDocumentSymbols(
    allocator: std.mem.Allocator,
    query: *Query,
    root: Node,
    source: []const u8,
    rules: []const SymbolRule,
) SymbolError![]DocumentSymbol {
    var cursor = try QueryCursor.init();
    defer cursor.deinit();
    cursor.exec(query, root);

    var symbols = std.ArrayList(DocumentSymbol).init(allocator);
    errdefer {
        deinitSymbolList(allocator, symbols.items);
        symbols.deinit();
    }

    if (rules.len == 0) return symbols.toOwnedSlice();

    const Accumulator = struct {
        rule_index: ?usize = null,
        symbol_node: ?Node = null,
        name_node: ?Node = null,
        detail_node: ?Node = null,
    };

    var accumulators = std.AutoHashMap(u32, Accumulator).init(allocator);
    defer accumulators.deinit();

    while (cursor.nextCapture(query)) |result| {
        const capture_name = result.capture.name;
        const maybe_rule = resolveRuleIndex(rules, capture_name);
        if (maybe_rule == null) {
            if (isLastCapture(result)) {
                _ = accumulators.remove(result.match_id);
            }
            continue;
        }

        const rule_index = maybe_rule.?;
        const rule = rules[rule_index];

        var entry = try accumulators.getOrPut(result.match_id);
        if (!entry.found_existing) {
            entry.value_ptr.* = .{};
        }

        if (entry.value_ptr.rule_index) |existing| {
            if (existing != rule_index) {
                // Prefer first matching rule per match.
                if (isLastCapture(result)) {
                    _ = accumulators.remove(result.match_id);
                }
                continue;
            }
        } else {
            entry.value_ptr.rule_index = rule_index;
        }

        if (std.mem.eql(u8, capture_name, rule.symbol_capture)) {
            entry.value_ptr.symbol_node = result.capture.node;
        }
        if (std.mem.eql(u8, capture_name, rule.name_capture)) {
            entry.value_ptr.name_node = result.capture.node;
        }
        if (rule.detail_capture) |detail_name| {
            if (std.mem.eql(u8, capture_name, detail_name)) {
                entry.value_ptr.detail_node = result.capture.node;
            }
        }

        if (isLastCapture(result)) {
            if (entry.value_ptr.rule_index) |stored_index| {
                if (entry.value_ptr.symbol_node) |symbol_node| {
                    if (entry.value_ptr.name_node) |name_node| {
                        const detail_node = entry.value_ptr.detail_node;
                        const rule_for_match = rules[stored_index];
                        const symbol = try buildSymbol(
                            allocator,
                            rule_for_match,
                            symbol_node,
                            name_node,
                            detail_node,
                            source,
                        );
                        try symbols.append(symbol);
                    }
                }
            }
            _ = accumulators.remove(result.match_id);
        }
    }

    return symbols.toOwnedSlice();
}

pub fn freeDocumentSymbols(allocator: std.mem.Allocator, symbols: []DocumentSymbol) void {
    if (symbols.len == 0) {
        allocator.free(symbols);
        return;
    }
    for (symbols) |symbol| {
        deinitSymbol(allocator, symbol);
    }
    allocator.free(symbols);
}

fn deinitSymbolList(allocator: std.mem.Allocator, items: []DocumentSymbol) void {
    for (items) |symbol| {
        deinitSymbol(allocator, symbol);
    }
}

fn deinitSymbol(allocator: std.mem.Allocator, symbol: DocumentSymbol) void {
    allocator.free(@constCast(symbol.name));
    if (symbol.detail) |detail| {
        allocator.free(@constCast(detail));
    }
    if (symbol.children.len > 0) {
        freeDocumentSymbols(allocator, symbol.children);
    }
}

pub const Definition = struct {
    range: Range,
    selection_range: Range,
    detail: ?[]const u8,
};

pub fn findDefinition(symbols: []const DocumentSymbol, name: []const u8) ?Definition {
    for (symbols) |symbol| {
        if (std.mem.eql(u8, symbol.name, name)) {
            return Definition{
                .range = symbol.range,
                .selection_range = symbol.selection_range,
                .detail = symbol.detail,
            };
        }
    }
    return null;
}

pub const HoverInfo = struct {
    name: []const u8,
    detail: ?[]const u8,
    range: Range,
};

pub fn hover(symbols: []const DocumentSymbol, name: []const u8) ?HoverInfo {
    for (symbols) |symbol| {
        if (std.mem.eql(u8, symbol.name, name)) {
            return HoverInfo{
                .name = symbol.name,
                .detail = symbol.detail,
                .range = symbol.selection_range,
            };
        }
    }
    return null;
}

fn resolveRuleIndex(rules: []const SymbolRule, capture_name: []const u8) ?usize {
    for (rules, 0..) |rule, idx| {
        if (std.mem.eql(u8, rule.symbol_capture, capture_name)) return idx;
        if (std.mem.eql(u8, rule.name_capture, capture_name)) return idx;
        if (rule.detail_capture) |detail_name| {
            if (std.mem.eql(u8, detail_name, capture_name)) return idx;
        }
    }
    return null;
}

fn isLastCapture(result: QueryModule.CaptureResult) bool {
    return result.capture_index + 1 == result.capture_count;
}

fn buildSymbol(
    allocator: std.mem.Allocator,
    rule: SymbolRule,
    symbol_node: Node,
    name_node: Node,
    detail_node: ?Node,
    source: []const u8,
) std.mem.Allocator.Error!DocumentSymbol {
    const name_slice = sliceNode(source, name_node);
    const name_copy = try allocator.dupe(u8, name_slice);
    errdefer allocator.free(name_copy);

    var detail_copy: ?[]const u8 = null;
    if (detail_node) |node| {
        const detail_slice = sliceNode(source, node);
        if (detail_slice.len > 0) {
            const owned = try allocator.dupe(u8, detail_slice);
            errdefer allocator.free(owned);
            detail_copy = owned;
        }
    }

    return DocumentSymbol{
        .name = name_copy,
        .detail = detail_copy,
        .kind = rule.kind,
        .range = Range{
            .start = symbol_node.startPosition(),
            .end = symbol_node.endPosition(),
        },
        .selection_range = Range{
            .start = name_node.startPosition(),
            .end = name_node.endPosition(),
        },
    };
}

fn sliceNode(source: []const u8, node: Node) []const u8 {
    const start = node.startByte();
    const end = node.endByte();
    if (start >= source.len or end > source.len or end <= start) {
        return &[_]u8{};
    }
    return source[start..end];
}

const testing = std.testing;
const Languages = @import("../languages.zig").Bundled;
const Parser = @import("../core/parser.zig").Parser;

fn parseJsonTree(allocator: std.mem.Allocator, source: []const u8) !Tree {
    var parser = try Parser.init(allocator);
    defer parser.deinit();
    const lang = try Languages.json.get();
    try parser.setLanguage(lang);
    return try parser.parseUtf8(null, source);
}

test "collectFoldingRanges returns multi-line nodes" {
    const allocator = testing.allocator;
    var tree = try parseJsonTree(allocator, "{\n  \"hello\": true,\n  \"world\": [1,2,3]\n}");
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;
    const ranges = try collectFoldingRanges(allocator, root, .{ .min_line_span = 1 });
    defer allocator.free(ranges);

    try testing.expect(ranges.len >= 1);
    try testing.expect(ranges[0].start_line == 0);
}

test "collectDocumentSymbols extracts JSON keys" {
    const allocator = testing.allocator;
    const source = "{\"hello\": 1, \"world\": 2}";
    var tree = try parseJsonTree(allocator, source);
    defer tree.deinit();
    const root = tree.rootNode() orelse return error.MissingRoot;

    const lang = try Languages.json.get();
    const query_source =
        \\((pair key: (string) @pair.key value: (_) @pair.value) @pair.node)
    ;
    var query = try Query.init(allocator, lang, query_source);
    defer query.deinit();

    const rules = [_]SymbolRule{
        .{
            .symbol_capture = "pair.node",
            .name_capture = "pair.key",
            .detail_capture = "pair.value",
            .kind = .property,
        },
    };

    const symbols = try collectDocumentSymbols(allocator, &query, root, source, rules);
    defer freeDocumentSymbols(allocator, symbols);

    try testing.expect(symbols.len == 2);
    try testing.expect(std.mem.eql(u8, symbols[0].name, "\"hello\""));
}

test "findDefinition locates symbol" {
    const allocator = testing.allocator;
    const source = "{\"hello\": 1}";
    var tree = try parseJsonTree(allocator, source);
    defer tree.deinit();
    const root = tree.rootNode() orelse return error.MissingRoot;
    const lang = try Languages.json.get();
    const query_source =
        \\((pair key: (string) @pair.key value: (_) @pair.value) @pair.node)
    ;
    var query = try Query.init(allocator, lang, query_source);
    defer query.deinit();
    const rules = [_]SymbolRule{
        .{
            .symbol_capture = "pair.node",
            .name_capture = "pair.key",
            .detail_capture = "pair.value",
            .kind = .property,
        },
    };

    const symbols = try collectDocumentSymbols(allocator, &query, root, source, rules);
    defer freeDocumentSymbols(allocator, symbols);

    const maybe_def = findDefinition(symbols, "\"hello\"");
    try testing.expect(maybe_def != null);
    const definition = maybe_def.?;
    try testing.expect(definition.range.start.row == 0);
}
