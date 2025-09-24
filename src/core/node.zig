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
        if (c.ts_node_is_null(child_node) != 0) return null;
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
};
