const app_run_loop_driver = @import("run_loop_driver.zig");
const app_shell = @import("../app_shell.zig");

const Shell = app_shell.Shell;

pub const Hooks = struct {
    run_one_frame: *const fn (*anyopaque) anyerror!bool,
};

const RuntimeCtx = struct {
    user_ctx: *anyopaque,
    hooks: Hooks,
};

pub fn run(shell: *Shell, ctx: *anyopaque, hooks: Hooks) !void {
    var runtime_ctx = RuntimeCtx{
        .user_ctx = ctx,
        .hooks = hooks,
    };
    try app_run_loop_driver.runMainLoop(
        shell,
        @ptrCast(&runtime_ctx),
        .{
            .run_one_frame = struct {
                fn inner(raw: *anyopaque) !bool {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    return try rc.hooks.run_one_frame(rc.user_ctx);
                }
            }.inner,
        },
    );
}
