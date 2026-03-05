const ts_api = @import("treesitter_api.zig");

extern "c" fn tree_sitter_zig() *const ts_api.c_api.TSLanguage;

pub fn language() *const ts_api.c_api.TSLanguage {
    return tree_sitter_zig();
}
