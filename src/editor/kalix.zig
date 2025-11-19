const std = @import("std");
const Features = @import("features.zig");
const Query = @import("../core/query.zig").Query;
const Languages = @import("../languages.zig").Bundled;
const Node = @import("../core/node.zig").Node;
const testing = std.testing;
const Parser = @import("../core/parser.zig").Parser;

const DocumentSymbol = Features.DocumentSymbol;
const SymbolRule = Features.SymbolRule;
const FoldingOptions = Features.FoldingOptions;
const FoldingRange = Features.FoldingRange;

const kalix_symbol_rules = [_]SymbolRule{
    .{
        .symbol_capture = "local.definition.contract",
        .name_capture = "local.definition.contract",
        .kind = .class,
    },
    .{
        .symbol_capture = "local.definition.function",
        .name_capture = "local.definition.function",
        .kind = .function,
    },
    .{
        .symbol_capture = "local.definition.state",
        .name_capture = "local.definition.state",
        .kind = .field,
    },
    .{
        .symbol_capture = "local.definition.table",
        .name_capture = "local.definition.table",
        .kind = .field,
    },
    .{
        .symbol_capture = "local.definition.event",
        .name_capture = "local.definition.event",
        .kind = .event,
    },
};

const kalix_folding_captures = [_][]const u8{
    "function.outer",
    "block.outer",
    "class.outer",
};

pub const KalixUtilities = struct {
    allocator: std.mem.Allocator,
    locals_query: Query,
    textobjects_query: Query,

    pub fn init(allocator: std.mem.Allocator) !KalixUtilities {
        const language = try Languages.kalix.get();

        var locals_query = try Query.init(
            allocator,
            language,
            @embedFile("../../vendor/grammars/kalix/queries/locals.scm"),
        );
        errdefer locals_query.deinit();

        var textobjects_query = try Query.init(
            allocator,
            language,
            @embedFile("../../vendor/grammars/kalix/queries/textobjects.scm"),
        );
        errdefer textobjects_query.deinit();

        return .{
            .allocator = allocator,
            .locals_query = locals_query,
            .textobjects_query = textobjects_query,
        };
    }

    pub fn deinit(self: *KalixUtilities) void {
        self.locals_query.deinit();
        self.textobjects_query.deinit();
    }

    pub fn documentSymbols(
        self: *KalixUtilities,
        root: Node,
        source: []const u8,
    ) Features.SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.locals_query,
            root,
            source,
            &kalix_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *KalixUtilities,
        root: Node,
        options: FoldingOptions,
    ) Features.FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.textobjects_query,
            root,
            &kalix_folding_captures,
            options,
        );
    }
};

test "kalix utilities produce document symbols and folding ranges" {
    const allocator = testing.allocator;

    var utils = try KalixUtilities.init(allocator);
    defer utils.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const language = try Languages.kalix.get();
    try parser.setLanguage(language);

    const source =
        \\contract Treasury {
        \\    state balance: u64;
        \\    fn deposit(amount: u64) {
        \\        state.balance = state.balance + amount;
        \\    }
        \\}
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;

    const symbols = try utils.documentSymbols(root, source);
    defer Features.freeDocumentSymbols(allocator, symbols);

    try testing.expect(symbols.len >= 1); // At least the contract

    const folding = try utils.foldingRanges(root, .{ .min_line_span = 1 });
    defer allocator.free(folding);

    try testing.expect(folding.len >= 1); // At least the contract block
}
