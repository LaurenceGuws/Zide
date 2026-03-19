const std = @import("std");
const widgets = @import("../../ui/widgets.zig");
const editor_mod = @import("../../editor/editor.zig");

const TabBar = widgets.TabBar;
const Editor = editor_mod.Editor;

fn titleForEditor(editor: *Editor) []const u8 {
    const doc = editor.documentCore();
    if (doc.filePath()) |path| {
        return std.fs.path.basename(path);
    }
    return "untitled";
}

pub fn sync(tab_bar: *TabBar, editors: []*Editor) !void {
    var editor_index: usize = 0;
    for (tab_bar.tabs.items, 0..) |tab, idx| {
        if (tab.kind != .editor) continue;
        if (editor_index >= editors.len) break;
        const editor = editors[editor_index];
        try tab_bar.setTabTitle(idx, titleForEditor(editor));
        tab_bar.setTabModified(idx, editor.documentCore().isModified());
        editor_index += 1;
    }
}
