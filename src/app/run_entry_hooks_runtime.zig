const app_run_entry_runtime = @import("run_entry_runtime.zig");
const app_run_main_loop_hooks_runtime = @import("run_main_loop_hooks_runtime.zig");
const app_run_mode_init_hooks_runtime = @import("run_mode_init_hooks_runtime.zig");

pub fn run(state: anytype) !void {
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
                    try app_run_mode_init_hooks_runtime.handle(rc.state);
                }
            }.call,
            .run_main_loop = struct {
                fn call(raw: *anyopaque) !void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    try app_run_main_loop_hooks_runtime.run(rc.state);
                }
            }.call,
        },
    );
}

pub fn runFocused(state: anytype, comptime app_mode: @import("bootstrap.zig").AppMode) !void {
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
                    try app_run_mode_init_hooks_runtime.handleFocused(rc.state, app_mode);
                }
            }.call,
            .run_main_loop = struct {
                fn call(raw: *anyopaque) !void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    try app_run_main_loop_hooks_runtime.runFocused(rc.state, app_mode);
                }
            }.call,
        },
    );
}
