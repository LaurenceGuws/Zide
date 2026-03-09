const app_modes = @import("modes/mod.zig");
const app_terminal_active_widget = @import("terminal_active_widget.zig");
const app_terminal_close_confirm_state = @import("terminal_close_confirm_state.zig");
const app_terminal_refresh_sizing_runtime = @import("terminal_refresh_sizing_runtime.zig");

pub const Hooks = struct {
    sync_terminal_mode_tab_bar: *const fn (*anyopaque) anyerror!void,
};

pub fn closeActive(state: anytype, ctx: *anyopaque, hooks: Hooks) !bool {
    if (!app_modes.ide.shouldUseTerminalWorkspace(state.app_mode)) return false;
    if (state.terminal_workspace) |*workspace| {
        if (workspace.tabCount() == 0) return false;
        if (workspace.activeTabId()) |active_tab_id| {
            if (app_terminal_close_confirm_state.shouldArmCloseConfirm(
                state.terminal_close_confirm_tab,
                active_tab_id,
                workspace.activeSessionShouldConfirmClose(),
            )) {
                state.terminal_close_confirm_tab = active_tab_id;
                state.needs_redraw = true;
                return false;
            }
        }
        const active_idx = workspace.activeIndex();
        if (active_idx < state.terminal_widgets.items.len) {
            state.terminal_widgets.items[active_idx].deinit();
            _ = state.terminal_widgets.orderedRemove(active_idx);
        }
        if (!workspace.closeActiveTab()) return false;
        state.terminal_close_confirm_tab = null;
        if (workspace.tabCount() == 0) {
            state.terminal_window_close_pending = false;
            state.shell.requestClose();
        } else {
            try hooks.sync_terminal_mode_tab_bar(ctx);
            try app_terminal_refresh_sizing_runtime.handle(
                state,
                state.app_mode,
                &state.terminal_workspace,
                state.terminals.items,
                state.show_terminal,
                state.terminal_height,
                state.shell,
            );
            if (app_terminal_active_widget.resolveActive(
                state.app_mode,
                &state.terminal_workspace,
                state.terminals.items.len,
                state.terminal_widgets.items,
            )) |widget| {
                widget.invalidateTextureCache();
            }
        }
        return true;
    }
    return false;
}
