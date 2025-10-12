// Command validation API for REPL/shell environments
// Allows external validation of commands (e.g., checking PATH)

const std = @import("std");
const Node = @import("../core/node.zig").Node;

/// Validator function provided by shell to check if command exists
/// Returns true if command is valid (exists in PATH, is builtin, etc.)
pub const CommandValidator = *const fn (command: []const u8) bool;

/// Result of command validation
pub const ValidationResult = struct {
    /// Start byte of validated item
    start_byte: u32,
    /// End byte of validated item
    end_byte: u32,
    /// Whether the command is valid
    is_valid: bool,
    /// Type of validation (command, builtin, external, etc.)
    kind: ValidationType,
};

pub const ValidationType = enum {
    command,
    builtin,
    external,
    unknown,
};

/// Validate commands in a parsed tree using external validator
///
/// Walks the tree looking for command nodes and validates them
/// using the provided validator function.
pub fn validateCommands(
    allocator: std.mem.Allocator,
    root: Node,
    source: []const u8,
    validator: CommandValidator,
) ![]ValidationResult {
    var results = std.ArrayList(ValidationResult).init(allocator);
    errdefer results.deinit();

    try walkAndValidate(root, source, validator, &results);

    return try results.toOwnedSlice();
}

fn walkAndValidate(
    node: Node,
    source: []const u8,
    validator: CommandValidator,
    results: *std.ArrayList(ValidationResult),
) !void {
    const node_kind = node.kind();

    // Check if this is a command node
    if (std.mem.eql(u8, node_kind, "command_name") or
        std.mem.eql(u8, node_kind, "builtin_command"))
    {
        const start = node.startByte();
        const end = node.endByte();

        if (end > start and end <= source.len) {
            const command_text = source[start..end];
            const is_valid = validator(command_text);

            const kind: ValidationType = if (std.mem.eql(u8, node_kind, "builtin_command"))
                .builtin
            else if (is_valid)
                .external
            else
                .unknown;

            try results.append(.{
                .start_byte = start,
                .end_byte = end,
                .is_valid = is_valid or std.mem.eql(u8, node_kind, "builtin_command"),
                .kind = kind,
            });
        }
    }

    // Recurse into children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            try walkAndValidate(child, source, validator, results);
        }
    }
}

/// Check if a specific command exists (convenience wrapper)
pub fn isValidCommand(
    root: Node,
    source: []const u8,
    command: []const u8,
    validator: CommandValidator,
) bool {
    return checkCommandInTree(root, source, command, validator);
}

fn checkCommandInTree(
    node: Node,
    source: []const u8,
    target_command: []const u8,
    validator: CommandValidator,
) bool {
    const node_kind = node.kind();

    if (std.mem.eql(u8, node_kind, "command_name") or
        std.mem.eql(u8, node_kind, "builtin_command"))
    {
        const start = node.startByte();
        const end = node.endByte();

        if (end > start and end <= source.len) {
            const command_text = source[start..end];
            if (std.mem.eql(u8, command_text, target_command)) {
                return validator(command_text) or std.mem.eql(u8, node_kind, "builtin_command");
            }
        }
    }

    // Recurse into children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            if (checkCommandInTree(child, source, target_command, validator)) {
                return true;
            }
        }
    }

    return false;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const Languages = @import("../languages.zig").Bundled;
const Parser = @import("../core/parser.zig").Parser;

fn mockValidator(command: []const u8) bool {
    // Mock: ls, git, cat are valid; others are not
    return std.mem.eql(u8, command, "ls") or
        std.mem.eql(u8, command, "git") or
        std.mem.eql(u8, command, "cat");
}

test "validateCommands: valid external command" {
    const lang = try Languages.gshell.get();
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    try parser.setLanguage(lang);

    const source = "ls -la";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.NoRoot;
    const results = try validateCommands(testing.allocator, root, source, mockValidator);
    defer testing.allocator.free(results);

    try testing.expect(results.len > 0);
    try testing.expect(results[0].is_valid);
    try testing.expectEqual(ValidationType.external, results[0].kind);
}

test "validateCommands: invalid external command" {
    const lang = try Languages.gshell.get();
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    try parser.setLanguage(lang);

    const source = "invalidcmd -x";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.NoRoot;
    const results = try validateCommands(testing.allocator, root, source, mockValidator);
    defer testing.allocator.free(results);

    try testing.expect(results.len > 0);
    try testing.expect(!results[0].is_valid);
    try testing.expectEqual(ValidationType.unknown, results[0].kind);
}

test "validateCommands: builtin command always valid" {
    const lang = try Languages.gshell.get();
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    try parser.setLanguage(lang);

    const source = "cd /tmp";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.NoRoot;
    const results = try validateCommands(testing.allocator, root, source, mockValidator);
    defer testing.allocator.free(results);

    try testing.expect(results.len > 0);
    try testing.expect(results[0].is_valid);
    try testing.expectEqual(ValidationType.builtin, results[0].kind);
}

test "validateCommands: multiple commands in pipeline" {
    const lang = try Languages.gshell.get();
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    try parser.setLanguage(lang);

    const source = "ls -la | grep test";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.NoRoot;
    const results = try validateCommands(testing.allocator, root, source, mockValidator);
    defer testing.allocator.free(results);

    // Should find both ls and grep (both valid in our mock)
    try testing.expect(results.len >= 2);
    try testing.expect(results[0].is_valid); // ls
}

test "isValidCommand: check specific command" {
    const lang = try Languages.gshell.get();
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    try parser.setLanguage(lang);

    const source = "git status";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.NoRoot;

    try testing.expect(isValidCommand(root, source, "git", mockValidator));
    try testing.expect(!isValidCommand(root, source, "invalid", mockValidator));
}
