const app_modes = @import("../modes/mod.zig");
const app_terminal_close_confirm_actions_runtime = @import("terminal_close_confirm_actions_runtime.zig");

pub const Hooks = app_terminal_close_confirm_actions_runtime.Hooks;

pub fn applyDecision(
    state: anytype,
    decision: app_modes.ide.TerminalCloseConfirmDecision,
    now: f64,
    ctx: *anyopaque,
    hooks: Hooks,
) !bool {
    return switch (decision) {
        .confirm => try app_terminal_close_confirm_actions_runtime.requestConfirm(state, now, ctx, hooks),
        .cancel => app_terminal_close_confirm_actions_runtime.requestCancel(state, now, ctx, hooks),
        .consume => true,
        .none => false,
    };
}
