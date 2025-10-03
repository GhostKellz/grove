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

const markdown_symbol_rules = [_]SymbolRule{
    .{
        .symbol_capture = "heading.definition",
        .name_capture = "heading.text",
        .detail_capture = null,
        .kind = .module,
    },
};

const markdown_folding_captures = [_][]const u8{
    "section.structure",
    "code.block",
};

const markdown_symbols_query_source =
    \\(atx_heading) @heading.definition
    \\(setext_heading) @heading.definition
;

const markdown_folding_query_source =
    \\(section) @section.structure
    \\(fenced_code_block) @code.block
;

pub const MarkdownUtilities = struct {
    allocator: std.mem.Allocator,
    symbols_query: Query,
    folding_query: Query,

    pub fn init(allocator: std.mem.Allocator) !MarkdownUtilities {
        const language = try Languages.markdown.get();

        var symbols_query = try Query.init(allocator, language, markdown_symbols_query_source);
        errdefer symbols_query.deinit();

        var folding_query = try Query.init(allocator, language, markdown_folding_query_source);
        errdefer folding_query.deinit();

        return .{
            .allocator = allocator,
            .symbols_query = symbols_query,
            .folding_query = folding_query,
        };
    }

    pub fn deinit(self: *MarkdownUtilities) void {
        self.symbols_query.deinit();
        self.folding_query.deinit();
    }

    pub fn documentSymbols(
        self: *MarkdownUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return Features.collectDocumentSymbols(
            self.allocator,
            &self.symbols_query,
            root,
            source,
            &markdown_symbol_rules,
        );
    }

    pub fn foldingRanges(
        self: *MarkdownUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return Features.collectFoldingRangesFromQuery(
            self.allocator,
            &self.folding_query,
            root,
            &markdown_folding_captures,
            options,
        );
    }
};

const testing = std.testing;

test "markdown utilities produce document symbols and folding ranges" {
    const allocator = testing.allocator;

    var utils = try MarkdownUtilities.init(allocator);
    defer utils.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const language = try Languages.markdown.get();
    try parser.setLanguage(language);

    const source =
        \\# Title
        \\
        \\Some text
        \\
        \\## Subtitle
        \\
        \\More text
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.MissingRoot;

    const symbols = try utils.documentSymbols(root, source);
    defer Features.freeDocumentSymbols(allocator, symbols);

    const folding = try utils.foldingRanges(root, .{ .min_line_span = 1 });
    defer allocator.free(folding);
}
