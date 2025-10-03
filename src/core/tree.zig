const c = @import("../c/tree_sitter.zig").c;
const Node = @import("node.zig").Node;
const Language = @import("../language.zig").Language;

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

    /// Get the language this tree was parsed with
    pub fn language(self: *const Tree) Language {
        const ptr = self.handle orelse @panic("invalid tree handle");
        const lang_ptr = c.ts_tree_language(ptr);
        return Language.fromRaw(lang_ptr);
    }
};
