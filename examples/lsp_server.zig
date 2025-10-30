//! Example: Building a Simple LSP Server with Grove
//!
//! This example demonstrates how to use Grove's LSP helpers to build
//! a minimal Language Server Protocol server with:
//! - Document symbols
//! - Diagnostics
//! - Go-to-definition
//! - Find references
//! - Folding ranges
//! - Semantic tokens
//!
//! Run with: zig build run-example-lsp

const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.log.err("Memory leak detected!", .{});
        }
    }
    const allocator = gpa.allocator();

    // Initialize LSP server
    var server = try SimpleLSPServer.init(allocator);
    defer server.deinit();

    // Example document
    const source =
        \\-- Ghostlang example
        \\function calculateSum(numbers)
        \\    local total = 0
        \\    for i, num in ipairs(numbers) do
        \\        total = total + num
        \\    end
        \\    return total
        \\end
        \\
        \\function main()
        \\    local data = {1, 2, 3, 4, 5}
        \\    local result = calculateSum(data)
        \\    print("Sum:", result)
        \\end
        \\
        \\-- Invalid syntax for testing diagnostics
        \\function broken(
        \\    -- missing closing paren
    ;

    std.log.info("Opening document...", .{});
    try server.openDocument("file:///example.gza", source);

    // Demonstrate LSP features
    std.log.info("\n=== Document Symbols ===", .{});
    try server.showDocumentSymbols("file:///example.gza");

    std.log.info("\n=== Diagnostics ===", .{});
    try server.showDiagnostics("file:///example.gza");

    std.log.info("\n=== Go-to-Definition ===", .{});
    const position = grove.LSP.Position{ .line = 11, .character = 19 }; // "calculateSum" in main
    try server.showDefinition("file:///example.gza", position);

    std.log.info("\n=== Find References ===", .{});
    try server.showReferences("file:///example.gza", "calculateSum");

    std.log.info("\n=== Folding Ranges ===", .{});
    try server.showFoldingRanges("file:///example.gza");

    std.log.info("\n=== Semantic Tokens ===", .{});
    try server.showSemanticTokens("file:///example.gza");
}

/// Simple LSP Server using Grove helpers
const SimpleLSPServer = struct {
    allocator: std.mem.Allocator,
    parser: grove.Parser,
    language: grove.Language,
    documents: std.StringHashMap(Document),

    const Document = struct {
        uri: []const u8,
        source: []const u8,
        tree: ?grove.Tree,
    };

    pub fn init(allocator: std.mem.Allocator) !SimpleLSPServer {
        var parser = try grove.Parser.init(allocator);
        const language = try grove.Languages.ghostlang.get();
        try parser.setLanguage(language);

        return .{
            .allocator = allocator,
            .parser = parser,
            .language = language,
            .documents = std.StringHashMap(Document).init(allocator),
        };
    }

    pub fn deinit(self: *SimpleLSPServer) void {
        var it = self.documents.valueIterator();
        while (it.next()) |doc| {
            if (doc.tree) |*tree| {
                tree.deinit();
            }
            self.allocator.free(doc.uri);
            self.allocator.free(doc.source);
        }
        self.documents.deinit();
        self.parser.deinit();
    }

    pub fn openDocument(self: *SimpleLSPServer, uri: []const u8, source: []const u8) !void {
        const uri_owned = try self.allocator.dupe(u8, uri);
        errdefer self.allocator.free(uri_owned);

        const source_owned = try self.allocator.dupe(u8, source);
        errdefer self.allocator.free(source_owned);

        const tree = try self.parser.parseUtf8(null, source_owned);

        try self.documents.put(uri_owned, .{
            .uri = uri_owned,
            .source = source_owned,
            .tree = tree,
        });
    }

    fn getDocument(self: *SimpleLSPServer, uri: []const u8) ?*Document {
        return self.documents.getPtr(uri);
    }

    pub fn showDocumentSymbols(self: *SimpleLSPServer, uri: []const u8) !void {
        const doc = self.getDocument(uri) orelse return error.DocumentNotFound;
        const tree = doc.tree orelse return error.TreeNotParsed;
        const root = tree.rootNode() orelse return;

        var symbols = try grove.LSP.extractSymbols(
            self.allocator,
            root,
            doc.source,
            null,
        );
        defer {
            for (symbols.items) |*sym| sym.deinit(self.allocator);
            symbols.deinit(self.allocator);
        }

        for (symbols.items) |sym| {
            std.log.info("  {s} {s} line {}", .{
                sym.name,
                @tagName(sym.kind),
                sym.range.start.line,
            });

            // Show children (nested symbols)
            for (sym.children.items) |child| {
                std.log.info("    └─ {s} {s} line {}", .{
                    child.name,
                    @tagName(child.kind),
                    child.range.start.line,
                });
            }
        }
    }

    pub fn showDiagnostics(self: *SimpleLSPServer, uri: []const u8) !void {
        const doc = self.getDocument(uri) orelse return error.DocumentNotFound;
        const tree = doc.tree orelse return error.TreeNotParsed;
        const root = tree.rootNode() orelse return;

        var diagnostics = try grove.LSP.collectDiagnostics(
            self.allocator,
            root,
            doc.source,
        );
        defer {
            for (diagnostics.items) |*diag| diag.deinit(self.allocator);
            diagnostics.deinit(self.allocator);
        }

        if (diagnostics.items.len == 0) {
            std.log.info("  No syntax errors found!", .{});
        } else {
            for (diagnostics.items) |diag| {
                std.log.info("  [{}:{}] {s}: {s}", .{
                    diag.range.start.line,
                    diag.range.start.character,
                    @tagName(diag.severity),
                    diag.message,
                });
            }
        }
    }

    pub fn showDefinition(self: *SimpleLSPServer, uri: []const u8, position: grove.LSP.Position) !void {
        const doc = self.getDocument(uri) orelse return error.DocumentNotFound;
        const tree = doc.tree orelse return error.TreeNotParsed;
        const root = tree.rootNode() orelse return;

        // Find node at cursor
        const cursor_node = grove.LSP.findNodeAtPosition(root, position) orelse {
            std.log.info("  No node at position", .{});
            return;
        };

        std.log.info("  Cursor on: {s}", .{cursor_node.kind()});

        // Check if it's an identifier
        if (std.mem.eql(u8, cursor_node.kind(), "identifier")) {
            const identifier = cursor_node.text(doc.source) orelse return;
            std.log.info("  Looking for definition of: {s}", .{identifier});

            // Find definition
            if (grove.LSP.findDefinition(root, identifier, doc.source)) |def_node| {
                const range = grove.LSP.nodeToRange(def_node);
                std.log.info("  ✓ Definition found at line {} ({s})", .{
                    range.start.line,
                    def_node.kind(),
                });
            } else {
                std.log.info("  ✗ Definition not found", .{});
            }
        }
    }

    pub fn showReferences(self: *SimpleLSPServer, uri: []const u8, identifier: []const u8) !void {
        const doc = self.getDocument(uri) orelse return error.DocumentNotFound;
        const tree = doc.tree orelse return error.TreeNotParsed;
        const root = tree.rootNode() orelse return;

        var references = try grove.LSP.findReferences(
            self.allocator,
            root,
            identifier,
            doc.source,
        );
        defer references.deinit(self.allocator);

        std.log.info("  Found {} reference(s) to '{s}':", .{ references.items.len, identifier });
        for (references.items) |ref_node| {
            const range = grove.LSP.nodeToRange(ref_node);
            std.log.info("    - line {} column {}", .{
                range.start.line,
                range.start.character,
            });
        }
    }

    pub fn showFoldingRanges(self: *SimpleLSPServer, uri: []const u8) !void {
        const doc = self.getDocument(uri) orelse return error.DocumentNotFound;
        const tree = doc.tree orelse return error.TreeNotParsed;
        const root = tree.rootNode() orelse return;

        var folding = try grove.LSP.extractFoldingRanges(
            self.allocator,
            root,
            doc.source,
        );
        defer folding.deinit(self.allocator);

        for (folding.items) |range| {
            const kind_str = if (range.kind) |k| @tagName(k) else "region";
            std.log.info("  lines {}-{} ({s})", .{
                range.start_line,
                range.end_line,
                kind_str,
            });
        }
    }

    pub fn showSemanticTokens(self: *SimpleLSPServer, uri: []const u8) !void {
        const doc = self.getDocument(uri) orelse return error.DocumentNotFound;
        const tree = doc.tree orelse return error.TreeNotParsed;
        const root = tree.rootNode() orelse return;

        var tokens = try grove.LSP.extractSemanticTokens(
            self.allocator,
            root,
            doc.source,
            null,
        );
        defer tokens.deinit(self.allocator);

        std.log.info("  Generated {} semantic tokens", .{tokens.items.len});

        // Show first 10 tokens as example
        const count = @min(tokens.items.len, 10);
        for (tokens.items[0..count]) |token| {
            std.log.info("    [{}:{}] {s} (len={})", .{
                token.line,
                token.start_char,
                @tagName(token.token_type),
                token.length,
            });
        }

        if (tokens.items.len > 10) {
            std.log.info("    ... and {} more", .{tokens.items.len - 10});
        }
    }
};
