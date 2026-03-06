pub const Hooks = struct {
    route_close_intent_and_sync: *const fn (*anyopaque) anyerror!void,
    close_active_terminal_tab: *const fn (*anyopaque) anyerror!bool,
    note_input: *const fn (*anyopaque, f64) void,
};

pub fn requestConfirm(state: anytype, now: f64, ctx: *anyopaque, hooks: Hooks) !bool {
    try hooks.route_close_intent_and_sync(ctx);
    if (try hooks.close_active_terminal_tab(ctx)) {
        state.needs_redraw = true;
    }
    hooks.note_input(ctx, now);
    return true;
}

pub fn requestCancel(state: anytype, now: f64, ctx: *anyopaque, hooks: Hooks) bool {
    _ = ctx;
    _ = hooks;
    state.terminal_close_confirm_tab = null;
    state.terminal_window_close_pending = false;
    state.shell.clearCloseRequest();
    state.needs_redraw = true;
    state.metrics.noteInput(now);
    return true;
}
