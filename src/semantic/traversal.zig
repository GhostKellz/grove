const std = @import("std");
const Node = @import("../core/node.zig").Node;
const Point = @import("../core/node.zig").Point;

/// Traversal strategies for semantic analysis
pub const TraversalStrategy = enum {
    depth_first_pre,
    depth_first_post,
    breadth_first,
    siblings_only,
    ancestors_only,
};

/// Visitor function type for tree traversal
pub const VisitorFn = *const fn (node: Node, depth: usize, context: *anyopaque) bool;

/// Predicate function type for filtering nodes
pub const PredicateFn = *const fn (node: Node, context: *anyopaque) bool;

/// Tree traversal utilities for semantic analysis
pub const TreeTraversal = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TreeTraversal {
        return .{ .allocator = allocator };
    }

    /// Traverse tree with custom visitor function
    pub fn traverse(
        self: *TreeTraversal,
        root: Node,
        strategy: TraversalStrategy,
        visitor: VisitorFn,
        context: *anyopaque
    ) void {
        switch (strategy) {
            .depth_first_pre => self.traverseDepthFirstPre(root, visitor, context, 0),
            .depth_first_post => self.traverseDepthFirstPost(root, visitor, context, 0),
            .breadth_first => self.traverseBreadthFirst(root, visitor, context),
            .siblings_only => self.traverseSiblings(root, visitor, context),
            .ancestors_only => {}, // Requires starting from specific node
        }
    }

    /// Depth-first pre-order traversal
    fn traverseDepthFirstPre(
        self: *TreeTraversal,
        node: Node,
        visitor: VisitorFn,
        context: *anyopaque,
        depth: usize
    ) void {
        // Visit current node first
        if (!visitor(node, depth, context)) return;

        // Then visit children
        for (0..node.childCount()) |i| {
            const child = node.child(i);
            self.traverseDepthFirstPre(child, visitor, context, depth + 1);
        }
    }

    /// Depth-first post-order traversal
    fn traverseDepthFirstPost(
        self: *TreeTraversal,
        node: Node,
        visitor: VisitorFn,
        context: *anyopaque,
        depth: usize
    ) void {
        // Visit children first
        for (0..node.childCount()) |i| {
            const child = node.child(i);
            self.traverseDepthFirstPost(child, visitor, context, depth + 1);
        }

        // Then visit current node
        _ = visitor(node, depth, context);
    }

    /// Breadth-first traversal
    fn traverseBreadthFirst(
        self: *TreeTraversal,
        root: Node,
        visitor: VisitorFn,
        context: *anyopaque
    ) void {
        var queue = std.ArrayList(QueueItem){};
        defer queue.deinit(self.allocator);

        queue.append(self.allocator, .{ .node = root, .depth = 0 }) catch return;

        while (queue.items.len > 0) {
            const item = queue.orderedRemove(0);

            if (!visitor(item.node, item.depth, context)) continue;

            // Add children to queue
            for (0..item.node.childCount()) |i| {
                const child = item.node.child(i);
                queue.append(self.allocator, .{
                    .node = child,
                    .depth = item.depth + 1
                }) catch continue;
            }
        }
    }

    /// Traverse only siblings of the given node
    fn traverseSiblings(
        self: *TreeTraversal,
        node: Node,
        visitor: VisitorFn,
        context: *anyopaque
    ) void {
        _ = self;
        const parent = node.parent() orelse return;

        for (0..parent.childCount()) |i| {
            const sibling = parent.child(i);
            if (!visitor(sibling, 0, context)) break;
        }
    }

    /// Find nodes matching a predicate
    pub fn findNodes(
        self: *TreeTraversal,
        root: Node,
        predicate: PredicateFn,
        max_results: ?usize,
        context: *anyopaque
    ) ![]Node {
        var collector = NodeCollector.init(self.allocator, predicate, max_results, context);
        defer collector.deinit();

        self.traverse(root, .depth_first_pre, NodeCollector.visit, &collector);
        return collector.results.toOwnedSlice(self.allocator);
    }

    /// Find the first node matching a predicate
    pub fn findFirstNode(
        self: *TreeTraversal,
        root: Node,
        predicate: PredicateFn,
        context: *anyopaque
    ) ?Node {
        var finder = FirstNodeFinder.init(predicate, context);
        self.traverse(root, .depth_first_pre, FirstNodeFinder.visit, &finder);
        return finder.result;
    }

    /// Count nodes matching a predicate
    pub fn countNodes(
        self: *TreeTraversal,
        root: Node,
        predicate: PredicateFn,
        context: *anyopaque
    ) u32 {
        var counter = NodeCounter.init(predicate, context);
        self.traverse(root, .depth_first_pre, NodeCounter.visit, &counter);
        return counter.count;
    }

    /// Analyze tree structure and return statistics
    pub fn analyzeStructure(self: *TreeTraversal, root: Node) TreeStats {
        var analyzer = TreeAnalyzer.init();
        self.traverse(root, .depth_first_pre, TreeAnalyzer.visit, &analyzer);
        return analyzer.stats;
    }
};

/// Helper for breadth-first traversal queue
const QueueItem = struct {
    node: Node,
    depth: usize,
};

/// Helper for collecting nodes that match a predicate
const NodeCollector = struct {
    allocator: std.mem.Allocator,
    results: std.ArrayList(Node),
    predicate: PredicateFn,
    max_results: ?usize,
    context: *anyopaque,

    fn init(
        allocator: std.mem.Allocator,
        predicate: PredicateFn,
        max_results: ?usize,
        context: *anyopaque
    ) NodeCollector {
        return .{
            .allocator = allocator,
            .results = std.ArrayList(Node){},
            .predicate = predicate,
            .max_results = max_results,
            .context = context,
        };
    }

    fn deinit(self: *NodeCollector) void {
        self.results.deinit(self.allocator);
    }

    fn visit(node: Node, depth: usize, context: *anyopaque) bool {
        _ = depth;
        const self: *NodeCollector = @ptrCast(@alignCast(context));

        if (self.max_results) |max| {
            if (self.results.items.len >= max) return false;
        }

        if (self.predicate(node, self.context)) {
            self.results.append(self.allocator, node) catch return false;
        }

        return true;
    }
};

/// Helper for finding the first matching node
const FirstNodeFinder = struct {
    predicate: PredicateFn,
    context: *anyopaque,
    result: ?Node,

    fn init(predicate: PredicateFn, context: *anyopaque) FirstNodeFinder {
        return .{
            .predicate = predicate,
            .context = context,
            .result = null,
        };
    }

    fn visit(node: Node, depth: usize, context: *anyopaque) bool {
        _ = depth;
        const self: *FirstNodeFinder = @ptrCast(@alignCast(context));

        if (self.predicate(node, self.context)) {
            self.result = node;
            return false; // Stop traversal
        }

        return true;
    }
};

/// Helper for counting matching nodes
const NodeCounter = struct {
    predicate: PredicateFn,
    context: *anyopaque,
    count: u32,

    fn init(predicate: PredicateFn, context: *anyopaque) NodeCounter {
        return .{
            .predicate = predicate,
            .context = context,
            .count = 0,
        };
    }

    fn visit(node: Node, depth: usize, context: *anyopaque) bool {
        _ = depth;
        const self: *NodeCounter = @ptrCast(@alignCast(context));

        if (self.predicate(node, self.context)) {
            self.count += 1;
        }

        return true;
    }
};

/// Helper for analyzing tree structure
const TreeAnalyzer = struct {
    stats: TreeStats,

    fn init() TreeAnalyzer {
        return .{
            .stats = .{
                .total_nodes = 0,
                .max_depth = 0,
                .leaf_nodes = 0,
                .average_children = 0.0,
            },
        };
    }

    fn visit(node: Node, depth: usize, context: *anyopaque) bool {
        const self: *TreeAnalyzer = @ptrCast(@alignCast(context));

        self.stats.total_nodes += 1;

        if (depth > self.stats.max_depth) {
            self.stats.max_depth = depth;
        }

        if (node.childCount() == 0) {
            self.stats.leaf_nodes += 1;
        }

        // Calculate average children (will be finalized after traversal)
        self.stats.average_children += @floatFromInt(node.childCount());

        return true;
    }
};

/// Tree structure statistics
pub const TreeStats = struct {
    total_nodes: u32,
    max_depth: usize,
    leaf_nodes: u32,
    average_children: f32,

    pub fn finalize(self: *TreeStats) void {
        if (self.total_nodes > 0) {
            self.average_children /= @floatFromInt(self.total_nodes);
        }
    }
};

/// Common predicates for node filtering
pub const Predicates = struct {
    /// Predicate context for type matching
    pub const TypeContext = struct {
        node_type: []const u8,
    };

    /// Check if node is of a specific type
    pub fn isType(node: Node, context: *anyopaque) bool {
        const ctx: *TypeContext = @ptrCast(@alignCast(context));
        return std.mem.eql(u8, node.type(), ctx.node_type);
    }

    /// Check if node is named (not anonymous)
    pub fn isNamed(node: Node, context: *anyopaque) bool {
        _ = context;
        return node.isNamed();
    }

    /// Check if node is a leaf (has no children)
    pub fn isLeaf(node: Node, context: *anyopaque) bool {
        _ = context;
        return node.childCount() == 0;
    }

    /// Check if node has errors
    pub fn hasError(node: Node, context: *anyopaque) bool {
        _ = context;
        return node.hasError();
    }

    /// Check if node is missing
    pub fn isMissing(node: Node, context: *anyopaque) bool {
        _ = context;
        return node.isMissing();
    }

    /// Check if node spans multiple lines
    pub fn isMultiline(node: Node, context: *anyopaque) bool {
        _ = context;
        const start = node.startPosition();
        const end = node.endPosition();
        return end.row > start.row;
    }
};