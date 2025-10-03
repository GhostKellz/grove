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

const yaml_symbol_rules = [_]SymbolRule{
    .{
        .symbol_capture = "block.definition",
        .name_capture = "block.name",
        .detail_capture = null,
        .kind = .class,
    },
};

const yaml_folding_captures = [_][]const u8{
    "block.body",
};

const yaml_symbols_query_source =
    \\(block_mapping_pair key: (flow_node) @block.name) @block.definition
;

const yaml_folding_query_source =
    \\(block_mapping) @block.body
;

pub const YAMLUtilities = struct {
    allocator: std.mem.Allocator,
    symbols_query: Query,
    folding_query: Query,

    pub fn init(allocator: std.mem.Allocator) !YAMLUtilities {
        const language = try Languages.yaml.get();

        var symbols_query = try Query.init(allocator, language, yaml_symbols_query_source);
        errdefer symbols_query.deinit();

        var folding_query = try Query.init(allocator, language, yaml_folding_query_source);
        errdefer folding_query.deinit();

        return .{
            .allocator = allocator,
            .symbols_query = symbols_query,
            .folding_query = folding_query,
        };
    }

    pub fn deinit(self: *YAMLUtilities) void {
        self.symbols_query.deinit();
        self.folding_query.deinit();
    }

    pub fn documentSymbols(
        self: *YAMLUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.symbols_query,
            root,
            source,
            &yaml_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *YAMLUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.folding_query,
            root,
            &yaml_folding_captures,
            options,
        );
    }
};
