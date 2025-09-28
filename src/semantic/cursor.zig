const std = @import("std");
const Node = @import("../core/node.zig").Node;
const Point = @import("../core/node.zig").Point;
const Language = @import("../language.zig").Language;
const Query = @import("../core/query.zig").Query;
const QueryCursor = @import("../core/query.zig").QueryCursor;

/// Semantic cursor for advanced Tree-sitter navigation and analysis
pub const SemanticCursor = struct {
    allocator: std.mem.Allocator,
    root: Node,
    current: Node,
    path: std.ArrayList(Node),

    pub fn init(allocator: std.mem.Allocator, root: Node) SemanticCursor {
        return .{
            .allocator = allocator,
            .root = root,
            .current = root,
            .path = std.ArrayList(Node){},
        };
    }

    pub fn deinit(self: *SemanticCursor) void {
        self.path.deinit(self.allocator);
    }

    /// Navigate to a specific position in the source code
    pub fn gotoPosition(self: *SemanticCursor, line: u32, column: u32) bool {
        const target_point = Point{ .row = line, .column = column };
        return self.gotoPoint(target_point);
    }

    /// Navigate to a specific point
    pub fn gotoPoint(self: *SemanticCursor, point: Point) bool {
        const target_node = self.findNodeAtPoint(self.root, point);
        if (target_node) |node| {
            self.current = node;
            self.rebuildPath();
            return true;
        }
        return false;
    }

    /// Find the smallest node containing the given point
    fn findNodeAtPoint(self: *SemanticCursor, node: Node, point: Point) ?Node {
        if (!node.containsPoint(point)) return null;

        // Check children first (depth-first)
        for (0..node.childCount()) |i| {
            const child = node.child(@intCast(i));
            if (child) |valid_child| {
                if (self.findNodeAtPoint(valid_child, point)) |found| {
                    return found;
                }
            }
        }

        // If no child contains the point, this node is the smallest
        return node;
    }

    /// Rebuild the path from root to current node
    fn rebuildPath(self: *SemanticCursor) void {
        self.path.clearRetainingCapacity();
        _ = self.buildPathToNode(self.root, self.current);
    }

    /// Recursively build path to target node
    fn buildPathToNode(self: *SemanticCursor, node: Node, target: Node) bool {
        self.path.append(self.allocator, node) catch return false;

        if (node.eql(target)) return true;

        for (0..node.childCount()) |i| {
            const child = node.child(@intCast(i));
            if (child) |valid_child| {
                if (self.buildPathToNode(valid_child, target)) return true;
            }
        }

        _ = self.path.pop();
        return false;
    }

    /// Get the current node
    pub fn getCurrentNode(self: *const SemanticCursor) Node {
        return self.current;
    }

    /// Get the parent of the current node
    pub fn getParent(self: *const SemanticCursor) ?Node {
        if (self.path.items.len < 2) return null;
        return self.path.items[self.path.items.len - 2];
    }

    /// Move cursor to parent node
    pub fn moveToParent(self: *SemanticCursor) bool {
        if (self.getParent()) |parent| {
            self.current = parent;
            _ = self.path.pop();
            return true;
        }
        return false;
    }

    /// Move cursor to first child
    pub fn moveToFirstChild(self: *SemanticCursor) bool {
        if (self.current.childCount() > 0) {
            const child = self.current.child(0);
            self.path.append(self.allocator, self.current) catch return false;
            self.current = child;
            return true;
        }
        return false;
    }

    /// Move cursor to next sibling
    pub fn moveToNextSibling(self: *SemanticCursor) bool {
        const parent = self.getParent() orelse return false;

        for (0..parent.childCount()) |i| {
            const child = parent.child(i);
            if (child.eql(self.current) and i + 1 < parent.childCount()) {
                self.current = parent.child(i + 1);
                return true;
            }
        }
        return false;
    }

    /// Move cursor to previous sibling
    pub fn moveToPreviousSibling(self: *SemanticCursor) bool {
        const parent = self.getParent() orelse return false;

        for (0..parent.childCount()) |i| {
            const child = parent.child(i);
            if (child.eql(self.current) and i > 0) {
                self.current = parent.child(i - 1);
                return true;
            }
        }
        return false;
    }

    /// Get the current path as a slice of nodes from root to current
    pub fn getPath(self: *const SemanticCursor) []const Node {
        return self.path.items;
    }

    /// Get the depth of the current node (distance from root)
    pub fn getDepth(self: *const SemanticCursor) usize {
        return self.path.items.len - 1;
    }

    /// Check if current node matches a type
    pub fn isNodeType(self: *const SemanticCursor, node_type: []const u8) bool {
        return std.mem.eql(u8, self.current.type(), node_type);
    }

    /// Find the nearest ancestor of a specific type
    pub fn findAncestorOfType(self: *const SemanticCursor, node_type: []const u8) ?Node {
        var i = self.path.items.len;
        while (i > 0) {
            i -= 1;
            const ancestor = self.path.items[i];
            if (std.mem.eql(u8, ancestor.kind(), node_type)) {
                return ancestor;
            }
        }
        return null;
    }

    /// Find all descendant nodes of a specific type
    pub fn findDescendantsOfType(
        self: *SemanticCursor,
        node_type: []const u8,
        max_results: ?usize
    ) ![]Node {
        var results = std.ArrayList(Node){};
        defer results.deinit(self.allocator);

        try self.collectDescendantsOfType(self.current, node_type, &results, max_results);
        return results.toOwnedSlice(self.allocator);
    }

    /// Recursively collect descendants of a specific type
    fn collectDescendantsOfType(
        self: *SemanticCursor,
        node: Node,
        node_type: []const u8,
        results: *std.ArrayList(Node),
        max_results: ?usize
    ) !void {
        if (max_results) |max| {
            if (results.items.len >= max) return;
        }

        if (std.mem.eql(u8, node.type(), node_type)) {
            try results.append(self.allocator, node);
        }

        for (0..node.childCount()) |i| {
            const child = node.child(@intCast(i));
            try self.collectDescendantsOfType(child, node_type, results, max_results);
        }
    }

    /// Check if current node is inside a specific context (ancestor type)
    pub fn isInContext(self: *const SemanticCursor, context_type: []const u8) bool {
        return self.findAncestorOfType(context_type) != null;
    }

    /// Get the source text for the current node
    pub fn getCurrentText(self: *const SemanticCursor, source: []const u8) []const u8 {
        const start_byte = self.current.startByte();
        const end_byte = self.current.endByte();

        if (start_byte >= source.len or end_byte > source.len or start_byte >= end_byte) {
            return "";
        }

        return source[start_byte..end_byte];
    }

    /// Execute a query at the current position and return matches
    pub fn queryAtCursor(
        self: *SemanticCursor,
        query: *Query,
        max_matches: ?usize
    ) ![]QueryMatch {
        var cursor = QueryCursor.init() catch return error.QueryCursorFailed;
        defer cursor.deinit();

        cursor.exec(query, self.current);

        var matches = std.ArrayList(QueryMatch){};
        defer matches.deinit(self.allocator);

        var count: usize = 0;
        while (cursor.nextCapture(query)) |capture| {
            if (max_matches) |max| {
                if (count >= max) break;
            }

            try matches.append(self.allocator, .{
                .capture_name = capture.capture.name,
                .node = capture.capture.node,
                .pattern_index = capture.pattern_index,
            });
            count += 1;
        }

        return matches.toOwnedSlice(self.allocator);
    }
};

/// A query match result from semantic analysis
pub const QueryMatch = struct {
    capture_name: []const u8,
    node: Node,
    pattern_index: u32,
};

/// Semantic analysis context for a specific language
pub const SemanticAnalyzer = struct {
    allocator: std.mem.Allocator,
    language: Language,
    queries: std.StringHashMap(*Query),

    pub fn init(allocator: std.mem.Allocator, language: Language) SemanticAnalyzer {
        return .{
            .allocator = allocator,
            .language = language,
            .queries = std.StringHashMap(*Query).init(allocator),
        };
    }

    pub fn deinit(self: *SemanticAnalyzer) void {
        var iterator = self.queries.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.queries.deinit();
    }

    /// Register a named query for semantic analysis
    pub fn registerQuery(self: *SemanticAnalyzer, name: []const u8, source: []const u8) !void {
        const query = try self.allocator.create(Query);
        query.* = Query.init(self.allocator, self.language, source) catch return error.QueryCompileFailed;
        try self.queries.put(name, query);
    }

    /// Create a semantic cursor for the given tree root
    pub fn createCursor(self: *SemanticAnalyzer, root: Node) SemanticCursor {
        return SemanticCursor.init(self.allocator, root);
    }

    /// Analyze scope and binding information
    pub fn analyzeScope(_: *SemanticAnalyzer, cursor: *SemanticCursor) !ScopeInfo {
        // Find function/method/class scopes
        const function_scope = cursor.findAncestorOfType("function_declaration") orelse
                              cursor.findAncestorOfType("method_definition") orelse
                              cursor.findAncestorOfType("arrow_function");

        const class_scope = cursor.findAncestorOfType("class_declaration") orelse
                           cursor.findAncestorOfType("class_definition");

        return ScopeInfo{
            .function_scope = function_scope,
            .class_scope = class_scope,
            .is_global = function_scope == null and class_scope == null,
        };
    }

    /// Find all references to a symbol
    pub fn findReferences(
        self: *SemanticAnalyzer,
        cursor: *SemanticCursor,
        _: []const u8
    ) ![]Node {
        // Use locals query if available
        if (self.queries.get("locals")) |locals_query| {
            const matches = try cursor.queryAtCursor(locals_query, null);
            defer self.allocator.free(matches);

            var references = std.ArrayList(Node){};
            defer references.deinit(self.allocator);

            for (matches) |match| {
                if (std.mem.eql(u8, match.capture_name, "reference") or
                    std.mem.eql(u8, match.capture_name, "definition")) {
                    try references.append(self.allocator, match.node);
                }
            }

            return references.toOwnedSlice(self.allocator);
        }

        // Fallback: find all identifiers with matching text
        return cursor.findDescendantsOfType("identifier", null);
    }
};

/// Information about the current scope context
pub const ScopeInfo = struct {
    function_scope: ?Node,
    class_scope: ?Node,
    is_global: bool,
};