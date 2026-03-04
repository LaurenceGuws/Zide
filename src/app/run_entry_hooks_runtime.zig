const app_run_entry_runtime = @import("run_entry_runtime.zig");

pub const Hooks = struct {
    initialize_run_mode_state: *const fn (*anyopaque) anyerror!void,
    run_main_loop: *const fn (*anyopaque) anyerror!void,
};

const RuntimeCtx = struct {
    user_ctx: *anyopaque,
    hooks: Hooks,
};

pub fn run(ctx: *anyopaque, hooks: Hooks) !void {
    var runtime_ctx = RuntimeCtx{
        .user_ctx = ctx,
        .hooks = hooks,
    };
    try app_run_entry_runtime.run(
        @ptrCast(&runtime_ctx),
        .{
            .initialize_run_mode_state = struct {
                fn call(raw: *anyopaque) !void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    try rc.hooks.initialize_run_mode_state(rc.user_ctx);
                }
            }.call,
            .run_main_loop = struct {
                fn call(raw: *anyopaque) !void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    try rc.hooks.run_main_loop(rc.user_ctx);
                }
            }.call,
        },
    );
}
