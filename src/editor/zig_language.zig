const std = @import("std");
const ts_api = @import("treesitter_api.zig");
const grammar_manager_mod = @import("grammar_manager.zig");

var cached_language: ?*const ts_api.c_api.TSLanguage = null;
var leaked_manager: ?*grammar_manager_mod.GrammarManager = null;

pub const ZigLanguageError = error{
    OutOfMemory,
    InitFailed,
    GrammarLoadFailed,
    GrammarMissing,
};

pub fn language() ZigLanguageError!*const ts_api.c_api.TSLanguage {
    if (cached_language) |lang| return lang;
    cached_language = try loadFromGrammarCache();
    return cached_language.?;
}

fn loadFromGrammarCache() ZigLanguageError!*const ts_api.c_api.TSLanguage {
    if (leaked_manager == null) {
        const gm = std.heap.page_allocator.create(grammar_manager_mod.GrammarManager) catch return error.OutOfMemory;
        gm.* = grammar_manager_mod.GrammarManager.init(std.heap.page_allocator) catch return error.InitFailed;
        leaked_manager = gm;
    }
    const grammar = leaked_manager.?.getOrLoad("zig") catch return error.GrammarLoadFailed;
    if (grammar == null) {
        return error.GrammarMissing;
    }
    return grammar.?.ts_language;
}
