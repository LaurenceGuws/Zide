const std = @import("std");
const editor_mod = @import("../../editor/editor.zig");

const Editor = editor_mod.Editor;

pub fn visualIndexToEditorOrdinal(tab_bar: anytype, active_index: usize) ?usize {
    if (active_index >= tab_bar.tabs.items.len) return null;
    if (tab_bar.tabs.items[active_index].kind != .editor) return null;

    var editor_ordinal: usize = 0;
    for (tab_bar.tabs.items, 0..) |tab, idx| {
        if (idx == active_index) return editor_ordinal;
        if (tab.kind == .editor) editor_ordinal += 1;
    }
    return null;
}

pub fn fromVisualIndex(tab_bar: anytype, editors: []*Editor, active_index: usize) ?*Editor {
    const editor_ordinal = visualIndexToEditorOrdinal(tab_bar, active_index) orelse return null;
    if (editor_ordinal >= editors.len) return null;
    return editors[editor_ordinal];
}

pub fn fromState(state: anytype) ?*Editor {
    return fromVisualIndex(&state.tab_bar, state.editors.items, state.active_tab);
}

test "visualIndexToEditorOrdinal skips terminals" {
    const widgets = @import("../../ui/widgets.zig");

    var tab_bar = widgets.TabBar.init(std.testing.allocator);
    defer tab_bar.deinit();

    try tab_bar.addTerminalTab("term-a", 1);
    try tab_bar.addTab("editor-a", .editor);
    try tab_bar.addTerminalTab("term-b", 2);
    try tab_bar.addTab("editor-b", .editor);

    try std.testing.expectEqual(@as(?usize, null), visualIndexToEditorOrdinal(&tab_bar, 0));
    try std.testing.expectEqual(@as(?usize, 0), visualIndexToEditorOrdinal(&tab_bar, 1));
    try std.testing.expectEqual(@as(?usize, null), visualIndexToEditorOrdinal(&tab_bar, 2));
    try std.testing.expectEqual(@as(?usize, 1), visualIndexToEditorOrdinal(&tab_bar, 3));
}
