const std = @import("std");
const c = @import("../c/tree_sitter.zig").c;

pub const Point = struct {
    row: u32,
    column: u32,

    pub fn fromRaw(value: c.TSPoint) Point {
        return .{ .row = value.row, .column = value.column };
    }
};

pub const Node = struct {
    handle: c.TSNode,

    pub fn fromRaw(handle: c.TSNode) Node {
        return .{ .handle = handle };
    }

    pub fn raw(self: Node) c.TSNode {
        return self.handle;
    }

    pub fn isNull(self: Node) bool {
        return c.ts_node_is_null(self.handle) != 0;
    }

    pub fn kind(self: Node) []const u8 {
        const cstr: [*c]const u8 = c.ts_node_type(self.handle);
        return std.mem.span(cstr);
    }

    pub fn startByte(self: Node) u32 {
        return c.ts_node_start_byte(self.handle);
    }

    pub fn endByte(self: Node) u32 {
        return c.ts_node_end_byte(self.handle);
    }

    pub fn startPosition(self: Node) Point {
        return Point.fromRaw(c.ts_node_start_point(self.handle));
    }

    pub fn endPosition(self: Node) Point {
        return Point.fromRaw(c.ts_node_end_point(self.handle));
    }

    pub fn childCount(self: Node) u32 {
        return c.ts_node_child_count(self.handle);
    }

    pub fn child(self: Node, index: u32) ?Node {
        const child_node = c.ts_node_child(self.handle, index);
        if (c.ts_node_is_null(child_node)) return null;
        return Node.fromRaw(child_node);
    }

    pub fn toSExpression(self: Node, allocator: std.mem.Allocator) ![]u8 {
        const sexp_ptr = c.ts_node_to_sexp(self.handle);
        defer c.ts_free(@constCast(sexp_ptr));
        const view = std.mem.span(sexp_ptr);
        const buffer = try allocator.alloc(u8, view.len);
        std.mem.copyForwards(u8, buffer, view);
        return buffer;
    }

    pub fn containsPoint(self: Node, point: Point) bool {
        const start = self.startPosition();
        const end = self.endPosition();

        if (point.row < start.row or point.row > end.row) return false;
        if (point.row == start.row and point.column < start.column) return false;
        if (point.row == end.row and point.column > end.column) return false;

        return true;
    }

    pub fn eql(self: Node, other: Node) bool {
        return c.ts_node_eq(self.handle, other.handle);
    }

    pub fn parent(self: Node) ?Node {
        const parent_node = c.ts_node_parent(self.handle);
        if (c.ts_node_is_null(parent_node)) return null;
        return Node.fromRaw(parent_node);
    }

    pub fn descendantForPointRange(self: Node, start: Point, end: Point) ?Node {
        const start_point = c.TSPoint{ .row = start.row, .column = start.column };
        const end_point = c.TSPoint{ .row = end.row, .column = end.column };
        const descendant = c.ts_node_descendant_for_point_range(self.handle, start_point, end_point);
        if (c.ts_node_is_null(descendant)) return null;
        return Node.fromRaw(descendant);
    }

    pub fn childByFieldName(self: Node, field_name: []const u8) ?Node {
        const child_node = c.ts_node_child_by_field_name(self.handle, field_name.ptr, @intCast(field_name.len));
        if (c.ts_node_is_null(child_node)) return null;
        return Node.fromRaw(child_node);
    }

    pub fn treeWalk(self: Node) !@import("cursor.zig").TreeCursor {
        return @import("cursor.zig").TreeCursor.init(self);
    }

    /// Extract the text content of this node from the source
    /// Returns null if the byte range is invalid
    pub fn text(self: Node, source: []const u8) ?[]const u8 {
        const start = self.startByte();
        const end = self.endByte();

        if (start >= source.len or end > source.len or start > end) {
            return null;
        }

        return source[start..end];
    }

    /// Get the depth of this node in the tree (distance from root)
    /// Root node has depth 0
    pub fn depth(self: Node) u32 {
        var count: u32 = 0;
        var current = self;

        while (current.parent()) |p| {
            count += 1;
            current = p;
        }

        return count;
    }

    /// Check if this node has an error
    pub fn hasError(self: Node) bool {
        return c.ts_node_has_error(self.handle);
    }

    /// Check if this node is named (vs anonymous like punctuation)
    pub fn isNamed(self: Node) bool {
        return c.ts_node_is_named(self.handle);
    }

    /// Check if this node represents a syntax error
    pub fn isError(self: Node) bool {
        return std.mem.eql(u8, self.kind(), "ERROR");
    }

    /// Check if this node is missing (inserted by error recovery)
    pub fn isMissing(self: Node) bool {
        return c.ts_node_is_missing(self.handle);
    }

    /// Get the symbol ID for this node (for advanced tree-sitter usage)
    pub fn symbol(self: Node) u16 {
        return c.ts_node_symbol(self.handle);
    }

    /// Get field ID for this node within its parent
    pub fn childFieldId(self: Node) u16 {
        return c.ts_node_child_by_field_id(self.handle, 0);
    }

    /// Get the named child at the given index
    pub fn namedChild(self: Node, index: u32) ?Node {
        const child_node = c.ts_node_named_child(self.handle, index);
        if (c.ts_node_is_null(child_node)) return null;
        return Node.fromRaw(child_node);
    }

    /// Get the count of named children
    pub fn namedChildCount(self: Node) u32 {
        return c.ts_node_named_child_count(self.handle);
    }

    /// Get next sibling node
    pub fn nextSibling(self: Node) ?Node {
        const sibling = c.ts_node_next_sibling(self.handle);
        if (c.ts_node_is_null(sibling)) return null;
        return Node.fromRaw(sibling);
    }

    /// Get previous sibling node
    pub fn prevSibling(self: Node) ?Node {
        const sibling = c.ts_node_prev_sibling(self.handle);
        if (c.ts_node_is_null(sibling)) return null;
        return Node.fromRaw(sibling);
    }

    /// Get next named sibling node
    pub fn nextNamedSibling(self: Node) ?Node {
        const sibling = c.ts_node_next_named_sibling(self.handle);
        if (c.ts_node_is_null(sibling)) return null;
        return Node.fromRaw(sibling);
    }

    /// Get previous named sibling node
    pub fn prevNamedSibling(self: Node) ?Node {
        const sibling = c.ts_node_prev_named_sibling(self.handle);
        if (c.ts_node_is_null(sibling)) return null;
        return Node.fromRaw(sibling);
    }

    /// Get the field name for a child at the given index
    /// Returns null if the child has no field name or the index is out of bounds
    pub fn fieldNameForChild(self: Node, child_index: u32) ?[]const u8 {
        const field_name_cstr = c.ts_node_field_name_for_child(self.handle, child_index);
        if (field_name_cstr == null) return null;
        return std.mem.span(field_name_cstr);
    }

    /// Get all children with the given field name
    /// Caller owns the returned ArrayList and must call deinit()
    pub fn childrenByFieldName(self: Node, allocator: std.mem.Allocator, field_name: []const u8) !std.ArrayList(Node) {
        var results: std.ArrayList(Node) = .{};
        errdefer results.deinit(allocator);

        const count = self.childCount();
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            if (self.fieldNameForChild(i)) |name| {
                if (std.mem.eql(u8, name, field_name)) {
                    if (self.child(i)) |node| {
                        try results.append(allocator, node);
                    }
                }
            }
        }

        return results;
    }

    /// Byte range structure for convenience
    pub const ByteRange = struct {
        start: u32,
        end: u32,

        /// Get the length of the range
        pub fn len(self: ByteRange) u32 {
            return self.end - self.start;
        }
    };

    /// Get the byte range of this node
    pub fn byteRange(self: Node) ByteRange {
        return .{
            .start = self.startByte(),
            .end = self.endByte(),
        };
    }

    /// Iterator for named descendants
    pub const NamedDescendantsIterator = struct {
        stack: std.ArrayList(Node),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, root: Node) !NamedDescendantsIterator {
            var stack: std.ArrayList(Node) = .{};
            try stack.append(allocator, root);
            return .{
                .stack = stack,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *NamedDescendantsIterator) void {
            self.stack.deinit(self.allocator);
        }

        pub fn next(self: *NamedDescendantsIterator) !?Node {
            while (self.stack.items.len > 0) {
                const node = self.stack.pop();

                // Add children to stack in reverse order for depth-first traversal
                const count = node.namedChildCount();
                if (count > 0) {
                    var i = count;
                    while (i > 0) {
                        i -= 1;
                        if (node.namedChild(i)) |ch| {
                            try self.stack.append(self.allocator, ch);
                        }
                    }
                }

                // Skip the root node itself on first iteration
                if (self.stack.items.len > 0 or node.isNamed()) {
                    return node;
                }
            }
            return null;
        }
    };

    /// Get an iterator over all named descendants (depth-first)
    pub fn namedDescendants(self: Node, allocator: std.mem.Allocator) !NamedDescendantsIterator {
        return NamedDescendantsIterator.init(allocator, self);
    }

    /// Filter children by a predicate function
    /// Caller owns the returned ArrayList and must call deinit()
    pub fn childrenWhere(
        self: Node,
        allocator: std.mem.Allocator,
        predicate: *const fn (Node) bool,
    ) !std.ArrayList(Node) {
        var results: std.ArrayList(Node) = .{};
        errdefer results.deinit(allocator);

        const count = self.childCount();
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            if (self.child(i)) |ch| {
                if (predicate(ch)) {
                    try results.append(allocator, ch);
                }
            }
        }

        return results;
    }
};
