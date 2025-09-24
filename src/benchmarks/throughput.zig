const std = @import("std");
const grove = @import("grove");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    const language = try grove.Languages.zig.get();
    try parser.setLanguage(language);

    const source = @embedFile("data/zig_sample.zig");
    var report = try parser.parseUtf8Timed(null, source);
    defer report.tree.deinit();

    const duration_ns = report.duration_ns;
    const bytes = report.bytes;
    const throughput = if (duration_ns == 0) 0 else (bytes * std.time.ns_per_s) / duration_ns;

    std.debug.print(
        "bytes={d} duration_ns={d} throughput_bytes_per_sec={d}\n",
        .{ bytes, duration_ns, throughput },
    );
}
