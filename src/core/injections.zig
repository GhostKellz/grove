const std = @import("std");
const Parser = @import("parser.zig").Parser;
const Tree = @import("tree.zig").Tree;
const Node = @import("node.zig").Node;
const Language = @import("../language.zig").Language;

/// Language injection for embedded code (e.g., markdown code blocks, HTML script tags)
pub const Injection = struct {
    /// The language to parse this range with
    language: Language,
    /// Start byte offset
    start_byte: u32,
    /// End byte offset
    end_byte: u32,
    /// Content to parse (slice of original source)
    content: []const u8,
};

/// Result of parsing with injections
pub const InjectionResult = struct {
    /// Primary tree for the host language
    host_tree: Tree,
    /// Trees for injected languages
    injected_trees: []InjectedTree,
    /// Allocator used for injected_trees
    allocator: std.mem.Allocator,

    pub const InjectedTree = struct {
        tree: Tree,
        language: Language,
        start_byte: u32,
        end_byte: u32,
    };

    pub fn deinit(self: *InjectionResult) void {
        self.host_tree.deinit();
        for (self.injected_trees) |*injected| {
            injected.tree.deinit();
        }
        self.allocator.free(self.injected_trees);
    }
};

/// Parse source with language injections
pub fn parseWithInjections(
    allocator: std.mem.Allocator,
    host_language: Language,
    source: []const u8,
    injections: []const Injection,
) !InjectionResult {
    // Parse the host document first
    var host_parser = try Parser.init(allocator);
    defer host_parser.deinit();

    try host_parser.setLanguage(host_language);
    const host_tree = try host_parser.parseUtf8(null, source);

    // Parse each injection
    var injected_trees = std.ArrayList(InjectionResult.InjectedTree).init(allocator);
    errdefer {
        for (injected_trees.items) |*item| {
            item.tree.deinit();
        }
        injected_trees.deinit();
    }

    for (injections) |injection| {
        var injection_parser = try Parser.init(allocator);
        defer injection_parser.deinit();

        try injection_parser.setLanguage(injection.language);
        const injected_tree = try injection_parser.parseUtf8(null, injection.content);

        try injected_trees.append(.{
            .tree = injected_tree,
            .language = injection.language,
            .start_byte = injection.start_byte,
            .end_byte = injection.end_byte,
        });
    }

    return .{
        .host_tree = host_tree,
        .injected_trees = try injected_trees.toOwnedSlice(),
        .allocator = allocator,
    };
}

/// Helper to find injections in a tree using a query
/// For example, finding code blocks in markdown
pub fn findInjections(
    allocator: std.mem.Allocator,
    tree: Tree,
    source: []const u8,
    injection_query: []const u8,
    language_map: std.StringHashMap(Language),
) ![]Injection {
    const Query = @import("query.zig").Query;
    const QueryCursor = @import("query.zig").QueryCursor;

    const root = tree.rootNode() orelse return &[_]Injection{};

    var query = try Query.init(allocator, tree.language(), injection_query);
    defer query.deinit();

    var cursor = try QueryCursor.init();
    defer cursor.deinit();

    cursor.exec(&query, root);

    var injections = std.ArrayList(Injection).init(allocator);
    errdefer injections.deinit();

    while (cursor.nextCapture(&query)) |capture_result| {
        const capture = capture_result.capture;

        // Look for language and content captures
        if (std.mem.eql(u8, capture.name, "injection.language")) {
            const lang_name = capture.node.text(source);
            if (language_map.get(lang_name)) |lang| {
                // Find corresponding content node
                // This is simplified - real implementation would match pairs
                const start = capture.node.startByte();
                const end = capture.node.endByte();

                try injections.append(.{
                    .language = lang,
                    .start_byte = start,
                    .end_byte = end,
                    .content = source[start..end],
                });
            }
        }
    }

    return injections.toOwnedSlice();
}

const testing = std.testing;
const Languages = @import("../languages.zig").Bundled;

test "parseWithInjections handles embedded languages" {
    const allocator = testing.allocator;

    // Parse markdown with embedded JSON
    const markdown_source = "```json\n{\"key\": true}\n```";
    const json_lang = try Languages.json.get();
    const markdown_lang = try Languages.markdown.get();

    const injections = [_]Injection{.{
        .language = json_lang,
        .start_byte = 8,
        .end_byte = 21,
        .content = "{\"key\": true}",
    }};

    var result = try parseWithInjections(
        allocator,
        markdown_lang,
        markdown_source,
        &injections,
    );
    defer result.deinit();

    try testing.expect(result.host_tree.isValid());
    try testing.expectEqual(@as(usize, 1), result.injected_trees.len);
    try testing.expect(result.injected_trees[0].tree.isValid());
}
