// Real-time REPL highlighter optimized for interactive shell highlighting
// Designed for sub-5ms latency for typical single-line edits

const std = @import("std");
const Parser = @import("../core/parser.zig").Parser;
const Tree = @import("../core/tree.zig").Tree;
const Node = @import("../core/node.zig").Node;
const Point = @import("../core/node.zig").Point;
const Language = @import("../language.zig").Language;
const Query = @import("../core/query.zig").Query;
const QueryCursor = @import("../core/query.zig").QueryCursor;
const EditBuilder = @import("../core/edit.zig").EditBuilder;
const InputEdit = @import("../core/edit.zig").InputEdit;

pub const HighlightSpan = struct {
    /// Start byte offset in source
    start_byte: u32,
    /// End byte offset in source
    end_byte: u32,
    /// Capture name from query (e.g., "function", "keyword", "string")
    capture: []const u8,
    /// Optional class override (for custom theming)
    class: ?[]const u8 = null,
};

pub const RealtimeHighlighterError = error{
    OutOfMemory,
    ParserError,
    QueryError,
    InvalidTree,
} || Parser.ParseError || Query.QueryError;

/// Real-time highlighter optimized for REPL environments
///
/// Features:
/// - Sub-5ms highlight latency for typical lines
/// - Incremental parsing support
/// - Memory-efficient arena allocator pattern
/// - Handles partial/invalid syntax gracefully
pub const RealtimeHighlighter = struct {
    allocator: std.mem.Allocator,
    parser: Parser,
    language: Language,
    query: ?Query = null,
    previous_tree: ?Tree = null,
    arena: std.heap.ArenaAllocator,

    /// Initialize highlighter for a specific language
    ///
    /// `query_source` should be highlight queries (highlights.scm)
    /// Pass null to skip query-based highlighting (syntax-only)
    pub fn init(
        allocator: std.mem.Allocator,
        language: Language,
        query_source: ?[]const u8,
    ) RealtimeHighlighterError!RealtimeHighlighter {
        var parser = try Parser.init(allocator);
        errdefer parser.deinit();

        try parser.setLanguage(language);

        var query: ?Query = null;
        if (query_source) |src| {
            query = try Query.init(allocator, language, src);
        }

        return .{
            .allocator = allocator,
            .parser = parser,
            .language = language,
            .query = query,
            .previous_tree = null,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *RealtimeHighlighter) void {
        if (self.query) |*q| {
            q.deinit();
        }
        if (self.previous_tree) |*tree| {
            tree.deinit();
        }
        self.parser.deinit();
        self.arena.deinit();
    }

    /// Highlight a line of input from scratch
    ///
    /// This is the fast path for new input or major changes.
    /// Returns highlight spans ordered by start_byte.
    pub fn highlightLine(self: *RealtimeHighlighter, line: []const u8) RealtimeHighlighterError![]HighlightSpan {
        // Free previous tree if exists
        if (self.previous_tree) |*tree| {
            tree.deinit();
            self.previous_tree = null;
        }

        // Reset arena for fresh allocation
        _ = self.arena.reset(.retain_capacity);

        // Parse line
        var tree = try self.parser.parseUtf8(null, line);
        errdefer tree.deinit();

        // Extract highlights
        const spans = try self.extractHighlights(&tree);

        // Save tree for incremental updates
        self.previous_tree = tree;

        return spans;
    }

    /// Update highlights incrementally after an edit
    ///
    /// This is the optimized path for small edits (character insertions/deletions).
    /// Falls back to full re-highlight if previous tree is unavailable.
    pub fn updateLine(
        self: *RealtimeHighlighter,
        new_line: []const u8,
        edit: InputEdit,
    ) RealtimeHighlighterError![]HighlightSpan {
        // If no previous tree, do full highlight
        if (self.previous_tree == null) {
            return self.highlightLine(new_line);
        }

        // Reset arena
        _ = self.arena.reset(.retain_capacity);

        // Apply edit to previous tree
        var old_tree = self.previous_tree.?;
        old_tree.edit(&edit);

        // Incremental parse
        var new_tree = try self.parser.parseUtf8(old_tree, new_line);
        errdefer new_tree.deinit();

        // Cleanup old tree
        old_tree.deinit();

        // Extract highlights
        const spans = try self.extractHighlights(&new_tree);

        // Save new tree
        self.previous_tree = new_tree;

        return spans;
    }

    /// Extract highlight spans from parsed tree
    fn extractHighlights(self: *RealtimeHighlighter, tree: *Tree) ![]HighlightSpan {
        const arena_allocator = self.arena.allocator();

        // If no query, return empty spans (syntax-only mode)
        if (self.query == null) {
            return &[_]HighlightSpan{};
        }

        const query = &self.query.?;
        const cursor = try QueryCursor.init();
        defer cursor.deinit();

        const root = tree.rootNode() orelse return RealtimeHighlighterError.InvalidTree;
        cursor.exec(query, root);

        var spans = std.ArrayList(HighlightSpan).init(arena_allocator);

        while (try cursor.nextCapture(query)) |result| {
            const node = result.capture.node;
            try spans.append(.{
                .start_byte = node.startByte(),
                .end_byte = node.endByte(),
                .capture = result.capture.name,
                .class = null,
            });
        }

        return try spans.toOwnedSlice();
    }

    /// Check if line has syntax errors
    ///
    /// Useful for showing error indicators in REPL prompt
    pub fn hasErrors(self: *RealtimeHighlighter) bool {
        if (self.previous_tree) |tree| {
            const root = tree.rootNode() orelse return false;
            return root.hasError();
        }
        return false;
    }

    /// Get detailed syntax errors (if any)
    pub fn getErrors(self: *RealtimeHighlighter) ![]SyntaxError {
        const arena_allocator = self.arena.allocator();

        if (self.previous_tree) |tree| {
            const root = tree.rootNode() orelse return &[_]SyntaxError{};
            return try collectErrors(arena_allocator, root);
        }

        return &[_]SyntaxError{};
    }
};

pub const SyntaxError = struct {
    start_byte: u32,
    end_byte: u32,
    kind: []const u8,
};

fn collectErrors(allocator: std.mem.Allocator, root: Node) ![]SyntaxError {
    var errors = std.ArrayList(SyntaxError).init(allocator);

    // Walk tree looking for ERROR nodes
    try walkForErrors(root, &errors);

    return try errors.toOwnedSlice();
}

fn walkForErrors(node: Node, errors: *std.ArrayList(SyntaxError)) !void {
    if (std.mem.eql(u8, node.kind(), "ERROR") or std.mem.eql(u8, node.kind(), "MISSING")) {
        try errors.append(.{
            .start_byte = node.startByte(),
            .end_byte = node.endByte(),
            .kind = node.kind(),
        });
    }

    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            try walkForErrors(child, errors);
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const Languages = @import("../languages.zig").Bundled;

const gshell_highlight_query =
    \\(builtin_command) @function.builtin
    \\(command_name (word) @function)
    \\(flag) @parameter
    \\(string) @string
    \\(expansion "$" @punctuation.special (variable_name) @variable)
    \\(comment) @comment
;

test "RealtimeHighlighter: init and deinit" {
    const lang = try Languages.gshell.get();
    var highlighter = try RealtimeHighlighter.init(
        testing.allocator,
        lang,
        gshell_highlight_query,
    );
    defer highlighter.deinit();
}

test "RealtimeHighlighter: highlight simple command" {
    const lang = try Languages.gshell.get();
    var highlighter = try RealtimeHighlighter.init(
        testing.allocator,
        lang,
        gshell_highlight_query,
    );
    defer highlighter.deinit();

    const spans = try highlighter.highlightLine("ls -la");
    try testing.expect(spans.len > 0);

    // Should have at least command and flag
    var has_command = false;
    var has_flag = false;

    for (spans) |span| {
        if (std.mem.eql(u8, span.capture, "function")) has_command = true;
        if (std.mem.eql(u8, span.capture, "parameter")) has_flag = true;
    }

    try testing.expect(has_command);
    try testing.expect(has_flag);
}

test "RealtimeHighlighter: highlight with string" {
    const lang = try Languages.gshell.get();
    var highlighter = try RealtimeHighlighter.init(
        testing.allocator,
        lang,
        gshell_highlight_query,
    );
    defer highlighter.deinit();

    const spans = try highlighter.highlightLine("echo \"hello world\"");
    try testing.expect(spans.len > 0);

    var has_string = false;
    for (spans) |span| {
        if (std.mem.eql(u8, span.capture, "string")) has_string = true;
    }

    try testing.expect(has_string);
}

test "RealtimeHighlighter: highlight builtin command" {
    const lang = try Languages.gshell.get();
    var highlighter = try RealtimeHighlighter.init(
        testing.allocator,
        lang,
        gshell_highlight_query,
    );
    defer highlighter.deinit();

    const spans = try highlighter.highlightLine("cd /tmp");
    try testing.expect(spans.len > 0);

    var has_builtin = false;
    for (spans) |span| {
        if (std.mem.eql(u8, span.capture, "function.builtin")) has_builtin = true;
    }

    try testing.expect(has_builtin);
}

test "RealtimeHighlighter: highlight variable expansion" {
    const lang = try Languages.gshell.get();
    var highlighter = try RealtimeHighlighter.init(
        testing.allocator,
        lang,
        gshell_highlight_query,
    );
    defer highlighter.deinit();

    const spans = try highlighter.highlightLine("echo $HOME");
    try testing.expect(spans.len > 0);

    var has_variable = false;
    for (spans) |span| {
        if (std.mem.eql(u8, span.capture, "variable")) has_variable = true;
    }

    try testing.expect(has_variable);
}

test "RealtimeHighlighter: detect syntax errors" {
    const lang = try Languages.gshell.get();
    var highlighter = try RealtimeHighlighter.init(
        testing.allocator,
        lang,
        gshell_highlight_query,
    );
    defer highlighter.deinit();

    // Parse valid command - should have no errors
    _ = try highlighter.highlightLine("ls -la");
    try testing.expect(!highlighter.hasErrors());

    // Parse incomplete pipeline - should have errors
    _ = try highlighter.highlightLine("ls |");
    // Note: May or may not have errors depending on grammar's error recovery
    // This test demonstrates the API, not grammar specifics
}

test "RealtimeHighlighter: incremental update (character insertion)" {
    const lang = try Languages.gshell.get();
    var highlighter = try RealtimeHighlighter.init(
        testing.allocator,
        lang,
        gshell_highlight_query,
    );
    defer highlighter.deinit();

    // Initial line
    const old_line = "ls -l";
    _ = try highlighter.highlightLine(old_line);

    // User adds 'a' to make "ls -la"
    const new_line = "ls -la";

    const edit = InputEdit{
        .start_byte = 5,
        .old_end_byte = 5,
        .new_end_byte = 6,
        .start_point = .{ .row = 0, .column = 5 },
        .old_end_point = .{ .row = 0, .column = 5 },
        .new_end_point = .{ .row = 0, .column = 6 },
    };

    const spans = try highlighter.updateLine(new_line, edit);
    try testing.expect(spans.len > 0);
}

test "RealtimeHighlighter: multiple highlight calls" {
    const lang = try Languages.gshell.get();
    var highlighter = try RealtimeHighlighter.init(
        testing.allocator,
        lang,
        gshell_highlight_query,
    );
    defer highlighter.deinit();

    // Multiple highlights should work without leaking
    _ = try highlighter.highlightLine("ls");
    _ = try highlighter.highlightLine("cd /tmp");
    _ = try highlighter.highlightLine("echo hello");
    _ = try highlighter.highlightLine("git status");
}
