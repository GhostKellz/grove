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

// Define Rust-specific symbol extraction rules
const rust_symbol_rules = [_]SymbolRule{
    .{
        .symbol_capture = "function.declaration",
        .name_capture = "function.name",
        .kind = .function,
    },
    .{
        .symbol_capture = "struct.declaration",
        .name_capture = "struct.name",
        .kind = .class,
    },
    .{
        .symbol_capture = "enum.declaration",
        .name_capture = "enum.name",
        .kind = .enum_member,
    },
    .{
        .symbol_capture = "impl.declaration",
        .name_capture = "impl.name",
        .kind = .class,
    },
    .{
        .symbol_capture = "trait.declaration",
        .name_capture = "trait.name",
        .kind = .class,
    },
    .{
        .symbol_capture = "mod.declaration",
        .name_capture = "mod.name",
        .kind = .module,
    },
};

// Rust constructs that should be foldable
const rust_folding_captures = [_][]const u8{
    "function.declaration",
    "struct.declaration",
    "enum.declaration",
    "impl.declaration",
    "trait.declaration",
    "mod.declaration",
    "block.statement",
    "match.statement",
    "if.statement",
    "for.statement",
    "while.statement",
    "loop.statement",
};

// Create queries for Rust symbols and folding
const rust_symbols_query_source =
    \\(function_item name: (identifier) @function.name) @function.declaration
    \\(struct_item name: (type_identifier) @struct.name) @struct.declaration
    \\(enum_item name: (type_identifier) @enum.name) @enum.declaration
    \\(impl_item type: (type_identifier) @impl.name) @impl.declaration
    \\(trait_item name: (type_identifier) @trait.name) @trait.declaration
    \\(mod_item name: (identifier) @mod.name) @mod.declaration
;

const rust_folding_query_source =
    \\(function_item body: (block) @function.declaration)
    \\(struct_item body: (field_declaration_list) @struct.declaration)
    \\(enum_item body: (enum_variant_list) @enum.declaration)
    \\(impl_item body: (declaration_list) @impl.declaration)
    \\(trait_item body: (declaration_list) @trait.declaration)
    \\(mod_item body: (declaration_list) @mod.declaration)
    \\(block) @block.statement
    \\(match_expression body: (match_block) @match.statement)
    \\(if_expression consequence: (block) @if.statement)
    \\(for_expression body: (block) @for.statement)
    \\(while_expression body: (block) @while.statement)
    \\(loop_expression body: (block) @loop.statement)
;

pub const RustUtilities = struct {
    allocator: std.mem.Allocator,
    symbols_query: Query,
    folding_query: Query,

    pub fn init(allocator: std.mem.Allocator) !RustUtilities {
        const language = try Languages.rust.get();

        var symbols_query = try Query.init(allocator, language, rust_symbols_query_source);
        errdefer symbols_query.deinit();

        var folding_query = try Query.init(allocator, language, rust_folding_query_source);
        errdefer folding_query.deinit();

        return .{
            .allocator = allocator,
            .symbols_query = symbols_query,
            .folding_query = folding_query,
        };
    }

    pub fn deinit(self: *RustUtilities) void {
        self.symbols_query.deinit();
        self.folding_query.deinit();
    }

    pub fn documentSymbols(
        self: *RustUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.symbols_query,
            root,
            source,
            &rust_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *RustUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.folding_query,
            root,
            &rust_folding_captures,
            options,
        );
    }
};

const testing = std.testing;

test "rust utilities produce document symbols and folding ranges" {
    const allocator = testing.allocator;

    var utils = try RustUtilities.init(allocator);
    defer utils.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const language = try Languages.rust.get();
    try parser.setLanguage(language);

    const source =
        \\fn main() {
        \\    println!("Hello, world!");
        \\}
        \\
        \\struct Point {
        \\    x: i32,
        \\    y: i32,
        \\}
        \\
        \\impl Point {
        \\    fn new(x: i32, y: i32) -> Point {
        \\        Point { x, y }
        \\    }
        \\}
        \\
        \\pub trait Display {
        \\    fn display(&self) -> String;
        \\}
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;

    const symbols = try utils.documentSymbols(root, source);
    defer Features.freeDocumentSymbols(allocator, symbols);

    // Should find at least the function, struct, impl, and trait
    try testing.expect(symbols.len >= 2);

    const folding = try utils.foldingRanges(root, .{ .min_line_span = 1 });
    defer allocator.free(folding);

    // Should find foldable regions
    try testing.expect(folding.len >= 2);
}