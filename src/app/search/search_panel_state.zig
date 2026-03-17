const std = @import("std");
const editor_mod = @import("../../editor/editor.zig");

const Editor = editor_mod.Editor;

pub fn openPanel(
    allocator: std.mem.Allocator,
    active: *bool,
    select_all: *bool,
    query: *std.ArrayList(u8),
    editor: *Editor,
) !void {
    active.* = true;
    query.clearRetainingCapacity();
    if (editor.searchQuery()) |existing_query| {
        try query.appendSlice(allocator, existing_query);
    }
    select_all.* = query.items.len > 0;
    editor.setSearchRefreshOnTextChange(true);
}

pub fn closePanel(active: *bool, select_all: *bool, editor: *Editor) void {
    active.* = false;
    select_all.* = false;
    editor.setSearchRefreshOnTextChange(false);
}

pub fn syncEditorSearchQuery(editor: *Editor, query: *const std.ArrayList(u8)) !void {
    if (query.items.len == 0) {
        try editor.setSearchQuery(null);
        return;
    }
    try editor.setSearchQuery(query.items);
}

pub fn popQueryScalar(query: *std.ArrayList(u8)) void {
    if (query.items.len == 0) return;
    var idx = query.items.len - 1;
    while (idx > 0 and (query.items[idx] & 0b1100_0000) == 0b1000_0000) : (idx -= 1) {}
    query.items.len = idx;
}
