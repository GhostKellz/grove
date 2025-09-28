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

const typescript_highlight_query_source = @embedFile("../../vendor/grammars/typescript/queries/highlights.scm");

// Define TypeScript-specific symbol extraction rules
const typescript_symbol_rules = [_]SymbolRule{
    .{
        .symbol_capture = "function.declaration",
        .name_capture = "function.name",
        .kind = .function,
    },
    .{
        .symbol_capture = "method.declaration",
        .name_capture = "method.name",
        .kind = .method,
    },
    .{
        .symbol_capture = "class.declaration",
        .name_capture = "class.name",
        .kind = .class,
    },
    .{
        .symbol_capture = "interface.declaration",
        .name_capture = "interface.name",
        .kind = .class, // Use class for interfaces
    },
    .{
        .symbol_capture = "variable.declaration",
        .name_capture = "variable.name",
        .kind = .variable,
    },
    .{
        .symbol_capture = "const.declaration",
        .name_capture = "const.name",
        .kind = .constant,
    },
};

// TypeScript constructs that should be foldable
const typescript_folding_captures = [_][]const u8{
    "function.declaration",
    "method.declaration",
    "class.declaration",
    "interface.declaration",
    "object.literal",
    "array.literal",
    "block.statement",
    "switch.statement",
    "if.statement",
    "for.statement",
    "while.statement",
};

// Create a simple query for TypeScript symbols since we may not have locals.scm
const typescript_symbols_query_source =
    \\(function_declaration name: (identifier) @function.name) @function.declaration
    \\(method_definition key: (property_identifier) @method.name) @method.declaration
    \\(class_declaration name: (type_identifier) @class.name) @class.declaration
    \\(interface_declaration name: (type_identifier) @interface.name) @interface.declaration
    \\(lexical_declaration (variable_declarator name: (identifier) @variable.name)) @variable.declaration
    \\(variable_declaration (variable_declarator name: (identifier) @const.name)) @const.declaration
;

const typescript_folding_query_source =
    \\(function_declaration body: (statement_block) @function.declaration)
    \\(method_definition value: (function) @method.declaration)
    \\(class_declaration body: (class_body) @class.declaration)
    \\(interface_declaration body: (object_type) @interface.declaration)
    \\(object) @object.literal
    \\(array) @array.literal
    \\(statement_block) @block.statement
    \\(switch_statement body: (switch_body) @switch.statement)
    \\(if_statement consequence: (_) @if.statement)
    \\(for_statement body: (_) @for.statement)
    \\(while_statement body: (_) @while.statement
;

pub const TypeScriptUtilities = struct {
    allocator: std.mem.Allocator,
    symbols_query: Query,
    folding_query: Query,

    pub fn init(allocator: std.mem.Allocator) !TypeScriptUtilities {
        const language = try Languages.typescript.get();

        var symbols_query = try Query.init(allocator, language, typescript_symbols_query_source);
        errdefer symbols_query.deinit();

        var folding_query = try Query.init(allocator, language, typescript_folding_query_source);
        errdefer folding_query.deinit();

        return .{
            .allocator = allocator,
            .symbols_query = symbols_query,
            .folding_query = folding_query,
        };
    }

    pub fn deinit(self: *TypeScriptUtilities) void {
        self.symbols_query.deinit();
        self.folding_query.deinit();
    }

    pub fn documentSymbols(
        self: *TypeScriptUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.symbols_query,
            root,
            source,
            &typescript_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *TypeScriptUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.folding_query,
            root,
            &typescript_folding_captures,
            options,
        );
    }
};

const testing = std.testing;

test "typescript utilities produce document symbols and folding ranges" {
    const allocator = testing.allocator;

    var utils = try TypeScriptUtilities.init(allocator);
    defer utils.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const language = try Languages.typescript.get();
    try parser.setLanguage(language);

    const source =
        \\function greet(name: string): string {
        \\  return "Hello, " + name;
        \\}
        \\
        \\class Calculator {
        \\  add(a: number, b: number): number {
        \\    return a + b;
        \\  }
        \\}
        \\
        \\const result = greet("World");
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;

    const symbols = try utils.documentSymbols(root, source);
    defer Features.freeDocumentSymbols(allocator, symbols);

    // Should find at least the function and class
    try testing.expect(symbols.len >= 2);

    const folding = try utils.foldingRanges(root, .{ .min_line_span = 1 });
    defer allocator.free(folding);

    // Should find foldable regions
    try testing.expect(folding.len >= 1);
}