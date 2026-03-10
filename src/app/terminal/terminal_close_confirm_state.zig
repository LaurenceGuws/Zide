const app_modes = @import("../modes/mod.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");

const TerminalTabId = terminal_mod.TerminalTabId;
const TerminalWorkspace = terminal_mod.TerminalWorkspace;

pub fn reconcilePending(
    pending: ?TerminalTabId,
    active_tab: ?TerminalTabId,
) ?TerminalTabId {
    return app_modes.ide.reconcileTerminalCloseConfirmTab(pending, active_tab);
}

pub fn shouldArmCloseConfirm(
    pending: ?TerminalTabId,
    active_tab_id: TerminalTabId,
    requires_confirm: bool,
) bool {
    if (!requires_confirm) return false;
    const confirm_matches = pending != null and pending.? == active_tab_id;
    return !confirm_matches;
}

pub const ActiveState = struct {
    pending: ?TerminalTabId,
    active: bool,
};

pub fn reconcileActiveState(
    pending: ?TerminalTabId,
    terminal_workspace: *?TerminalWorkspace,
) ActiveState {
    const active_tab: ?TerminalTabId = if (terminal_workspace.*) |*workspace| workspace.activeTabId() else null;
    const next_pending = reconcilePending(pending, active_tab);
    return .{
        .pending = next_pending,
        .active = next_pending != null,
    };
}
