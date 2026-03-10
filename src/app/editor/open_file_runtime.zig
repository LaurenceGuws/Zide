const std = @import("std");
const app_editor_create_intent_runtime = @import("editor_create_intent_runtime.zig");
const app_mode_adapter_sync_runtime = @import("../mode_adapter_sync_runtime.zig");
const editor_mod = @import("../../editor/editor.zig");

const Editor = editor_mod.Editor;

pub fn open(state: anytype, path: []const u8) !void {
    const grammar_manager = if (state.grammar_manager) |*gm| gm else return error.UnsupportedMode;
    _ = try app_editor_create_intent_runtime.routeCreateAndSync(state);
    const editor = try Editor.init(state.allocator, grammar_manager);
    try editor.openFile(path);
    try state.editors.append(state.allocator, editor);

    const filename = std.fs.path.basename(path);
    try state.tab_bar.addTab(filename, .editor);
    state.active_tab = state.tab_bar.tabs.items.len - 1;
    state.active_kind = .editor;
    try app_mode_adapter_sync_runtime.sync(state);
}

pub fn openAt(state: anytype, path: []const u8, line_1: usize, col_1: ?usize) !void {
    const grammar_manager = if (state.grammar_manager) |*gm| gm else return error.UnsupportedMode;
    _ = try app_editor_create_intent_runtime.routeCreateAndSync(state);
    const editor = try Editor.init(state.allocator, grammar_manager);
    try editor.openFile(path);
    try state.editors.append(state.allocator, editor);

    const filename = std.fs.path.basename(path);
    try state.tab_bar.addTab(filename, .editor);
    state.active_tab = state.tab_bar.tabs.items.len - 1;
    state.active_kind = .editor;
    try app_mode_adapter_sync_runtime.sync(state);

    const line0 = if (line_1 > 0) line_1 - 1 else 0;
    const col0 = if (col_1) |c1| (if (c1 > 0) c1 - 1 else 0) else 0;
    const clamped_line = @min(line0, editor.lineCount() -| 1);
    const line_len = editor.lineLen(clamped_line);
    const clamped_col = @min(col0, line_len);
    editor.setCursor(clamped_line, clamped_col);
}
