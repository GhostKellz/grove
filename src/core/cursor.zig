const std = @import("std");
const c = @import("../c/tree_sitter.zig").c;
const Node = @import("node.zig").Node;
const Point = @import("node.zig").Point;

/// Tree-sitter cursor for efficient tree traversal
pub const TreeCursor = struct {
    handle: c.TSTreeCursor,

    pub fn init(node: Node) !TreeCursor {
        return .{
            .handle = c.ts_tree_cursor_new(node.raw()),
        };
    }

    pub fn deinit(self: *TreeCursor) void {
        c.ts_tree_cursor_delete(&self.handle);
    }

    pub fn currentNode(self: *const TreeCursor) Node {
        return Node.fromRaw(c.ts_tree_cursor_current_node(&self.handle));
    }

    pub fn currentFieldName(self: *const TreeCursor) ?[]const u8 {
        const cstr = c.ts_tree_cursor_current_field_name(&self.handle);
        if (cstr == null) return null;
        return std.mem.span(cstr);
    }

    pub fn gotoParent(self: *TreeCursor) bool {
        return c.ts_tree_cursor_goto_parent(&self.handle);
    }

    pub fn gotoNextSibling(self: *TreeCursor) bool {
        return c.ts_tree_cursor_goto_next_sibling(&self.handle);
    }

    pub fn gotoPreviousSibling(self: *TreeCursor) bool {
        return c.ts_tree_cursor_goto_previous_sibling(&self.handle);
    }

    pub fn gotoFirstChild(self: *TreeCursor) bool {
        return c.ts_tree_cursor_goto_first_child(&self.handle);
    }

    pub fn gotoLastChild(self: *TreeCursor) bool {
        return c.ts_tree_cursor_goto_last_child(&self.handle);
    }

    /// Iterate to the next node in depth-first order
    pub fn nextNode(self: *TreeCursor) ?Node {
        // Try to go to first child
        if (self.gotoFirstChild()) {
            return self.currentNode();
        }

        // Try to go to next sibling
        if (self.gotoNextSibling()) {
            return self.currentNode();
        }

        // Go back up and try siblings of parents
        while (self.gotoParent()) {
            if (self.gotoNextSibling()) {
                return self.currentNode();
            }
        }

        return null;
    }

    pub fn reset(self: *TreeCursor, node: Node) void {
        c.ts_tree_cursor_reset(&self.handle, node.raw());
    }
};
