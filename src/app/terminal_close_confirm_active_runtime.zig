const app_terminal_close_confirm_state = @import("terminal_close_confirm_state.zig");

pub fn reconcile(state: anytype) bool {
    const close_state = app_terminal_close_confirm_state.reconcileActiveState(
        state.terminal_close_confirm_tab,
        &state.terminal_workspace,
    );
    state.terminal_close_confirm_tab = close_state.pending;
    return close_state.active;
}
