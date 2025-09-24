const c = @import("c/tree_sitter.zig").c;

pub const LanguageError = error{
    InvalidLanguagePointer,
};

pub const Language = struct {
    ptr: *const c.TSLanguage,

    pub fn fromRaw(ptr: ?*const c.TSLanguage) LanguageError!Language {
        if (ptr) |value| {
            return .{ .ptr = value };
        }
        return LanguageError.InvalidLanguagePointer;
    }

    pub fn raw(self: Language) *const c.TSLanguage {
        return self.ptr;
    }
};

const std = @import("std");

test "Language.fromRaw rejects null" {
    try std.testing.expectError(LanguageError.InvalidLanguagePointer, Language.fromRaw(null));
}
