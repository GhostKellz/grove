const std = @import("std");

pub const c = @cImport({
    @cDefine("TREE_SITTER_STATIC", "1");
    @cInclude("tree_sitter/api.h");
});
