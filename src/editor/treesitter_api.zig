const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

pub const c_api = c;
pub const TSLanguage = c.TSLanguage;
