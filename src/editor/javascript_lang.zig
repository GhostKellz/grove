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

const javascript_symbol_rules = [_]SymbolRule{
    .{
        .symbol_capture = "function.definition",
        .name_capture = "function.name",
        .detail_capture = null,
        .kind = .function,
    },
    .{
        .symbol_capture = "class.definition",
        .name_capture = "class.name",
        .detail_capture = null,
        .kind = .class,
    },
    .{
        .symbol_capture = "method.definition",
        .name_capture = "method.name",
        .detail_capture = null,
        .kind = .method,
    },
};

const javascript_folding_captures = [_][]const u8{
    "function.body",
    "class.body",
    "block.structure",
};

const javascript_symbols_query_source =
    \\(function_declaration name: (identifier) @function.name) @function.definition
    \\(class_declaration name: (identifier) @class.name) @class.definition
    \\(method_definition name: (property_identifier) @method.name) @method.definition
;

const javascript_folding_query_source =
    \\(function_declaration body: (statement_block) @function.body)
    \\(class_declaration body: (class_body) @class.body)
    \\(statement_block) @block.structure
;

pub const JavaScriptUtilities = struct {
    allocator: std.mem.Allocator,
    symbols_query: Query,
    folding_query: Query,

    pub fn init(allocator: std.mem.Allocator) !JavaScriptUtilities {
        const language = try Languages.javascript.get();

        var symbols_query = try Query.init(allocator, language, javascript_symbols_query_source);
        errdefer symbols_query.deinit();

        var folding_query = try Query.init(allocator, language, javascript_folding_query_source);
        errdefer folding_query.deinit();

        return .{
            .allocator = allocator,
            .symbols_query = symbols_query,
            .folding_query = folding_query,
        };
    }

    pub fn deinit(self: *JavaScriptUtilities) void {
        self.symbols_query.deinit();
        self.folding_query.deinit();
    }

    pub fn documentSymbols(
        self: *JavaScriptUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.symbols_query,
            root,
            source,
            &javascript_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *JavaScriptUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.folding_query,
            root,
            &javascript_folding_captures,
            options,
        );
    }
};

const testing = std.testing;

test "javascript utilities produce document symbols and folding ranges" {
    const allocator = testing.allocator;

    var utils = try JavaScriptUtilities.init(allocator);
    defer utils.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const language = try Languages.javascript.get();
    try parser.setLanguage(language);

    const source =
        \\function greet(name) {
        \\  return "Hello " + name;
        \\}
        \\class Person {
        \\  constructor(name) {
        \\    this.name = name;
        \\  }
        \\}
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;

    const symbols = try utils.documentSymbols(root, source);
    defer Features.freeDocumentSymbols(allocator, symbols);

    const folding = try utils.foldingRanges(root, .{ .min_line_span = 1 });
    defer allocator.free(folding);
}
