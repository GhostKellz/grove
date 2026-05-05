//! LSP Helper Functions
//!
//! This module provides commonly-needed utilities for implementing LSP features
//! that would otherwise be duplicated across every LSP server implementation.
//!
//! These helpers reduce boilerplate in language servers by ~50% by providing:
//! - Node position lookups
//! - Symbol extraction
//! - Diagnostic collection
//! - Range conversions

const std = @import("std");
const grove = @import("../root.zig");
const lsp = @import("../lsp.zig");

/// Find the smallest (most specific) node at a given LSP position
///
/// This is the most common operation in LSP servers - converting a cursor position
/// to a tree-sitter node. Used by hover, go-to-definition, completion, etc.
///
/// Returns the deepest (most specific) node that contains the position.
/// Returns null if the position is outside the tree or the tree has no root.
///
/// Example:
/// ```zig
/// const tree = try parser.parseUtf8(null, source);
/// const position = lsp.Position{ .line = 10, .character = 5 };
/// const node = grove.LSP.findNodeAtPosition(tree.rootNode().?, position);
/// ```
pub fn findNodeAtPosition(
    root: grove.Node,
    position: lsp.Position,
) ?grove.Node {
    const grove_point = position.toGrovePoint();

    // Use Grove's built-in descendantForPointRange (most efficient way)
    return root.descendantForPointRange(grove_point, grove_point);
}

/// Convert a Grove Node to an LSP Range
///
/// This is used in nearly every LSP feature to convert tree-sitter nodes
/// to LSP protocol ranges.
///
/// Example:
/// ```zig
/// const range = grove.LSP.nodeToRange(identifier_node);
/// const location = lsp.Location{
///     .uri = document_uri,
///     .range = range,
/// };
/// ```
pub fn nodeToRange(node: grove.Node) lsp.Range {
    const start_point = node.startPosition();
    const end_point = node.endPosition();

    return .{
        .start = .{
            .line = start_point.row,
            .character = start_point.column,
        },
        .end = .{
            .line = end_point.row,
            .character = end_point.column,
        },
    };
}

/// Symbol information for LSP document symbols
pub const SymbolInfo = struct {
    name: []const u8,
    kind: lsp.SymbolKind,
    range: lsp.Range,
    selection_range: lsp.Range,
    children: std.ArrayList(SymbolInfo),

    pub fn deinit(self: *SymbolInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.children.items) |*child| {
            child.deinit(allocator);
        }
        self.children.deinit(allocator);
    }
};

/// Extract document symbols from a syntax tree
///
/// This replaces 200+ lines of manual tree walking in typical LSP implementations.
/// Automatically detects functions, variables, classes, methods, etc. based on
/// common tree-sitter node naming conventions.
///
/// The `node_kind_map` parameter allows language-specific customization.
/// If null, uses default heuristics (looks for "declaration", "function", etc. in node kinds).
///
/// Example:
/// ```zig
/// var tree = try parser.parseUtf8(null, source);
/// defer tree.deinit();
///
/// var symbols = try grove.LSP.extractSymbols(
///     allocator,
///     tree.rootNode().?,
///     source,
///     null, // Use default mapping
/// );
/// defer {
///     for (symbols.items) |*sym| sym.deinit(allocator);
///     symbols.deinit(allocator);
/// }
/// ```
pub fn extractSymbols(
    allocator: std.mem.Allocator,
    root: grove.Node,
    source: []const u8,
    node_kind_map: ?*const NodeKindToSymbolKind,
) !std.ArrayList(SymbolInfo) {
    var symbols: std.ArrayList(SymbolInfo) = .empty;
    errdefer {
        for (symbols.items) |*sym| sym.deinit(allocator);
        symbols.deinit(allocator);
    }

    try collectSymbolsRecursive(allocator, root, source, &symbols, node_kind_map);
    return symbols;
}

/// Mapping function type for custom node kind to symbol kind conversion
pub const NodeKindToSymbolKind = fn (node_kind: []const u8) ?lsp.SymbolKind;

fn collectSymbolsRecursive(
    allocator: std.mem.Allocator,
    node: grove.Node,
    source: []const u8,
    symbols: *std.ArrayList(SymbolInfo),
    node_kind_map: ?*const NodeKindToSymbolKind,
) !void {
    const kind_str = node.kind();

    // Determine if this node represents a symbol
    const symbol_kind = if (node_kind_map) |mapper|
        mapper(kind_str)
    else
        inferSymbolKind(kind_str);

    if (symbol_kind) |kind| {
        // Extract symbol name
        const name = try extractSymbolName(allocator, node, source);

        var children: std.ArrayList(SymbolInfo) = .empty;
        errdefer {
            for (children.items) |*child| child.deinit(allocator);
            children.deinit(allocator);
        }

        // Recursively collect children
        const child_count = node.childCount();
        var i: u32 = 0;
        while (i < child_count) : (i += 1) {
            if (node.child(i)) |child| {
                try collectSymbolsRecursive(allocator, child, source, &children, node_kind_map);
            }
        }

        const symbol = SymbolInfo{
            .name = name,
            .kind = kind,
            .range = nodeToRange(node),
            .selection_range = nodeToRange(node),
            .children = children,
        };

        try symbols.append(allocator, symbol);
    } else {
        // Not a symbol node, but check its children
        const child_count = node.childCount();
        var i: u32 = 0;
        while (i < child_count) : (i += 1) {
            if (node.child(i)) |child| {
                try collectSymbolsRecursive(allocator, child, source, symbols, node_kind_map);
            }
        }
    }
}

fn inferSymbolKind(node_kind: []const u8) ?lsp.SymbolKind {
    // Common patterns across tree-sitter grammars
    if (std.mem.eql(u8, node_kind, "function_declaration") or
        std.mem.eql(u8, node_kind, "function_definition") or
        std.mem.eql(u8, node_kind, "function_item") or
        std.mem.eql(u8, node_kind, "function")) {
        return .function;
    } else if (std.mem.eql(u8, node_kind, "method_declaration") or
               std.mem.eql(u8, node_kind, "method_definition") or
               std.mem.eql(u8, node_kind, "method")) {
        return .method;
    } else if (std.mem.eql(u8, node_kind, "variable_declaration") or
               std.mem.eql(u8, node_kind, "let_declaration") or
               std.mem.eql(u8, node_kind, "var_declaration")) {
        return .variable;
    } else if (std.mem.eql(u8, node_kind, "const_declaration") or
               std.mem.eql(u8, node_kind, "constant_declaration")) {
        return .constant;
    } else if (std.mem.eql(u8, node_kind, "class_declaration") or
               std.mem.eql(u8, node_kind, "class_definition") or
               std.mem.eql(u8, node_kind, "class")) {
        return .class;
    } else if (std.mem.eql(u8, node_kind, "struct_declaration") or
               std.mem.eql(u8, node_kind, "struct_definition") or
               std.mem.eql(u8, node_kind, "struct_item") or
               std.mem.eql(u8, node_kind, "struct")) {
        return .@"struct";
    } else if (std.mem.eql(u8, node_kind, "enum_declaration") or
               std.mem.eql(u8, node_kind, "enum_definition") or
               std.mem.eql(u8, node_kind, "enum_item") or
               std.mem.eql(u8, node_kind, "enum")) {
        return .@"enum";
    } else if (std.mem.eql(u8, node_kind, "interface_declaration") or
               std.mem.eql(u8, node_kind, "interface_definition") or
               std.mem.eql(u8, node_kind, "interface")) {
        return .interface;
    } else if (std.mem.eql(u8, node_kind, "type_declaration") or
               std.mem.eql(u8, node_kind, "type_alias") or
               std.mem.eql(u8, node_kind, "type_definition")) {
        return .type_parameter;
    }

    return null;
}

fn extractSymbolName(
    allocator: std.mem.Allocator,
    node: grove.Node,
    source: []const u8,
) ![]const u8 {
    // Try to find an identifier child (most common pattern)
    const child_count = node.childCount();
    var i: u32 = 0;
    while (i < child_count) : (i += 1) {
        if (node.child(i)) |child| {
            const child_kind = child.kind();
            if (std.mem.eql(u8, child_kind, "identifier") or
                std.mem.eql(u8, child_kind, "type_identifier") or
                std.mem.eql(u8, child_kind, "name")) {
                const start = child.startByte();
                const end = child.endByte();
                if (end > start and end <= source.len) {
                    return try allocator.dupe(u8, source[start..end]);
                }
            }
        }
    }

    // Try using fieldName
    if (node.childByFieldName("name")) |name_node| {
        const start = name_node.startByte();
        const end = name_node.endByte();
        if (end > start and end <= source.len) {
            return try allocator.dupe(u8, source[start..end]);
        }
    }

    // Fallback: use node text (truncated)
    const start = node.startByte();
    const end = node.endByte();
    if (end > start and end <= source.len) {
        const node_text = source[start..end];
        const max_len = 50;
        const truncated = if (node_text.len > max_len)
            node_text[0..max_len]
        else
            node_text;
        return try allocator.dupe(u8, truncated);
    }

    return try allocator.dupe(u8, "<unnamed>");
}

/// Diagnostic information extracted from syntax tree
pub const DiagnosticInfo = struct {
    range: lsp.Range,
    message: []const u8,
    severity: lsp.DiagnosticSeverity,

    pub fn deinit(self: *DiagnosticInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.message);
    }
};

/// Collect syntax errors from a tree
///
/// This replaces manual ERROR node traversal in LSP implementations.
/// Automatically finds all ERROR and MISSING nodes and converts them to LSP diagnostics.
///
/// Example:
/// ```zig
/// var tree = try parser.parseUtf8(null, source);
/// defer tree.deinit();
///
/// var diagnostics = try grove.LSP.collectDiagnostics(
///     allocator,
///     tree.rootNode().?,
///     source,
/// );
/// defer {
///     for (diagnostics.items) |*diag| diag.deinit(allocator);
///     diagnostics.deinit(allocator);
/// }
/// ```
pub fn collectDiagnostics(
    allocator: std.mem.Allocator,
    root: grove.Node,
    source: []const u8,
) !std.ArrayList(DiagnosticInfo) {
    var diagnostics: std.ArrayList(DiagnosticInfo) = .empty;
    errdefer {
        for (diagnostics.items) |*diag| diag.deinit(allocator);
        diagnostics.deinit(allocator);
    }

    try collectErrorsRecursive(allocator, root, source, &diagnostics);
    return diagnostics;
}

fn collectErrorsRecursive(
    allocator: std.mem.Allocator,
    node: grove.Node,
    source: []const u8,
    diagnostics: *std.ArrayList(DiagnosticInfo),
) !void {
    const node_kind = node.kind();

    // Check for ERROR or MISSING nodes
    if (std.mem.eql(u8, node_kind, "ERROR")) {
        const start_byte = node.startByte();
        const end_byte = node.endByte();
        const node_text = if (end_byte > start_byte and end_byte <= source.len)
            source[start_byte..end_byte]
        else
            "<error>";

        const message = try std.fmt.allocPrint(
            allocator,
            "Syntax error near '{s}'",
            .{node_text},
        );

        try diagnostics.append(allocator, .{
            .range = nodeToRange(node),
            .message = message,
            .severity = .@"error",
        });
    } else if (std.mem.eql(u8, node_kind, "MISSING")) {
        const message = try std.fmt.allocPrint(
            allocator,
            "Missing syntax element",
            .{},
        );

        try diagnostics.append(allocator, .{
            .range = nodeToRange(node),
            .message = message,
            .severity = .@"error",
        });
    }

    // Recurse into children
    const child_count = node.childCount();
    var i: u32 = 0;
    while (i < child_count) : (i += 1) {
        if (node.child(i)) |child_node| {
            try collectErrorsRecursive(allocator, child_node, source, diagnostics);
        }
    }
}

/// Find the definition node for a given identifier
///
/// This implements basic single-file go-to-definition by searching for
/// declaration nodes that match the identifier name.
///
/// For cross-file definitions, the LSP server should maintain a workspace index.
///
/// Example:
/// ```zig
/// const cursor_node = grove.LSP.findNodeAtPosition(root, position).?;
/// if (std.mem.eql(u8, cursor_node.kind(), "identifier")) {
///     const identifier_text = source[cursor_node.startByte()..cursor_node.endByte()];
///     const definition = grove.LSP.findDefinition(root, identifier_text, source);
/// }
/// ```
pub fn findDefinition(
    root: grove.Node,
    identifier: []const u8,
    source: []const u8,
) ?grove.Node {
    return findDefinitionRecursive(root, identifier, source);
}

fn findDefinitionRecursive(
    node: grove.Node,
    identifier: []const u8,
    source: []const u8,
) ?grove.Node {
    const kind = node.kind();

    // Check if this is a declaration node
    const is_declaration = std.mem.eql(u8, kind, "function_declaration") or
                          std.mem.eql(u8, kind, "function_definition") or
                          std.mem.eql(u8, kind, "function") or
                          std.mem.eql(u8, kind, "variable_declaration") or
                          std.mem.eql(u8, kind, "let_declaration") or
                          std.mem.eql(u8, kind, "const_declaration") or
                          std.mem.eql(u8, kind, "class_declaration") or
                          std.mem.eql(u8, kind, "struct_declaration") or
                          std.mem.eql(u8, kind, "enum_declaration") or
                          std.mem.eql(u8, kind, "type_declaration");

    if (is_declaration) {
        // Look for identifier child that matches
        const child_count = node.childCount();
        var i: u32 = 0;
        while (i < child_count) : (i += 1) {
            if (node.child(i)) |child| {
                const child_kind = child.kind();
                if (std.mem.eql(u8, child_kind, "identifier") or
                    std.mem.eql(u8, child_kind, "type_identifier")) {
                    const start = child.startByte();
                    const end = child.endByte();
                    if (end > start and end <= source.len) {
                        const child_text = source[start..end];
                        if (std.mem.eql(u8, child_text, identifier)) {
                            return node;
                        }
                    }
                }
            }
        }

        // Also try field name
        if (node.childByFieldName("name")) |name_node| {
            const start = name_node.startByte();
            const end = name_node.endByte();
            if (end > start and end <= source.len) {
                const name_text = source[start..end];
                if (std.mem.eql(u8, name_text, identifier)) {
                    return node;
                }
            }
        }
    }

    // Recursively search children
    const child_count = node.childCount();
    var i: u32 = 0;
    while (i < child_count) : (i += 1) {
        if (node.child(i)) |child| {
            if (findDefinitionRecursive(child, identifier, source)) |found| {
                return found;
            }
        }
    }

    return null;
}

/// Find all references to an identifier in the tree
///
/// This scans the entire tree for identifier nodes matching the given name.
/// Returns a list of nodes (typically you'll convert these to LSP Locations).
///
/// Example:
/// ```zig
/// var references = try grove.LSP.findReferences(allocator, root, "myFunction", source);
/// defer references.deinit(allocator);
///
/// for (references.items) |ref_node| {
///     const range = grove.LSP.nodeToRange(ref_node);
///     // Create LSP Location...
/// }
/// ```
pub fn findReferences(
    allocator: std.mem.Allocator,
    root: grove.Node,
    identifier: []const u8,
    source: []const u8,
) !std.ArrayList(grove.Node) {
    var references: std.ArrayList(grove.Node) = .empty;
    errdefer references.deinit(allocator);

    try findReferencesRecursive(allocator, root, identifier, source, &references);
    return references;
}

fn findReferencesRecursive(
    allocator: std.mem.Allocator,
    node: grove.Node,
    identifier: []const u8,
    source: []const u8,
    references: *std.ArrayList(grove.Node),
) !void {
    const kind = node.kind();

    // Check if this is an identifier that matches
    if (std.mem.eql(u8, kind, "identifier") or
        std.mem.eql(u8, kind, "type_identifier")) {
        const start = node.startByte();
        const end = node.endByte();
        if (end > start and end <= source.len) {
            const node_text = source[start..end];
            if (std.mem.eql(u8, node_text, identifier)) {
                try references.append(allocator, node);
            }
        }
    }

    // Recurse into children
    const child_count = node.childCount();
    var i: u32 = 0;
    while (i < child_count) : (i += 1) {
        if (node.child(i)) |child| {
            try findReferencesRecursive(allocator, child, identifier, source, references);
        }
    }
}

/// Extract folding ranges from a syntax tree
///
/// This finds blocks that can be folded in an editor (functions, classes, blocks, etc.)
///
/// Example:
/// ```zig
/// var folding = try grove.LSP.extractFoldingRanges(allocator, root, source);
/// defer folding.deinit();
/// ```
pub fn extractFoldingRanges(
    allocator: std.mem.Allocator,
    root: grove.Node,
    source: []const u8,
) !std.ArrayList(lsp.FoldingRange) {
    _ = source;
    var ranges: std.ArrayList(lsp.FoldingRange) = .empty;
    errdefer ranges.deinit(allocator);

    try collectFoldingRangesRecursive(allocator, root, &ranges);
    return ranges;
}

fn collectFoldingRangesRecursive(
    allocator: std.mem.Allocator,
    node: grove.Node,
    ranges: *std.ArrayList(lsp.FoldingRange),
) !void {
    const kind = node.kind();

    // Determine if this node should be foldable
    const is_foldable = isFoldableNode(kind);

    if (is_foldable) {
        const start = node.startPosition();
        const end = node.endPosition();

        // Only create folding range if it spans multiple lines
        if (end.row > start.row) {
            const folding_kind = getFoldingKind(kind);
            try ranges.append(allocator, .{
                .start_line = start.row,
                .end_line = end.row,
                .kind = folding_kind,
            });
        }
    }

    // Recurse into children
    const child_count = node.childCount();
    var i: u32 = 0;
    while (i < child_count) : (i += 1) {
        if (node.child(i)) |child| {
            try collectFoldingRangesRecursive(allocator, child, ranges);
        }
    }
}

fn isFoldableNode(kind: []const u8) bool {
    // Common foldable node types across languages
    return std.mem.indexOf(u8, kind, "function") != null or
           std.mem.indexOf(u8, kind, "class") != null or
           std.mem.indexOf(u8, kind, "struct") != null or
           std.mem.indexOf(u8, kind, "enum") != null or
           std.mem.indexOf(u8, kind, "interface") != null or
           std.mem.indexOf(u8, kind, "block") != null or
           std.mem.indexOf(u8, kind, "object") != null or
           std.mem.indexOf(u8, kind, "array") != null or
           std.mem.eql(u8, kind, "comment") or
           std.mem.indexOf(u8, kind, "statement_block") != null;
}

fn getFoldingKind(kind: []const u8) ?lsp.FoldingRangeKind {
    if (std.mem.eql(u8, kind, "comment") or std.mem.indexOf(u8, kind, "comment") != null) {
        return .comment;
    } else if (std.mem.indexOf(u8, kind, "import") != null or std.mem.indexOf(u8, kind, "use") != null) {
        return .imports;
    }
    return .region;
}

/// Semantic token type for LSP
pub const SemanticTokenType = enum(u32) {
    namespace = 0,
    type = 1,
    class = 2,
    @"enum" = 3,
    interface = 4,
    @"struct" = 5,
    type_parameter = 6,
    parameter = 7,
    variable = 8,
    property = 9,
    enum_member = 10,
    event = 11,
    function = 12,
    method = 13,
    macro = 14,
    keyword = 15,
    modifier = 16,
    comment = 17,
    string = 18,
    number = 19,
    regexp = 20,
    operator = 21,
};

/// Semantic token modifier flags
pub const SemanticTokenModifier = enum(u32) {
    declaration = 0,
    definition = 1,
    readonly = 2,
    @"static" = 3,
    deprecated = 4,
    @"abstract" = 5,
    @"async" = 6,
    modification = 7,
    documentation = 8,
    default_library = 9,
};

/// A single semantic token
pub const SemanticToken = struct {
    line: u32,
    start_char: u32,
    length: u32,
    token_type: SemanticTokenType,
    modifiers: u32, // Bitmask of SemanticTokenModifier
};

/// Extract semantic tokens from a syntax tree
///
/// This provides fine-grained token information for semantic highlighting.
/// Uses tree-sitter node types to infer semantic token types.
///
/// Example:
/// ```zig
/// var tokens = try grove.LSP.extractSemanticTokens(allocator, root, source, null);
/// defer tokens.deinit(allocator);
/// ```
pub fn extractSemanticTokens(
    allocator: std.mem.Allocator,
    root: grove.Node,
    source: []const u8,
    type_mapper: ?*const NodeKindToTokenType,
) !std.ArrayList(SemanticToken) {
    var tokens: std.ArrayList(SemanticToken) = .empty;
    errdefer tokens.deinit(allocator);

    try collectSemanticTokensRecursive(allocator, root, source, &tokens, type_mapper);

    // Sort tokens by position (required by LSP spec)
    std.mem.sort(SemanticToken, tokens.items, {}, compareSemanticTokens);

    return tokens;
}

/// Mapping function type for custom node kind to semantic token type conversion
pub const NodeKindToTokenType = fn (node_kind: []const u8) ?SemanticTokenType;

fn collectSemanticTokensRecursive(
    allocator: std.mem.Allocator,
    node: grove.Node,
    source: []const u8,
    tokens: *std.ArrayList(SemanticToken),
    type_mapper: ?*const NodeKindToTokenType,
) !void {
    const kind = node.kind();

    // Only process named nodes (skip punctuation, etc.)
    if (!node.isNamed()) {
        const child_count = node.childCount();
        var i: u32 = 0;
        while (i < child_count) : (i += 1) {
            if (node.child(i)) |child| {
                try collectSemanticTokensRecursive(allocator, child, source, tokens, type_mapper);
            }
        }
        return;
    }

    // Determine token type
    const token_type = if (type_mapper) |mapper|
        mapper(kind)
    else
        inferTokenType(kind);

    if (token_type) |tt| {
        const start_pos = node.startPosition();
        const node_text = node.text(source) orelse return;

        try tokens.append(allocator, .{
            .line = start_pos.row,
            .start_char = start_pos.column,
            .length = @intCast(node_text.len),
            .token_type = tt,
            .modifiers = detectModifiers(node, kind),
        });
    }

    // Recurse into children
    const child_count = node.childCount();
    var i: u32 = 0;
    while (i < child_count) : (i += 1) {
        if (node.child(i)) |child| {
            try collectSemanticTokensRecursive(allocator, child, source, tokens, type_mapper);
        }
    }
}

/// Detect semantic token modifiers based on node kind and context
fn detectModifiers(node: grove.Node, kind: []const u8) u32 {
    var modifiers: u32 = 0;

    // Check for declaration/definition
    if (std.mem.indexOf(u8, kind, "declaration") != null) {
        modifiers |= @as(u32, 1) << @intFromEnum(SemanticTokenModifier.declaration);
    }
    if (std.mem.indexOf(u8, kind, "definition") != null) {
        modifiers |= @as(u32, 1) << @intFromEnum(SemanticTokenModifier.definition);
    }

    // Check for static
    if (std.mem.indexOf(u8, kind, "static") != null) {
        modifiers |= @as(u32, 1) << @intFromEnum(SemanticTokenModifier.@"static");
    }

    // Check for async
    if (std.mem.indexOf(u8, kind, "async") != null) {
        modifiers |= @as(u32, 1) << @intFromEnum(SemanticTokenModifier.@"async");
    }

    // Check for abstract
    if (std.mem.indexOf(u8, kind, "abstract") != null) {
        modifiers |= @as(u32, 1) << @intFromEnum(SemanticTokenModifier.@"abstract");
    }

    // Check for readonly/const by looking at siblings or parent
    if (std.mem.indexOf(u8, kind, "const") != null or
        std.mem.indexOf(u8, kind, "readonly") != null or
        std.mem.indexOf(u8, kind, "final") != null)
    {
        modifiers |= @as(u32, 1) << @intFromEnum(SemanticTokenModifier.readonly);
    }

    // Check parent/siblings for modifiers
    if (node.parent()) |parent| {
        const parent_kind = parent.kind();

        // If parent is a const/readonly context
        if (std.mem.indexOf(u8, parent_kind, "const") != null or
            std.mem.indexOf(u8, parent_kind, "readonly") != null)
        {
            modifiers |= @as(u32, 1) << @intFromEnum(SemanticTokenModifier.readonly);
        }

        // Check if parent indicates deprecated
        if (std.mem.indexOf(u8, parent_kind, "deprecated") != null) {
            modifiers |= @as(u32, 1) << @intFromEnum(SemanticTokenModifier.deprecated);
        }
    }

    return modifiers;
}

fn inferTokenType(kind: []const u8) ?SemanticTokenType {
    if (std.mem.eql(u8, kind, "function_declaration") or
        std.mem.eql(u8, kind, "function_definition") or
        std.mem.eql(u8, kind, "function")) {
        return .function;
    } else if (std.mem.eql(u8, kind, "method_declaration") or
               std.mem.eql(u8, kind, "method_definition") or
               std.mem.eql(u8, kind, "method")) {
        return .method;
    } else if (std.mem.eql(u8, kind, "class_declaration") or
               std.mem.eql(u8, kind, "class")) {
        return .class;
    } else if (std.mem.eql(u8, kind, "struct_declaration") or
               std.mem.eql(u8, kind, "struct")) {
        return .@"struct";
    } else if (std.mem.eql(u8, kind, "enum_declaration") or
               std.mem.eql(u8, kind, "enum")) {
        return .@"enum";
    } else if (std.mem.eql(u8, kind, "interface_declaration") or
               std.mem.eql(u8, kind, "interface")) {
        return .interface;
    } else if (std.mem.eql(u8, kind, "type_identifier") or
               std.mem.eql(u8, kind, "type")) {
        return .type;
    } else if (std.mem.eql(u8, kind, "identifier")) {
        return .variable;
    } else if (std.mem.indexOf(u8, kind, "comment") != null) {
        return .comment;
    } else if (std.mem.indexOf(u8, kind, "string") != null) {
        return .string;
    } else if (std.mem.indexOf(u8, kind, "number") != null) {
        return .number;
    } else if (std.mem.indexOf(u8, kind, "keyword") != null) {
        return .keyword;
    } else if (std.mem.indexOf(u8, kind, "operator") != null) {
        return .operator;
    }

    return null;
}

fn compareSemanticTokens(_: void, a: SemanticToken, b: SemanticToken) bool {
    if (a.line != b.line) return a.line < b.line;
    return a.start_char < b.start_char;
}

// Tests
test "findNodeAtPosition" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    const language = try grove.Languages.json.get();
    try parser.setLanguage(language);

    const source = "{\"hello\": true}";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode().?;

    // Find node at position of "hello"
    const position = lsp.Position{ .line = 0, .character = 2 };
    const node = findNodeAtPosition(root, position);
    try testing.expect(node != null);
}

test "nodeToRange" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    const language = try grove.Languages.json.get();
    try parser.setLanguage(language);

    const source = "{\"hello\": true}";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode().?;
    const range = nodeToRange(root);

    try testing.expectEqual(@as(u32, 0), range.start.line);
    try testing.expectEqual(@as(u32, 0), range.start.character);
}

test "collectDiagnostics" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    const language = try grove.Languages.json.get();
    try parser.setLanguage(language);

    // Invalid JSON with syntax error
    const source = "{\"hello\": }";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode().?;
    var diagnostics = try collectDiagnostics(allocator, root, source);
    defer {
        for (diagnostics.items) |*diag| diag.deinit(allocator);
        diagnostics.deinit(allocator);
    }

    // Should have at least one error
    try testing.expect(diagnostics.items.len > 0);
}
