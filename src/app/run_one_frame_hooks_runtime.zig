const app_run_loop_driver = @import("run_loop_driver.zig");
const app_frame_render_idle_hooks_runtime = @import("frame_render_idle_hooks_runtime.zig");
const app_prepare_run_frame_runtime = @import("prepare_run_frame_runtime.zig");
const app_update_frame_hooks_runtime = @import("update_frame_hooks_runtime.zig");
const shared_types = @import("../types/mod.zig");

pub fn run(state: anytype) !bool {
    const State = @TypeOf(state);
    const RuntimeCtx = struct {
        state: State,
    };
    var runtime_ctx = RuntimeCtx{
        .state = state,
    };
    return try app_run_loop_driver.runOneFrame(
        @ptrCast(&runtime_ctx),
        .{
            .prepare_run_frame = struct {
                fn step(raw: *anyopaque) !?app_run_loop_driver.FrameSetup {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    return try app_prepare_run_frame_runtime.prepare(rc.state);
                }
            }.step,
            .update = struct {
                fn step(raw: *anyopaque, input_batch: *shared_types.input.InputBatch) !void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    try app_update_frame_hooks_runtime.handle(rc.state, input_batch);
                }
            }.step,
            .handle_frame_render_and_idle = struct {
                fn step(raw: *anyopaque, input_batch: *shared_types.input.InputBatch, poll_ms: f64, build_ms: f64, update_ms: f64) void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    app_frame_render_idle_hooks_runtime.handle(rc.state, input_batch, poll_ms, build_ms, update_ms);
                }
            }.step,
            .should_stop_for_perf = struct {
                fn step(raw: *anyopaque) bool {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    return rc.state.perf_mode and rc.state.perf_frames_done >= rc.state.perf_frames_total and rc.state.perf_frames_total > 0;
                }
            }.step,
            .on_perf_complete = struct {
                fn step(raw: *anyopaque) void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    rc.state.perf_logger.logf("perf complete frames={d}", .{rc.state.perf_frames_done});
                }
            }.step,
        },
    );
}

pub fn runFocused(state: anytype, comptime app_mode: @import("bootstrap.zig").AppMode) !bool {
    const State = @TypeOf(state);
    const RuntimeCtx = struct {
        state: State,
    };
    var runtime_ctx = RuntimeCtx{
        .state = state,
    };
    return try app_run_loop_driver.runOneFrame(
        @ptrCast(&runtime_ctx),
        .{
            .prepare_run_frame = struct {
                fn step(raw: *anyopaque) !?app_run_loop_driver.FrameSetup {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    return try app_prepare_run_frame_runtime.prepareFocused(rc.state, app_mode);
                }
            }.step,
            .update = struct {
                fn step(raw: *anyopaque, input_batch: *shared_types.input.InputBatch) !void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    try app_update_frame_hooks_runtime.handle(rc.state, input_batch);
                }
            }.step,
            .handle_frame_render_and_idle = struct {
                fn step(raw: *anyopaque, input_batch: *shared_types.input.InputBatch, poll_ms: f64, build_ms: f64, update_ms: f64) void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    app_frame_render_idle_hooks_runtime.handle(rc.state, input_batch, poll_ms, build_ms, update_ms);
                }
            }.step,
            .should_stop_for_perf = struct {
                fn step(raw: *anyopaque) bool {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    return rc.state.perf_mode and rc.state.perf_frames_done >= rc.state.perf_frames_total and rc.state.perf_frames_total > 0;
                }
            }.step,
            .on_perf_complete = struct {
                fn step(raw: *anyopaque) void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    rc.state.perf_logger.logf("perf complete frames={d}", .{rc.state.perf_frames_done});
                }
            }.step,
        },
    );
}
