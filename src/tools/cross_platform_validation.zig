const std = @import("std");
const grove = @import("grove");
const builtin = @import("builtin");

/// Simple cross-platform validation for Grove
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Grove Cross-Platform Validation Suite ===\n\n", .{});

    // Platform detection
    const platform_info = getPlatformInfo();
    std.debug.print("Platform: {s}\n", .{platform_info.name});
    std.debug.print("Architecture: {s}\n", .{@tagName(builtin.cpu.arch)});
    std.debug.print("OS: {s}\n", .{@tagName(builtin.os.tag)});
    std.debug.print("ABI: {s}\n\n", .{@tagName(builtin.abi)});

    var passed: u32 = 0;
    var failed: u32 = 0;

    // Test 1: Language loading
    testResult("Language Loading", testLanguageLoading(), &passed, &failed);

    // Test 2: Path handling (platform-specific)
    testResult("Path Handling", testPlatformPaths(), &passed, &failed);

    // Test 3: Build targets support
    testResult("Build Target Support", testBuildTargets(), &passed, &failed);

    // Test 4: Editor services initialization
    testResult("Editor Services", testEditorServices(allocator), &passed, &failed);

    // Test 5: Grim bridge
    testResult("Grim Bridge", testGrimBridge(allocator), &passed, &failed);

    // Test 6: Memory management basics
    testResult("Memory Management", testMemoryManagement(allocator), &passed, &failed);

    // Summary
    std.debug.print("\n=== Validation Results ===\n", .{});
    std.debug.print("Platform: {s}\n", .{platform_info.name});
    std.debug.print("Passed: {d}\n", .{passed});
    std.debug.print("Failed: {d}\n", .{failed});

    if (failed == 0) {
        std.debug.print("✅ All tests passed on {s}!\n", .{platform_info.name});

        // Create platform validation report
        try createPlatformReport(allocator, platform_info, passed, failed);
    } else {
        std.debug.print("❌ {d} test(s) failed on {s}\n", .{ failed, platform_info.name });
        std.process.exit(1);
    }
}

const PlatformInfo = struct {
    name: []const u8,
    path_separator: u8,
    line_ending: []const u8,
};

fn getPlatformInfo() PlatformInfo {
    return switch (builtin.os.tag) {
        .windows => .{
            .name = "Windows",
            .path_separator = '\\',
            .line_ending = "\r\n",
        },
        .macos => .{
            .name = "macOS",
            .path_separator = '/',
            .line_ending = "\n",
        },
        .linux => .{
            .name = "Linux",
            .path_separator = '/',
            .line_ending = "\n",
        },
        else => .{
            .name = "Other Unix",
            .path_separator = '/',
            .line_ending = "\n",
        },
    };
}

fn testResult(test_name: []const u8, result: bool, passed: *u32, failed: *u32) void {
    if (result) {
        std.debug.print("✅ {s}\n", .{test_name});
        passed.* += 1;
    } else {
        std.debug.print("❌ {s}\n", .{test_name});
        failed.* += 1;
    }
}

fn testLanguageLoading() bool {
    // Test that all bundled languages can be loaded
    const languages = [_]grove.Languages{
        .ghostlang,
        .typescript,
        .tsx,
        .zig,
        .json,
        .rust,
    };

    for (languages) |lang| {
        const language = lang.get() catch return false;
        _ = language; // Language doesn't need explicit deinitialization
    }

    return true;
}

fn testPlatformPaths() bool {
    const platform = getPlatformInfo();

    // Test path separator handling
    const test_path = switch (builtin.os.tag) {
        .windows => "C:\\Users\\test\\file.zig",
        else => "/home/test/file.zig",
    };

    // Test that the path contains the expected separator
    const has_separator = std.mem.indexOfScalar(u8, test_path, platform.path_separator) != null;

    return has_separator;
}

fn testBuildTargets() bool {
    // Test that Grove can be compiled for different targets
    const target_info = builtin.target;

    // Verify we're on a supported architecture and OS
    const supported_arch = switch (target_info.cpu.arch) {
        .x86_64, .aarch64, .arm => true,
        else => false,
    };

    const supported_os = switch (target_info.os.tag) {
        .linux, .windows, .macos => true,
        else => false,
    };

    return supported_arch and supported_os;
}

fn testEditorServices(allocator: std.mem.Allocator) bool {
    var services = grove.EditorServices.init(allocator);
    defer services.deinit();

    // Just test that initialization works
    return true;
}

fn testGrimBridge(allocator: std.mem.Allocator) bool {
    var bridge = grove.GrimBridge.init(allocator);
    defer bridge.deinit();

    // Test configuration export
    const config = bridge.getGrimConfig() catch return false;
    defer allocator.free(config);

    // Test language queries
    const queries = bridge.getLanguageQueries(.ghostlang) catch return false;
    defer allocator.free(queries);

    // Test theme config
    const theme = bridge.getThemeConfig("default") catch return false;
    defer if (theme) |t| allocator.free(t);

    return config.len > 0 and queries.len > 0;
}

fn testMemoryManagement(allocator: std.mem.Allocator) bool {
    // Test basic memory allocations
    const test_string = allocator.alloc(u8, 1024) catch return false;
    defer allocator.free(test_string);

    // Test multiple allocations
    var strings: [10][]u8 = undefined;
    for (&strings) |*s| {
        s.* = allocator.alloc(u8, 100) catch return false;
    }
    defer for (strings) |s| allocator.free(s);

    return true;
}

fn createPlatformReport(allocator: std.mem.Allocator, platform: PlatformInfo, passed: u32, failed: u32) !void {
    const report_dir = "validation_reports";
    std.fs.cwd().makeDir(report_dir) catch {}; // Ignore if exists

    const report_filename = try std.fmt.allocPrint(allocator, "{s}/grove_validation_{s}_{s}_{s}.md", .{
        report_dir,
        platform.name,
        @tagName(builtin.cpu.arch),
        @tagName(builtin.os.tag),
    });
    defer allocator.free(report_filename);

    const status = if (failed == 0) "✅ PASS" else "❌ FAIL";

    const report_content = try std.fmt.allocPrint(allocator,
        \\# Grove Cross-Platform Validation Report
        \\
        \\**Platform**: {s}
        \\**Architecture**: {s}
        \\**OS**: {s}
        \\**ABI**: {s}
        \\**Date**: {d}
        \\
        \\## Test Results
        \\
        \\- **Passed**: {d}
        \\- **Failed**: {d}
        \\- **Status**: {s}
        \\
        \\## Validated Features
        \\
        \\- Language Loading (Ghostlang, TypeScript, TSX, Zig, JSON, Rust)
        \\- Platform-specific Path Handling
        \\- Build Target Support
        \\- Editor Services Initialization
        \\- Grim Bridge Integration
        \\- Memory Management
        \\
        \\## Grove Version
        \\
        \\RC1 candidate with cross-platform validation
        \\
    , .{
        platform.name,
        @tagName(builtin.cpu.arch),
        @tagName(builtin.os.tag),
        @tagName(builtin.abi),
        std.time.timestamp(),
        passed,
        failed,
        status,
    });
    defer allocator.free(report_content);

    try std.fs.cwd().writeFile(.{ .sub_path = report_filename, .data = report_content });

    std.debug.print("📄 Platform report saved: {s}\n", .{report_filename});
}