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

const cmake_symbol_rules = [_]SymbolRule{
    .{
        .symbol_capture = "function.definition",
        .name_capture = "function.name",
        .detail_capture = null,
        .kind = .function,
    },
};

const cmake_folding_captures = [_][]const u8{
    "function.body",
    "if.body",
};

const cmake_symbols_query_source =
    \\(function_def (function_command (argument) @function.name)) @function.definition
;

const cmake_folding_query_source =
    \\(function_def (body) @function.body)
    \\(if_condition (body) @if.body)
;

pub const CMakeUtilities = struct {
    allocator: std.mem.Allocator,
    symbols_query: Query,
    folding_query: Query,

    pub fn init(allocator: std.mem.Allocator) !CMakeUtilities {
        const language = try Languages.cmake.get();

        var symbols_query = try Query.init(allocator, language, cmake_symbols_query_source);
        errdefer symbols_query.deinit();

        var folding_query = try Query.init(allocator, language, cmake_folding_query_source);
        errdefer folding_query.deinit();

        return .{
            .allocator = allocator,
            .symbols_query = symbols_query,
            .folding_query = folding_query,
        };
    }

    pub fn deinit(self: *CMakeUtilities) void {
        self.symbols_query.deinit();
        self.folding_query.deinit();
    }

    pub fn documentSymbols(
        self: *CMakeUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.symbols_query,
            root,
            source,
            &cmake_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *CMakeUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.folding_query,
            root,
            &cmake_folding_captures,
            options,
        );
    }
};
