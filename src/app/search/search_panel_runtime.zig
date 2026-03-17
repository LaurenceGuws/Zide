const app_search_panel_input = @import("search_panel_input.zig");
const app_search_panel_state = @import("search_panel_state.zig");
const std = @import("std");

const Editor = @import("../../editor/editor.zig").Editor;

pub const CommandApplyResult = struct {
    handled: bool = false,
    query_changed: bool = false,
};

fn runSearchAction(editor: *Editor, forward: bool) bool {
    const active = editor.searchActiveMatch() orelse return false;
    if (editor.cursor.offset != active.start) {
        return editor.focusSearchActiveMatch();
    }
    return if (forward)
        editor.activateNextSearchMatch()
    else
        editor.activatePrevSearchMatch();
}

pub fn applyCommand(
    command: app_search_panel_input.SearchPanelCommand,
    editor: *Editor,
    panel_active: *bool,
    panel_select_all: *bool,
    query: *std.ArrayList(u8),
) CommandApplyResult {
    var out: CommandApplyResult = .{};
    switch (command) {
        .close => {
            app_search_panel_state.closePanel(panel_active, panel_select_all, editor);
            out.handled = true;
        },
        .next => {
            _ = runSearchAction(editor, true);
            out.handled = true;
        },
        .prev => {
            _ = runSearchAction(editor, false);
            out.handled = true;
        },
        .backspace => {
            if (panel_select_all.*) {
                query.clearRetainingCapacity();
                panel_select_all.* = false;
            } else {
                app_search_panel_state.popQueryScalar(query);
            }
            out.query_changed = true;
            out.handled = true;
        },
        .none => {},
    }
    return out;
}
