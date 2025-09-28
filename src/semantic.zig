//! Semantic analysis module for Grove
//!
//! This module provides advanced semantic analysis capabilities for Tree-sitter
//! syntax trees, including cursor-based navigation, scope analysis, and
//! language-specific semantic understanding.

const std = @import("std");

// Re-export core semantic analysis types
pub const SemanticCursor = @import("semantic/cursor.zig").SemanticCursor;
pub const SemanticAnalyzer = @import("semantic/cursor.zig").SemanticAnalyzer;
pub const QueryMatch = @import("semantic/cursor.zig").QueryMatch;
pub const ScopeInfo = @import("semantic/cursor.zig").ScopeInfo;

// Re-export traversal utilities
pub const TreeTraversal = @import("semantic/traversal.zig").TreeTraversal;
pub const TraversalStrategy = @import("semantic/traversal.zig").TraversalStrategy;
pub const VisitorFn = @import("semantic/traversal.zig").VisitorFn;
pub const PredicateFn = @import("semantic/traversal.zig").PredicateFn;
pub const TreeStats = @import("semantic/traversal.zig").TreeStats;
pub const Predicates = @import("semantic/traversal.zig").Predicates;

// Re-export language-specific analyzers
pub const TypeScriptAnalyzer = @import("semantic/analyzers.zig").TypeScriptAnalyzer;
pub const ZigAnalyzer = @import("semantic/analyzers.zig").ZigAnalyzer;
pub const FunctionInfo = @import("semantic/analyzers.zig").FunctionInfo;
pub const FunctionKind = @import("semantic/analyzers.zig").FunctionKind;
pub const ClassInfo = @import("semantic/analyzers.zig").ClassInfo;
pub const ImportInfo = @import("semantic/analyzers.zig").ImportInfo;
pub const ImportKind = @import("semantic/analyzers.zig").ImportKind;
pub const VariableInfo = @import("semantic/analyzers.zig").VariableInfo;
pub const VariableKind = @import("semantic/analyzers.zig").VariableKind;

// Import core types for convenience
const Node = @import("core/node.zig").Node;
const Point = @import("core/node.zig").Point;
const Language = @import("language.zig").Language;
const Languages = @import("languages.zig").Bundled;

/// Create a semantic cursor for the given tree root
pub fn createCursor(allocator: std.mem.Allocator, root: Node) SemanticCursor {
    return SemanticCursor.init(allocator, root);
}

/// Create a semantic analyzer for a specific language
pub fn createAnalyzer(allocator: std.mem.Allocator, language: Language) SemanticAnalyzer {
    return SemanticAnalyzer.init(allocator, language);
}

/// Create a tree traversal utility
pub fn createTraversal(allocator: std.mem.Allocator) TreeTraversal {
    return TreeTraversal.init(allocator);
}

/// Create a TypeScript-specific analyzer
pub fn createTypeScriptAnalyzer(allocator: std.mem.Allocator) !TypeScriptAnalyzer {
    return TypeScriptAnalyzer.init(allocator);
}

/// Create a Zig-specific analyzer
pub fn createZigAnalyzer(allocator: std.mem.Allocator) !ZigAnalyzer {
    return ZigAnalyzer.init(allocator);
}

/// Quick semantic analysis for a position in source code
pub fn analyzePosition(
    allocator: std.mem.Allocator,
    root: Node,
    line: u32,
    column: u32,
    language: Languages
) !PositionAnalysis {
    var cursor = createCursor(allocator, root);
    defer cursor.deinit();

    if (!cursor.gotoPosition(line, column)) {
        return PositionAnalysis{
            .node = root,
            .path = &.{},
            .scope = .{ .function_scope = null, .class_scope = null, .is_global = true },
            .context = .unknown,
        };
    }

    const lang = try language.get();
    var analyzer = createAnalyzer(allocator, lang);
    defer analyzer.deinit();

    const scope = try analyzer.analyzeScope(&cursor);
    const context = analyzeContext(&cursor);

    return PositionAnalysis{
        .node = cursor.getCurrentNode(),
        .path = cursor.getPath(),
        .scope = scope,
        .context = context,
    };
}

/// Analyze the semantic context of the current cursor position
fn analyzeContext(cursor: *SemanticCursor) SemanticContext {
    const node_type = cursor.getCurrentNode().kind();

    if (std.mem.eql(u8, node_type, "string") or std.mem.eql(u8, node_type, "template_string")) {
        return .string_literal;
    }

    if (std.mem.eql(u8, node_type, "comment")) {
        return .comment;
    }

    if (std.mem.eql(u8, node_type, "identifier")) {
        if (cursor.isInContext("call_expression")) {
            return .function_call;
        }
        return .identifier;
    }

    if (cursor.isInContext("function_declaration") or
       cursor.isInContext("method_definition") or
       cursor.isInContext("arrow_function")) {
        return .function_body;
    }

    if (cursor.isInContext("class_declaration") or cursor.isInContext("class_definition")) {
        return .class_body;
    }

    return .unknown;
}

/// Result of semantic analysis for a specific position
pub const PositionAnalysis = struct {
    node: Node,
    path: []const Node,
    scope: ScopeInfo,
    context: SemanticContext,
};

/// Semantic context types
pub const SemanticContext = enum {
    unknown,
    string_literal,
    comment,
    identifier,
    function_call,
    function_body,
    class_body,
};