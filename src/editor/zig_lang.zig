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

// Define Zig-specific symbol extraction rules
const zig_symbol_rules = [_]SymbolRule{
    .{
        .symbol_capture = "function.declaration",
        .name_capture = "function.name",
        .kind = .function,
    },
    .{
        .symbol_capture = "struct.declaration",
        .name_capture = "struct.name",
        .kind = .class, // Use class for structs
    },
    .{
        .symbol_capture = "enum.declaration",
        .name_capture = "enum.name",
        .kind = .enum_member,
    },
    .{
        .symbol_capture = "const.declaration",
        .name_capture = "const.name",
        .kind = .constant,
    },
    .{
        .symbol_capture = "var.declaration",
        .name_capture = "var.name",
        .kind = .variable,
    },
};

// Zig constructs that should be foldable
const zig_folding_captures = [_][]const u8{
    "function.declaration",
    "struct.declaration",
    "enum.declaration",
    "union.declaration",
    "block.statement",
    "switch.statement",
    "if.statement",
    "for.statement",
    "while.statement",
};

// Create queries for Zig symbols and folding
const zig_symbols_query_source =
    \\(FnProto (IDENTIFIER) @function.name) @function.declaration
    \\(ContainerDecl (IDENTIFIER) @struct.name) @struct.declaration
    \\(VarDecl (IDENTIFIER) @var.name) @var.declaration
;

const zig_folding_query_source =
    \\(FnProto (Block) @function.declaration)
    \\(ContainerDecl) @struct.declaration
    \\(Block) @block.statement
    \\(SwitchExpr) @switch.statement
    \\(IfExpr) @if.statement
    \\(ForExpr) @for.statement
    \\(WhileExpr) @while.statement
;

pub const ZigUtilities = struct {
    allocator: std.mem.Allocator,
    symbols_query: Query,
    folding_query: Query,

    pub fn init(allocator: std.mem.Allocator) !ZigUtilities {
        const language = try Languages.zig.get();

        var symbols_query = try Query.init(allocator, language, zig_symbols_query_source);
        errdefer symbols_query.deinit();

        var folding_query = try Query.init(allocator, language, zig_folding_query_source);
        errdefer folding_query.deinit();

        return .{
            .allocator = allocator,
            .symbols_query = symbols_query,
            .folding_query = folding_query,
        };
    }

    pub fn deinit(self: *ZigUtilities) void {
        self.symbols_query.deinit();
        self.folding_query.deinit();
    }

    pub fn documentSymbols(
        self: *ZigUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.symbols_query,
            root,
            source,
            &zig_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *ZigUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.folding_query,
            root,
            &zig_folding_captures,
            options,
        );
    }
};

const testing = std.testing;

test "zig utilities produce document symbols and folding ranges" {
    const allocator = testing.allocator;

    var utils = try ZigUtilities.init(allocator);
    defer utils.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const language = try Languages.zig.get();
    try parser.setLanguage(language);

    const source =
        \\const std = @import("std");
        \\
        \\pub fn main() void {
        \\    const message = "Hello, World!";
        \\    std.debug.print("{s}\n", .{message});
        \\}
        \\
        \\const Calculator = struct {
        \\    value: i32,
        \\
        \\    pub fn init(initial: i32) Calculator {
        \\        return Calculator{ .value = initial };
        \\    }
        \\};
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;

    const symbols = try utils.documentSymbols(root, source);
    defer Features.freeDocumentSymbols(allocator, symbols);

    // Should find at least some symbols
    try testing.expect(symbols.len >= 1);

    const folding = try utils.foldingRanges(root, .{ .min_line_span = 1 });
    defer allocator.free(folding);

    // Should find foldable regions
    try testing.expect(folding.len >= 1);
}