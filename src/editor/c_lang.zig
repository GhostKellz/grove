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

const c_symbol_rules = [_]SymbolRule{
    .{
        .symbol_capture = "function.definition",
        .name_capture = "function.name",
        .detail_capture = null,
        .kind = .function,
    },
    .{
        .symbol_capture = "struct.definition",
        .name_capture = "struct.name",
        .detail_capture = null,
        .kind = .class,
    },
};

const c_folding_captures = [_][]const u8{
    "function.body",
    "struct.body",
};

const c_symbols_query_source =
    \\(function_definition declarator: (function_declarator declarator: (identifier) @function.name)) @function.definition
    \\(struct_specifier name: (type_identifier) @struct.name) @struct.definition
;

const c_folding_query_source =
    \\(function_definition body: (compound_statement) @function.body)
    \\(struct_specifier body: (field_declaration_list) @struct.body)
;

pub const CUtilities = struct {
    allocator: std.mem.Allocator,
    symbols_query: Query,
    folding_query: Query,

    pub fn init(allocator: std.mem.Allocator) !CUtilities {
        const language = try Languages.c.get();

        var symbols_query = try Query.init(allocator, language, c_symbols_query_source);
        errdefer symbols_query.deinit();

        var folding_query = try Query.init(allocator, language, c_folding_query_source);
        errdefer folding_query.deinit();

        return .{
            .allocator = allocator,
            .symbols_query = symbols_query,
            .folding_query = folding_query,
        };
    }

    pub fn deinit(self: *CUtilities) void {
        self.symbols_query.deinit();
        self.folding_query.deinit();
    }

    pub fn documentSymbols(
        self: *CUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.symbols_query,
            root,
            source,
            &c_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *CUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.folding_query,
            root,
            &c_folding_captures,
            options,
        );
    }
};
