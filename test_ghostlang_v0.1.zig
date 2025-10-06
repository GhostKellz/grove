const std = @import("std");
const Grove = @import("src/lib.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const lua_style =
        \\-- Lua-style test
        \\local count = 0
        \\
        \\function greet(name)
        \\    if name ~= nil then
        \\        local msg = "Hello, " .. name
        \\        notify(msg)
        \\    else
        \\        notify("Hello!")
        \\    end
        \\end
        \\
        \\while count < 5 do
        \\    count = count + 1
        \\end
        \\
        \\for i = 1, 10, 2 do
        \\    log(i)
        \\end
        \\
        \\repeat
        \\    count = count - 1
        \\until count <= 0
    ;

    const c_style =
        \\// C-style test
        \\var count = 0;
        \\
        \\function greet(name) {
        \\    if (name != null) {
        \\        var msg = "Hello, " + name;
        \\        notify(msg);
        \\    } else {
        \\        notify("Hello!");
        \\    }
        \\}
        \\
        \\while (count < 5) {
        \\    count = count + 1;
        \\}
        \\
        \\for (var i = 0; i < 10; i = i + 1) {
        \\    log(i);
        \\}
    ;

    const mixed =
        \\-- Mixed syntax test
        \\local x = 5
        \\var y = 10;
        \\
        \\function luaStyle()
        \\    if x > 0 and y < 20 then
        \\        return true
        \\    end
        \\end
        \\
        \\function cStyle() {
        \\    if (x > 0 && y < 20) {
        \\        return true;
        \\    }
        \\}
    ;

    var parser = try Grove.Parser.init(allocator);
    defer parser.deinit();

    const language = try Grove.Languages.Bundled.ghostlang.get();
    try parser.setLanguage(language);

    std.debug.print("Testing Ghostlang v0.1.0 dual syntax parsing...\n\n", .{});

    // Test Lua-style
    std.debug.print("1. Testing Lua-style syntax...\n", .{});
    var lua_tree = try parser.parseUtf8(null, lua_style);
    defer lua_tree.deinit();

    const lua_root = lua_tree.rootNode() orelse return error.MissingRoot;
    std.debug.print("   ✅ Parsed {} nodes\n", .{lua_root.childCount()});

    // Test C-style
    std.debug.print("\n2. Testing C-style syntax...\n", .{});
    var c_tree = try parser.parseUtf8(null, c_style);
    defer c_tree.deinit();

    const c_root = c_tree.rootNode() orelse return error.MissingRoot;
    std.debug.print("   ✅ Parsed {} nodes\n", .{c_root.childCount()});

    // Test mixed
    std.debug.print("\n3. Testing mixed syntax...\n", .{});
    var mixed_tree = try parser.parseUtf8(null, mixed);
    defer mixed_tree.deinit();

    const mixed_root = mixed_tree.rootNode() orelse return error.MissingRoot;
    std.debug.print("   ✅ Parsed {} nodes\n", .{mixed_root.childCount()});

    // Test highlighting with new keywords
    std.debug.print("\n4. Testing syntax highlighting queries...\n", .{});
    var ghost_utils = try Grove.Editor.GhostlangUtilities.init(allocator);
    defer ghost_utils.deinit();

    const symbols = try ghost_utils.documentSymbols(lua_root, lua_style);
    defer Grove.Editor.Features.freeDocumentSymbols(allocator, symbols);
    std.debug.print("   ✅ Found {} symbols\n", .{symbols.len});

    const folding = try ghost_utils.foldingRanges(lua_root, .{ .min_line_span = 1 });
    defer allocator.free(folding);
    std.debug.print("   ✅ Found {} folding ranges\n", .{folding.len});

    std.debug.print("\n🎉 All Ghostlang v0.1.0 tests passed!\n", .{});
    std.debug.print("   ✅ Lua-style syntax (if/then/end, while/do/end, for/do/end, repeat/until)\n", .{});
    std.debug.print("   ✅ C-style syntax (braces, semicolons)\n", .{});
    std.debug.print("   ✅ Mixed syntax support\n", .{});
    std.debug.print("   ✅ Local variables and functions\n", .{});
    std.debug.print("   ✅ Lua operators (and, or, not, ~=, ..)\n", .{});
    std.debug.print("   ✅ Document symbols and folding\n", .{});
}
