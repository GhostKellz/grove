/// Example LSP server implementation using Grove
/// This demonstrates how to use grove.lsp module to build a language server
///
/// Usage:
///   zig build-exe examples/lsp_server.zig
///   ./lsp_server --stdio
///
/// This example shows how Ghostls and other LSP servers can leverage Grove's
/// tree-sitter parsing capabilities for syntax analysis, diagnostics, and code intelligence.

const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize language server factory
    const factory = grove.lsp.LanguageServerFactory.init(allocator);

    // Example 1: TypeScript/JavaScript Language Server
    std.debug.print("=== TypeScript LSP Server Example ===\n", .{});
    try typeScriptExample(factory);

    // Example 2: Ghostlang Language Server
    std.debug.print("\n=== Ghostlang LSP Server Example ===\n", .{});
    try ghostlangExample(factory);

    // Example 3: Low-level LSP utilities
    std.debug.print("\n=== Low-level LSP Utilities Example ===\n", .{});
    try lowLevelExample(allocator);
}

/// Example TypeScript language server operations
fn typeScriptExample(factory: grove.lsp.LanguageServerFactory) !void {
    var server = try factory.createTypeScriptServer();
    defer server.deinit();

    const typescript_source =
        \\function greet(name: string): string {
        \\  return `Hello, ${name}!`;
        \\}
        \\
        \\const message = greet("World");
        \\console.log(message);
    ;

    // 1. Get diagnostics (syntax errors)
    std.debug.print("1. Diagnostics:\n", .{});
    const diagnostics = try server.diagnostics(typescript_source);
    defer server.allocator.free(diagnostics);

    if (diagnostics.len == 0) {
        std.debug.print("   ✓ No syntax errors found\n", .{});
    } else {
        for (diagnostics) |diag| {
            std.debug.print("   ✗ {s} at line {d}:{d}\n", .{
                diag.message,
                diag.range.start.line,
                diag.range.start.character,
            });
        }
    }

    // 2. Get document symbols (outline)
    std.debug.print("\n2. Document Symbols:\n", .{});
    const symbols = try server.documentSymbols(typescript_source);
    defer server.allocator.free(symbols);

    for (symbols) |symbol| {
        std.debug.print("   • {s} ({s}) at line {d}\n", .{
            symbol.label,
            @tagName(symbol.kind),
            symbol.range.start.line,
        });
    }

    // 3. Get folding ranges
    std.debug.print("\n3. Folding Ranges:\n", .{});
    const folds = try server.foldingRanges(typescript_source);
    defer server.allocator.free(folds);

    for (folds) |fold| {
        std.debug.print("   • Fold lines {d}-{d}\n", .{
            fold.start_line,
            fold.end_line,
        });
    }

    // 4. Go to definition
    std.debug.print("\n4. Go to Definition:\n", .{});
    const cursor_position = grove.lsp.Position{ .line = 4, .character = 18 }; // "greet" call
    const definition = try server.gotoDefinition(typescript_source, cursor_position);

    if (definition) |def| {
        std.debug.print("   → Definition found at line {d}:{d}\n", .{
            def.range.start.line,
            def.range.start.character,
        });
    } else {
        std.debug.print("   ⨯ No definition found\n", .{});
    }

    // 5. Hover information
    std.debug.print("\n5. Hover Info:\n", .{});
    const hover_text = try server.hover(typescript_source, cursor_position);
    defer if (hover_text) |text| server.allocator.free(text);

    if (hover_text) |text| {
        std.debug.print("   {s}\n", .{text});
    }

    // 6. Completions
    std.debug.print("\n6. Completions:\n", .{});
    const completions = try server.completion(typescript_source, cursor_position);
    defer server.allocator.free(completions);

    for (completions[0..@min(5, completions.len)]) |completion| {
        std.debug.print("   • {s} ({s})\n", .{
            completion.label,
            @tagName(completion.kind),
        });
    }
}

/// Example Ghostlang language server operations
fn ghostlangExample(factory: grove.lsp.LanguageServerFactory) !void {
    var server = try factory.createGhostlangServer();
    defer server.deinit();

    const ghostlang_source =
        \\-- Ghostlang configuration example
        \\local function setup_editor()
        \\    set_option("line_numbers", true)
        \\    set_option("tab_width", 4)
        \\end
        \\
        \\local config = {
        \\    theme = "tokyonight",
        \\    keybindings = {
        \\        { mode = "n", key = "<leader>w", cmd = ":write<CR>" }
        \\    }
        \\}
        \\
        \\setup_editor()
        \\register_config(config)
    ;

    // Parse and analyze Ghostlang code
    std.debug.print("1. Parsing Ghostlang source...\n", .{});

    const diagnostics = try server.diagnostics(ghostlang_source);
    defer server.allocator.free(diagnostics);

    if (diagnostics.len == 0) {
        std.debug.print("   ✓ Valid Ghostlang syntax\n", .{});
    }

    const symbols = try server.documentSymbols(ghostlang_source);
    defer server.allocator.free(symbols);

    std.debug.print("\n2. Ghostlang Symbols:\n", .{});
    for (symbols) |symbol| {
        std.debug.print("   • {s} ({s})\n", .{
            symbol.label,
            @tagName(symbol.kind),
        });
    }
}

/// Example of low-level LSP utilities without LanguageServer abstraction
fn lowLevelExample(allocator: std.mem.Allocator) !void {
    const source =
        \\fn calculate(x: i32, y: i32) i32 {
        \\    return x + y
        \\}
    ;

    // Parse with grove directly
    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    const language = try grove.Languages.zig.get();
    try parser.setLanguage(language);

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.EmptyTree;

    // Use LSP utilities
    std.debug.print("1. Position/Offset Conversion:\n", .{});

    const position = grove.lsp.Position{ .line = 1, .character = 4 };
    const offset = grove.lsp.Utils.positionToByteOffset(source, position);
    std.debug.print("   Position line:{d} char:{d} → offset:{d}\n", .{
        position.line,
        position.character,
        offset,
    });

    const back_to_position = grove.lsp.Utils.byteOffsetToPosition(source, offset);
    std.debug.print("   Offset:{d} → position line:{d} char:{d}\n", .{
        offset,
        back_to_position.line,
        back_to_position.character,
    });

    // Find node at position
    std.debug.print("\n2. Node at Position:\n", .{});
    const grove_point = position.toGrovePoint();
    const node_at_pos = root.descendantForPointRange(grove_point, grove_point);

    if (node_at_pos) |node| {
        std.debug.print("   Node kind: {s}\n", .{node.kind()});
        std.debug.print("   Node text: {s}\n", .{node.text(source) orelse "<no text>"});

        const node_range = grove.lsp.Range{
            .start = grove.lsp.Position.fromGrovePoint(node.startPosition()),
            .end = grove.lsp.Position.fromGrovePoint(node.endPosition()),
        };
        std.debug.print("   Range: line:{d}-{d}\n", .{
            node_range.start.line,
            node_range.end.line,
        });
    }

    // Extract diagnostics manually
    std.debug.print("\n3. Manual Diagnostic Collection:\n", .{});
    var diagnostics = std.ArrayList(grove.lsp.Diagnostic).init(allocator);
    defer diagnostics.deinit();

    // Walk tree looking for ERROR nodes
    var cursor = try grove.TreeCursor.init(root);
    defer cursor.deinit();

    while (cursor.nextNode()) |node| {
        if (std.mem.eql(u8, node.kind(), "ERROR") or
            std.mem.eql(u8, node.kind(), "MISSING"))
        {
            try diagnostics.append(.{
                .range = .{
                    .start = grove.lsp.Position.fromGrovePoint(node.startPosition()),
                    .end = grove.lsp.Position.fromGrovePoint(node.endPosition()),
                },
                .severity = .@"error",
                .message = "Syntax error detected",
                .source = "grove-manual",
            });
        }
    }

    if (diagnostics.items.len == 0) {
        std.debug.print("   ✓ No errors found (manual scan)\n", .{});
    }
}

// ============================================================================
// Bonus: JSON-RPC Message Handling Example
// ============================================================================

/// Example JSON-RPC message handler for LSP protocol
/// This shows how to integrate Grove LSP with actual LSP protocol messages
const JsonRpcHandler = struct {
    server: grove.lsp.LanguageServer,
    documents: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator, language: grove.Language) !JsonRpcHandler {
        return .{
            .server = try grove.lsp.LanguageServer.init(allocator, language),
            .documents = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *JsonRpcHandler) void {
        var it = self.documents.iterator();
        while (it.next()) |entry| {
            self.server.allocator.free(entry.key_ptr.*);
            self.server.allocator.free(entry.value_ptr.*);
        }
        self.documents.deinit();
        self.server.deinit();
    }

    /// Handle textDocument/didOpen notification
    pub fn handleDidOpen(self: *JsonRpcHandler, uri: []const u8, text: []const u8) !void {
        const uri_copy = try self.server.allocator.dupe(u8, uri);
        const text_copy = try self.server.allocator.dupe(u8, text);
        try self.documents.put(uri_copy, text_copy);

        // Send diagnostics
        const diagnostics = try self.server.diagnostics(text);
        defer self.server.allocator.free(diagnostics);

        // In real LSP server, you would send these diagnostics as JSON-RPC notification
        std.debug.print("[LSP] textDocument/didOpen: {s}\n", .{uri});
        std.debug.print("[LSP] Found {d} diagnostics\n", .{diagnostics.len});
    }

    /// Handle textDocument/hover request
    pub fn handleHover(self: *JsonRpcHandler, uri: []const u8, position: grove.lsp.Position) !?[]const u8 {
        const text = self.documents.get(uri) orelse return null;
        return try self.server.hover(text, position);
    }

    /// Handle textDocument/definition request
    pub fn handleDefinition(self: *JsonRpcHandler, uri: []const u8, position: grove.lsp.Position) !?grove.lsp.Location {
        const text = self.documents.get(uri) orelse return null;
        var location = (try self.server.gotoDefinition(text, position)) orelse return null;

        // Set the URI
        location.uri = uri;
        return location;
    }
};

test "lsp server example" {
    const allocator = std.testing.allocator;

    const factory = grove.lsp.LanguageServerFactory.init(allocator);
    var server = try factory.createZigServer();
    defer server.deinit();

    const source = "const x: i32 = 42;";

    const diagnostics = try server.diagnostics(source);
    defer allocator.free(diagnostics);

    try std.testing.expect(diagnostics.len == 0);
}
