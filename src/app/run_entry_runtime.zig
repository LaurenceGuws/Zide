pub const Hooks = struct {
    initialize_run_mode_state: *const fn (*anyopaque) anyerror!void,
    run_main_loop: *const fn (*anyopaque) anyerror!void,
};

pub fn run(ctx: *anyopaque, hooks: Hooks) !void {
    try hooks.initialize_run_mode_state(ctx);
    try hooks.run_main_loop(ctx);
}
