# Grove LSP Helper Functions

**Version:** 0.2.0
**Status:** Production-Ready

Grove provides a comprehensive set of LSP (Language Server Protocol) helper functions that eliminate ~50% of boilerplate code typically required when implementing language servers.

These helpers are battle-tested in production use by:
- **GhostLS** - Native LSP server for Ghostlang, Zig, and Rust
- **Grim** - Neovim-like text editor

---

## Quick Start

```zig
const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse document
    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    const language = try grove.Languages.ghostlang.get();
    try parser.setLanguage(language);

    const source =
        \\function greet(name)
        \\  print("Hello, " .. name)
        \\end
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode().?;

    // Use LSP helpers
    const position = grove.LSP.Position{ .line = 0, .character = 9 };
    if (grove.LSP.findNodeAtPosition(root, position)) |node| {
        std.debug.print("Node at cursor: {s}\n", .{node.kind()});
    }
}
```

---

## Core Helper Functions

### 1. `findNodeAtPosition` - Position to Node Lookup

**Purpose:** Convert an LSP Position (line, character) to a tree-sitter Node.

**Replaces:** 30-60 lines of manual position traversal code.

```zig
pub fn findNodeAtPosition(
    root: grove.Node,
    position: grove.LSP.Position,
) ?grove.Node
```

**Example:**
```zig
const position = grove.LSP.Position{ .line = 10, .character = 5 };
const node = grove.LSP.findNodeAtPosition(root, position);

if (node) |n| {
    std.debug.print("Found {s} at cursor\n", .{n.kind()});
}
```

**Use Cases:**
- Hover information
- Go-to-definition
- Completion triggers
- Rename refactoring

---

### 2. `nodeToRange` - Node to LSP Range Conversion

**Purpose:** Convert a tree-sitter Node to an LSP Range.

**Replaces:** Duplicated range conversion logic across providers.

```zig
pub fn nodeToRange(node: grove.Node) grove.LSP.Range
```

**Example:**
```zig
const range = grove.LSP.nodeToRange(identifier_node);

const location = grove.LSP.Location{
    .uri = "file:///path/to/file.gla",
    .range = range,
};

// Send to LSP client
```

**Use Cases:**
- Creating LSP Locations
- Highlighting ranges
- Diagnostic ranges
- Code action ranges

---

### 3. `extractSymbols` - Document Symbol Extraction

**Purpose:** Automatically extract all symbols (functions, classes, variables) from a syntax tree.

**Replaces:** 200+ lines of manual tree walking and symbol classification.

```zig
pub fn extractSymbols(
    allocator: std.mem.Allocator,
    root: grove.Node,
    source: []const u8,
    node_kind_map: ?*const NodeKindToSymbolKind,
) !std.ArrayList(SymbolInfo)
```

**Example:**
```zig
var symbols = try grove.LSP.extractSymbols(
    allocator,
    root,
    source,
    null, // Use default heuristics
);
defer {
    for (symbols.items) |*sym| sym.deinit(allocator);
    symbols.deinit();
}

for (symbols.items) |sym| {
    std.debug.print("Symbol: {s} ({s})\n", .{
        sym.name,
        @tagName(sym.kind),
    });
}
```

**Custom Symbol Mapping:**
```zig
fn customSymbolMapper(node_kind: []const u8) ?grove.LSP.SymbolKind {
    if (std.mem.eql(u8, node_kind, "fn_decl")) {
        return .function;
    } else if (std.mem.eql(u8, node_kind, "let_stmt")) {
        return .variable;
    }
    return null;
}

var symbols = try grove.LSP.extractSymbols(
    allocator,
    root,
    source,
    &customSymbolMapper,
);
```

**Use Cases:**
- Document outline view
- Breadcrumb navigation
- Symbol search
- Code structure analysis

---

### 4. `collectDiagnostics` - Syntax Error Collection

**Purpose:** Collect all syntax errors from a tree (ERROR and MISSING nodes).

**Replaces:** Manual ERROR node recursion.

```zig
pub fn collectDiagnostics(
    allocator: std.mem.Allocator,
    root: grove.Node,
    source: []const u8,
) !std.ArrayList(DiagnosticInfo)
```

**Example:**
```zig
const source = "{\"hello\": }"; // Invalid JSON

var tree = try parser.parseUtf8(null, source);
defer tree.deinit();

var diagnostics = try grove.LSP.collectDiagnostics(
    allocator,
    tree.rootNode().?,
    source,
);
defer {
    for (diagnostics.items) |*diag| diag.deinit(allocator);
    diagnostics.deinit();
}

for (diagnostics.items) |diag| {
    std.debug.print("Error at {}:{}: {s}\n", .{
        diag.range.start.line,
        diag.range.start.character,
        diag.message,
    });
}
```

**Use Cases:**
- `textDocument/publishDiagnostics`
- Real-time error detection
- Syntax validation
- Error recovery hints

---

## Additional Helpers

### 5. `findDefinition` - Single-File Go-to-Definition

**Purpose:** Find the declaration of an identifier in the same file.

```zig
pub fn findDefinition(
    root: grove.Node,
    identifier: []const u8,
    source: []const u8,
) ?grove.Node
```

**Example:**
```zig
const cursor_node = grove.LSP.findNodeAtPosition(root, position).?;

if (std.mem.eql(u8, cursor_node.kind(), "identifier")) {
    const identifier_text = cursor_node.text(source).?;

    if (grove.LSP.findDefinition(root, identifier_text, source)) |def_node| {
        const location = grove.LSP.Location{
            .uri = document_uri,
            .range = grove.LSP.nodeToRange(def_node),
        };
        // Return location to client
    }
}
```

---

### 6. `findReferences` - Find All References

**Purpose:** Find all occurrences of an identifier in the tree.

```zig
pub fn findReferences(
    allocator: std.mem.Allocator,
    root: grove.Node,
    identifier: []const u8,
    source: []const u8,
) !std.ArrayList(grove.Node)
```

**Example:**
```zig
var references = try grove.LSP.findReferences(
    allocator,
    root,
    "myFunction",
    source,
);
defer references.deinit();

for (references.items) |ref_node| {
    const range = grove.LSP.nodeToRange(ref_node);
    std.debug.print("Reference at {}:{}\n", .{
        range.start.line,
        range.start.character,
    });
}
```

---

### 7. `extractFoldingRanges` - Code Folding

**Purpose:** Extract foldable regions (functions, classes, blocks).

```zig
pub fn extractFoldingRanges(
    allocator: std.mem.Allocator,
    root: grove.Node,
    source: []const u8,
) !std.ArrayList(grove.LSP.FoldingRange)
```

**Example:**
```zig
var folding = try grove.LSP.extractFoldingRanges(allocator, root, source);
defer folding.deinit();

for (folding.items) |range| {
    std.debug.print("Fold lines {}-{} ({})\n", .{
        range.start_line,
        range.end_line,
        @tagName(range.kind orelse .region),
    });
}
```

**Detected Folding Types:**
- Functions, classes, structs, enums
- Code blocks and statement blocks
- Comments
- Import/use statements

---

### 8. `extractSemanticTokens` - Semantic Highlighting

**Purpose:** Generate fine-grained semantic tokens for advanced syntax highlighting.

```zig
pub fn extractSemanticTokens(
    allocator: std.mem.Allocator,
    root: grove.Node,
    source: []const u8,
    type_mapper: ?*const NodeKindToTokenType,
) !std.ArrayList(SemanticToken)
```

**Example:**
```zig
var tokens = try grove.LSP.extractSemanticTokens(
    allocator,
    root,
    source,
    null, // Use default mapping
);
defer tokens.deinit();

for (tokens.items) |token| {
    std.debug.print("Token at {}:{} type={s}\n", .{
        token.line,
        token.start_char,
        @tagName(token.token_type),
    });
}
```

**Semantic Token Types:**
- `function`, `method`, `class`, `struct`, `enum`
- `variable`, `parameter`, `property`
- `keyword`, `operator`, `comment`
- `string`, `number`, `type`

---

## Memory Safety Guarantees

All Grove LSP helpers are designed with zero-leak guarantees:

✅ **Proper Resource Cleanup:**
```zig
var symbols = try grove.LSP.extractSymbols(allocator, root, source, null);
defer {
    for (symbols.items) |*sym| sym.deinit(allocator); // Free nested data
    symbols.deinit(); // Free array
}
```

✅ **Error Handling:**
```zig
var diagnostics = try grove.LSP.collectDiagnostics(allocator, root, source);
errdefer {
    for (diagnostics.items) |*diag| diag.deinit(allocator);
    diagnostics.deinit();
}
```

✅ **No Hidden Allocations:**
- All helpers that allocate memory return owned data structures
- Caller is responsible for deallocation (clear ownership model)
- No global state or hidden caches

---

## Performance Characteristics

| Helper Function | Time Complexity | Memory | Notes |
|-----------------|-----------------|--------|-------|
| `findNodeAtPosition` | O(log n) | O(1) | Uses tree-sitter's optimized descendant search |
| `nodeToRange` | O(1) | O(1) | Direct field access |
| `extractSymbols` | O(n) | O(s) | s = number of symbols |
| `collectDiagnostics` | O(n) | O(e) | e = number of errors |
| `findDefinition` | O(n) | O(1) | Single tree traversal |
| `findReferences` | O(n) | O(r) | r = number of references |
| `extractFoldingRanges` | O(n) | O(f) | f = number of foldable regions |
| `extractSemanticTokens` | O(n) | O(t) | t = number of tokens |

Where n = total nodes in tree.

**Optimization Tips:**
1. Cache parsed trees for open documents
2. Use incremental parsing for edits
3. Debounce diagnostic collection
4. Lazy-load semantic tokens (only when client requests)

---

## Integration with GhostLS

### Before (GhostLS v0.3.0):

```zig
// symbol_provider.zig - 200+ lines
fn collectSymbols(node: grove.Node, text: []const u8, symbols: *ArrayList) !void {
    const kind_str = node.kind();

    // Manual symbol detection
    const symbol_info = if (std.mem.eql(u8, kind_str, "function_declaration"))
        SymbolInfo{ .kind = .Function }
    else if (std.mem.eql(u8, kind_str, "variable_declaration"))
        SymbolInfo{ .kind = .Variable }
    // ... 50 more lines ...

    const name = try extractSymbolName(node, text); // 40 lines
    // ... recursive traversal logic ... (60 lines)
}
```

### After (GhostLS v0.4.0 with Grove helpers):

```zig
// symbol_provider.zig - 20 lines
pub fn getSymbols(tree: *grove.Tree, text: []const u8) ![]SymbolInfo {
    const root = tree.rootNode().?;
    var symbols = try grove.LSP.extractSymbols(allocator, root, text, null);
    return symbols;
}
```

**Code Reduction:** 90% less code, same functionality.

---

## Integration with Grim

Grim uses Grove LSP helpers for:

### Syntax Highlighting
```zig
// grim/syntax/grove.zig
var tokens = try grove.LSP.extractSemanticTokens(allocator, root, source, null);
defer tokens.deinit();

for (tokens.items) |token| {
    const style = tokenTypeToStyle(token.token_type);
    phantom.setStyle(buffer, token.line, token.start_char, token.length, style);
}
```

### Document Outline
```zig
// grim/ui/outline_panel.zig
var symbols = try grove.LSP.extractSymbols(allocator, root, source, null);
defer { /* cleanup */ }

for (symbols.items) |sym| {
    outline.addEntry(sym.name, sym.kind, sym.range);
}
```

---

## Best Practices

### 1. Always Check for Null Nodes
```zig
const root_opt = tree.rootNode();
if (root_opt == null) return &[_]Diagnostic{};
const root = root_opt.?;
```

### 2. Use Defer for Cleanup
```zig
var symbols = try grove.LSP.extractSymbols(allocator, root, source, null);
defer {
    for (symbols.items) |*sym| sym.deinit(allocator);
    symbols.deinit();
}
```

### 3. Handle Text Extraction Safely
```zig
const node_text = node.text(source) orelse return error.InvalidRange;
```

### 4. Combine Helpers for Complex Features
```zig
// Hover provider combining multiple helpers
const cursor_node = grove.LSP.findNodeAtPosition(root, position).?;
const range = grove.LSP.nodeToRange(cursor_node);

if (std.mem.eql(u8, cursor_node.kind(), "identifier")) {
    const identifier = cursor_node.text(source).?;
    if (grove.LSP.findDefinition(root, identifier, source)) |def_node| {
        // Show definition preview
    }
}
```

---

## Testing for Memory Leaks

```zig
test "LSP helpers - no memory leaks" {
    const testing = std.testing;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    const language = try grove.Languages.json.get();
    try parser.setLanguage(language);

    const source = "{\"test\": 123}";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode().?;

    // Test all helpers
    var symbols = try grove.LSP.extractSymbols(allocator, root, source, null);
    defer {
        for (symbols.items) |*sym| sym.deinit(allocator);
        symbols.deinit();
    }

    var diagnostics = try grove.LSP.collectDiagnostics(allocator, root, source);
    defer {
        for (diagnostics.items) |*diag| diag.deinit(allocator);
        diagnostics.deinit();
    }

    var folding = try grove.LSP.extractFoldingRanges(allocator, root, source);
    defer folding.deinit();

    var tokens = try grove.LSP.extractSemanticTokens(allocator, root, source, null);
    defer tokens.deinit();
}
```

---

## Language Support

Grove LSP helpers use heuristic node naming patterns that work across most tree-sitter grammars:

### Tested Languages (15+ grammars):
- ✅ Ghostlang
- ✅ Zig
- ✅ Rust
- ✅ TypeScript / JavaScript
- ✅ Python
- ✅ JSON
- ✅ Bash / GShell
- ✅ C / C++
- ✅ TOML / YAML
- ✅ Markdown

### Custom Language Support:
Provide custom mappers for language-specific node kinds:

```zig
fn zigSymbolMapper(node_kind: []const u8) ?grove.LSP.SymbolKind {
    if (std.mem.eql(u8, node_kind, "FnProto")) return .function;
    if (std.mem.eql(u8, node_kind, "VarDecl")) return .variable;
    if (std.mem.eql(u8, node_kind, "ContainerDecl")) return .@"struct";
    return null;
}
```

---

## Migration Guide

### From Raw Tree-sitter
```diff
- // Old: Manual position lookup (50 lines)
- fn findNodeAtCursor(node: Node, pos: Position) ?Node {
-     // Complex recursion logic...
- }

+ // New: One function call
+ const node = grove.LSP.findNodeAtPosition(root, position);
```

### From Custom Symbol Extraction
```diff
- // Old: Custom symbol walker (200 lines)
- fn walkTree(node: Node, symbols: *ArrayList) !void { /* ... */ }

+ // New: Built-in extraction
+ var symbols = try grove.LSP.extractSymbols(allocator, root, source, null);
```

---

## Future Enhancements (Roadmap)

- [ ] Query predicate support (#is?, #match?, #eq?)
- [ ] Cross-file reference resolution
- [ ] Call hierarchy extraction
- [ ] Type hierarchy extraction
- [ ] Incremental semantic token updates
- [ ] Highlight occurrences helper

---

## See Also

- [Grove README](../README.md) - Main documentation
- [API Reference](./API.md) - Complete API documentation
- [Editor Integration Guide](./EDITOR_INTEGRATION.md) - Building editors with Grove
- [GhostLS Source](https://github.com/ghostkellz/ghostls) - Real-world LSP usage

---

**Questions? Issues?**
File an issue at https://github.com/GhostKellz/grove/issues
