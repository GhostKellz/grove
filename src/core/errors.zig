const std = @import("std");
const Tree = @import("tree.zig").Tree;
const Node = @import("node.zig").Node;
const Point = @import("node.zig").Point;

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

    pub const ErrorKind = enum {
        error_node,
        missing_node,
    };
};

/// Collect all syntax errors (ERROR and MISSING nodes) from a tree
pub fn getSyntaxErrors(tree: Tree, allocator: std.mem.Allocator) ![]SyntaxError {
    const root = tree.rootNode() orelse return &[_]SyntaxError{};

    var errors = std.ArrayList(SyntaxError).init(allocator);
    errdefer errors.deinit();

    try collectErrorsRecursive(root, &errors);

    return errors.toOwnedSlice();
}

fn collectErrorsRecursive(node: Node, errors: *std.ArrayList(SyntaxError)) !void {
    const kind_str = node.kind();

    // Check if this is an ERROR or MISSING node
    const error_kind: ?SyntaxError.ErrorKind = if (std.mem.eql(u8, kind_str, "ERROR"))
        .error_node
    else if (node.isMissing())
        .missing_node
    else
        null;

    if (error_kind) |kind| {
        try errors.append(.{
            .node = node,
            .kind = kind,
            .start_point = node.startPoint(),
            .end_point = node.endPoint(),
            .start_byte = node.startByte(),
            .end_byte = node.endByte(),
            .parent = node.parent(),
        });
    }

    // Recursively check children
    var cursor = node.walk();
    defer cursor.deinit();

    if (cursor.gotoFirstChild()) {
        while (true) {
            try collectErrorsRecursive(cursor.currentNode(), errors);
            if (!cursor.gotoNextSibling()) break;
        }
    }
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
    defer allocator.free(errors);

    // Should find at least one error
    try testing.expect(errors.len > 0);
    try testing.expect(errors[0].kind == .error_node or errors[0].kind == .missing_node);
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
    defer allocator.free(errors);

    try testing.expectEqual(@as(usize, 0), errors.len);
}
