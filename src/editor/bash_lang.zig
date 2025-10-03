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

const bash_symbol_rules = [_]SymbolRule{
    .{
        .symbol_capture = "function.definition",
        .name_capture = "function.name",
        .detail_capture = null,
        .kind = .function,
    },
};

const bash_folding_captures = [_][]const u8{
    "function.body",
    "block.structure",
};

const bash_symbols_query_source =
    \\(function_definition name: (word) @function.name) @function.definition
;

const bash_folding_query_source =
    \\(function_definition body: (_) @function.body)
    \\(compound_statement) @block.structure
;

pub const BashUtilities = struct {
    allocator: std.mem.Allocator,
    symbols_query: Query,
    folding_query: Query,

    pub fn init(allocator: std.mem.Allocator) !BashUtilities {
        const language = try Languages.bash.get();

        var symbols_query = try Query.init(allocator, language, bash_symbols_query_source);
        errdefer symbols_query.deinit();

        var folding_query = try Query.init(allocator, language, bash_folding_query_source);
        errdefer folding_query.deinit();

        return .{
            .allocator = allocator,
            .symbols_query = symbols_query,
            .folding_query = folding_query,
        };
    }

    pub fn deinit(self: *BashUtilities) void {
        self.symbols_query.deinit();
        self.folding_query.deinit();
    }

    pub fn documentSymbols(
        self: *BashUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.symbols_query,
            root,
            source,
            &bash_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *BashUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.folding_query,
            root,
            &bash_folding_captures,
            options,
        );
    }
};

const testing = std.testing;

test "bash utilities produce document symbols and folding ranges" {
    const allocator = testing.allocator;

    var utils = try BashUtilities.init(allocator);
    defer utils.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const language = try Languages.bash.get();
    try parser.setLanguage(language);

    const source =
        \\#!/bin/bash
        \\function greet() {
        \\  echo "Hello, $1"
        \\}
        \\greet "World"
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;

    const symbols = try utils.documentSymbols(root, source);
    defer Features.freeDocumentSymbols(allocator, symbols);

    const folding = try utils.foldingRanges(root, .{ .min_line_span = 1 });
    defer allocator.free(folding);
}
