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

const toml_symbol_rules = [_]SymbolRule{
    .{
        .symbol_capture = "table.definition",
        .name_capture = "table.name",
        .detail_capture = null,
        .kind = .class,
    },
};

const toml_folding_captures = [_][]const u8{
    "table.body",
};

const toml_symbols_query_source =
    \\(table (dotted_key) @table.name) @table.definition
;

const toml_folding_query_source =
    \\(table) @table.body
;

pub const TOMLUtilities = struct {
    allocator: std.mem.Allocator,
    symbols_query: Query,
    folding_query: Query,

    pub fn init(allocator: std.mem.Allocator) !TOMLUtilities {
        const language = try Languages.toml.get();

        var symbols_query = try Query.init(allocator, language, toml_symbols_query_source);
        errdefer symbols_query.deinit();

        var folding_query = try Query.init(allocator, language, toml_folding_query_source);
        errdefer folding_query.deinit();

        return .{
            .allocator = allocator,
            .symbols_query = symbols_query,
            .folding_query = folding_query,
        };
    }

    pub fn deinit(self: *TOMLUtilities) void {
        self.symbols_query.deinit();
        self.folding_query.deinit();
    }

    pub fn documentSymbols(
        self: *TOMLUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.symbols_query,
            root,
            source,
            &toml_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *TOMLUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.folding_query,
            root,
            &toml_folding_captures,
            options,
        );
    }
};
