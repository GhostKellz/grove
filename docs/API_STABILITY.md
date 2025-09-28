# Grove API Stability & Public Surface

This document defines Grove's public API surface and stability guarantees for the RC1 release.

## API Stability Promise

Grove follows semantic versioning (SemVer) for API compatibility:

- **PATCH** (0.1.x): Bug fixes, internal optimizations, non-breaking additions
- **MINOR** (0.x.0): New features, backward-compatible API additions
- **MAJOR** (x.0.0): Breaking changes to public API

## Public API Surface

### Core Parsing API

**STABLE** - These APIs are considered stable and will not change without a major version bump:

```zig
// Core parsing types and functions
pub const Parser = @import("core/parser.zig").Parser;
pub const Tree = @import("core/tree.zig").Tree;
pub const Node = @import("core/node.zig").Node;
pub const Point = @import("core/node.zig").Point;

// Language management
pub const Language = @import("language.zig").Language;
pub const Languages = @import("languages.zig").Bundled;

// Query system
pub const Query = @import("core/query.zig").Query;
pub const QueryCursor = @import("core/query.zig").QueryCursor;
pub const QueryCapture = @import("core/query.zig").Capture;

// Parser pooling
pub const ParserPool = @import("core/pool.zig").ParserPool;
pub const ParserLease = @import("core/pool.zig").Lease;
```

**Core Parser Interface:**
```zig
// Parser creation and management
Parser.init(allocator: Allocator) !Parser
Parser.deinit(self: *Parser) void
Parser.setLanguage(self: *Parser, language: Language) !void
Parser.parseUtf8(self: *Parser, previous: ?*const Tree, source: []const u8) !Tree

// Tree traversal
Tree.deinit(self: *Tree) void
Tree.rootNode(self: Tree) ?Node

// Node inspection
Node.kind(self: Node) []const u8
Node.startByte(self: Node) u32
Node.endByte(self: Node) u32
Node.startPosition(self: Node) Point
Node.endPosition(self: Node) Point
Node.childCount(self: Node) u32
Node.child(self: Node, index: u32) ?Node
Node.parent(self: Node) ?Node
```

### Editor Integration API

**STABLE** - Editor services and highlighting:

```zig
// Editor services
pub const Editor = @import("editor.zig");
pub const EditorServices = Editor.EditorServices;
pub const QueryRegistry = Editor.QueryRegistry;

// Highlighting
pub const Highlight = @import("editor/highlight.zig");
```

**Editor Services Interface:**
```zig
EditorServices.init(allocator: Allocator) !EditorServices
EditorServices.deinit(self: *EditorServices) void
EditorServices.getUtilities(self: *EditorServices, language: Language) !LanguageUtilities

// Language utilities (varies by language)
utilities.documentSymbols(root: Node, source: []const u8) ![]DocumentSymbol
utilities.foldingRanges(root: Node, source: []const u8) ![]FoldingRange
```

### Semantic Analysis API

**BETA** - Semantic analysis features (may change in minor versions):

```zig
pub const Semantic = @import("semantic.zig");

// Core semantic types
Semantic.SemanticCursor
Semantic.SemanticAnalyzer
Semantic.TreeTraversal

// Language-specific analyzers
Semantic.TypeScriptAnalyzer
Semantic.ZigAnalyzer

// Analysis functions
Semantic.createCursor(allocator, root) SemanticCursor
Semantic.createAnalyzer(allocator, language) SemanticAnalyzer
Semantic.analyzePosition(allocator, root, line, column, language) !PositionAnalysis
```

### LSP Helper API

**BETA** - LSP integration helpers (may change in minor versions):

```zig
pub const LSP = @import("lsp.zig");

// LSP types
LSP.Position
LSP.Range
LSP.DocumentSymbol
LSP.CompletionItem
LSP.FoldingRange
LSP.Diagnostic

// Server interface
LSP.LanguageServer
LSP.LanguageServerFactory

// Utility functions
LSP.Utils.pointToPosition(point) Position
LSP.Utils.positionToPoint(position) Point
```

### Grim Bridge API

**STABLE** - Grim editor integration:

```zig
pub const GrimBridge = Editor.GrimBridge;

// Configuration export
GrimBridge.getGrimConfig(allocator) ![]u8
GrimBridge.getLanguageQueries(allocator, language) !LanguageQuerySet
GrimBridge.getThemeConfig(allocator, theme_name) !ThemeConfig
```

## Deprecated APIs

None currently. When APIs are deprecated, they will be marked with deprecation warnings and documented here.

## Experimental APIs

**EXPERIMENTAL** - These APIs may change significantly or be removed:

```zig
// Advanced semantic analysis features
Semantic.SymbolInfo
Semantic.ScopeInfo

// Custom query compilation
Query.compile(allocator, language, source) !Query
```

## Internal APIs

**INTERNAL** - These are implementation details and may change without notice:

- All functions and types in `c/` directory
- Internal parser state management
- Memory pool implementations
- Tree-sitter C bindings (beyond what's exposed in public API)

## API Evolution Guidelines

### Adding New APIs

**Allowed in PATCH releases:**
- New optional parameters with defaults
- New methods on existing types
- New utility functions
- Performance improvements
- Bug fixes

**Allowed in MINOR releases:**
- New public types and modules
- New required parameters (with migration path)
- New error types
- Behavioral changes that improve correctness

**Requires MAJOR release:**
- Removing public APIs
- Changing function signatures
- Changing return types
- Changing error types in breaking ways
- Significant behavioral changes

### Backward Compatibility

Grove maintains backward compatibility within major versions by:

1. **Additive changes only** - New APIs are added without removing old ones
2. **Deprecation warnings** - Old APIs are deprecated before removal
3. **Migration guides** - Clear upgrade paths for breaking changes
4. **Semantic versioning** - Version numbers reflect API compatibility

## Language Support Stability

### Bundled Languages

**STABLE** - These languages have stable grammar and query support:

- **JSON** - Core data interchange format
- **Zig** - Primary development language
- **TypeScript/TSX** - Web development support
- **Rust** - Systems programming support
- **Ghostlang** - Experimental language integration

### Grammar Updates

Grammar updates follow these rules:

1. **Bug fixes** - Parser improvements allowed in PATCH releases
2. **New language features** - Grammar extensions allowed in MINOR releases
3. **Breaking grammar changes** - Require MAJOR release or new language variant

### Query Compatibility

Tree-sitter queries are versioned with their grammars:

- Query improvements and additions allowed in MINOR releases
- Breaking query changes require grammar version updates
- Backward compatibility maintained through query migration

## RFC Process for Breaking Changes

Major API changes require an RFC (Request for Comments) process:

### 1. RFC Proposal

Create RFC document in `docs/rfcs/` with:
- Problem statement and motivation
- Detailed design proposal
- Migration strategy
- Alternatives considered
- Timeline and implementation plan

### 2. Community Review

- Post RFC for community feedback
- Address concerns and iterate on design
- Seek consensus from maintainers and major users

### 3. Implementation

- Implement behind feature flags when possible
- Provide migration tools and documentation
- Update examples and tests

### 4. Release

- Include in appropriate version (MAJOR for breaking changes)
- Provide clear migration documentation
- Support old APIs with deprecation warnings when feasible

## Current RFC Topics

### Open RFCs

None currently open.

### Potential Future RFCs

- **Streaming Parser API** - Large file parsing support
- **Plugin System** - External language and feature plugins
- **Async Parsing** - Non-blocking parser operations
- **Custom Highlight Themes** - User-defined highlighting rules

## Version History

### v0.1.0 (RC1) - Current

- Initial stable API surface definition
- Core parsing and editor integration APIs
- Semantic analysis and LSP helper APIs (beta)
- Five bundled languages with stable support

### Future Versions

**v0.2.0** - Planned features:
- Streaming parser support
- Enhanced semantic analysis
- Additional language support
- Performance optimizations

**v1.0.0** - Stability milestone:
- All APIs promoted to stable
- Long-term compatibility guarantees
- Production-ready for all use cases

## API Usage Examples

### Basic Parsing

```zig
const grove = @import("grove");

var parser = try grove.Parser.init(allocator);
defer parser.deinit();

const language = try grove.Languages.json.get();
try parser.setLanguage(language);

const tree = try parser.parseUtf8(null, source);
defer tree.deinit();

const root = tree.rootNode().?;
std.debug.print("Parsed tree with {} children\n", .{root.childCount()});
```

### Editor Integration

```zig
var services = try grove.EditorServices.init(allocator);
defer services.deinit();

const language = try grove.Languages.typescript.get();
const utilities = try services.getUtilities(language);

const symbols = try utilities.documentSymbols(root, source);
const ranges = try utilities.foldingRanges(root, source);
```

### LSP Server

```zig
const factory = grove.LSP.LanguageServerFactory.init(allocator);
var server = try factory.createTypeScriptServer();
defer server.deinit();

const symbols = try server.documentSymbols(source);
const diagnostics = try server.diagnostics(source);
```

This API stability document ensures Grove provides reliable, predictable interfaces for its users while allowing for continued evolution and improvement.