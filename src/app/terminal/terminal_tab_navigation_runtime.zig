const app_terminal_active_widget = @import("terminal_active_widget.zig");
const app_terminal_tab_ops = @import("terminal_tab_ops.zig");

pub fn focusByIndex(state: anytype, index: usize) bool {
    const changed = app_terminal_tab_ops.focusByVisualIndex(
        state.app_mode,
        &state.terminal_workspace,
        &state.tab_bar,
        index,
    );
    if (!changed) return false;
    state.terminal_close_confirm_tab = null;
    app_terminal_active_widget.syncUiFocus(
        state.app_mode,
        &state.terminal_workspace,
        state.terminals.items.len,
        state.terminal_widgets.items,
        state.active_kind == .terminal,
    );
    if (app_terminal_active_widget.resolveActive(
        state.app_mode,
        &state.terminal_workspace,
        state.terminals.items.len,
        state.terminal_widgets.items,
    )) |widget| {
        widget.*.invalidatePresentationContent();
    }
    return true;
}

pub fn cycle(state: anytype, next: bool) bool {
    const changed = app_terminal_tab_ops.cycle(
        state.app_mode,
        &state.terminal_workspace,
        &state.tab_bar,
        next,
    );
    if (!changed) return false;
    state.terminal_close_confirm_tab = null;
    app_terminal_active_widget.syncUiFocus(
        state.app_mode,
        &state.terminal_workspace,
        state.terminals.items.len,
        state.terminal_widgets.items,
        state.active_kind == .terminal,
    );
    if (app_terminal_active_widget.resolveActive(
        state.app_mode,
        &state.terminal_workspace,
        state.terminals.items.len,
        state.terminal_widgets.items,
    )) |widget| {
        widget.*.invalidatePresentationContent();
    }
    return true;
}

pub fn moveByVisualIndex(app_mode: anytype, terminal_workspace: anytype, tab_bar: anytype, to_index: usize) bool {
    return app_terminal_tab_ops.moveByVisualIndex(
        app_mode,
        terminal_workspace,
        tab_bar,
        to_index,
    );
}

pub fn moveWidgetByIndex(state: anytype, from_index: usize, to_index: usize) bool {
    if (from_index >= state.terminal_widgets.items.len) return false;
    if (to_index >= state.terminal_widgets.items.len) return false;
    if (from_index == to_index) return true;

    const moved = state.terminal_widgets.orderedRemove(from_index);
    state.terminal_widgets.insert(state.allocator, to_index, moved) catch return false;
    return true;
}
