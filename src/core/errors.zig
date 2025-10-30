const std = @import("std");
const Tree = @import("tree.zig").Tree;
const Node = @import("node.zig").Node;
const Point = @import("node.zig").Point;

/// Severity level for syntax errors
pub const ErrorSeverity = enum {
    @"error", // Critical syntax error
    warning, // Recoverable issue
    hint, // Stylistic suggestion
};

/// Syntax error information for error recovery
pub const SyntaxError = struct {
    /// The error or missing node
    node: Node,
    /// Type of error
    kind: ErrorKind,
    /// Start position
    start_point: Point,
    /// End position
    end_point: Point,
    /// Start byte offset
    start_byte: u32,
    /// End byte offset
    end_byte: u32,
    /// Parent node for context
    parent: ?Node,
    /// Human-readable error message
    message: []const u8,
    /// Severity level
    severity: ErrorSeverity,
    /// Expected token types (if available)
    expected: ?[]const []const u8,
    /// Context: the kind of the parent node
    context_kind: ?[]const u8,

    pub const ErrorKind = enum {
        error_node,
        missing_node,
        unexpected_token,
    };

    pub fn deinit(self: *SyntaxError, allocator: std.mem.Allocator) void {
        allocator.free(self.message);
        if (self.expected) |exp| {
            for (exp) |token| {
                allocator.free(token);
            }
            allocator.free(exp);
        }
        if (self.context_kind) |ctx| {
            allocator.free(ctx);
        }
    }
};

/// Collect all syntax errors (ERROR and MISSING nodes) from a tree
/// Returns syntax errors with enhanced context and suggestions
pub fn getSyntaxErrors(tree: Tree, allocator: std.mem.Allocator) ![]SyntaxError {
    const root = tree.rootNode() orelse return &[_]SyntaxError{};

    var errors: std.ArrayList(SyntaxError) = .{};
    errdefer {
        for (errors.items) |*err| err.deinit(allocator);
        errors.deinit(allocator);
    }

    try collectErrorsRecursive(allocator, root, &errors);

    return errors.toOwnedSlice(allocator);
}

fn collectErrorsRecursive(allocator: std.mem.Allocator, node: Node, errors: *std.ArrayList(SyntaxError)) !void {
    const kind_str = node.kind();

    // Check if this is an ERROR or MISSING node
    const error_kind: ?SyntaxError.ErrorKind = if (std.mem.eql(u8, kind_str, "ERROR"))
        .error_node
    else if (node.isMissing())
        .missing_node
    else
        null;

    if (error_kind) |kind| {
        const parent_node = node.parent();

        // Generate helpful error message based on context
        const message = try generateErrorMessage(allocator, node, kind, parent_node);
        errdefer allocator.free(message);

        // Get parent context
        const context_kind = if (parent_node) |p|
            try allocator.dupe(u8, p.kind())
        else
            null;
        errdefer if (context_kind) |ctx| allocator.free(ctx);

        // Determine severity
        const severity: ErrorSeverity = switch (kind) {
            .error_node => .@"error",
            .missing_node => if (isCriticalMissing(node, parent_node)) .@"error" else .warning,
            .unexpected_token => .@"error",
        };

        // Try to infer expected tokens
        const expected = try inferExpectedTokens(allocator, node, parent_node);
        errdefer if (expected) |exp| {
            for (exp) |token| allocator.free(token);
            allocator.free(exp);
        };

        try errors.append(allocator, .{
            .node = node,
            .kind = kind,
            .start_point = node.startPosition(),
            .end_point = node.endPosition(),
            .start_byte = node.startByte(),
            .end_byte = node.endByte(),
            .parent = parent_node,
            .message = message,
            .severity = severity,
            .expected = expected,
            .context_kind = context_kind,
        });
    }

    // Recursively check children
    var cursor = try node.treeWalk();
    defer cursor.deinit();

    if (cursor.gotoFirstChild()) {
        while (true) {
            try collectErrorsRecursive(allocator, cursor.currentNode(), errors);
            if (!cursor.gotoNextSibling()) break;
        }
    }
}

fn generateErrorMessage(
    allocator: std.mem.Allocator,
    node: Node,
    kind: SyntaxError.ErrorKind,
    parent: ?Node,
) ![]const u8 {
    return switch (kind) {
        .error_node => if (parent) |p|
            try std.fmt.allocPrint(
                allocator,
                "Syntax error in {s}",
                .{p.kind()},
            )
        else
            try allocator.dupe(u8, "Syntax error"),
        .missing_node => blk: {
            const expected_kind = node.kind();
            if (parent) |p| {
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "Missing {s} in {s}",
                    .{ expected_kind, p.kind() },
                );
            } else {
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "Missing {s}",
                    .{expected_kind},
                );
            }
        },
        .unexpected_token => try allocator.dupe(u8, "Unexpected token"),
    };
}

fn isCriticalMissing(node: Node, parent: ?Node) bool {
    const kind = node.kind();

    // Missing semicolons, commas are warnings
    // Missing braces, parentheses are errors
    if (std.mem.indexOf(u8, kind, "semicolon") != null or
        std.mem.indexOf(u8, kind, "comma") != null)
    {
        return false;
    }

    if (std.mem.indexOf(u8, kind, "brace") != null or
        std.mem.indexOf(u8, kind, "bracket") != null or
        std.mem.indexOf(u8, kind, "paren") != null)
    {
        return true;
    }

    // If parent is a declaration/definition, it's critical
    if (parent) |p| {
        const parent_kind = p.kind();
        if (std.mem.indexOf(u8, parent_kind, "declaration") != null or
            std.mem.indexOf(u8, parent_kind, "definition") != null)
        {
            return true;
        }
    }

    return true; // Default to critical
}

fn inferExpectedTokens(
    allocator: std.mem.Allocator,
    node: Node,
    parent: ?Node,
) !?[]const []const u8 {
    _ = node;

    if (parent) |p| {
        const parent_kind = p.kind();

        // Common patterns for expected tokens
        if (std.mem.indexOf(u8, parent_kind, "function") != null) {
            var expected: std.ArrayList([]const u8) = .{};
            try expected.append(allocator, try allocator.dupe(u8, "identifier"));
            try expected.append(allocator, try allocator.dupe(u8, "parameter"));
            try expected.append(allocator, try allocator.dupe(u8, "body"));
            return try expected.toOwnedSlice(allocator);
        }

        if (std.mem.indexOf(u8, parent_kind, "call") != null) {
            var expected: std.ArrayList([]const u8) = .{};
            try expected.append(allocator, try allocator.dupe(u8, "argument"));
            try expected.append(allocator, try allocator.dupe(u8, ")"));
            return try expected.toOwnedSlice(allocator);
        }

        if (std.mem.indexOf(u8, parent_kind, "array") != null or
            std.mem.indexOf(u8, parent_kind, "list") != null)
        {
            var expected: std.ArrayList([]const u8) = .{};
            try expected.append(allocator, try allocator.dupe(u8, "element"));
            try expected.append(allocator, try allocator.dupe(u8, ","));
            try expected.append(allocator, try allocator.dupe(u8, "]"));
            return try expected.toOwnedSlice(allocator);
        }
    }

    return null;
}

const testing = std.testing;
const Parser = @import("parser.zig").Parser;
const Languages = @import("../languages.zig").Bundled;

test "getSyntaxErrors finds ERROR nodes" {
    const allocator = testing.allocator;

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const lang = try Languages.json.get();
    try parser.setLanguage(lang);

    // Invalid JSON with syntax error
    var tree = try parser.parseUtf8(null, "{\"key\": }");
    defer tree.deinit();

    const errors = try getSyntaxErrors(tree, allocator);
    defer {
        for (errors) |*err| {
            var e = err.*;
            e.deinit(allocator);
        }
        allocator.free(errors);
    }

    // Should find at least one error
    try testing.expect(errors.len > 0);
    try testing.expect(errors[0].kind == .error_node or errors[0].kind == .missing_node);
    try testing.expect(errors[0].message.len > 0); // Should have a message
}

test "getSyntaxErrors returns empty for valid code" {
    const allocator = testing.allocator;

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const lang = try Languages.json.get();
    try parser.setLanguage(lang);

    var tree = try parser.parseUtf8(null, "{\"key\": true}");
    defer tree.deinit();

    const errors = try getSyntaxErrors(tree, allocator);
    defer {
        for (errors) |*err| {
            var e = err.*;
            e.deinit(allocator);
        }
        allocator.free(errors);
    }

    try testing.expectEqual(@as(usize, 0), errors.len);
}
