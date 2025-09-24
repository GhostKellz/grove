const std = @import("std");
const c = @import("../c/tree_sitter.zig").c;
const Tree = @import("tree.zig").Tree;
const Language = @import("../language.zig").Language;
const Languages = @import("../languages.zig").Bundled;

pub const ParserError = error{
    ParserUnavailable,
    LanguageNotSet,
    LanguageUnsupported,
    InputTooLarge,
    ParseFailed,
};

pub const ParseReport = struct {
    tree: Tree,
    duration_ns: u64,
    bytes: usize,
};

const ChunkContext = struct {
    chunks: []const []const u8,
    offsets: []const u32,
};

fn chunkRead(
    payload: ?*anyopaque,
    byte_index: u32,
    position: c.TSPoint,
    bytes_read: *u32,
) callconv(.c) [*c]const u8 {
    _ = position;
    if (payload == null) {
        bytes_read.* = 0;
        return null;
    }

    const ctx = @as(*ChunkContext, @ptrCast(payload.?));
    const idx = findChunkIndex(ctx, byte_index) orelse {
        bytes_read.* = 0;
        return null;
    };

    const chunk = ctx.chunks[idx];
    const start = byte_index - ctx.offsets[idx];
    if (start >= chunk.len) {
        bytes_read.* = 0;
        return null;
    }

    const remaining = chunk.len - start;
    const remaining_u32 = std.math.cast(u32, remaining) orelse {
        bytes_read.* = 0;
        return null;
    };
    bytes_read.* = remaining_u32;
    return @ptrCast(chunk.ptr + start);
}

fn findChunkIndex(ctx: *const ChunkContext, byte_index: u32) ?usize {
    var i: usize = 0;
    while (i < ctx.chunks.len) : (i += 1) {
        const start = ctx.offsets[i];
        const chunk_len = std.math.cast(u32, ctx.chunks[i].len) orelse return null;
        const end = start + chunk_len;
        if (byte_index < end) return i;
    }
    return null;
}

pub const Parser = struct {
    handle: ?*c.TSParser,
    language_set: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ParserError!Parser {
        const handle = c.ts_parser_new();
        if (handle == null) return ParserError.ParserUnavailable;
        return .{
            .handle = handle,
            .language_set = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Parser) void {
        if (self.handle) |parser| {
            c.ts_parser_delete(parser);
            self.handle = null;
        }
        self.language_set = false;
    }

    pub fn setLanguage(self: *Parser, language: Language) ParserError!void {
        if (self.handle == null) return ParserError.ParserUnavailable;
        const ok = c.ts_parser_set_language(self.handle.?, language.raw());
        if (!ok) return ParserError.LanguageUnsupported;
        self.language_set = true;
    }

    pub fn parseUtf8(self: *Parser, previous: ?*const Tree, source: []const u8) ParserError!Tree {
        if (self.handle == null) return ParserError.ParserUnavailable;
        if (!self.language_set) return ParserError.LanguageNotSet;
        const encoded_len: u32 = std.math.cast(u32, source.len) orelse return ParserError.InputTooLarge;
        const old_tree_ptr: ?*c.TSTree = if (previous) |tree| tree.raw() else null;
        const tree_ptr = c.ts_parser_parse_string_encoding(self.handle.?, old_tree_ptr, source.ptr, encoded_len, c.TSInputEncodingUTF8);
        if (tree_ptr == null) return ParserError.ParseFailed;
        return Tree.fromRaw(tree_ptr.?);
    }

    pub fn parseChunks(self: *Parser, previous: ?*const Tree, chunks: []const []const u8) ParserError!Tree {
        if (self.handle == null) return ParserError.ParserUnavailable;
        if (!self.language_set) return ParserError.LanguageNotSet;

        if (chunks.len == 0) {
            const empty: []const u8 = &[_]u8{};
            return self.parseUtf8(previous, empty);
        }

        var offsets = try self.allocator.alloc(u32, chunks.len);
        defer self.allocator.free(offsets);

        var total: u64 = 0;
        for (chunks, 0..) |chunk, idx| {
            const len_u32 = std.math.cast(u32, chunk.len) orelse return ParserError.InputTooLarge;
            const start_u32 = std.math.cast(u32, total) orelse return ParserError.InputTooLarge;
            offsets[idx] = start_u32;
            total += len_u32;
        }
        if (total > std.math.maxInt(u32)) return ParserError.InputTooLarge;

        var context = ChunkContext{ .chunks = chunks, .offsets = offsets };
        const input = c.TSInput{
            .payload = @ptrCast(&context),
            .read = chunkRead,
            .encoding = c.TSInputEncodingUTF8,
        };

        const old_tree_ptr: ?*c.TSTree = if (previous) |tree| tree.raw() else null;
        const tree_ptr = c.ts_parser_parse(self.handle.?, old_tree_ptr, input);
        if (tree_ptr == null) return ParserError.ParseFailed;
        return Tree.fromRaw(tree_ptr.?);
    }

    pub fn parseUtf8Timed(self: *Parser, previous: ?*const Tree, source: []const u8) ParserError!ParseReport {
        const start = std.time.nanoTimestamp();
        const tree = try self.parseUtf8(previous, source);
        const end = std.time.nanoTimestamp();
        const elapsed = if (end > start) @as(u64, @intCast(end - start)) else 0;
        return .{
            .tree = tree,
            .duration_ns = elapsed,
            .bytes = source.len,
        };
    }

    pub fn reset(self: *Parser) void {
        if (self.handle) |parser| {
            c.ts_parser_reset(parser);
        }
        self.language_set = false;
    }
};

const testing = std.testing;

test "parser init and teardown" {
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();
    try testing.expect(parser.handle != null);
}

test "parse without language returns error" {
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();
    try testing.expectError(ParserError.LanguageNotSet, parser.parseUtf8(null, "const x = 42;"));
}

test "parse basic json document" {
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    const language = try Languages.json.get();
    try parser.setLanguage(language);

    const source = "{\"hello\": [true, false, null]}";
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return testing.fail("missing root node");
    try testing.expectEqualStrings("document", root.kind());
    try testing.expectEqual(@as(u32, 1), root.childCount());

    const value_node = root.child(0) orelse return testing.fail("missing document value");
    try testing.expectEqualStrings("object", value_node.kind());
    try testing.expect(value_node.childCount() >= 1);
}

test "parse basic zig translation unit" {
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    const language = try Languages.zig.get();
    try parser.setLanguage(language);

    const source =
        \\const std = @import("std");
        \\pub fn main() void { std.debug.print("hi\\n", .{}); }
    ;
    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return testing.fail("missing root node");
    try testing.expectEqualStrings("source_file", root.kind());
    try testing.expect(root.childCount() >= 1);
}

test "parse ghostlang plugin script" {
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    const language = try Languages.ghostlang.get();
    try parser.setLanguage(language);

    const source =
        \\function plugin() {
        \\  var cursor = getCursorPosition();
        \\  if (cursor != null) {
        \\    notify("ghost ready");
        \\  }
        \\}
        \\var lines = createArray();
        \\for (var i = 0; i < 3; i += 1) {
        \\  arrayPush(lines, i);
        \\}
        \\return lines;
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return testing.fail("missing root node");
    try testing.expect(root.childCount() >= 2);
    try testing.expectEqualStrings("source_file", root.kind());
}

test "parse chunked input matches contiguous parse" {
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    const language = try Languages.json.get();
    try parser.setLanguage(language);

    const chunks = [_][]const u8{
        "{",
        "\"hello\": true",
        ",",
        "\"items\": [1,2,3]",
        "}",
    };

    var chunk_tree = try parser.parseChunks(null, chunks);
    defer chunk_tree.deinit();

    const root = chunk_tree.rootNode() orelse return testing.fail("missing root node");
    try testing.expectEqualStrings("document", root.kind());
    try testing.expect(root.childCount() >= 1);
}

test "parseUtf8Timed includes metrics" {
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    const language = try Languages.json.get();
    try parser.setLanguage(language);

    const source = "{\"hello\": [1,2,3,4,5]}";
    const report = try parser.parseUtf8Timed(null, source);
    defer report.tree.deinit();

    try testing.expect(report.duration_ns >= 0);
    try testing.expectEqual(source.len, report.bytes);
}
