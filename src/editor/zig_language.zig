const std = @import("std");
const ts_api = @import("treesitter_api.zig");
const grammar_manager_mod = @import("grammar_manager.zig");

var cached_language: ?*const ts_api.c_api.TSLanguage = null;
var leaked_manager: ?*grammar_manager_mod.GrammarManager = null;

pub fn language() *const ts_api.c_api.TSLanguage {
    if (cached_language) |lang| return lang;
    cached_language = loadFromGrammarCache();
    return cached_language.?;
}

fn loadFromGrammarCache() *const ts_api.c_api.TSLanguage {
    if (leaked_manager == null) {
        const gm = std.heap.page_allocator.create(grammar_manager_mod.GrammarManager) catch @panic("zig grammar: failed to allocate GrammarManager");
        gm.* = grammar_manager_mod.GrammarManager.init(std.heap.page_allocator) catch @panic("zig grammar: failed to init GrammarManager");
        leaked_manager = gm;
    }
    const grammar = leaked_manager.?.getOrLoad("zig") catch @panic("zig grammar: failed to load grammar");
    if (grammar == null) {
        @panic("zig grammar missing from grammar cache (run: zig build grammar-update)");
    }
    return grammar.?.ts_language;
}
