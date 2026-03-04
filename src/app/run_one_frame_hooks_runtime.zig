const app_run_loop_driver = @import("run_loop_driver.zig");
const shared_types = @import("../types/mod.zig");

pub const Hooks = struct {
    prepare_run_frame: *const fn (*anyopaque) anyerror!?app_run_loop_driver.FrameSetup,
    update: *const fn (*anyopaque, *shared_types.input.InputBatch) anyerror!void,
    handle_frame_render_and_idle: *const fn (*anyopaque, *shared_types.input.InputBatch, f64, f64, f64) void,
    should_stop_for_perf: *const fn (*anyopaque) bool,
    on_perf_complete: *const fn (*anyopaque) void,
};

const RuntimeCtx = struct {
    user_ctx: *anyopaque,
    hooks: Hooks,
};

pub fn run(ctx: *anyopaque, hooks: Hooks) !bool {
    var runtime_ctx = RuntimeCtx{
        .user_ctx = ctx,
        .hooks = hooks,
    };
    return try app_run_loop_driver.runOneFrame(
        @ptrCast(&runtime_ctx),
        .{
            .prepare_run_frame = struct {
                fn step(raw: *anyopaque) !?app_run_loop_driver.FrameSetup {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    return try rc.hooks.prepare_run_frame(rc.user_ctx);
                }
            }.step,
            .update = struct {
                fn step(raw: *anyopaque, input_batch: *shared_types.input.InputBatch) !void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    try rc.hooks.update(rc.user_ctx, input_batch);
                }
            }.step,
            .handle_frame_render_and_idle = struct {
                fn step(raw: *anyopaque, input_batch: *shared_types.input.InputBatch, poll_ms: f64, build_ms: f64, update_ms: f64) void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    rc.hooks.handle_frame_render_and_idle(rc.user_ctx, input_batch, poll_ms, build_ms, update_ms);
                }
            }.step,
            .should_stop_for_perf = struct {
                fn step(raw: *anyopaque) bool {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    return rc.hooks.should_stop_for_perf(rc.user_ctx);
                }
            }.step,
            .on_perf_complete = struct {
                fn step(raw: *anyopaque) void {
                    const rc: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    rc.hooks.on_perf_complete(rc.user_ctx);
                }
            }.step,
        },
    );
}
