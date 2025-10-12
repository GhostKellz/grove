// Completion context detection for shell REPL
// Determines what kind of completion to offer based on cursor position

const std = @import("std");
const Node = @import("../core/node.zig").Node;
const Point = @import("../core/node.zig").Point;

/// Type of completion expected at cursor position
pub const CompletionContext = enum {
    /// At start of command or after pipe/semicolon
    command,
    /// After command name, expecting flag
    flag,
    /// After command/flag, expecting file path
    file_path,
    /// Inside variable expansion ($VAR)
    variable,
    /// Inside Ghostlang/embedded script block
    embedded_script,
    /// After equals sign in assignment
    assignment_value,
    /// Unknown/ambiguous context
    unknown,
};

/// Detailed completion context with position info
pub const CompletionInfo = struct {
    /// Type of completion expected
    context: CompletionContext,
    /// Byte offset where completion starts
    start_byte: u32,
    /// Byte offset of cursor position
    cursor_byte: u32,
    /// Partial text already typed (if any)
    partial: ?[]const u8 = null,
    /// Parent command (if completing flag/argument)
    command: ?[]const u8 = null,
};

/// Get completion context at cursor position
///
/// Analyzes the syntax tree to determine what kind of completion
/// should be offered at the given cursor position.
pub fn getCompletionContext(
    allocator: std.mem.Allocator,
    root: Node,
    source: []const u8,
    cursor_byte: u32,
) !CompletionInfo {
    _ = allocator; // May be needed for future enhancements

    // Find the node at cursor position
    const node_at_cursor = findNodeAtPosition(root, cursor_byte);

    if (node_at_cursor == null) {
        // Cursor in whitespace or at end of input
        return inferContextFromPrevious(root, source, cursor_byte);
    }

    const node = node_at_cursor.?;
    const node_kind = node.kind();

    // Determine context based on node type
    if (std.mem.eql(u8, node_kind, "command_name") or
        std.mem.eql(u8, node_kind, "builtin_command") or
        std.mem.eql(u8, node_kind, "word"))
    {
        // Inside or at end of command name
        return .{
            .context = .command,
            .start_byte = node.startByte(),
            .cursor_byte = cursor_byte,
            .partial = if (node.startByte() < cursor_byte and cursor_byte <= node.endByte())
                source[node.startByte()..cursor_byte]
            else
                null,
        };
    }

    if (std.mem.eql(u8, node_kind, "flag")) {
        return .{
            .context = .flag,
            .start_byte = node.startByte(),
            .cursor_byte = cursor_byte,
            .partial = if (node.startByte() < cursor_byte and cursor_byte <= node.endByte())
                source[node.startByte()..cursor_byte]
            else
                null,
        };
    }

    if (std.mem.eql(u8, node_kind, "variable_name") or
        std.mem.eql(u8, node_kind, "expansion"))
    {
        return .{
            .context = .variable,
            .start_byte = node.startByte(),
            .cursor_byte = cursor_byte,
            .partial = if (node.startByte() < cursor_byte and cursor_byte <= node.endByte())
                source[node.startByte()..cursor_byte]
            else
                null,
        };
    }

    if (std.mem.eql(u8, node_kind, "variable_assignment")) {
        return .{
            .context = .assignment_value,
            .start_byte = node.startByte(),
            .cursor_byte = cursor_byte,
        };
    }

    // Check if inside command structure - might be file path argument
    if (isInsideCommand(node)) {
        const cmd = findParentCommand(node);
        return .{
            .context = .file_path,
            .start_byte = node.startByte(),
            .cursor_byte = cursor_byte,
            .command = if (cmd) |c| getCommandName(c, source) else null,
        };
    }

    return .{
        .context = .unknown,
        .start_byte = cursor_byte,
        .cursor_byte = cursor_byte,
    };
}

/// Find node at specific byte position
fn findNodeAtPosition(node: Node, position: u32) ?Node {
    const start = node.startByte();
    const end = node.endByte();

    // Position not in this node's range
    if (position < start or position > end) {
        return null;
    }

    // Check children first (more specific)
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            if (findNodeAtPosition(child, position)) |found| {
                return found;
            }
        }
    }

    // No child contains position, this node is the most specific
    return node;
}

/// Infer context from previous tokens when cursor is in whitespace
fn inferContextFromPrevious(root: Node, source: []const u8, cursor_byte: u32) CompletionInfo {
    // Find the last token before cursor
    const prev_node = findLastNodeBefore(root, cursor_byte);

    if (prev_node) |node| {
        const node_kind = node.kind();

        // After command name -> expect flag or file path
        if (std.mem.eql(u8, node_kind, "command_name") or
            std.mem.eql(u8, node_kind, "builtin_command"))
        {
            return .{
                .context = .flag,
                .start_byte = cursor_byte,
                .cursor_byte = cursor_byte,
                .command = getCommandName(node, source),
            };
        }

        // After flag -> expect file path
        if (std.mem.eql(u8, node_kind, "flag")) {
            const cmd = findParentCommand(node);
            return .{
                .context = .file_path,
                .start_byte = cursor_byte,
                .cursor_byte = cursor_byte,
                .command = if (cmd) |c| getCommandName(c, source) else null,
            };
        }

        // After pipe -> expect command
        if (std.mem.eql(u8, node_kind, "pipeline") or
            (node.endByte() < cursor_byte and
            source[node.endByte() - 1] == '|'))
        {
            return .{
                .context = .command,
                .start_byte = cursor_byte,
                .cursor_byte = cursor_byte,
            };
        }
    }

    // Default: start of line or unknown context -> command
    return .{
        .context = .command,
        .start_byte = cursor_byte,
        .cursor_byte = cursor_byte,
    };
}

/// Find last node that ends before given position
fn findLastNodeBefore(node: Node, position: u32) ?Node {
    if (node.endByte() > position) {
        // This node extends past position, check children
        var last_child: ?Node = null;
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                if (child.endByte() <= position) {
                    last_child = child;
                } else {
                    // Child extends past position, recurse
                    if (findLastNodeBefore(child, position)) |found| {
                        return found;
                    }
                }
            }
        }
        return last_child;
    }

    return node;
}

/// Check if node is inside a command structure
fn isInsideCommand(node: Node) bool {
    var current: ?Node = node;
    while (current) |n| {
        const kind = n.kind();
        if (std.mem.eql(u8, kind, "command") or
            std.mem.eql(u8, kind, "pipeline"))
        {
            return true;
        }
        current = n.parent();
    }
    return false;
}

/// Find parent command node
fn findParentCommand(node: Node) ?Node {
    var current: ?Node = node.parent();
    while (current) |n| {
        const kind = n.kind();
        if (std.mem.eql(u8, kind, "command")) {
            return n;
        }
        current = n.parent();
    }
    return null;
}

/// Extract command name from command node
fn getCommandName(node: Node, source: []const u8) ?[]const u8 {
    // If this is the command name node itself
    const kind = node.kind();
    if (std.mem.eql(u8, kind, "command_name") or
        std.mem.eql(u8, kind, "builtin_command"))
    {
        const start = node.startByte();
        const end = node.endByte();
        if (end > start and end <= source.len) {
            return source[start..end];
        }
    }

    // If this is a command node, find the name child
    if (std.mem.eql(u8, kind, "command")) {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_kind = child.kind();
                if (std.mem.eql(u8, child_kind, "command_name") or
                    std.mem.eql(u8, child_kind, "builtin_command"))
                {
                    return getCommandName(child, source);
                }
            }
        }
    }

    return null;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const Languages = @import("../languages.zig").Bundled;
const Parser = @import("../core/parser.zig").Parser;

test "getCompletionContext: at start expects command" {
    const lang = try Languages.gshell.get();
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    try parser.setLanguage(lang);

    const source = "";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.NoRoot;
    const info = try getCompletionContext(testing.allocator, root, source, 0);

    try testing.expectEqual(CompletionContext.command, info.context);
}

test "getCompletionContext: after command expects flag" {
    const lang = try Languages.gshell.get();
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    try parser.setLanguage(lang);

    const source = "ls ";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.NoRoot;
    const info = try getCompletionContext(testing.allocator, root, source, 3);

    try testing.expectEqual(CompletionContext.flag, info.context);
}

test "getCompletionContext: partial command completion" {
    const lang = try Languages.gshell.get();
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    try parser.setLanguage(lang);

    const source = "gi";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.NoRoot;
    const info = try getCompletionContext(testing.allocator, root, source, 2);

    try testing.expectEqual(CompletionContext.command, info.context);
    if (info.partial) |partial| {
        try testing.expectEqualStrings("gi", partial);
    }
}

test "getCompletionContext: after pipe expects command" {
    const lang = try Languages.gshell.get();
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    try parser.setLanguage(lang);

    const source = "ls | ";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.NoRoot;
    const info = try getCompletionContext(testing.allocator, root, source, 5);

    try testing.expectEqual(CompletionContext.command, info.context);
}

test "getCompletionContext: variable expansion" {
    const lang = try Languages.gshell.get();
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    try parser.setLanguage(lang);

    const source = "echo $HO";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.NoRoot;
    const info = try getCompletionContext(testing.allocator, root, source, 8);

    try testing.expectEqual(CompletionContext.variable, info.context);
}
