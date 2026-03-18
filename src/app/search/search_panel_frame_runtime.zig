const std = @import("std");
const app_active_editor_runtime = @import("../editor/active_editor_runtime.zig");
const app_search_panel_input = @import("search_panel_input.zig");
const app_search_panel_runtime = @import("search_panel_runtime.zig");
const app_search_panel_state = @import("search_panel_state.zig");
const app_shell = @import("../../app_shell.zig");
const shared_types = @import("../../types/mod.zig");

const input_types = shared_types.input;
const Shell = app_shell.Shell;

pub const Result = struct {
    consumed_input: bool = false,
    clear_editor_cluster_cache: bool = false,
    needs_redraw: bool = false,
    note_input: bool = false,
};

pub fn handle(
    allocator: std.mem.Allocator,
    shell: *Shell,
    search_panel_active: *bool,
    search_panel_select_all: *bool,
    search_panel_query: *std.ArrayList(u8),
    editors: anytype,
    active_tab: usize,
    tab_bar: anytype,
    input_batch: *input_types.InputBatch,
) !Result {
    var out: Result = .{};
    if (!search_panel_active.* or editors.len == 0) return out;

    const editor = app_active_editor_runtime.fromVisualIndex(tab_bar, editors, active_tab) orelse return out;
    var handled = false;
    var query_changed = false;

    const command_result = app_search_panel_runtime.applyCommand(
        app_search_panel_input.searchPanelCommand(input_batch),
        editor,
        search_panel_active,
        search_panel_select_all,
        search_panel_query,
    );
    if (command_result.handled and !command_result.query_changed) {
        handled = true;
    } else {
        handled = command_result.handled;
        query_changed = command_result.query_changed;
    }

    if (try app_search_panel_input.handleSearchPanelFieldShortcuts(
        allocator,
        shell,
        search_panel_query,
        search_panel_select_all,
        input_batch,
    )) {
        query_changed = true;
        handled = true;
    }

    if (try app_search_panel_input.appendSearchPanelTextEvents(allocator, search_panel_query, search_panel_select_all, input_batch)) {
        query_changed = true;
        handled = true;
    }

    if (query_changed) {
        try app_search_panel_state.syncEditorSearchQuery(editor, search_panel_query);
    }

    if (handled) {
        out.consumed_input = true;
        out.clear_editor_cluster_cache = true;
        out.needs_redraw = true;
        out.note_input = true;
    }
    return out;
}
