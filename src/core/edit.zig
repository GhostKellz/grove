const std = @import("std");
const c = @import("../c/tree_sitter.zig").c;

/// Point in source code (row, column)
pub const Point = struct {
    row: u32,
    column: u32,
};

/// Input edit for incremental parsing
pub const InputEdit = c.TSInputEdit;

/// Builder for common edit operations
pub const EditBuilder = struct {
    /// Insert text at a position
    pub fn insertText(row: u32, col: u32, text: []const u8) InputEdit {
        const start_byte = 0; // Caller should calculate actual byte offset
        const start_point = Point{ .row = row, .column = col };

        // Count newlines and calculate end position
        var end_row = row;
        var end_col = col;
        var byte_count: u32 = 0;

        for (text) |ch| {
            if (ch == '\n') {
                end_row += 1;
                end_col = 0;
            } else {
                end_col += 1;
            }
            byte_count += 1;
        }

        return .{
            .start_byte = start_byte,
            .old_end_byte = start_byte,
            .new_end_byte = start_byte + byte_count,
            .start_point = .{ .row = start_point.row, .column = start_point.column },
            .old_end_point = .{ .row = start_point.row, .column = start_point.column },
            .new_end_point = .{ .row = end_row, .column = end_col },
        };
    }

    /// Delete a range of text
    pub fn deleteRange(
        start_row: u32,
        start_col: u32,
        end_row: u32,
        end_col: u32,
        start_byte: u32,
        old_end_byte: u32,
    ) InputEdit {
        return .{
            .start_byte = start_byte,
            .old_end_byte = old_end_byte,
            .new_end_byte = start_byte,
            .start_point = .{ .row = start_row, .column = start_col },
            .old_end_point = .{ .row = end_row, .column = end_col },
            .new_end_point = .{ .row = start_row, .column = start_col },
        };
    }

    /// Replace a range with new text
    pub fn replaceRange(
        start_row: u32,
        start_col: u32,
        end_row: u32,
        end_col: u32,
        start_byte: u32,
        old_end_byte: u32,
        new_text: []const u8,
    ) InputEdit {
        var new_end_row = start_row;
        var new_end_col = start_col;
        var byte_count: u32 = 0;

        for (new_text) |ch| {
            if (ch == '\n') {
                new_end_row += 1;
                new_end_col = 0;
            } else {
                new_end_col += 1;
            }
            byte_count += 1;
        }

        return .{
            .start_byte = start_byte,
            .old_end_byte = old_end_byte,
            .new_end_byte = start_byte + byte_count,
            .start_point = .{ .row = start_row, .column = start_col },
            .old_end_point = .{ .row = end_row, .column = end_col },
            .new_end_point = .{ .row = new_end_row, .column = new_end_col },
        };
    }

    /// Helper to create an edit from byte offsets when positions are known
    pub fn fromByteRange(
        start_byte: u32,
        old_end_byte: u32,
        new_end_byte: u32,
        start_point: Point,
        old_end_point: Point,
        new_end_point: Point,
    ) InputEdit {
        return .{
            .start_byte = start_byte,
            .old_end_byte = old_end_byte,
            .new_end_byte = new_end_byte,
            .start_point = .{ .row = start_point.row, .column = start_point.column },
            .old_end_point = .{ .row = old_end_point.row, .column = old_end_point.column },
            .new_end_point = .{ .row = new_end_point.row, .column = new_end_point.column },
        };
    }
};

const testing = std.testing;

test "EditBuilder.insertText creates correct edit" {
    const edit = EditBuilder.insertText(0, 0, "hello\nworld");
    try testing.expectEqual(@as(u32, 0), edit.start_byte);
    try testing.expectEqual(@as(u32, 0), edit.old_end_byte);
    try testing.expectEqual(@as(u32, 11), edit.new_end_byte);
    try testing.expectEqual(@as(u32, 0), edit.start_point.row);
    try testing.expectEqual(@as(u32, 1), edit.new_end_point.row);
    try testing.expectEqual(@as(u32, 5), edit.new_end_point.column);
}

test "EditBuilder.deleteRange creates correct edit" {
    const edit = EditBuilder.deleteRange(0, 0, 1, 5, 0, 11);
    try testing.expectEqual(@as(u32, 0), edit.start_byte);
    try testing.expectEqual(@as(u32, 11), edit.old_end_byte);
    try testing.expectEqual(@as(u32, 0), edit.new_end_byte);
    try testing.expectEqual(@as(u32, 0), edit.new_end_point.row);
    try testing.expectEqual(@as(u32, 0), edit.new_end_point.column);
}

test "EditBuilder.replaceRange creates correct edit" {
    const edit = EditBuilder.replaceRange(0, 0, 0, 5, 0, 5, "hi");
    try testing.expectEqual(@as(u32, 0), edit.start_byte);
    try testing.expectEqual(@as(u32, 5), edit.old_end_byte);
    try testing.expectEqual(@as(u32, 2), edit.new_end_byte);
    try testing.expectEqual(@as(u32, 0), edit.new_end_point.row);
    try testing.expectEqual(@as(u32, 2), edit.new_end_point.column);
}
