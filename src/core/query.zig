const std = @import("std");
const c = @import("../c/tree_sitter.zig").c;
const Language = @import("../language.zig").Language;
const node_mod = @import("node.zig");
const Node = node_mod.Node;
const Point = node_mod.Point;

pub const QueryError = error{
    Syntax,
    NodeType,
    Field,
    Capture,
    Structure,
    LanguageMismatch,
    AllocationFailed,
};

pub const CursorError = error{CursorUnavailable};

pub const Query = struct {
    handle: ?*c.TSQuery,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, language: Language, source: []const u8) QueryError!Query {
        var error_offset: u32 = undefined;
        var error_type: c.TSQueryError = undefined;
        const length = std.math.cast(u32, source.len) orelse return QueryError.AllocationFailed;
        const ptr = c.ts_query_new(
            language.raw(),
            source.ptr,
            length,
            &error_offset,
            &error_type,
        );
        if (ptr == null) {
            return switch (error_type) {
                c.TSQueryErrorSyntax => QueryError.Syntax,
                c.TSQueryErrorNodeType => QueryError.NodeType,
                c.TSQueryErrorField => QueryError.Field,
                c.TSQueryErrorCapture => QueryError.Capture,
                c.TSQueryErrorStructure => QueryError.Structure,
                c.TSQueryErrorLanguage => QueryError.LanguageMismatch,
                else => QueryError.AllocationFailed,
            };
        }
        return .{
            .handle = ptr,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Query) void {
        if (self.handle) |query| {
            c.ts_query_delete(query);
            self.handle = null;
        }
    }

    fn must(self: *const Query) *c.TSQuery {
        return self.handle orelse @panic("invalid query handle");
    }

    pub fn captureCount(self: *const Query) u32 {
        return c.ts_query_capture_count(self.must());
    }

    pub fn patternCount(self: *const Query) u32 {
        return c.ts_query_pattern_count(self.must());
    }

    pub fn captureName(self: *const Query, id: u32) []const u8 {
        var length: u32 = undefined;
        const raw_ptr = c.ts_query_capture_name_for_id(self.must(), id, &length);
        if (raw_ptr == null or length == 0) return &[_]u8{};
        const slice_ptr: [*]const u8 = @ptrCast(raw_ptr);
        return slice_ptr[0..length];
    }

    pub fn textPredicate(self: *const Query, pattern_index: u32) []const u8 {
        var length: u32 = undefined;
        const raw_ptr = c.ts_query_string_value_for_id(self.must(), pattern_index, &length);
        if (raw_ptr == null or length == 0) return &[_]u8{};
        const slice_ptr: [*]const u8 = @ptrCast(raw_ptr);
        return slice_ptr[0..length];
    }
};

pub const Capture = struct {
    id: u32,
    name: []const u8,
    node: Node,
};

pub const CaptureResult = struct {
    match_id: u32,
    pattern_index: u32,
    capture_index: u32,
    capture_count: u32,
    capture: Capture,
};

pub const QueryCursor = struct {
    handle: ?*c.TSQueryCursor,

    pub fn init() CursorError!QueryCursor {
        const ptr = c.ts_query_cursor_new();
        if (ptr == null) return CursorError.CursorUnavailable;
        return .{ .handle = ptr };
    }

    pub fn deinit(self: *QueryCursor) void {
        if (self.handle) |cursor| {
            c.ts_query_cursor_delete(cursor);
            self.handle = null;
        }
    }

    fn must(self: *const QueryCursor) *c.TSQueryCursor {
        return self.handle orelse @panic("invalid query cursor handle");
    }

    pub fn reset(self: *QueryCursor) void {
        c.ts_query_cursor_reset(self.must());
    }

    pub fn exec(self: *QueryCursor, query: *const Query, node: Node) void {
        c.ts_query_cursor_exec(self.must(), query.must(), node.raw());
    }

    pub fn setByteRange(self: *QueryCursor, start_byte: u32, end_byte: u32) void {
        c.ts_query_cursor_set_byte_range(self.must(), start_byte, end_byte);
    }

    pub fn setPointRange(self: *QueryCursor, start: Point, end: Point) void {
        c.ts_query_cursor_set_point_range(self.must(), toTSPoint(start), toTSPoint(end));
    }

    pub fn nextCapture(self: *QueryCursor, query: *const Query) ?CaptureResult {
        var match_obj: c.TSQueryMatch = undefined;
        var capture_index: u32 = undefined;
        const has_next = c.ts_query_cursor_next_capture(self.must(), &match_obj, &capture_index);
        if (!has_next) return null;

        const captures_ptr: [*]const c.TSQueryCapture = @ptrCast(match_obj.captures);
        const capture = captures_ptr[capture_index];
        const name = query.captureName(capture.index);
        return .{
            .match_id = match_obj.id,
            .pattern_index = match_obj.pattern_index,
            .capture_index = capture_index,
            .capture_count = @as(u32, match_obj.capture_count),
            .capture = .{
                .id = capture.index,
                .name = name,
                .node = Node.fromRaw(capture.node),
            },
        };
    }
};

fn toTSPoint(point: Point) c.TSPoint {
    return .{ .row = point.row, .column = point.column };
}

/// Validation result for query syntax
pub const ValidationResult = struct {
    valid: bool,
    error_offset: u32,
    error_type: QueryError,
    error_message: []const u8,

    pub fn ok() ValidationResult {
        return .{
            .valid = true,
            .error_offset = 0,
            .error_type = QueryError.AllocationFailed, // placeholder, won't be used
            .error_message = "",
        };
    }

    pub fn err(offset: u32, err_type: QueryError, message: []const u8) ValidationResult {
        return .{
            .valid = false,
            .error_offset = offset,
            .error_type = err_type,
            .error_message = message,
        };
    }
};

/// Validate a query string without creating a Query object
pub fn validateQuery(language: Language, source: []const u8) ValidationResult {
    var error_offset: u32 = 0;
    var error_type: c.TSQueryError = c.TSQueryErrorNone;
    const length = std.math.cast(u32, source.len) orelse {
        return ValidationResult.err(0, QueryError.AllocationFailed, "Query too large");
    };

    const ptr = c.ts_query_new(
        language.raw(),
        source.ptr,
        length,
        &error_offset,
        &error_type,
    );

    if (ptr == null) {
        const err = switch (error_type) {
            c.TSQueryErrorSyntax => QueryError.Syntax,
            c.TSQueryErrorNodeType => QueryError.NodeType,
            c.TSQueryErrorField => QueryError.Field,
            c.TSQueryErrorCapture => QueryError.Capture,
            c.TSQueryErrorStructure => QueryError.Structure,
            c.TSQueryErrorLanguage => QueryError.LanguageMismatch,
            else => QueryError.AllocationFailed,
        };
        const msg = switch (err) {
            QueryError.Syntax => "Syntax error in query",
            QueryError.NodeType => "Invalid node type",
            QueryError.Field => "Invalid field name",
            QueryError.Capture => "Invalid capture name",
            QueryError.Structure => "Invalid query structure",
            QueryError.LanguageMismatch => "Query language mismatch",
            else => "Unknown error",
        };
        return ValidationResult.err(error_offset, err, msg);
    }

    c.ts_query_delete(ptr);
    return ValidationResult.ok();
}

/// Validate a query file (.scm) without creating a Query object
pub fn validateQueryFile(allocator: std.mem.Allocator, language: Language, path: []const u8) !ValidationResult {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024); // 1MB max
    defer allocator.free(source);

    return validateQuery(language, source);
}

const testing = std.testing;
const Languages = @import("../languages.zig").Bundled;
const Parser = @import("parser.zig").Parser;
const Tree = @import("tree.zig").Tree;

fn parseJson(allocator: std.mem.Allocator, source: []const u8) !Tree {
    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const lang = try Languages.json.get();
    try parser.setLanguage(lang);

    return try parser.parseUtf8(null, source);
}

fn createQuery(allocator: std.mem.Allocator, source: []const u8) !Query {
    const lang = try Languages.json.get();
    return try Query.init(allocator, lang, source);
}

fn consumeHighlights(query: *const Query, tree: Tree) !usize {
    var cursor = try QueryCursor.init();
    defer cursor.deinit();
    cursor.exec(query, tree.rootNode() orelse return error.MissingRoot);

    var count: usize = 0;
    while (cursor.nextCapture(query)) |_| {
        count += 1;
    }
    return count;
}

test "query compiles and iterates captures" {
    const allocator = testing.allocator;
    var tree = try parseJson(allocator, "{\"hello\": true}");
    defer tree.deinit();

    var query = try createQuery(allocator, "(pair key: (string) @key value: (_) @value)");
    defer query.deinit();

    const count = try consumeHighlights(&query, tree);
    try testing.expect(count >= 2);
}
