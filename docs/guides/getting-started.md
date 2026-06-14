# Grove Quickstart

Get up and running with Grove in under 10 minutes.

## Installation

Add Grove as a Zig dependency in your `build.zig.zon`:

```zig
.dependencies = .{
    .grove = .{
        .url = "https://github.com/ghostkellz/grove/archive/refs/heads/main.tar.gz",
        // Add hash after first build attempt
    },
},
```

In your `build.zig`:

```zig
const grove = b.dependency("grove", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("grove", grove.module("grove"));
```

## Your First Parse

```zig
const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a parser
    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    // Set the language (JSON in this example)
    const language = try grove.Languages.json.get();
    try parser.setLanguage(language);

    // Parse some source code
    const source = "{\"name\": \"Grove\", \"version\": 1}";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    // Access the syntax tree
    const root = tree.rootNode() orelse return error.EmptyTree;
    std.debug.print("Root: {s}\n", .{root.kind()});
    std.debug.print("Children: {d}\n", .{root.childCount()});
}
```

Output:
```
Root: document
Children: 1
```

## Syntax Highlighting

```zig
const grove = @import("grove");

pub fn highlightCode(allocator: std.mem.Allocator, source: []const u8) ![]grove.Highlight.Span {
    // Get language and parse
    const language = try grove.Languages.zig.get();

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();
    try parser.setLanguage(language);

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    // Load highlight query
    var query = try grove.Query.init(language, @embedFile("queries/highlights.scm"));
    defer query.deinit();

    // Get highlights
    const root = tree.rootNode() orelse return error.EmptyTree;
    return try grove.Highlight.collectHighlights(allocator, &query, root, source);
}
```

## Walking the Tree

```zig
fn printTree(node: grove.Node, depth: usize) void {
    // Print indentation
    for (0..depth) |_| std.debug.print("  ", .{});

    // Print node info
    std.debug.print("{s}", .{node.kind()});
    if (node.isNamed()) {
        std.debug.print(" [{d}:{d}]", .{node.startPoint().row, node.startPoint().column});
    }
    std.debug.print("\n", .{});

    // Recurse into children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            printTree(child, depth + 1);
        }
    }
}

// Usage
const root = tree.rootNode() orelse return error.EmptyTree;
printTree(root, 0);
```

## Incremental Parsing

When source code changes, you can reparse incrementally:

```zig
// Original parse
var tree = try parser.parseUtf8(null, original_source);

// Create edit description
const edit = grove.InputEdit{
    .start_byte = 10,
    .old_end_byte = 15,
    .new_end_byte = 20,
    .start_point = .{ .row = 0, .column = 10 },
    .old_end_point = .{ .row = 0, .column = 15 },
    .new_end_point = .{ .row = 0, .column = 20 },
};

// Apply edit to tree
tree.edit(&edit);

// Reparse with old tree for incremental update
var new_tree = try parser.parseUtf8(&tree, new_source);
defer new_tree.deinit();
```

## Error Handling

Extract syntax errors from a parse tree:

```zig
const errors = try grove.getSyntaxErrors(allocator, tree, source);
defer allocator.free(errors);

for (errors) |err| {
    std.debug.print("Error at {d}:{d}: {s}\n", .{
        err.range.start.row,
        err.range.start.column,
        err.message,
    });
}
```

## Available Languages

```zig
// All bundled languages
const json = try grove.Languages.json.get();
const zig_lang = try grove.Languages.zig.get();
const rust = try grove.Languages.rust.get();
const ghostlang = try grove.Languages.ghostlang.get();
const typescript = try grove.Languages.typescript.get();
const tsx = try grove.Languages.tsx.get();
const bash = try grove.Languages.bash.get();
const javascript = try grove.Languages.javascript.get();
const python = try grove.Languages.python.get();
const markdown = try grove.Languages.markdown.get();
const cmake = try grove.Languages.cmake.get();
const toml = try grove.Languages.toml.get();
const yaml = try grove.Languages.yaml.get();
const c = try grove.Languages.c.get();
const gshell = try grove.Languages.gshell.get();
```

## Next Steps

- See [examples/](../examples/) for complete working examples
- Check [error-handling.md](error-handling.md) for robust error handling patterns
- Read the [documentation index](../README.md) for full API documentation
