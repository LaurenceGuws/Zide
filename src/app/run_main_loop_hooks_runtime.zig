const app_run_loop_driver = @import("run_loop_driver.zig");
const app_run_one_frame_hooks_runtime = @import("run_one_frame_hooks_runtime.zig");
const app_shell = @import("../app_shell.zig");

const Shell = app_shell.Shell;

pub fn run(state: anytype) !void {
    try runWithMode(state, null);
}

pub fn runFocused(state: anytype, comptime app_mode: @import("bootstrap.zig").AppMode) !void {
    try runWithMode(state, app_mode);
}

fn runWithMode(
    state: anytype,
    comptime forced_mode: ?@import("bootstrap.zig").AppMode,
) !void {
    const app_mode = if (comptime forced_mode) |mode| mode else state.app_mode;

    const State = @TypeOf(state);
    const RuntimeCtx = struct {
        state: State,
    };
    var runtime_ctx = RuntimeCtx{
        .state = state,
    };
    try app_run_loop_driver.runMainLoop(
        state.shell,
        @ptrCast(&runtime_ctx),
        .{
            .run_one_frame = struct {
                fn inner(raw: *anyopaque) !bool {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    return if (comptime forced_mode != null)
                        try app_run_one_frame_hooks_runtime.runFocused(rc.state, app_mode)
                    else
                        try app_run_one_frame_hooks_runtime.run(rc.state);
                }
            }.inner,
        },
    );
    _ = Shell;
}
