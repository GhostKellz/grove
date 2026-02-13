# Error Handling in Grove

Grove uses Zig's error handling patterns throughout. This guide covers best practices for robust error handling.

## Error Types

### Parser Errors

```zig
const grove = @import("grove");

// Parser initialization can fail on memory allocation
var parser = grove.Parser.init(allocator) catch |err| {
    std.log.err("Failed to create parser: {}", .{err});
    return err;
};
defer parser.deinit();

// Setting language can fail if language is invalid
parser.setLanguage(language) catch |err| {
    std.log.err("Invalid language: {}", .{err});
    return err;
};
```

### Parse Errors

Parsing itself doesn't fail - Tree-sitter always produces a tree, even for invalid input. Instead, check for error nodes:

```zig
var tree = try parser.parseUtf8(null, source);
defer tree.deinit();

const root = tree.rootNode() orelse {
    // Empty tree (shouldn't happen with valid parser setup)
    return error.EmptyTree;
};

// Check if tree has errors
if (root.hasError()) {
    const errors = try grove.getSyntaxErrors(allocator, tree, source);
    defer allocator.free(errors);

    for (errors) |err| {
        std.log.warn("Syntax error at {d}:{d}: {s}", .{
            err.range.start.row + 1,
            err.range.start.column,
            err.message,
        });
    }
}
```

### Query Errors

Query compilation can fail with invalid patterns:

```zig
var query = grove.Query.init(language, query_source) catch |err| switch (err) {
    error.QuerySyntax => {
        std.log.err("Invalid query syntax", .{});
        return err;
    },
    error.QueryNodeType => {
        std.log.err("Unknown node type in query", .{});
        return err;
    },
    error.QueryField => {
        std.log.err("Unknown field name in query", .{});
        return err;
    },
    error.QueryCapture => {
        std.log.err("Invalid capture in query", .{});
        return err;
    },
    else => return err,
};
defer query.deinit();
```

### Validation Before Runtime

Validate queries at build time or startup:

```zig
// Validate query string
const validation = grove.validateQuery(language, query_source);
if (validation.error) |err| {
    std.log.err("Query error at offset {d}: {s}", .{
        validation.error_offset,
        err,
    });
    return error.InvalidQuery;
}

// Validate query file
const file_result = try grove.validateQueryFile(allocator, language, "queries/highlights.scm");
if (!file_result.valid) {
    std.log.err("Invalid query file: {s}", .{file_result.error_message});
    return error.InvalidQueryFile;
}
```

## Resource Management

Always use defer for cleanup:

```zig
pub fn processFile(allocator: std.mem.Allocator, path: []const u8) !void {
    // Parser cleanup
    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    // Tree cleanup
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    // Query cleanup
    var query = try grove.Query.init(language, query_source);
    defer query.deinit();

    // Cursor cleanup
    var cursor = try grove.QueryCursor.init();
    defer cursor.deinit();

    // ... use resources
}
```

## Null Checks

Many tree operations return optionals:

```zig
const root = tree.rootNode() orelse return error.EmptyTree;

// Child access
if (node.child(0)) |first_child| {
    // use first_child
}

// Named children
if (node.childByFieldName("name")) |name_node| {
    // use name_node
}

// Sibling navigation
if (node.nextSibling()) |sibling| {
    // use sibling
}
```

## Error Recovery Patterns

### Graceful Degradation

```zig
pub fn highlight(source: []const u8) ![]Span {
    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(language);

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse {
        // Return empty highlights instead of failing
        return &[_]Span{};
    };

    // If tree has errors, still try to highlight valid parts
    return try collectHighlights(root, source);
}
```

### Timeout Handling

For large files, set parse timeouts:

```zig
// Set timeout in microseconds
parser.setTimeoutMicros(100_000); // 100ms

var tree = parser.parseUtf8(null, large_source) catch |err| {
    if (err == error.Timeout) {
        std.log.warn("Parse timeout, file too large", .{});
        return error.FileTooLarge;
    }
    return err;
};
```

### Memory Limits

Use bounded allocators for untrusted input:

```zig
// Create bounded allocator (max 10MB)
var bounded = std.heap.MemoryPoolExtra(u8, .{}).init(allocator);
bounded.setLimit(10 * 1024 * 1024);

var parser = try grove.Parser.init(bounded.allocator());
defer parser.deinit();

// Parse will fail if memory limit exceeded
var tree = parser.parseUtf8(null, source) catch |err| {
    if (err == error.OutOfMemory) {
        std.log.warn("Parse exceeded memory limit", .{});
        return error.FileTooLarge;
    }
    return err;
};
```

## Testing Error Paths

```zig
test "handles invalid syntax" {
    var parser = try grove.Parser.init(std.testing.allocator);
    defer parser.deinit();

    try parser.setLanguage(try grove.Languages.json.get());

    // Invalid JSON
    var tree = try parser.parseUtf8(null, "{invalid}");
    defer tree.deinit();

    const root = tree.rootNode().?;
    try std.testing.expect(root.hasError());
}

test "handles empty input" {
    var parser = try grove.Parser.init(std.testing.allocator);
    defer parser.deinit();

    try parser.setLanguage(try grove.Languages.json.get());

    var tree = try parser.parseUtf8(null, "");
    defer tree.deinit();

    // Empty input still produces a tree
    try std.testing.expect(tree.rootNode() != null);
}
```

## Best Practices

1. **Always defer cleanup** - Use `defer deinit()` immediately after creation
2. **Check optionals** - Use `orelse` or `if` for nullable returns
3. **Validate early** - Check queries and configurations at startup
4. **Log errors** - Provide context for debugging
5. **Graceful fallback** - Return partial results when possible
6. **Bound resources** - Set timeouts and memory limits for untrusted input
