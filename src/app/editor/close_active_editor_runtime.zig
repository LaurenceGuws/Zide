const std = @import("std");
const app_active_editor_runtime = @import("active_editor_runtime.zig");
const app_mode_adapter_sync_runtime = @import("../mode_adapter_sync_runtime.zig");
const editor_mod = @import("../../editor/editor.zig");

const Editor = editor_mod.Editor;

fn setActiveFromTabIndex(state: anytype, tab_index: usize) void {
    state.active_tab = tab_index;
    state.tab_bar.active_index = tab_index;
    state.active_kind = switch (state.tab_bar.tabs.items[tab_index].kind) {
        .editor => .editor,
        .terminal => .terminal,
    };
}

pub fn activeEditor(state: anytype) ?*Editor {
    const active_index = state.tab_bar.active_index;
    const editor_ordinal = app_active_editor_runtime.visualIndexToEditorOrdinal(&state.tab_bar, active_index) orelse return null;
    if (editor_ordinal >= state.editors.items.len) return null;
    return state.editors.items[editor_ordinal];
}

fn closeResolvedActive(state: anytype, editor: *Editor) !bool {
    const active_index = state.tab_bar.active_index;

    var editor_ordinal_opt: ?usize = null;
    for (state.editors.items, 0..) |candidate, idx| {
        if (candidate == editor) {
            editor_ordinal_opt = idx;
            break;
        }
    }
    const editor_ordinal = editor_ordinal_opt orelse return false;

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

pub fn closeActive(state: anytype) !bool {
    const editor = activeEditor(state) orelse return false;
    if (editor.documentCore().isModified()) return false;
    return closeResolvedActive(state, editor);
}

pub fn forceCloseActive(state: anytype) !bool {
    const editor = activeEditor(state) orelse return false;
    return closeResolvedActive(state, editor);
}
