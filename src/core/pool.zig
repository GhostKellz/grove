const std = @import("std");
const Parser = @import("parser.zig").Parser;
const ParserError = @import("parser.zig").ParserError;
const Language = @import("../language.zig").Language;

pub const ParserPool = struct {
    allocator: std.mem.Allocator,
    language: Language,
    capacity: usize,
    store: std.ArrayList(Parser),

    pub fn init(allocator: std.mem.Allocator, language: Language, capacity: usize) ParserError!ParserPool {
        return .{
            .allocator = allocator,
            .language = language,
            .capacity = capacity,
            .store = std.ArrayList(Parser).init(allocator),
        };
    }

    pub fn deinit(self: *ParserPool) void {
        for (self.store.items) |*parser| {
            parser.deinit();
        }
        self.store.deinit();
    }

    pub fn acquire(self: *ParserPool) ParserError!Lease {
        if (self.store.popOrNull()) |parser| {
            return Lease{ .pool = self, .parser = parser, .released = false };
        }

        var parser = try Parser.init(self.allocator);
        errdefer parser.deinit();
        try parser.setLanguage(self.language);
        return Lease{ .pool = self, .parser = parser, .released = false };
    }

    fn recycle(self: *ParserPool, parser: Parser) void {
        var value = parser;
        value.reset();
        if (value.setLanguage(self.language)) |_| {
            if (self.store.items.len >= self.capacity) {
                value.deinit();
                return;
            }
            self.store.append(value) catch {
                value.deinit();
            };
        } else |err| {
            _ = err;
            value.deinit();
        }
    }
};

pub const Lease = struct {
    pool: *ParserPool,
    parser: Parser,
    released: bool,

    pub fn parserRef(self: *Lease) *Parser {
        return &self.parser;
    }

    pub fn release(self: *Lease) void {
        if (self.released) return;
        self.pool.recycle(self.parser);
        self.released = true;
    }

    pub fn deinit(self: *Lease) void {
        self.release();
    }
};

const testing = std.testing;
const Languages = @import("../languages.zig").Bundled;

test "parser pool reuses parser instances" {
    var pool = try ParserPool.init(testing.allocator, try Languages.json.get(), 2);
    defer pool.deinit();

    {
        var lease = try pool.acquire();
        defer lease.deinit();
        const parser = lease.parserRef();
        const source = "{\"hello\": 1}";
        var tree = try parser.parseUtf8(null, source);
        defer tree.deinit();
    }

    try testing.expectEqual(@as(usize, 1), pool.store.items.len);

    var lease_a = try pool.acquire();
    try testing.expectEqual(@as(usize, 0), pool.store.items.len);
    lease_a.release();
    try testing.expectEqual(@as(usize, 1), pool.store.items.len);
    lease_a.deinit();
}
