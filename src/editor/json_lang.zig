const std = @import("std");
const Features = @import("features.zig");
const Query = @import("../core/query.zig").Query;
const Languages = @import("../languages.zig").Bundled;
const Parser = @import("../core/parser.zig").Parser;
const Node = @import("../core/node.zig").Node;

const DocumentSymbol = Features.DocumentSymbol;
const SymbolRule = Features.SymbolRule;
const FoldingOptions = Features.FoldingOptions;
const FoldingRange = Features.FoldingRange;
const FoldingQueryError = Features.FoldingQueryError;
const SymbolError = Features.SymbolError;

// Define JSON-specific symbol extraction rules
const json_symbol_rules = [_]SymbolRule{
    .{
        .symbol_capture = "object.pair",
        .name_capture = "object.key",
        .detail_capture = "object.value",
        .kind = .property,
    },
    .{
        .symbol_capture = "array.item",
        .name_capture = "array.index",
        .detail_capture = "array.value",
        .kind = .field,
    },
};

// JSON constructs that should be foldable
const json_folding_captures = [_][]const u8{
    "object.structure",
    "array.structure",
};

// Create queries for JSON symbols and folding
const json_symbols_query_source =
    \\((pair key: (string) @object.key value: (_) @object.value) @object.pair)
;

const json_folding_query_source =
    \\(object) @object.structure
    \\(array) @array.structure
;

pub const JsonUtilities = struct {
    allocator: std.mem.Allocator,
    symbols_query: Query,
    folding_query: Query,

    pub fn init(allocator: std.mem.Allocator) !JsonUtilities {
        const language = try Languages.json.get();

        var symbols_query = try Query.init(allocator, language, json_symbols_query_source);
        errdefer symbols_query.deinit();

        var folding_query = try Query.init(allocator, language, json_folding_query_source);
        errdefer folding_query.deinit();

        return .{
            .allocator = allocator,
            .symbols_query = symbols_query,
            .folding_query = folding_query,
        };
    }

    pub fn deinit(self: *JsonUtilities) void {
        self.symbols_query.deinit();
        self.folding_query.deinit();
    }

    pub fn documentSymbols(
        self: *JsonUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.symbols_query,
            root,
            source,
            &json_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *JsonUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.folding_query,
            root,
            &json_folding_captures,
            options,
        );
    }
};

const testing = std.testing;

test "json utilities produce document symbols and folding ranges" {
    const allocator = testing.allocator;

    var utils = try JsonUtilities.init(allocator);
    defer utils.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const language = try Languages.json.get();
    try parser.setLanguage(language);

    const source =
        \\{
        \\  "name": "grove",
        \\  "version": "0.1.0",
        \\  "dependencies": {
        \\    "tree-sitter": "^0.20.0"
        \\  },
        \\  "scripts": {
        \\    "build": "zig build",
        \\    "test": "zig build test"
        \\  },
        \\  "keywords": ["parser", "tree-sitter", "zig"]
        \\}
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;

    const symbols = try utils.documentSymbols(root, source);
    defer Features.freeDocumentSymbols(allocator, symbols);

    // Should find the top-level properties
    try testing.expect(symbols.len >= 5);

    const folding = try utils.foldingRanges(root, .{ .min_line_span = 1 });
    defer allocator.free(folding);

    // Should find foldable objects and arrays
    try testing.expect(folding.len >= 3);
}