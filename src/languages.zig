const c = @import("c/tree_sitter.zig").c;
const Language = @import("language.zig").Language;
const LanguageError = @import("language.zig").LanguageError;

extern fn tree_sitter_json() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_zig() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_rust() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_ghostlang() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_typescript() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_tsx() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_bash() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_javascript() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_python() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_markdown() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_cmake() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_toml() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_yaml() callconv(.c) *const c.TSLanguage;
extern fn tree_sitter_c() callconv(.c) *const c.TSLanguage;

pub const Bundled = enum {
    json,
    zig,
    rust,
    ghostlang,
    typescript,
    tsx,
    bash,
    javascript,
    python,
    markdown,
    cmake,
    toml,
    yaml,
    c,

    pub fn raw(self: Bundled) *const c.TSLanguage {
        return switch (self) {
            .json => tree_sitter_json(),
            .zig => tree_sitter_zig(),
            .rust => tree_sitter_rust(),
            .ghostlang => tree_sitter_ghostlang(),
            .typescript => tree_sitter_typescript(),
            .tsx => tree_sitter_tsx(),
            .bash => tree_sitter_bash(),
            .javascript => tree_sitter_javascript(),
            .python => tree_sitter_python(),
            .markdown => tree_sitter_markdown(),
            .cmake => tree_sitter_cmake(),
            .toml => tree_sitter_toml(),
            .yaml => tree_sitter_yaml(),
            .c => tree_sitter_c(),
        };
    }

    pub fn get(self: Bundled) LanguageError!Language {
        const raw_ptr: *const c.TSLanguage = self.raw();
        const optional_ptr: ?*const c.TSLanguage = raw_ptr;
        return Language.fromRaw(optional_ptr);
    }
};

const std = @import("std");

pub const DynamicLoadError = LanguageError || std.DynLib.OpenError || error{SymbolNotFound};
pub const Registry = struct {
    allocator: std.mem.Allocator,
    map: std.StringArrayHashMap(Language),

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{
            .allocator = allocator,
            .map = std.StringArrayHashMap(Language).init(allocator),
        };
    }

    pub fn deinit(self: *Registry) void {
        self.map.deinit();
    }

    pub fn register(self: *Registry, name: []const u8, language: Language) !void {
        try self.map.put(name, language);
    }

    pub fn get(self: *const Registry, name: []const u8) ?Language {
        return self.map.get(name);
    }

    pub fn ensureBundled(self: *Registry) !void {
        try self.register("json", try Bundled.json.get());
        try self.register("zig", try Bundled.zig.get());
        try self.register("rust", try Bundled.rust.get());
        try self.register("ghostlang", try Bundled.ghostlang.get());
        try self.register("typescript", try Bundled.typescript.get());
        try self.register("tsx", try Bundled.tsx.get());
        try self.register("bash", try Bundled.bash.get());
        try self.register("javascript", try Bundled.javascript.get());
        try self.register("python", try Bundled.python.get());
        try self.register("markdown", try Bundled.markdown.get());
        try self.register("cmake", try Bundled.cmake.get());
        try self.register("toml", try Bundled.toml.get());
        try self.register("yaml", try Bundled.yaml.get());
        try self.register("c", try Bundled.c.get());
    }

    pub fn registerSharedLibrary(
        self: *Registry,
        name: []const u8,
        lib_path: []const u8,
        symbol: []const u8,
    ) DynamicLoadError!void {
        var lib = try std.DynLib.open(lib_path);
        defer lib.close();

        const Fn = *const fn () callconv(.c) *const c.TSLanguage;
        const func = lib.lookup(Fn, symbol) catch return DynamicLoadError.SymbolNotFound;
        const language = try Language.fromRaw(func());
        try self.register(name, language);
    }
};

test "bundled JSON language returns non-null pointer" {
    const lang = try Bundled.json.get();
    try std.testing.expect(lang.raw() != null);
}

test "bundled Zig language returns non-null pointer" {
    const lang = try Bundled.zig.get();
    try std.testing.expect(lang.raw() != null);
}

test "bundled Rust language returns non-null pointer" {
    const lang = try Bundled.rust.get();
    try std.testing.expect(lang.raw() != null);
}

test "bundled Ghostlang language returns non-null pointer" {
    const lang = try Bundled.ghostlang.get();
    try std.testing.expect(lang.raw() != null);
}

test "bundled TypeScript language returns non-null pointer" {
    const lang = try Bundled.typescript.get();
    try std.testing.expect(lang.raw() != null);
}

test "bundled TSX language returns non-null pointer" {
    const lang = try Bundled.tsx.get();
    try std.testing.expect(lang.raw() != null);
}

test "bundled Bash language returns non-null pointer" {
    const lang = try Bundled.bash.get();
    try std.testing.expect(lang.raw() != null);
}

test "bundled JavaScript language returns non-null pointer" {
    const lang = try Bundled.javascript.get();
    try std.testing.expect(lang.raw() != null);
}

test "bundled Python language returns non-null pointer" {
    const lang = try Bundled.python.get();
    try std.testing.expect(lang.raw() != null);
}

test "bundled Markdown language returns non-null pointer" {
    const lang = try Bundled.markdown.get();
    try std.testing.expect(lang.raw() != null);
}

test "bundled CMake language returns non-null pointer" {
    const lang = try Bundled.cmake.get();
    try std.testing.expect(lang.raw() != null);
}

test "bundled TOML language returns non-null pointer" {
    const lang = try Bundled.toml.get();
    try std.testing.expect(lang.raw() != null);
}

test "bundled YAML language returns non-null pointer" {
    const lang = try Bundled.yaml.get();
    try std.testing.expect(lang.raw() != null);
}

test "bundled C language returns non-null pointer" {
    const lang = try Bundled.c.get();
    try std.testing.expect(lang.raw() != null);
}

test "registry can register bundled languages" {
    var registry = Registry.init(std.testing.allocator);
    defer registry.deinit();

    try registry.ensureBundled();
    try std.testing.expect(registry.get("json") != null);
    try std.testing.expect(registry.get("zig") != null);
    try std.testing.expect(registry.get("rust") != null);
    try std.testing.expect(registry.get("ghostlang") != null);
    try std.testing.expect(registry.get("typescript") != null);
    try std.testing.expect(registry.get("tsx") != null);
    try std.testing.expect(registry.get("bash") != null);
    try std.testing.expect(registry.get("javascript") != null);
    try std.testing.expect(registry.get("python") != null);
    try std.testing.expect(registry.get("markdown") != null);
    try std.testing.expect(registry.get("cmake") != null);
    try std.testing.expect(registry.get("toml") != null);
    try std.testing.expect(registry.get("yaml") != null);
    try std.testing.expect(registry.get("c") != null);
}
