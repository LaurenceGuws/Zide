const gl = @import("gl.zig");
const screenshot = @import("screenshot.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const app_logger = @import("../../app_logger.zig");
const scene_frame_runtime = @import("scene_frame_runtime.zig");

pub fn beginFrame(renderer: anytype) void {
    scene_frame_runtime.refreshSceneTargetContract(renderer, renderer.display_metrics);
    if (renderer.capabilities().scene_composition_mode == .offscreen_scene_target) {
        scene_frame_runtime.prepareSceneTarget(renderer, gl.c.GL_NEAREST);
    }
    renderer.present.main_composition_target = switch (renderer.sceneCompositionMode()) {
        .offscreen_scene_target => if (scene_frame_runtime.beginSceneFrame(renderer))
            .offscreen_scene_target
        else
            .default_target,
        .direct_main_target => .default_target,
    };
    if (renderer.present.main_composition_target == .default_target) renderer.bindDefaultTarget();
    gl.Disable(gl.c.GL_SCISSOR_TEST);

    const bg = renderer.theme.background.toRgba();
    gl.ClearColor(
        @as(f32, @floatFromInt(bg.r)) / 255.0,
        @as(f32, @floatFromInt(bg.g)) / 255.0,
        @as(f32, @floatFromInt(bg.b)) / 255.0,
        @as(f32, @floatFromInt(bg.a)) / 255.0,
    );
    gl.Clear(gl.c.GL_COLOR_BUFFER_BIT);
}

pub fn submitFrame(renderer: anytype) scene_frame_runtime.FrameSubmission {
    if (renderer.present.main_composition_target == .offscreen_scene_target) scene_frame_runtime.drawSceneTargetToDefault(renderer);
    if (renderer.present.capture_armed) {
        if (renderer.present.capture_path) |path| {
            dumpWindowScreenshotPpm(renderer, path) catch |err| {
                app_logger.logger("renderer.present").logf(.warning, "capture failed frame_seq={d} path={s} err={s}", .{
                    renderer.present.frame_seq,
                    path,
                    @errorName(err),
                });
            };
            renderer.present.trace_current.captured_path = path;
        }
    }
    const swap_start = sdl_api.getPerformanceCounter();
    const swap_ok = sdl_api.glSwapWindow(renderer.window);
    if (!swap_ok) {
        app_logger.logger("sdl.gl").logStdout(.warning, "SDL_GL_SwapWindow failed err={s}", .{sdl_api.getError()});
    }
    const swap_end = sdl_api.getPerformanceCounter();
    renderer.present.last_swap_ms = scene_frame_runtime.performanceDeltaMs(swap_start, swap_end, renderer.perf_freq);
    renderer.present.main_composition_target = .default_target;
    renderer.present.trace_last = renderer.present.trace_current;
    renderer.present.capture_path = null;
    renderer.present.capture_armed = false;
    renderer.present.capture_frame_seq = 0;
    if (swap_ok) renderer.present.submission_sequence += 1;
    return .{
        .succeeded = swap_ok,
        .sequence = renderer.present.submission_sequence,
        .terminal_presented = renderer.present.trace_current.terminal_presentation_count > 0,
        .terminal_presented_generation = renderer.present.trace_current.terminal_presented_generation,
    };
}

pub fn dumpWindowScreenshotPpm(renderer: anytype, path: []const u8) !void {
    renderer.bindDefaultTarget();
    try screenshot.dumpFramebufferPpmScaled(
        renderer.allocator,
        renderer.render_width,
        renderer.render_height,
        renderer.width,
        renderer.height,
        path,
    );
}

pub fn dumpWindowScreenshotPpmSized(renderer: anytype, path: []const u8, out_width: i32, out_height: i32) !void {
    if (out_width <= 0 or out_height <= 0) {
        try dumpWindowScreenshotPpm(renderer, path);
        return;
    }
    renderer.bindDefaultTarget();
    try screenshot.dumpFramebufferPpmScaled(
        renderer.allocator,
        renderer.render_width,
        renderer.render_height,
        out_width,
        out_height,
        path,
    );
}
