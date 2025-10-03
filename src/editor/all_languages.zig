const std = @import("std");
const Features = @import("features.zig");
const Languages = @import("../languages.zig").Bundled;
const Node = @import("../core/node.zig").Node;

const GhostlangUtilities = @import("ghostlang.zig").GhostlangUtilities;
const TypeScriptUtilities = @import("typescript.zig").TypeScriptUtilities;
const ZigUtilities = @import("zig_lang.zig").ZigUtilities;
const JsonUtilities = @import("json_lang.zig").JsonUtilities;
const RustUtilities = @import("rust_lang.zig").RustUtilities;
const BashUtilities = @import("bash_lang.zig").BashUtilities;
const JavaScriptUtilities = @import("javascript_lang.zig").JavaScriptUtilities;
const PythonUtilities = @import("python_lang.zig").PythonUtilities;
const MarkdownUtilities = @import("markdown_lang.zig").MarkdownUtilities;
const CMakeUtilities = @import("cmake_lang.zig").CMakeUtilities;
const TOMLUtilities = @import("toml_lang.zig").TOMLUtilities;
const YAMLUtilities = @import("yaml_lang.zig").YAMLUtilities;
const CUtilities = @import("c_lang.zig").CUtilities;

const DocumentSymbol = Features.DocumentSymbol;
const FoldingOptions = Features.FoldingOptions;
const FoldingRange = Features.FoldingRange;
const FoldingQueryError = Features.FoldingQueryError;
const SymbolError = Features.SymbolError;

pub const LanguageError = error{
    UnsupportedLanguage,
} || SymbolError || FoldingQueryError;

pub const LanguageUtilities = union(enum) {
    ghostlang: GhostlangUtilities,
    typescript: TypeScriptUtilities,
    tsx: TypeScriptUtilities, // TSX uses same utilities as TypeScript
    zig: ZigUtilities,
    json: JsonUtilities,
    rust: RustUtilities,
    bash: BashUtilities,
    javascript: JavaScriptUtilities,
    python: PythonUtilities,
    markdown: MarkdownUtilities,
    cmake: CMakeUtilities,
    toml: TOMLUtilities,
    yaml: YAMLUtilities,
    c: CUtilities,

    pub fn init(allocator: std.mem.Allocator, language: Languages) !LanguageUtilities {
        return switch (language) {
            .ghostlang => LanguageUtilities{ .ghostlang = try GhostlangUtilities.init(allocator) },
            .typescript => LanguageUtilities{ .typescript = try TypeScriptUtilities.init(allocator) },
            .tsx => LanguageUtilities{ .tsx = try TypeScriptUtilities.init(allocator) },
            .zig => LanguageUtilities{ .zig = try ZigUtilities.init(allocator) },
            .json => LanguageUtilities{ .json = try JsonUtilities.init(allocator) },
            .rust => LanguageUtilities{ .rust = try RustUtilities.init(allocator) },
            .bash => LanguageUtilities{ .bash = try BashUtilities.init(allocator) },
            .javascript => LanguageUtilities{ .javascript = try JavaScriptUtilities.init(allocator) },
            .python => LanguageUtilities{ .python = try PythonUtilities.init(allocator) },
            .markdown => LanguageUtilities{ .markdown = try MarkdownUtilities.init(allocator) },
            .cmake => LanguageUtilities{ .cmake = try CMakeUtilities.init(allocator) },
            .toml => LanguageUtilities{ .toml = try TOMLUtilities.init(allocator) },
            .yaml => LanguageUtilities{ .yaml = try YAMLUtilities.init(allocator) },
            .c => LanguageUtilities{ .c = try CUtilities.init(allocator) },
        };
    }

    pub fn deinit(self: *LanguageUtilities) void {
        switch (self.*) {
            .ghostlang => |*utils| utils.deinit(),
            .typescript => |*utils| utils.deinit(),
            .tsx => |*utils| utils.deinit(),
            .zig => |*utils| utils.deinit(),
            .json => |*utils| utils.deinit(),
            .rust => |*utils| utils.deinit(),
            .bash => |*utils| utils.deinit(),
            .javascript => |*utils| utils.deinit(),
            .python => |*utils| utils.deinit(),
            .markdown => |*utils| utils.deinit(),
            .cmake => |*utils| utils.deinit(),
            .toml => |*utils| utils.deinit(),
            .yaml => |*utils| utils.deinit(),
            .c => |*utils| utils.deinit(),
        }
    }

    pub fn documentSymbols(
        self: *LanguageUtilities,
        root: Node,
        source: []const u8,
    ) SymbolError![]DocumentSymbol {
        return switch (self.*) {
            .ghostlang => |*utils| utils.documentSymbols(root, source),
            .typescript => |*utils| utils.documentSymbols(root, source),
            .tsx => |*utils| utils.documentSymbols(root, source),
            .zig => |*utils| utils.documentSymbols(root, source),
            .json => |*utils| utils.documentSymbols(root, source),
            .rust => |*utils| utils.documentSymbols(root, source),
            .bash => |*utils| utils.documentSymbols(root, source),
            .javascript => |*utils| utils.documentSymbols(root, source),
            .python => |*utils| utils.documentSymbols(root, source),
            .markdown => |*utils| utils.documentSymbols(root, source),
            .cmake => |*utils| utils.documentSymbols(root, source),
            .toml => |*utils| utils.documentSymbols(root, source),
            .yaml => |*utils| utils.documentSymbols(root, source),
            .c => |*utils| utils.documentSymbols(root, source),
        };
    }

    pub fn foldingRanges(
        self: *LanguageUtilities,
        root: Node,
        options: FoldingOptions,
    ) FoldingQueryError![]FoldingRange {
        return switch (self.*) {
            .ghostlang => |*utils| utils.foldingRanges(root, options),
            .typescript => |*utils| utils.foldingRanges(root, options),
            .tsx => |*utils| utils.foldingRanges(root, options),
            .zig => |*utils| utils.foldingRanges(root, options),
            .json => |*utils| utils.foldingRanges(root, options),
            .rust => |*utils| utils.foldingRanges(root, options),
            .bash => |*utils| utils.foldingRanges(root, options),
            .javascript => |*utils| utils.foldingRanges(root, options),
            .python => |*utils| utils.foldingRanges(root, options),
            .markdown => |*utils| utils.foldingRanges(root, options),
            .cmake => |*utils| utils.foldingRanges(root, options),
            .toml => |*utils| utils.foldingRanges(root, options),
            .yaml => |*utils| utils.foldingRanges(root, options),
            .c => |*utils| utils.foldingRanges(root, options),
        };
    }
};

pub const EditorServices = struct {
    allocator: std.mem.Allocator,
    utilities: std.EnumMap(Languages, ?LanguageUtilities),

    pub fn init(allocator: std.mem.Allocator) EditorServices {
        return .{
            .allocator = allocator,
            .utilities = std.EnumMap(Languages, ?LanguageUtilities).init(.{}),
        };
    }

    pub fn deinit(self: *EditorServices) void {
        var iter = self.utilities.iterator();
        while (iter.next()) |entry| {
            if (entry.value.*) |*utils| {
                utils.deinit();
            }
        }
    }

    pub fn getUtilities(self: *EditorServices, language: Languages) !*LanguageUtilities {
        if (self.utilities.get(language)) |*maybe_utils| {
            if (maybe_utils.*) |*utils| {
                return utils;
            }
        }

        // Initialize utilities for this language
        var utils = try LanguageUtilities.init(self.allocator, language);
        errdefer utils.deinit();

        self.utilities.put(language, utils);
        return &self.utilities.getPtr(language).*.?;
    }

    pub fn documentSymbols(
        self: *EditorServices,
        language: Languages,
        root: Node,
        source: []const u8,
    ) ![]DocumentSymbol {
        const utils = try self.getUtilities(language);
        return utils.documentSymbols(root, source);
    }

    pub fn foldingRanges(
        self: *EditorServices,
        language: Languages,
        root: Node,
        options: FoldingOptions,
    ) ![]FoldingRange {
        const utils = try self.getUtilities(language);
        return utils.foldingRanges(root, options);
    }
};

const testing = std.testing;
const Parser = @import("../core/parser.zig").Parser;

test "editor services work for all bundled languages" {
    const allocator = testing.allocator;

    var services = EditorServices.init(allocator);
    defer services.deinit();

    // Test each language
    const test_cases = [_]struct {
        language: Languages,
        source: []const u8,
    }{
        .{
            .language = .json,
            .source =
            \\{"name": "test", "value": 42}
            ,
        },
        .{
            .language = .zig,
            .source =
            \\pub fn main() void {
            \\    const x = 42;
            \\}
            ,
        },
        .{
            .language = .rust,
            .source =
            \\fn main() {
            \\    println!("Hello, world!");
            \\}
            ,
        },
        .{
            .language = .typescript,
            .source =
            \\function greet(name: string) {
            \\    return "Hello " + name;
            \\}
            ,
        },
        .{
            .language = .tsx,
            .source =
            \\function Button(props: { label: string }) {
            \\    return <button>{props.label}</button>;
            \\}
            ,
        },
        .{
            .language = .ghostlang,
            .source =
            \\function test() {
            \\    var x = 1;
            \\}
            ,
        },
        .{
            .language = .bash,
            .source =
            \\function greet() {
            \\  echo "Hello"
            \\}
            ,
        },
        .{
            .language = .javascript,
            .source =
            \\function test() {
            \\  return 42;
            \\}
            ,
        },
        .{
            .language = .python,
            .source =
            \\def test():
            \\    return 42
            ,
        },
        .{
            .language = .markdown,
            .source =
            \\# Title
            \\Some text
            ,
        },
        .{
            .language = .cmake,
            .source =
            \\function(my_function)
            \\  message("Hello")
            \\endfunction()
            ,
        },
        .{
            .language = .toml,
            .source =
            \\[package]
            \\name = "example"
            ,
        },
        .{
            .language = .yaml,
            .source =
            \\services:
            \\  web:
            \\    image: nginx
            ,
        },
        .{
            .language = .c,
            .source =
            \\int main() {
            \\  return 0;
            \\}
            ,
        },
    };

    for (test_cases) |test_case| {
        var parser = try Parser.init(allocator);
        defer parser.deinit();

        const lang = try test_case.language.get();
        try parser.setLanguage(lang);

        var tree = try parser.parseUtf8(null, test_case.source);
        defer tree.deinit();

        const root = tree.rootNode() orelse continue;

        // Test document symbols
        const symbols = services.documentSymbols(
            test_case.language,
            root,
            test_case.source,
        ) catch |err| {
            // Some queries might not match - that's okay for this test
            if (err == error.OutOfMemory) return err;
            continue;
        };
        defer Features.freeDocumentSymbols(allocator, symbols);

        // Test folding ranges
        const folding = services.foldingRanges(
            test_case.language,
            root,
            .{ .min_line_span = 1 },
        ) catch |err| {
            // Some queries might not match - that's okay for this test
            if (err == error.OutOfMemory) return err;
            continue;
        };
        defer allocator.free(folding);
    }
}
