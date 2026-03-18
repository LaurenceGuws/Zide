const std = @import("std");
const app_mode_adapter_sync_runtime = @import("../mode_adapter_sync_runtime.zig");
const editor_mod = @import("../../editor/editor.zig");

const Editor = editor_mod.Editor;

fn activeEditorOrdinal(tab_bar: anytype, active_index: usize) ?usize {
    if (active_index >= tab_bar.tabs.items.len) return null;
    if (tab_bar.tabs.items[active_index].kind != .editor) return null;

    var editor_ordinal: usize = 0;
    for (tab_bar.tabs.items, 0..) |tab, idx| {
        if (idx == active_index) return editor_ordinal;
        if (tab.kind == .editor) editor_ordinal += 1;
    }
    return null;
}

fn setActiveFromTabIndex(state: anytype, tab_index: usize) void {
    state.active_tab = tab_index;
    state.tab_bar.active_index = tab_index;
    state.active_kind = switch (state.tab_bar.tabs.items[tab_index].kind) {
        .editor => .editor,
        .terminal => .terminal,
    };
}

pub fn closeActive(state: anytype) !bool {
    const active_index = state.tab_bar.active_index;
    const editor_ordinal = activeEditorOrdinal(&state.tab_bar, active_index) orelse return false;
    if (editor_ordinal >= state.editors.items.len) return false;

    const editor = state.editors.items[editor_ordinal];
    if (editor.modified) return false;

    if (state.editors.items.len == 1 and state.tab_bar.tabs.items.len == 1) {
        const grammar_manager = if (state.grammar_manager) |*gm| gm else return error.UnsupportedMode;
        const replacement = try Editor.init(state.allocator, grammar_manager);
        editor.deinit();
        state.editors.items[0] = replacement;
        try state.tab_bar.setTabTitle(0, "untitled");
        state.tab_bar.setTabModified(0, false);
        setActiveFromTabIndex(state, 0);
        try app_mode_adapter_sync_runtime.sync(state);
        return true;
    }

    editor.deinit();
    _ = state.editors.orderedRemove(editor_ordinal);
    state.tab_bar.removeTabAt(active_index);

    if (state.tab_bar.tabs.items.len > 0) {
        const replacement_index = if (active_index >= state.tab_bar.tabs.items.len)
            state.tab_bar.tabs.items.len - 1
        else
            active_index;
        setActiveFromTabIndex(state, replacement_index);
    } else {
        state.active_tab = 0;
        state.tab_bar.active_index = 0;
        state.active_kind = .editor;
    }

    try app_mode_adapter_sync_runtime.sync(state);
    return true;
}

test "activeEditorOrdinal maps mixed tab bar index to editor ordinal" {
    const widgets = @import("../../ui/widgets.zig");

    var tab_bar = widgets.TabBar.init(std.testing.allocator);
    defer tab_bar.deinit();

    try tab_bar.addTab("editor-a", .editor);
    try tab_bar.addTerminalTab("terminal-a", 1);
    try tab_bar.addTab("editor-b", .editor);

    try std.testing.expectEqual(@as(?usize, 0), activeEditorOrdinal(&tab_bar, 0));
    try std.testing.expectEqual(@as(?usize, null), activeEditorOrdinal(&tab_bar, 1));
    try std.testing.expectEqual(@as(?usize, 1), activeEditorOrdinal(&tab_bar, 2));
}
