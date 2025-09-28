const std = @import("std");
const Highlight = @import("editor/highlight.zig");
const Features = @import("editor/features.zig");
const Ghostlang = @import("editor/ghostlang.zig");
const AllLanguages = @import("editor/all_languages.zig");
const QueryRegistryModule = @import("editor/query_registry.zig");
const GrimBridgeModule = @import("editor/grim_bridge.zig");
const Query = @import("core/query.zig").Query;
const Node = @import("core/node.zig").Node;
const Language = @import("language.zig").Language;
const Languages = @import("languages.zig").Bundled;

pub const HighlightRule = Highlight.HighlightRule;
pub const HighlightSpan = Highlight.HighlightSpan;
pub const HighlightEngine = Highlight.HighlightEngine;
pub const HighlightError = Highlight.HighlightError;
pub const HighlightEngineInitError = Highlight.HighlightEngineInitError;

pub const Range = Features.Range;
pub const FoldingRange = Features.FoldingRange;
pub const FoldingRangeKind = Features.FoldingRangeKind;
pub const FoldingOptions = Features.FoldingOptions;
pub const FoldingQueryError = Features.FoldingQueryError;
pub const DocumentSymbol = Features.DocumentSymbol;
pub const SymbolRule = Features.SymbolRule;
pub const SymbolKind = Features.SymbolKind;
pub const SymbolError = Features.SymbolError;
pub const Definition = Features.Definition;
pub const HoverInfo = Features.HoverInfo;
pub const GhostlangUtilities = Ghostlang.GhostlangUtilities;
pub const EditorServices = AllLanguages.EditorServices;
pub const LanguageUtilities = AllLanguages.LanguageUtilities;
pub const QueryRegistry = QueryRegistryModule.QueryRegistry;
pub const QueryPreset = QueryRegistryModule.QueryPreset;
pub const QueryType = QueryRegistryModule.QueryType;
pub const ThemePreset = QueryRegistryModule.ThemePreset;
pub const ThemeMapping = QueryRegistryModule.ThemeMapping;
pub const GrimBridge = GrimBridgeModule.GrimBridge;

pub fn getHighlights(
    allocator: std.mem.Allocator,
    query: *Query,
    root: Node,
    rules: []const HighlightRule,
) HighlightError![]HighlightSpan {
    return Highlight.collectHighlights(allocator, query, root, rules);
}

pub fn newHighlightEngine(
    allocator: std.mem.Allocator,
    language: Language,
    query_source: []const u8,
    rules: []const HighlightRule,
) HighlightEngineInitError!HighlightEngine {
    return Highlight.HighlightEngine.init(allocator, language, query_source, rules);
}

pub fn getFoldingRanges(
    allocator: std.mem.Allocator,
    root: Node,
    options: FoldingOptions,
) std.mem.Allocator.Error![]FoldingRange {
    return Features.collectFoldingRanges(allocator, root, options);
}

pub fn getFoldingRangesFromQuery(
    allocator: std.mem.Allocator,
    query: *Query,
    root: Node,
    capture_filter: []const []const u8,
    options: FoldingOptions,
) FoldingQueryError![]FoldingRange {
    return Features.collectFoldingRangesFromQuery(allocator, query, root, capture_filter, options);
}

pub fn getDocumentSymbols(
    allocator: std.mem.Allocator,
    query: *Query,
    root: Node,
    source: []const u8,
    rules: []const SymbolRule,
) SymbolError![]DocumentSymbol {
    return Features.collectDocumentSymbols(allocator, query, root, source, rules);
}

pub fn freeDocumentSymbols(allocator: std.mem.Allocator, symbols: []DocumentSymbol) void {
    Features.freeDocumentSymbols(allocator, symbols);
}

pub fn findDefinition(symbols: []const DocumentSymbol, name: []const u8) ?Definition {
    return Features.findDefinition(symbols, name);
}

pub fn hover(symbols: []const DocumentSymbol, name: []const u8) ?HoverInfo {
    return Features.hover(symbols, name);
}
