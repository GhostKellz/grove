const std = @import("std");
const grove = @import("grove");

/// Parser and query fixture lockdown tool
/// Generates checksums for parser binaries and query files to detect changes
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Grove Fixture Lockdown Tool ===\n\n", .{});

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const command = if (args.len >= 2) args[1] else "check";

    if (std.mem.eql(u8, command, "generate")) {
        try generateChecksums(allocator);
    } else if (std.mem.eql(u8, command, "check")) {
        try checkChecksums(allocator);
    } else if (std.mem.eql(u8, command, "help")) {
        printHelp(args[0]);
    } else {
        std.debug.print("❌ Unknown command: {s}\n", .{command});
        printHelp(args[0]);
        return;
    }
}

fn printHelp(program_name: []const u8) void {
    std.debug.print("Usage: {s} <command>\n\n", .{program_name});
    std.debug.print("Commands:\n", .{});
    std.debug.print("  generate  Generate fixture checksums\n", .{});
    std.debug.print("  check     Check fixture integrity\n", .{});
    std.debug.print("  help      Show this help message\n", .{});
}

const FixtureEntry = struct {
    path: []const u8,
    checksum: []const u8,
    size: u64,
    language: []const u8,
    type: FixtureType,
};

const FixtureType = enum {
    parser,
    query_highlights,
    query_locals,
    query_textobjects,
    query_folding,
};

fn generateChecksums(allocator: std.mem.Allocator) !void {
    std.debug.print("📝 Generating fixture checksums...\n\n", .{});

    var fixtures = std.ArrayList(FixtureEntry){};
    defer {
        for (fixtures.items) |fixture| {
            allocator.free(fixture.path);
            allocator.free(fixture.checksum);
            allocator.free(fixture.language);
        }
        fixtures.deinit(allocator);
    }

    // Scan for parser files
    try scanParsers(allocator, &fixtures);

    // Scan for query files
    try scanQueries(allocator, &fixtures);

    // Write checksums to file
    try writeChecksumFile(allocator, fixtures.items);

    std.debug.print("✅ Generated checksums for {} fixtures\n", .{fixtures.items.len});
}

fn checkChecksums(allocator: std.mem.Allocator) !void {
    std.debug.print("🔍 Checking fixture integrity...\n\n", .{});

    // Read existing checksums
    const existing_fixtures = readChecksumFile(allocator) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("⚠️  No checksum file found. Run 'generate' first.\n", .{});
            return;
        }
        return err;
    };
    defer {
        for (existing_fixtures) |fixture| {
            allocator.free(fixture.path);
            allocator.free(fixture.checksum);
            allocator.free(fixture.language);
        }
        allocator.free(existing_fixtures);
    }

    var current_fixtures = std.ArrayList(FixtureEntry){};
    defer {
        for (current_fixtures.items) |fixture| {
            allocator.free(fixture.path);
            allocator.free(fixture.checksum);
            allocator.free(fixture.language);
        }
        current_fixtures.deinit(allocator);
    }

    // Generate current checksums
    try scanParsers(allocator, &current_fixtures);
    try scanQueries(allocator, &current_fixtures);

    // Compare checksums
    var changes_found = false;
    var missing_files = false;

    for (existing_fixtures) |expected| {
        const current = findFixture(current_fixtures.items, expected.path);

        if (current == null) {
            std.debug.print("❌ Missing file: {s}\n", .{expected.path});
            missing_files = true;
            continue;
        }

        if (!std.mem.eql(u8, expected.checksum, current.?.checksum)) {
            std.debug.print("🔄 Changed: {s}\n", .{expected.path});
            std.debug.print("   Expected: {s}\n", .{expected.checksum});
            std.debug.print("   Current:  {s}\n", .{current.?.checksum});
            changes_found = true;
        } else if (expected.size != current.?.size) {
            std.debug.print("📏 Size changed: {s} ({d} -> {d} bytes)\n", .{
                expected.path, expected.size, current.?.size
            });
            changes_found = true;
        }
    }

    // Check for new files
    for (current_fixtures.items) |current| {
        const expected = findFixture(existing_fixtures, current.path);
        if (expected == null) {
            std.debug.print("➕ New file: {s}\n", .{current.path});
            changes_found = true;
        }
    }

    if (changes_found or missing_files) {
        std.debug.print("\n⚠️  Fixture changes detected!\n", .{});
        std.debug.print("Run 'generate' to update checksums if changes are intentional.\n", .{});
        std.process.exit(1);
    } else {
        std.debug.print("✅ All fixtures verified - no changes detected\n", .{});
    }
}

fn findFixture(fixtures: []const FixtureEntry, path: []const u8) ?FixtureEntry {
    for (fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.path, path)) {
            return fixture;
        }
    }
    return null;
}

fn scanParsers(allocator: std.mem.Allocator, fixtures: *std.ArrayList(FixtureEntry)) !void {
    const languages = [_][]const u8{ "json", "zig", "ghostlang", "typescript", "tsx", "rust" };

    for (languages) |language| {
        const parser_path = try std.fmt.allocPrint(allocator, "vendor/grammars/{s}/parser.c", .{language});
        defer allocator.free(parser_path);

        if (try fileExists(parser_path)) {
            const entry = try createFixtureEntry(allocator, parser_path, language, .parser);
            try fixtures.append(allocator, entry);
            std.debug.print("📊 Parser: {s} -> {s}\n", .{ parser_path, entry.checksum });
        }

        // Check for scanner.c
        const scanner_path = try std.fmt.allocPrint(allocator, "vendor/grammars/{s}/scanner.c", .{language});
        defer allocator.free(scanner_path);

        if (try fileExists(scanner_path)) {
            const entry = try createFixtureEntry(allocator, scanner_path, language, .parser);
            try fixtures.append(allocator, entry);
            std.debug.print("📊 Scanner: {s} -> {s}\n", .{ scanner_path, entry.checksum });
        }
    }
}

fn scanQueries(allocator: std.mem.Allocator, fixtures: *std.ArrayList(FixtureEntry)) !void {
    const languages = [_][]const u8{ "json", "zig", "ghostlang", "typescript", "tsx", "rust" };
    const query_types = [_]struct { name: []const u8, fixture_type: FixtureType }{
        .{ .name = "highlights", .fixture_type = .query_highlights },
        .{ .name = "locals", .fixture_type = .query_locals },
        .{ .name = "textobjects", .fixture_type = .query_textobjects },
        .{ .name = "folding", .fixture_type = .query_folding },
    };

    for (languages) |language| {
        for (query_types) |query_type| {
            const query_path = try std.fmt.allocPrint(allocator, "vendor/grammars/{s}/queries/{s}.scm", .{ language, query_type.name });
            defer allocator.free(query_path);

            if (try fileExists(query_path)) {
                const entry = try createFixtureEntry(allocator, query_path, language, query_type.fixture_type);
                try fixtures.append(allocator, entry);
                std.debug.print("🔍 Query: {s} -> {s}\n", .{ query_path, entry.checksum });
            }
        }
    }
}

fn createFixtureEntry(allocator: std.mem.Allocator, path: []const u8, language: []const u8, fixture_type: FixtureType) !FixtureEntry {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("❌ Failed to open {s}: {}\n", .{ path, err });
        return err;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const content = try allocator.alloc(u8, file_size);
    defer allocator.free(content);
    _ = try file.readAll(content);

    // Calculate SHA-256 checksum
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(content);
    var hash_bytes: [32]u8 = undefined;
    hasher.final(&hash_bytes);

    // Convert to hex string
    const checksum = try std.fmt.allocPrint(allocator, "{x}", .{hash_bytes});

    return FixtureEntry{
        .path = try allocator.dupe(u8, path),
        .checksum = checksum,
        .size = file_size,
        .language = try allocator.dupe(u8, language),
        .type = fixture_type,
    };
}

fn writeChecksumFile(allocator: std.mem.Allocator, fixtures: []const FixtureEntry) !void {
    const file = try std.fs.cwd().createFile("grove-fixtures.json", .{});
    defer file.close();

    // Generate JSON
    var json_string = std.ArrayList(u8){};
    defer json_string.deinit(allocator);

    try json_string.appendSlice(allocator, "{\n");
    try json_string.appendSlice(allocator, "  \"version\": \"1.0\",\n");
    try json_string.appendSlice(allocator, "  \"generated\": \"");

    const timestamp = std.time.timestamp();
    const datetime_str = try std.fmt.allocPrint(allocator, "{d}", .{timestamp});
    defer allocator.free(datetime_str);
    try json_string.appendSlice(allocator, datetime_str);

    try json_string.appendSlice(allocator, "\",\n");
    try json_string.appendSlice(allocator, "  \"fixtures\": [\n");

    for (fixtures, 0..) |fixture, i| {
        try json_string.appendSlice(allocator, "    {\n");

        const path_json = try std.fmt.allocPrint(allocator, "      \"path\": \"{s}\",\n", .{fixture.path});
        defer allocator.free(path_json);
        try json_string.appendSlice(allocator, path_json);

        const checksum_json = try std.fmt.allocPrint(allocator, "      \"checksum\": \"{s}\",\n", .{fixture.checksum});
        defer allocator.free(checksum_json);
        try json_string.appendSlice(allocator, checksum_json);

        const size_json = try std.fmt.allocPrint(allocator, "      \"size\": {d},\n", .{fixture.size});
        defer allocator.free(size_json);
        try json_string.appendSlice(allocator, size_json);

        const language_json = try std.fmt.allocPrint(allocator, "      \"language\": \"{s}\",\n", .{fixture.language});
        defer allocator.free(language_json);
        try json_string.appendSlice(allocator, language_json);

        const type_json = try std.fmt.allocPrint(allocator, "      \"type\": \"{s}\"\n", .{@tagName(fixture.type)});
        defer allocator.free(type_json);
        try json_string.appendSlice(allocator, type_json);

        if (i < fixtures.len - 1) {
            try json_string.appendSlice(allocator, "    },\n");
        } else {
            try json_string.appendSlice(allocator, "    }\n");
        }
    }

    try json_string.appendSlice(allocator, "  ]\n");
    try json_string.appendSlice(allocator, "}\n");

    try file.writeAll(json_string.items);
}

fn readChecksumFile(allocator: std.mem.Allocator) ![]FixtureEntry {
    const file = std.fs.cwd().openFile("grove-fixtures.json", .{}) catch |err| {
        return err;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const max_size = @min(file_size, 1024 * 1024); // 1MB limit
    const content = try allocator.alloc(u8, max_size);
    defer allocator.free(content);
    _ = try file.readAll(content);

    // Simple JSON parsing for fixtures
    // This is a minimal implementation - in production you'd use a proper JSON parser
    var fixtures = std.ArrayList(FixtureEntry){};
    defer fixtures.deinit(allocator);

    // Find fixtures array
    const fixtures_start = std.mem.indexOf(u8, content, "\"fixtures\": [") orelse return error.InvalidFormat;
    const fixtures_content = content[fixtures_start..];

    // Parse each fixture entry (simplified)
    var pos: usize = 0;
    while (pos < fixtures_content.len) {
        const entry_start = std.mem.indexOfPos(u8, fixtures_content, pos, "{") orelse break;
        const entry_end = std.mem.indexOfPos(u8, fixtures_content, entry_start, "}") orelse break;

        const entry_content = fixtures_content[entry_start..entry_end + 1];

        // Extract fields (simplified parsing)
        const path = try extractJsonString(allocator, entry_content, "path");
        const checksum = try extractJsonString(allocator, entry_content, "checksum");
        const size = try extractJsonNumber(entry_content, "size");
        const language = try extractJsonString(allocator, entry_content, "language");
        const type_str = try extractJsonString(allocator, entry_content, "type");
        defer allocator.free(type_str);

        const fixture_type = std.meta.stringToEnum(FixtureType, type_str) orelse .parser;

        try fixtures.append(allocator, FixtureEntry{
            .path = path,
            .checksum = checksum,
            .size = size,
            .language = language,
            .type = fixture_type,
        });

        pos = entry_end + 1;
    }

    return try fixtures.toOwnedSlice(allocator);
}

fn extractJsonString(allocator: std.mem.Allocator, json: []const u8, key: []const u8) ![]u8 {
    const search_pattern = try std.fmt.allocPrint(allocator, "\"{s}\": \"", .{key});
    defer allocator.free(search_pattern);

    const start = std.mem.indexOf(u8, json, search_pattern) orelse return error.KeyNotFound;
    const value_start = start + search_pattern.len;
    const value_end = std.mem.indexOfPos(u8, json, value_start, "\"") orelse return error.InvalidFormat;

    return try allocator.dupe(u8, json[value_start..value_end]);
}

fn extractJsonNumber(json: []const u8, key: []const u8) !u64 {
    const search_pattern = try std.fmt.allocPrint(std.heap.page_allocator, "\"{s}\": ", .{key});
    defer std.heap.page_allocator.free(search_pattern);

    const start = std.mem.indexOf(u8, json, search_pattern) orelse return error.KeyNotFound;
    const value_start = start + search_pattern.len;

    var value_end = value_start;
    while (value_end < json.len and (std.ascii.isDigit(json[value_end]) or json[value_end] == '.')) {
        value_end += 1;
    }

    return try std.fmt.parseInt(u64, json[value_start..value_end], 10);
}

fn fileExists(path: []const u8) !bool {
    std.fs.cwd().access(path, .{}) catch |err| {
        if (err == error.FileNotFound) return false;
        return err;
    };
    return true;
}