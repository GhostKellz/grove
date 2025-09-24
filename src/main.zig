const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var parser = try grove.Parser.init(gpa.allocator());
    defer parser.deinit();

    std.debug.print(
        "Grove runtime initialized. Load a Tree-sitter language and call parseUtf8() to build syntax trees.\n",
        .{},
    );
}

test "simple test" {
    const gpa = std.testing.allocator;
    var parser = try grove.Parser.init(gpa);
    defer parser.deinit();
    try std.testing.expectError(grove.ParserError.LanguageNotSet, parser.parseUtf8(null, "const value = 1;"));
}
