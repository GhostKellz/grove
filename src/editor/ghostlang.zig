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

const ghost_locals_query_source = @embedFile("../../vendor/grammars/ghostlang/queries/locals.scm");
const ghost_textobjects_query_source = @embedFile("../../vendor/grammars/ghostlang/queries/textobjects.scm");

const ghost_symbol_rules = [_]SymbolRule{
    .{
        .symbol_capture = "local.symbol.function",
        .name_capture = "local.definition.function",
        .kind = .function,
    },
    .{
        .symbol_capture = "local.symbol.variable",
        .name_capture = "local.definition.variable",
        .kind = .variable,
    },
};

const ghost_folding_captures = [_][]const u8{
    "function.outer",
    "block.outer",
    "conditional.outer",
    "loop.outer",
    "object.outer",
    "array.outer",
};

pub const GhostlangUtilities = struct {
    allocator: std.mem.Allocator,
    locals_query: Query,
    textobjects_query: Query,

    pub fn init(allocator: std.mem.Allocator) !GhostlangUtilities {
        const language = try Languages.ghostlang.get();

        var locals_query = try Query.init(allocator, language, ghost_locals_query_source);
        errdefer locals_query.deinit();

        var textobjects_query = try Query.init(allocator, language, ghost_textobjects_query_source);
        errdefer textobjects_query.deinit();

        return .{
            .allocator = allocator,
            .locals_query = locals_query,
            .textobjects_query = textobjects_query,
        };
    }

    pub fn deinit(self: *GhostlangUtilities) void {
        self.locals_query.deinit();
        self.textobjects_query.deinit();
    }

    pub fn documentSymbols(
        self: *GhostlangUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.locals_query,
            root,
            source,
            &ghost_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *GhostlangUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.textobjects_query,
            root,
            &ghost_folding_captures,
            options,
        );
    }
};

const testing = std.testing;

test "ghostlang utilities produce document symbols and folding ranges" {
    const allocator = testing.allocator;

    var utils = try GhostlangUtilities.init(allocator);
    defer utils.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const language = try Languages.ghostlang.get();
    try parser.setLanguage(language);

    const source =
        \\// Ghostlang sample script\\n
        \\function plugin(title, message) {\\n
        \\  var formatted = message + \"!\";\\n
        \\  if (formatted != null) {\\n
        \\    notify(title + formatted);\\n
        \\  }\\n
        \\  return formatted;\\n
        \\}\\n
        \\var counter = 0;\\n
        \\for (var i = 0; i < 3; i = i + 1) {\\n
        \\  counter = counter + i;\\n
        \\}\\n
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;

    const symbols = try utils.documentSymbols(root, source);
    defer Features.freeDocumentSymbols(allocator, symbols);

    try testing.expect(symbols.len >= 2);
    try testing.expect(std.mem.eql(u8, symbols[0].name, "plugin"));
    try testing.expect(symbols[0].kind == .function);

    const folding = try utils.foldingRanges(root, .{ .min_line_span = 1 });
    defer allocator.free(folding);

    try testing.expect(folding.len >= 3);
}
