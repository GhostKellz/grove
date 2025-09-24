# Grove Parser API (MVP)

This guide documents the initial Grove parser wrapper exposed via `@import("grove")`.

## Types

### `Parser`
```zig
pub const Parser = struct {
    pub fn init(allocator: std.mem.Allocator) ParserError!Parser;
    pub fn deinit(self: *Parser) void;
    pub fn setLanguage(self: *Parser, language: Language) ParserError!void;
    pub fn parseUtf8(self: *Parser, previous: ?*const Tree, source: []const u8) ParserError!Tree;
    pub fn parseChunks(self: *Parser, previous: ?*const Tree, chunks: []const []const u8) ParserError!Tree;
    pub fn parseUtf8Timed(self: *Parser, previous: ?*const Tree, source: []const u8) ParserError!ParseReport;
    pub fn reset(self: *Parser) void;
};
```

- **Allocator** is stored for future expansion (custom buffers, async integration).
- `setLanguage` must be called once per parser life; `LanguageNotSet` guards misuse.
- `parseUtf8` returns a fresh `Tree`. Pass the previous tree to reuse internal state (incremental parsing in later milestones).
- `parseChunks` consumes sequential slices without concatenation—ideal for Grim's rope and Ghostlang streams.
- `parseUtf8Timed` wraps `parseUtf8` and returns a `ParseReport` containing elapsed nanoseconds and byte counts for profiling.
- `reset` clears parser state and forgets the currently configured language.

### `ParserError`
```
error{
    ParserUnavailable,   // Failed to create TSParser (OOM or environment issue)
    LanguageNotSet,       // parse* called before setLanguage
    LanguageUnsupported,  // tree-sitter rejected the supplied language pointer
    InputTooLarge,        // source slice length exceeds u32 (Tree-sitter limit)
    ParseFailed,          // tree-sitter returned null (unexpected)
}
```

### `Language`
```zig
pub const Language = struct {
    pub fn fromRaw(ptr: ?*const c.TSLanguage) LanguageError!Language;
    pub fn raw(self: Language) *const c.TSLanguage;
};
```
Wraps a non-null `*const TSLanguage`. Grove also provides `grove.Languages` for vendored grammars (JSON today, Zig next).

### `Tree`
```zig
pub const Tree = struct {
    pub fn fromRaw(handle: *c.TSTree) Tree;
    pub fn raw(self: *const Tree) ?*c.TSTree;
    pub fn deinit(self: *Tree) void;
    pub fn copy(self: *const Tree) ?Tree;
    pub fn rootNode(self: Tree) ?Node;
};
```

### `Node` & `Point`
Expose common Tree-sitter node queries:
```zig
pub const Node = struct {
    pub fn kind(self: Node) []const u8;
    pub fn startByte(self: Node) u32;
    pub fn endByte(self: Node) u32;
    pub fn startPosition(self: Node) Point;
    pub fn endPosition(self: Node) Point;
    pub fn childCount(self: Node) u32;
    pub fn child(self: Node, index: u32) ?Node;
    pub fn toSExpression(self: Node, allocator: std.mem.Allocator) ![]u8;
};

pub const Point = struct {
    row: u32,
    column: u32,
};
```

### `ParseReport`
```zig
pub const ParseReport = struct {
    tree: Tree,
    duration_ns: u64,
    bytes: usize,
};
```
Call `report.tree.deinit()` when finished. `duration_ns` is coarse but stable across platforms, enabling throughput calculations.

### `ParserPool`
```zig
const ParserPool = @import("grove").ParserPool;

var pool = try ParserPool.init(allocator, try grove.Languages.json.get(), 4);
defer pool.deinit();

var lease = try pool.acquire();
defer lease.deinit();
var tree = try lease.parserRef().parseUtf8(null, source);
defer tree.deinit();
```
`ParserPool` amortises parser creation and language configuration. `Lease.deinit()` automatically returns the parser to the pool.

## Minimal Workflow
```zig
const std = @import("std");
const grove = @import("grove");

fn parseSource(source: []const u8, allocator: std.mem.Allocator) !void {
    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    const language = try grove.Languages.json.get();
    try parser.setLanguage(language);

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return error.EmptyTree;
    std.debug.print("root kind = {s}\n", .{root.kind()});
}
```

## Notes & Limitations
- JSON, Zig, Rust, and Ghostlang ship in-tree under `vendor/grammars`; additional grammars will be added as we validate them.
- `parseUtf8` operates synchronously; async/streaming APIs will depend on Zsync in Alpha.
- `Node.toSExpression` allocates a new buffer; caller owns the returned slice.
- Memory diagnostics rely on Zig testing; integration with external leak detectors is planned.

For additional context see `docs/mvp-overview.md`, `CODEX.md`, and `ROADMAP.md`.
