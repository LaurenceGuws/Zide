const shared_types = @import("../types/mod.zig");
const app_shell = @import("../app_shell.zig");

const input_types = shared_types.input;
const Shell = app_shell.Shell;

pub const FrameSetup = struct {
    input_batch: input_types.InputBatch,
    poll_ms: f64,
    build_ms: f64,
};

pub const OneFrameHooks = struct {
    prepare_run_frame: *const fn (*anyopaque) anyerror!?FrameSetup,
    update: *const fn (*anyopaque, *input_types.InputBatch) anyerror!void,
    handle_frame_render_and_idle: *const fn (*anyopaque, *input_types.InputBatch, f64, f64, f64) void,
    should_stop_for_perf: *const fn (*anyopaque) bool,
    on_perf_complete: *const fn (*anyopaque) void,
};

pub fn runOneFrame(ctx: *anyopaque, hooks: OneFrameHooks) !bool {
    var frame = (try hooks.prepare_run_frame(ctx)) orelse return false;
    defer frame.input_batch.deinit();

    const update_start = app_shell.getTime();
    try hooks.update(ctx, &frame.input_batch);
    const update_end = app_shell.getTime();
    const update_ms = (update_end - update_start) * 1000.0;
    hooks.handle_frame_render_and_idle(ctx, &frame.input_batch, frame.poll_ms, frame.build_ms, update_ms);

    if (hooks.should_stop_for_perf(ctx)) {
        hooks.on_perf_complete(ctx);
        return false;
    }
    return true;
}

pub const LoopHooks = struct {
    run_one_frame: *const fn (*anyopaque) anyerror!bool,
};

pub fn runMainLoop(shell: *Shell, ctx: *anyopaque, hooks: LoopHooks) !void {
    while (!shell.shouldClose()) {
        if (!try hooks.run_one_frame(ctx)) break;
    }
}
