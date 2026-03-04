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
    if (app_terminal_active_widget.resolveActive(
        state.app_mode,
        &state.terminal_workspace,
        state.terminals.items.len,
        state.terminal_widgets.items,
    )) |widget| {
        widget.invalidateTextureCache();
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
    if (app_terminal_active_widget.resolveActive(
        state.app_mode,
        &state.terminal_workspace,
        state.terminals.items.len,
        state.terminal_widgets.items,
    )) |widget| {
        widget.invalidateTextureCache();
    }
    return true;
}
