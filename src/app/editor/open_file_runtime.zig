const std = @import("std");
const app_editor_create_intent_runtime = @import("editor_create_intent_runtime.zig");
const app_mode_adapter_sync_runtime = @import("../mode_adapter_sync_runtime.zig");
const editor_mod = @import("../../editor/editor.zig");

const Editor = editor_mod.Editor;

fn tabBarIndexForEditorOrdinal(tab_bar: anytype, editor_ordinal: usize) ?usize {
    var current_editor: usize = 0;
    for (tab_bar.tabs.items, 0..) |tab, idx| {
        if (tab.kind != .editor) continue;
        if (current_editor == editor_ordinal) return idx;
        current_editor += 1;
    }
    return null;
}

fn findOpenEditorOrdinal(editors: []*Editor, normalized_path: []const u8) ?usize {
    for (editors, 0..) |editor, idx| {
        const path = editor.documentCore().filePath() orelse continue;
        if (std.mem.eql(u8, path, normalized_path)) return idx;
    }
    return null;
}

fn activateEditorOrdinal(state: anytype, editor_ordinal: usize) !void {
    const tab_index = tabBarIndexForEditorOrdinal(&state.tab_bar, editor_ordinal) orelse return error.InvalidTabIndex;
    state.active_tab = tab_index;
    state.tab_bar.active_index = tab_index;
    state.active_kind = .editor;
    try app_mode_adapter_sync_runtime.sync(state);
}

fn findReusableUntitledEditorOrdinal(editors: []*Editor) ?usize {
    if (editors.len != 1) return null;
    const editor = editors[0];
    const doc = editor.documentCore();
    if (doc.filePath() != null) return null;
    if (doc.isModified()) return null;
    return 0;
}

pub fn open(state: anytype, path: []const u8) !void {
    const normalized_path = try std.fs.cwd().realpathAlloc(state.allocator, path);
    defer state.allocator.free(normalized_path);

    if (findOpenEditorOrdinal(state.editors.items, normalized_path)) |editor_ordinal| {
        try activateEditorOrdinal(state, editor_ordinal);
        return;
    }

    if (findReusableUntitledEditorOrdinal(state.editors.items)) |editor_ordinal| {
        const editor = state.editors.items[editor_ordinal];
        try editor.openFile(normalized_path);
        try activateEditorOrdinal(state, editor_ordinal);
        return;
    }

    const grammar_manager = if (state.grammar_manager) |*gm| gm else return error.UnsupportedMode;
    _ = try app_editor_create_intent_runtime.routeCreateAndSync(state);
    const editor = try Editor.init(state.allocator, grammar_manager);
    try editor.openFile(normalized_path);
    try state.editors.append(state.allocator, editor);

    const filename = std.fs.path.basename(normalized_path);
    try state.tab_bar.addTab(filename, .editor);
    state.active_tab = state.tab_bar.tabs.items.len - 1;
    state.tab_bar.active_index = state.active_tab;
    state.active_kind = .editor;
    try app_mode_adapter_sync_runtime.sync(state);
}

pub fn openAt(state: anytype, path: []const u8, line_1: usize, col_1: ?usize) !void {
    const normalized_path = try std.fs.cwd().realpathAlloc(state.allocator, path);
    defer state.allocator.free(normalized_path);

    if (findOpenEditorOrdinal(state.editors.items, normalized_path)) |editor_ordinal| {
        const editor = state.editors.items[editor_ordinal];
        try activateEditorOrdinal(state, editor_ordinal);

        const line0 = if (line_1 > 0) line_1 - 1 else 0;
        const col0 = if (col_1) |c1| (if (c1 > 0) c1 - 1 else 0) else 0;
        const clamped_line = @min(line0, editor.lineCount() -| 1);
        const line_len = editor.lineLen(clamped_line);
        const clamped_col = @min(col0, line_len);
        editor.setCursor(clamped_line, clamped_col);
        return;
    }

    if (findReusableUntitledEditorOrdinal(state.editors.items)) |editor_ordinal| {
        const editor = state.editors.items[editor_ordinal];
        try editor.openFile(normalized_path);
        try activateEditorOrdinal(state, editor_ordinal);

        const line0 = if (line_1 > 0) line_1 - 1 else 0;
        const col0 = if (col_1) |c1| (if (c1 > 0) c1 - 1 else 0) else 0;
        const clamped_line = @min(line0, editor.lineCount() -| 1);
        const line_len = editor.lineLen(clamped_line);
        const clamped_col = @min(col0, line_len);
        editor.setCursor(clamped_line, clamped_col);
        return;
    }

    const grammar_manager = if (state.grammar_manager) |*gm| gm else return error.UnsupportedMode;
    _ = try app_editor_create_intent_runtime.routeCreateAndSync(state);
    const editor = try Editor.init(state.allocator, grammar_manager);
    try editor.openFile(normalized_path);
    try state.editors.append(state.allocator, editor);

    const filename = std.fs.path.basename(normalized_path);
    try state.tab_bar.addTab(filename, .editor);
    state.active_tab = state.tab_bar.tabs.items.len - 1;
    state.tab_bar.active_index = state.active_tab;
    state.active_kind = .editor;
    try app_mode_adapter_sync_runtime.sync(state);

    const line0 = if (line_1 > 0) line_1 - 1 else 0;
    const col0 = if (col_1) |c1| (if (c1 > 0) c1 - 1 else 0) else 0;
    const clamped_line = @min(line0, editor.lineCount() -| 1);
    const line_len = editor.lineLen(clamped_line);
    const clamped_col = @min(col0, line_len);
    editor.setCursor(clamped_line, clamped_col);
}

test "tabBarIndexForEditorOrdinal skips terminal tabs" {
    const widgets = @import("../../ui/widgets.zig");

    var tab_bar = widgets.TabBar.init(std.testing.allocator);
    defer tab_bar.deinit();

    try tab_bar.addTab("editor-a", .editor);
    try tab_bar.addTerminalTab("terminal-a", 1);
    try tab_bar.addTab("editor-b", .editor);
    try tab_bar.addTerminalTab("terminal-b", 2);

    try std.testing.expectEqual(@as(?usize, 0), tabBarIndexForEditorOrdinal(&tab_bar, 0));
    try std.testing.expectEqual(@as(?usize, 2), tabBarIndexForEditorOrdinal(&tab_bar, 1));
    try std.testing.expectEqual(@as(?usize, null), tabBarIndexForEditorOrdinal(&tab_bar, 2));
}

test "findReusableUntitledEditorOrdinal only reuses a sole clean untitled editor" {
    const grammar_manager_mod = @import("../../editor/grammar_manager.zig");

    var grammar_manager = try grammar_manager_mod.GrammarManager.init(std.testing.allocator);
    defer grammar_manager.deinit();

    const editor = try Editor.init(std.testing.allocator, &grammar_manager);
    defer editor.deinit();

    const single = [_]*Editor{editor};
    try std.testing.expectEqual(@as(?usize, 0), findReusableUntitledEditorOrdinal(&single));

    editor.modified = true;
    try std.testing.expectEqual(@as(?usize, null), findReusableUntitledEditorOrdinal(&single));
    editor.modified = false;

    editor.file_path = try std.testing.allocator.dupe(u8, "/tmp/example.txt");
    defer {
        std.testing.allocator.free(editor.file_path.?);
        editor.file_path = null;
    }
    try std.testing.expectEqual(@as(?usize, null), findReusableUntitledEditorOrdinal(&single));
}
