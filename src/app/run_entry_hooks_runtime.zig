const app_run_entry_runtime = @import("run_entry_runtime.zig");
const app_run_main_loop_hooks_runtime = @import("run_main_loop_hooks_runtime.zig");
const app_run_mode_init_hooks_runtime = @import("run_mode_init_hooks_runtime.zig");

pub fn run(state: anytype) !void {
    try runWithMode(state, null, .ide);
}

pub fn runFocused(state: anytype, comptime app_mode: @import("bootstrap.zig").AppMode) !void {
    try runWithMode(state, app_mode, .ide);
}

fn runWithMode(
    state: anytype,
    comptime forced_mode: ?@import("bootstrap.zig").AppMode,
    runtime_mode_fallback: @import("bootstrap.zig").AppMode,
) !void {
    const app_mode = if (comptime forced_mode) |mode| mode else state.app_mode;
    _ = runtime_mode_fallback;

    const State = @TypeOf(state);
    const RuntimeCtx = struct {
        state: State,
    };
    var runtime_ctx = RuntimeCtx{
        .state = state,
    };
    try app_run_entry_runtime.run(
        @ptrCast(&runtime_ctx),
        .{
            .initialize_run_mode_state = struct {
                fn call(raw: *anyopaque) !void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    if (comptime forced_mode != null)
                        try app_run_mode_init_hooks_runtime.handleFocused(rc.state, app_mode)
                    else
                        try app_run_mode_init_hooks_runtime.handle(rc.state);
                }
            }.call,
            .run_main_loop = struct {
                fn call(raw: *anyopaque) !void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    if (comptime forced_mode != null)
                        try app_run_main_loop_hooks_runtime.runFocused(rc.state, app_mode)
                    else
                        try app_run_main_loop_hooks_runtime.run(rc.state);
                }
            }.call,
        },
    );
}
