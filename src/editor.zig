const std = @import("std");
const Highlight = @import("editor/highlight.zig");
const Features = @import("editor/features.zig");
const Query = @import("core/query.zig").Query;
const Node = @import("core/node.zig").Node;
const Language = @import("language.zig").Language;

pub const HighlightRule = Highlight.HighlightRule;
pub const HighlightSpan = Highlight.HighlightSpan;
pub const HighlightEngine = Highlight.HighlightEngine;
pub const HighlightError = Highlight.HighlightError;
pub const HighlightEngineInitError = Highlight.HighlightEngineInitError;

pub const Range = Features.Range;
pub const FoldingRange = Features.FoldingRange;
pub const FoldingRangeKind = Features.FoldingRangeKind;
pub const FoldingOptions = Features.FoldingOptions;
pub const DocumentSymbol = Features.DocumentSymbol;
pub const SymbolRule = Features.SymbolRule;
pub const SymbolKind = Features.SymbolKind;
pub const SymbolError = Features.SymbolError;
pub const Definition = Features.Definition;
pub const HoverInfo = Features.HoverInfo;

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
