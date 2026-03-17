const std = @import("std");
const app_types = @import("../app_state_types.zig");
const editor_mod = @import("../../editor/editor.zig");

pub const Kind = app_types.PathPromptKind;
pub const State = app_types.PathPromptState;

const Editor = editor_mod.Editor;

pub fn open(state: *State, allocator: std.mem.Allocator, kind: Kind, initial_value: []const u8) !void {
    state.active = true;
    state.kind = kind;
    state.query.clearRetainingCapacity();
    try state.query.appendSlice(allocator, initial_value);
    state.select_all = initial_value.len > 0;
    state.error_text = null;
}

pub fn close(state: *State) void {
    state.active = false;
    state.kind = null;
    state.query.clearRetainingCapacity();
    state.select_all = false;
    state.error_text = null;
}

pub fn openForOpen(state: *State, allocator: std.mem.Allocator, editor: ?*Editor) !void {
    const initial_value = if (editor) |active_editor| active_editor.file_path orelse "" else "";
    try open(state, allocator, .open_file, initial_value);
}

pub fn openForSaveAs(state: *State, allocator: std.mem.Allocator, editor: ?*Editor) !void {
    const initial_value = if (editor) |active_editor| active_editor.file_path orelse "" else "";
    try open(state, allocator, .save_as, initial_value);
}

pub fn openForReplace(state: *State, allocator: std.mem.Allocator) !void {
    try open(state, allocator, .replace, "");
}

pub fn openForReplaceAll(state: *State, allocator: std.mem.Allocator) !void {
    try open(state, allocator, .replace_all, "");
}

pub fn label(kind: Kind) []const u8 {
    return switch (kind) {
        .open_file => "Open",
        .save_as => "Save As",
        .replace => "Replace",
        .replace_all => "Replace All",
    };
}

pub fn placeholder(kind: Kind) []const u8 {
    return switch (kind) {
        .open_file => "enter path and press Enter",
        .save_as => "enter destination path and press Enter",
        .replace => "enter replacement and press Enter",
        .replace_all => "enter replacement and press Enter",
    };
}
