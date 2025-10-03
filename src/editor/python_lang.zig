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

const python_symbol_rules = [_]SymbolRule{
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
};

const python_folding_captures = [_][]const u8{
    "function.body",
    "class.body",
};

const python_symbols_query_source =
    \\(function_definition name: (identifier) @function.name) @function.definition
    \\(class_definition name: (identifier) @class.name) @class.definition
;

const python_folding_query_source =
    \\(function_definition body: (block) @function.body)
    \\(class_definition body: (block) @class.body)
;

pub const PythonUtilities = struct {
    allocator: std.mem.Allocator,
    symbols_query: Query,
    folding_query: Query,

    pub fn init(allocator: std.mem.Allocator) !PythonUtilities {
        const language = try Languages.python.get();

        var symbols_query = try Query.init(allocator, language, python_symbols_query_source);
        errdefer symbols_query.deinit();

        var folding_query = try Query.init(allocator, language, python_folding_query_source);
        errdefer folding_query.deinit();

        return .{
            .allocator = allocator,
            .symbols_query = symbols_query,
            .folding_query = folding_query,
        };
    }

    pub fn deinit(self: *PythonUtilities) void {
        self.symbols_query.deinit();
        self.folding_query.deinit();
    }

    pub fn documentSymbols(
        self: *PythonUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.symbols_query,
            root,
            source,
            &python_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *PythonUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.folding_query,
            root,
            &python_folding_captures,
            options,
        );
    }
};

const testing = std.testing;

test "python utilities produce document symbols and folding ranges" {
    const allocator = testing.allocator;

    var utils = try PythonUtilities.init(allocator);
    defer utils.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const language = try Languages.python.get();
    try parser.setLanguage(language);

    const source =
        \\def greet(name):
        \\    return f"Hello {name}"
        \\
        \\class Person:
        \\    def __init__(self, name):
        \\        self.name = name
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;

    const symbols = try utils.documentSymbols(root, source);
    defer Features.freeDocumentSymbols(allocator, symbols);

    const folding = try utils.foldingRanges(root, .{ .min_line_span = 1 });
    defer allocator.free(folding);
}
