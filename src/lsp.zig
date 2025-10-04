//! Language Server Protocol helper module for Grove
//!
//! This module provides utilities and abstractions for implementing LSP features
//! using Grove's Tree-sitter parsing and semantic analysis capabilities.
//! It's designed to be used by external editors and language servers.

const std = @import("std");
const grove = @import("root.zig");

// Re-export common LSP types for convenience
pub const Position = struct {
    line: u32,
    character: u32,

    pub fn fromGrovePoint(point: grove.Point) Position {
        return .{ .line = point.row, .character = point.column };
    }

    pub fn toGrovePoint(self: Position) grove.Point {
        return .{ .row = self.line, .column = self.character };
    }
};

pub const Range = struct {
    start: Position,
    end: Position,

    pub fn fromGroveNodes(start_node: grove.Node, end_node: grove.Node) Range {
        return .{
            .start = Position.fromGrovePoint(start_node.startPosition()),
            .end = Position.fromGrovePoint(end_node.endPosition()),
        };
    }
};

pub const Location = struct {
    uri: []const u8,
    range: Range,
};

pub const DocumentSymbol = struct {
    name: []const u8,
    kind: SymbolKind,
    range: Range,
    selection_range: Range,
    children: ?[]DocumentSymbol = null,
};

pub const SymbolKind = enum(u32) {
    file = 1,
    module = 2,
    namespace = 3,
    package = 4,
    class = 5,
    method = 6,
    property = 7,
    field = 8,
    constructor = 9,
    @"enum" = 10,
    interface = 11,
    function = 12,
    variable = 13,
    constant = 14,
    string = 15,
    number = 16,
    boolean = 17,
    array = 18,
    object = 19,
    key = 20,
    null = 21,
    enum_member = 22,
    @"struct" = 23,
    event = 24,
    operator = 25,
    type_parameter = 26,
};

pub const CompletionItem = struct {
    label: []const u8,
    kind: CompletionItemKind,
    detail: ?[]const u8 = null,
    documentation: ?[]const u8 = null,
    insert_text: ?[]const u8 = null,
};

pub const CompletionItemKind = enum(u32) {
    text = 1,
    method = 2,
    function = 3,
    constructor = 4,
    field = 5,
    variable = 6,
    class = 7,
    interface = 8,
    module = 9,
    property = 10,
    unit = 11,
    value = 12,
    @"enum" = 13,
    keyword = 14,
    snippet = 15,
    color = 16,
    file = 17,
    reference = 18,
    folder = 19,
    enum_member = 20,
    constant = 21,
    @"struct" = 22,
    event = 23,
    operator = 24,
    type_parameter = 25,
};

pub const FoldingRange = struct {
    start_line: u32,
    start_character: ?u32 = null,
    end_line: u32,
    end_character: ?u32 = null,
    kind: ?FoldingRangeKind = null,
};

pub const FoldingRangeKind = enum {
    comment,
    imports,
    region,
};

/// LSP server interface for a specific language
pub const LanguageServer = struct {
    allocator: std.mem.Allocator,
    language: grove.Language,
    parser_pool: grove.ParserPool,
    semantic_analyzer: grove.Semantic.SemanticAnalyzer,
    editor_services: grove.EditorServices,

    pub fn init(allocator: std.mem.Allocator, language: grove.Language) !LanguageServer {
        const parser_pool = try grove.ParserPool.init(allocator, language, 4);
        const semantic_analyzer = grove.Semantic.createAnalyzer(allocator, language);
        const editor_services = try grove.EditorServices.init(allocator);

        return .{
            .allocator = allocator,
            .language = language,
            .parser_pool = parser_pool,
            .semantic_analyzer = semantic_analyzer,
            .editor_services = editor_services,
        };
    }

    pub fn deinit(self: *LanguageServer) void {
        self.parser_pool.deinit();
        self.semantic_analyzer.deinit();
        self.editor_services.deinit();
    }

    /// Parse document and return syntax tree
    pub fn parseDocument(self: *LanguageServer, source: []const u8) !grove.Tree {
        var lease = try self.parser_pool.acquire();
        defer lease.release();
        return try lease.parserRef().parseUtf8(null, source);
    }

    /// Get document symbols for outline/breadcrumb navigation
    pub fn documentSymbols(self: *LanguageServer, source: []const u8) ![]DocumentSymbol {
        var tree = try self.parseDocument(source);
        defer tree.deinit();

        const utilities = try self.editor_services.getUtilities(self.language);
        return try utilities.documentSymbols(tree.rootNode().?, source);
    }

    /// Get folding ranges for code folding
    pub fn foldingRanges(self: *LanguageServer, source: []const u8) ![]FoldingRange {
        var tree = try self.parseDocument(source);
        defer tree.deinit();

        const utilities = try self.editor_services.getUtilities(self.language);
        return try utilities.foldingRanges(tree.rootNode().?, source);
    }

    /// Find definition of symbol at position
    /// Uses Tree-sitter queries to locate function/variable definitions generically
    pub fn gotoDefinition(self: *LanguageServer, source: []const u8, position: Position) !?Location {
        var tree = try self.parseDocument(source);
        defer tree.deinit();

        const grove_point = position.toGrovePoint();
        const root = tree.rootNode() orelse return null;

        // Find the node at the cursor position
        const node_at_cursor = root.descendantForPointRange(grove_point, grove_point) orelse return null;

        // If it's an identifier, search for its definition
        const node_text = node_at_cursor.text(source) orelse return null;
        const identifier_name = if (std.mem.eql(u8, node_at_cursor.kind(), "identifier"))
            node_text
        else
            return null;

        // Walk the tree looking for definitions (function_declaration, variable_declaration, etc.)
        var cursor = try grove.TreeCursor.init(root);
        defer cursor.deinit();

        while (cursor.nextNode()) |node| {
            const kind = node.kind();
            // Generic pattern matching for common definition node types
            const is_definition = std.mem.indexOf(u8, kind, "declaration") != null or
                                std.mem.indexOf(u8, kind, "definition") != null;

            if (is_definition) {
                // Check if this definition matches our identifier
                const def_name = node.childByFieldName("name") orelse continue;
                const def_text = def_name.text(source) orelse continue;

                if (std.mem.eql(u8, identifier_name, def_text)) {
                    return Location{
                        .uri = "", // Caller must provide URI
                        .range = Range{
                            .start = Position.fromGrovePoint(def_name.startPosition()),
                            .end = Position.fromGrovePoint(def_name.endPosition()),
                        },
                    };
                }
            }
        }

        return null;
    }

    /// Get hover information at position
    pub fn hover(self: *LanguageServer, source: []const u8, position: Position) !?[]const u8 {
        var tree = try self.parseDocument(source);
        defer tree.deinit();

        const grove_point = position.toGrovePoint();
        const analysis = try grove.Semantic.analyzePosition(
            self.allocator,
            tree.rootNode().?,
            grove_point.row,
            grove_point.column,
            .typescript // Placeholder
        );

        // Generate hover text based on semantic context
        const hover_text = switch (analysis.context) {
            .function_call => "Function call",
            .function_body => "Function body",
            .class_body => "Class body",
            .identifier => "Identifier",
            .string_literal => "String literal",
            .comment => "Comment",
            .unknown => "Unknown",
        };

        return try std.fmt.allocPrint(self.allocator, "Node: {s}\nContext: {s}", .{
            analysis.node.kind(),
            hover_text,
        });
    }

    /// Get completions at position
    /// Extracts identifiers from the tree to provide basic completion suggestions
    pub fn completion(self: *LanguageServer, source: []const u8, position: Position) ![]CompletionItem {
        _ = position; // TODO: Use position to filter completions by scope

        var tree = try self.parseDocument(source);
        defer tree.deinit();

        const root = tree.rootNode() orelse return &.{};
        var completion_list = std.ArrayList(CompletionItem).init(self.allocator);
        errdefer completion_list.deinit();

        var seen_identifiers = std.StringHashMap(void).init(self.allocator);
        defer seen_identifiers.deinit();

        // Walk the tree and collect unique identifiers
        var cursor = try grove.TreeCursor.init(root);
        defer cursor.deinit();

        while (cursor.nextNode()) |node| {
            const kind = node.kind();

            // Collect function and variable names
            if (std.mem.indexOf(u8, kind, "function") != null or
                std.mem.indexOf(u8, kind, "variable") != null or
                std.mem.indexOf(u8, kind, "class") != null)
            {
                const name_node = node.childByFieldName("name") orelse continue;
                const name_text = name_node.text(source) orelse continue;

                // Skip if already seen
                if (seen_identifiers.contains(name_text)) continue;

                try seen_identifiers.put(name_text, {});

                const completion_kind: CompletionItemKind = if (std.mem.indexOf(u8, kind, "function") != null)
                    .function
                else if (std.mem.indexOf(u8, kind, "class") != null)
                    .class
                else
                    .variable;

                try completion_list.append(.{
                    .label = name_text,
                    .kind = completion_kind,
                    .detail = try std.fmt.allocPrint(self.allocator, "{s}", .{kind}),
                });
            }
        }

        return try completion_list.toOwnedSlice();
    }

    /// Format document
    /// Provides basic formatting by traversing the syntax tree and re-indenting based on nesting depth
    pub fn formatDocument(self: *LanguageServer, source: []const u8) ![]const u8 {
        var tree = try self.parseDocument(source);
        defer tree.deinit();

        const root = tree.rootNode() orelse return source;

        // Simple formatting: rebuild source with consistent indentation
        var formatted = std.ArrayList(u8).init(self.allocator);
        errdefer formatted.deinit();

        var current_line: u32 = 0;
        var indent_level: usize = 0;
        const indent_str = "    "; // 4 spaces

        var cursor = try grove.TreeCursor.init(root);
        defer cursor.deinit();

        while (cursor.nextNode()) |node| {
            const start_pos = node.startPosition();

            // Add newline and indentation for new lines
            if (start_pos.row > current_line) {
                try formatted.append('\n');
                current_line = start_pos.row;

                // Add indentation based on depth
                const depth = node.depth();
                indent_level = @min(depth, 20); // Cap at 20 levels
                for (0..indent_level) |_| {
                    try formatted.appendSlice(indent_str);
                }
            }

            // Append node text
            if (node.childCount() == 0) { // Only append leaf nodes
                if (node.text(source)) |text| {
                    try formatted.appendSlice(text);
                    try formatted.append(' '); // Add space between tokens
                }
            }
        }

        return try formatted.toOwnedSlice();
    }

    /// Get diagnostics (syntax errors, warnings)
    pub fn diagnostics(self: *LanguageServer, source: []const u8) ![]Diagnostic {
        var tree = try self.parseDocument(source);
        defer tree.deinit();

        var diagnostic_list = std.ArrayList(Diagnostic){};
        defer diagnostic_list.deinit(self.allocator);

        // Check for syntax errors
        if (tree.rootNode()) |root| {
            try self.collectDiagnostics(root, source, &diagnostic_list);
        }

        return try diagnostic_list.toOwnedSlice(self.allocator);
    }

    fn collectDiagnostics(self: *LanguageServer, node: grove.Node, source: []const u8, diagnostic_list: *std.ArrayList(Diagnostic)) !void {

        // Check if this node represents an error
        if (std.mem.eql(u8, node.kind(), "ERROR")) {
            const diagnostic = Diagnostic{
                .range = Range{
                    .start = Position.fromGrovePoint(node.startPosition()),
                    .end = Position.fromGrovePoint(node.endPosition()),
                },
                .severity = DiagnosticSeverity.@"error",
                .message = "Syntax error",
            };
            try diagnostic_list.append(self.allocator, diagnostic);
        }

        // Recursively check children
        for (0..node.childCount()) |i| {
            if (node.child(@intCast(i))) |child| {
                try self.collectDiagnostics(child, source, diagnostic_list);
            }
        }
    }
};

pub const Diagnostic = struct {
    range: Range,
    severity: DiagnosticSeverity,
    message: []const u8,
    source: ?[]const u8 = null,
};

pub const DiagnosticSeverity = enum(u32) {
    @"error" = 1,
    warning = 2,
    information = 3,
    hint = 4,
};

/// Factory for creating language servers for different languages
pub const LanguageServerFactory = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LanguageServerFactory {
        return .{ .allocator = allocator };
    }

    pub fn createTypeScriptServer(self: LanguageServerFactory) !LanguageServer {
        const language = try grove.Languages.typescript.get();
        return LanguageServer.init(self.allocator, language);
    }

    pub fn createZigServer(self: LanguageServerFactory) !LanguageServer {
        const language = try grove.Languages.zig.get();
        return LanguageServer.init(self.allocator, language);
    }

    pub fn createJSONServer(self: LanguageServerFactory) !LanguageServer {
        const language = try grove.Languages.json.get();
        return LanguageServer.init(self.allocator, language);
    }

    pub fn createRustServer(self: LanguageServerFactory) !LanguageServer {
        const language = try grove.Languages.rust.get();
        return LanguageServer.init(self.allocator, language);
    }

    pub fn createGhostlangServer(self: LanguageServerFactory) !LanguageServer {
        const language = try grove.Languages.ghostlang.get();
        return LanguageServer.init(self.allocator, language);
    }

    /// Create server for any supported language by name
    pub fn createServer(self: LanguageServerFactory, language_name: []const u8) !LanguageServer {
        if (std.mem.eql(u8, language_name, "typescript")) return self.createTypeScriptServer();
        if (std.mem.eql(u8, language_name, "javascript")) return self.createTypeScriptServer();
        if (std.mem.eql(u8, language_name, "tsx")) return self.createTypeScriptServer();
        if (std.mem.eql(u8, language_name, "jsx")) return self.createTypeScriptServer();
        if (std.mem.eql(u8, language_name, "zig")) return self.createZigServer();
        if (std.mem.eql(u8, language_name, "json")) return self.createJSONServer();
    if (std.mem.eql(u8, language_name, "rust")) return self.createRustServer();
        if (std.mem.eql(u8, language_name, "ghostlang")) return self.createGhostlangServer();

        return error.UnsupportedLanguage;
    }
};

/// Utility functions for LSP implementations
pub const Utils = struct {
    /// Convert Grove Point to LSP Position
    pub fn pointToPosition(point: grove.Point) Position {
        return Position.fromGrovePoint(point);
    }

    /// Convert LSP Position to Grove Point
    pub fn positionToPoint(position: Position) grove.Point {
        return position.toGrovePoint();
    }

    /// Convert byte offset to LSP Position in source text
    pub fn byteOffsetToPosition(source: []const u8, offset: u32) Position {
        var line: u32 = 0;
        var character: u32 = 0;

        for (source[0..@min(offset, source.len)]) |byte| {
            if (byte == '\n') {
                line += 1;
                character = 0;
            } else {
                character += 1;
            }
        }

        return .{ .line = line, .character = character };
    }

    /// Convert LSP Position to byte offset in source text
    pub fn positionToByteOffset(source: []const u8, position: Position) u32 {
        var line: u32 = 0;
        var character: u32 = 0;

        for (source, 0..) |byte, i| {
            if (line == position.line and character == position.character) {
                return @intCast(i);
            }

            if (byte == '\n') {
                line += 1;
                character = 0;
            } else {
                character += 1;
            }
        }

        return @intCast(source.len);
    }

    /// Extract text for a range from source
    pub fn extractRangeText(allocator: std.mem.Allocator, source: []const u8, range: Range) ![]const u8 {
        const start_offset = positionToByteOffset(source, range.start);
        const end_offset = positionToByteOffset(source, range.end);

        if (start_offset >= source.len or end_offset > source.len or start_offset > end_offset) {
            return error.InvalidRange;
        }

        const text = source[start_offset..end_offset];
        return try allocator.dupe(u8, text);
    }
};