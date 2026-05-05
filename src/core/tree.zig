const std = @import("std");
const c = @import("../c/tree_sitter.zig").c;
const Node = @import("node.zig").Node;
const Language = @import("../language.zig").Language;

pub const TreeError = error{InvalidHandle};

pub const Tree = struct {
    handle: ?*c.TSTree,

    pub fn fromRaw(handle: *c.TSTree) Tree {
        return .{ .handle = handle };
    }

    pub fn raw(self: *const Tree) ?*c.TSTree {
        return self.handle;
    }

    pub fn isValid(self: Tree) bool {
        return self.handle != null;
    }

    pub fn deinit(self: *Tree) void {
        if (self.handle) |ptr| {
            c.ts_tree_delete(ptr);
            self.handle = null;
        }
    }

    /// Create a shallow copy of the tree for undo/redo without re-parsing
    /// The copy shares the same underlying syntax nodes but can be edited independently
    pub fn copy(self: *const Tree) ?Tree {
        if (self.raw()) |ptr| {
            return Tree.fromRaw(c.ts_tree_copy(ptr));
        }
        return null;
    }

    /// Alias for copy() - clone a tree for undo/redo stacks
    pub fn clone(self: *const Tree) ?Tree {
        return self.copy();
    }

    pub fn rootNode(self: Tree) ?Node {
        if (self.raw()) |ptr| {
            return Node.fromRaw(c.ts_tree_root_node(ptr));
        }
        return null;
    }

    /// Get the language this tree was parsed with.
    /// Returns TreeError.InvalidHandle if the tree handle is null.
    pub fn language(self: *const Tree) TreeError!Language {
        const ptr = self.handle orelse return TreeError.InvalidHandle;
        const lang_ptr = c.ts_tree_language(ptr);
        return Language.fromRaw(lang_ptr);
    }

    /// A range that has changed between two trees
    pub const ChangedRange = struct {
        start_byte: u32,
        end_byte: u32,
        start_point: @import("node.zig").Point,
        end_point: @import("node.zig").Point,
    };

    /// Compare this tree with an old tree to find changed ranges
    /// Returns an ArrayList of changed ranges that the caller must deinit
    ///
    /// This is useful for incremental updates - you can determine exactly
    /// which parts of the document changed between edits.
    ///
    /// Example:
    /// ```zig
    /// var old_tree = try parser.parseUtf8(null, old_source);
    /// defer old_tree.deinit();
    ///
    /// var new_tree = try parser.parseUtf8(&old_tree, new_source);
    /// defer new_tree.deinit();
    ///
    /// var ranges = try new_tree.diff(allocator, &old_tree);
    /// defer ranges.deinit();
    /// ```
    pub fn diff(self: *const Tree, allocator: std.mem.Allocator, old_tree: *const Tree) !std.ArrayList(ChangedRange) {
        var ranges: std.ArrayList(ChangedRange) = .empty;
        errdefer ranges.deinit(allocator);

        const new_ptr = self.handle orelse return ranges;
        const old_ptr = old_tree.handle orelse return ranges;

        // Get changed ranges from tree-sitter
        var range_count: u32 = 0;
        const ts_ranges = c.ts_tree_get_changed_ranges(old_ptr, new_ptr, &range_count);
        defer c.ts_free(@constCast(@ptrCast(ts_ranges)));

        // Convert to our format
        var i: u32 = 0;
        while (i < range_count) : (i += 1) {
            const ts_range = ts_ranges[i];
            try ranges.append(allocator, .{
                .start_byte = ts_range.start_byte,
                .end_byte = ts_range.end_byte,
                .start_point = .{
                    .row = ts_range.start_point.row,
                    .column = ts_range.start_point.column,
                },
                .end_point = .{
                    .row = ts_range.end_point.row,
                    .column = ts_range.end_point.column,
                },
            });
        }

        return ranges;
    }

    /// Check if any syntax errors exist in the tree
    pub fn hasError(self: *const Tree) bool {
        if (self.rootNode()) |root| {
            return root.hasError();
        }
        return false;
    }
};
