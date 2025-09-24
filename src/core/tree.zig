const c = @import("../c/tree_sitter.zig").c;
const Node = @import("node.zig").Node;

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

    pub fn copy(self: *const Tree) ?Tree {
        if (self.raw()) |ptr| {
            return Tree.fromRaw(c.ts_tree_copy(ptr));
        }
        return null;
    }

    pub fn rootNode(self: Tree) ?Node {
        if (self.raw()) |ptr| {
            return Node.fromRaw(c.ts_tree_root_node(ptr));
        }
        return null;
    }
};
