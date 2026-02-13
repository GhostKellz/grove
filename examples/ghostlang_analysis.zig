//! Ghostlang-specific parsing example
//!
//! Demonstrates:
//! - Parsing Ghostlang source
//! - Finding function definitions
//! - Extracting variable declarations
//! - Modern syntax (optional chaining, nullish coalescing)

const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    const language = try grove.Languages.ghostlang.get();
    try parser.setLanguage(language);

    // Ghostlang source with modern features
    const source =
        \\-- Ghostlang example with modern syntax
        \\local config = {
        \\    name = "Example",
        \\    version = 1,
        \\    settings = nil
        \\}
        \\
        \\-- Optional chaining
        \\local name = config?.settings?.theme ?? "default"
        \\
        \\-- Function with varargs
        \\function greet(name, ...)
        \\    print("Hello, " .. name)
        \\    for i, arg in ... do
        \\        print("  arg: " .. arg)
        \\    end
        \\end
        \\
        \\-- Method call syntax
        \\local result = obj:method(arg1, arg2)
        \\
        \\-- Anonymous function
        \\local callback = function(x) return x * 2 end
    ;

    var tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode() orelse return;

    // Find all function definitions
    std.debug.print("=== Functions ===\n", .{});
    findNodes(root, "function_declaration", source);

    // Find local declarations
    std.debug.print("\n=== Local Variables ===\n", .{});
    findNodes(root, "local_declaration", source);

    // Find optional chains
    std.debug.print("\n=== Optional Chains ===\n", .{});
    findNodes(root, "optional_chain_expression", source);

    // Find nullish coalescing
    std.debug.print("\n=== Nullish Coalescing ===\n", .{});
    findNodes(root, "nullish_coalescing_expression", source);
}

fn findNodes(node: grove.Node, target_kind: []const u8, source: []const u8) void {
    if (std.mem.eql(u8, node.kind(), target_kind)) {
        const start = node.startByte();
        const end = node.endByte();
        const text = source[start..end];

        // Truncate long text
        const display = if (text.len > 60) text[0..60] else text;
        const ellipsis = if (text.len > 60) "..." else "";

        std.debug.print("  [{d}:{d}] {s}{s}\n", .{
            node.startPoint().row + 1,
            node.startPoint().column,
            display,
            ellipsis,
        });
    }

    // Recurse
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            findNodes(child, target_kind, source);
        }
    }
}
