const std = @import("std");
const gl = @import("gl.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const platform_window = @import("../../platform/window_metrics.zig");
const texture_draw = @import("texture_draw.zig");
const draw_ops = @import("draw_ops.zig");
const app_logger = @import("../../app_logger.zig");
const types = @import("types.zig");
const screenshot = @import("screenshot.zig");
const renderer_root = @import("../renderer.zig");

const Color = renderer_root.Color;
const SceneTargetContract = renderer_root.SceneTargetContract;
const SceneTargetInvalidation = renderer_root.SceneTargetInvalidation;
const WindowSizes = renderer_root.WindowSizes;

pub const FrameSubmission = struct {
    succeeded: bool,
    sequence: u64,
    terminal_surface_blitted: bool = false,
    terminal_surface_generation: ?u64 = null,
};

pub const PresentTrace = struct {
    frame_seq: u64 = 0,
    editor_surface_update_count: usize = 0,
    editor_surface_blit_count: usize = 0,
    terminal_surface_blit_count: usize = 0,
    terminal_surface_generation: ?u64 = null,
    composition_clip_count: usize = 0,
    composition_full_pane_clear: bool = false,
    captured_path: ?[]const u8 = null,
};

pub const PresentState = struct {
    frame_seq: u64 = 0,
    submission_sequence: u64 = 0,
    last_present_counter: u64 = 0,
    last_present_gap_ms: f64 = 0.0,
    last_swap_ms: f64 = 0.0,
    scene_frame_active: bool = false,
    drawing_editor_surface: bool = false,
    trace_current: PresentTrace = .{},
    trace_last: PresentTrace = .{},
    capture_path: ?[]const u8 = null,
    capture_armed: bool = false,
    capture_frame_seq: u64 = 0,
};

pub fn beginFrame(self: anytype) void {
    self.present.frame_seq +%= 1;
    self.present.trace_current = .{ .frame_seq = self.present.frame_seq };
    self.present.drawing_editor_surface = false;
    const sizes = refreshWindowSizes(self.window);
    self.width = sizes.width;
    self.height = sizes.height;
    self.render_width = sizes.render_width;
    self.render_height = sizes.render_height;
    refreshSceneTargetContract(self);
    prepareSceneTarget(self, gl.c.GL_NEAREST);

    self.text_render.bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };

    self.present.scene_frame_active = beginSceneFrame(self);
    if (!self.present.scene_frame_active) self.bindDefaultTarget();
    self.updateMouseScale();
    gl.Disable(gl.c.GL_SCISSOR_TEST);

    const bg = self.theme.background.toRgba();
    gl.ClearColor(
        @as(f32, @floatFromInt(bg.r)) / 255.0,
        @as(f32, @floatFromInt(bg.g)) / 255.0,
        @as(f32, @floatFromInt(bg.b)) / 255.0,
        @as(f32, @floatFromInt(bg.a)) / 255.0,
    );
    gl.Clear(gl.c.GL_COLOR_BUFFER_BIT);
}

pub fn submitFrame(self: anytype) FrameSubmission {
    if (self.present.scene_frame_active) drawSceneTargetToDefault(self);
    if (self.present.capture_armed) {
        if (self.present.capture_path) |path| {
            dumpWindowScreenshotPpm(self, path) catch |err| {
                app_logger.logger("renderer.present").logf(.warning, "capture failed frame_seq={d} path={s} err={s}", .{
                    self.present.frame_seq,
                    path,
                    @errorName(err),
                });
            };
            self.present.trace_current.captured_path = path;
        }
    }
    const swap_start = sdl_api.getPerformanceCounter();
    const swap_ok = sdl_api.glSwapWindow(self.window);
    if (!swap_ok) {
        app_logger.logger("sdl.gl").logStdout(.warning, "SDL_GL_SwapWindow failed err={s}", .{sdl_api.getError()});
    }
    const swap_end = sdl_api.getPerformanceCounter();
    self.present.last_swap_ms = performanceDeltaMs(swap_start, swap_end, self.perf_freq);
    self.present.scene_frame_active = false;
    self.present.trace_last = self.present.trace_current;
    self.present.capture_path = null;
    self.present.capture_armed = false;
    self.present.capture_frame_seq = 0;
    if (swap_ok) self.present.submission_sequence += 1;
    return .{
        .succeeded = swap_ok,
        .sequence = self.present.submission_sequence,
        .terminal_surface_blitted = self.present.trace_current.terminal_surface_blit_count > 0,
        .terminal_surface_generation = self.present.trace_current.terminal_surface_generation,
    };
}

pub fn restoreMainCompositionTarget(self: anytype) void {
    if (self.present.scene_frame_active) {
        if (!beginSceneFrame(self)) {
            self.present.scene_frame_active = false;
            self.bindDefaultTarget();
        }
        return;
    }
    self.bindDefaultTarget();
}

pub fn dumpWindowScreenshotPpm(self: anytype, path: []const u8) !void {
    self.bindDefaultTarget();
    try screenshot.dumpFramebufferPpmScaled(
        self.allocator,
        self.render_width,
        self.render_height,
        self.width,
        self.height,
        path,
    );
}

pub fn dumpWindowScreenshotPpmSized(self: anytype, path: []const u8, out_width: i32, out_height: i32) !void {
    if (out_width <= 0 or out_height <= 0) {
        try dumpWindowScreenshotPpm(self, path);
        return;
    }
    self.bindDefaultTarget();
    try screenshot.dumpFramebufferPpmScaled(
        self.allocator,
        self.render_width,
        self.render_height,
        out_width,
        out_height,
        path,
    );
}

pub fn armPresentCapture(self: anytype, path: []const u8) void {
    self.present.capture_path = path;
    self.present.capture_armed = true;
    self.present.capture_frame_seq = self.present.frame_seq;
}

pub fn lastPresentTrace(self: anytype) PresentTrace {
    return self.present.trace_last;
}

pub fn noteCompositionFullPaneClear(self: anytype) void {
    self.present.trace_current.composition_full_pane_clear = true;
}

pub fn noteCompositionClip(self: anytype) void {
    self.present.trace_current.composition_clip_count += 1;
}

pub fn noteEditorSurfaceUpdate(self: anytype) void {
    self.present.drawing_editor_surface = true;
    self.present.trace_current.editor_surface_update_count += 1;
}

pub fn noteEditorSurfaceBlit(self: anytype) void {
    self.present.trace_current.editor_surface_blit_count += 1;
}

pub fn noteTerminalSurfaceBlit(self: anytype, generation: ?u64) void {
    self.present.trace_current.terminal_surface_blit_count += 1;
    if (generation) |value| self.present.trace_current.terminal_surface_generation = value;
}

pub fn noteEditorSurfaceEnded(self: anytype) void {
    self.present.drawing_editor_surface = false;
}

pub fn noteEditorSurfaceFullPaneClear(self: anytype, x: i32, y: i32, w: i32, h: i32) void {
    if (!self.present.drawing_editor_surface) return;
    if (x != 0 or y != 0 or w != self.target_width or h != self.target_height) return;
    noteCompositionFullPaneClear(self);
}

pub fn refreshSceneTargetContract(self: anytype) void {
    const log = app_logger.logger("renderer.scene_target");
    const next = sceneTargetContractSnapshot(self);
    var reasons: SceneTargetInvalidation = .{};
    const previous = self.scene_target.contract;

    if (!self.scene_target.ready and self.scene_target.target == null) {
        reasons.uninitialized = true;
    }
    if (previous.drawable_width != next.drawable_width or
        previous.drawable_height != next.drawable_height or
        previous.logical_width != next.logical_width or
        previous.logical_height != next.logical_height)
    {
        reasons.drawable_resize = true;
    }
    if (previous.display_index != next.display_index) {
        reasons.display_change = true;
    }
    if (!std.math.approxEqAbs(f32, previous.render_scale, next.render_scale, 0.0001)) {
        reasons.render_scale_change = true;
    }

    self.scene_target.contract = next;
    if (!reasons.any()) return;

    self.scene_target.invalidation = reasons;
    self.scene_target.ready = false;
    if (self.scene_target.target != null) {
        self.destroyRenderTarget(&self.scene_target.target);
    }
    renderer_root.logSceneTargetState(log, "invalidate", self.scene_target.contract, self.scene_target.invalidation, self.scene_target.ready);
}

pub fn beginSceneFrame(self: anytype) bool {
    if (self.scene_target.target == null) return false;
    if (!self.beginRenderTarget(self.scene_target.target)) {
        noteSceneTargetRecreateFailure(self);
        return false;
    }
    return true;
}

pub fn drawSceneTargetToDefault(self: anytype) void {
    const target = self.scene_target.target orelse return;
    self.bindDefaultTarget();
    gl.Disable(gl.c.GL_SCISSOR_TEST);
    const bg = self.theme.background.toRgba();
    gl.ClearColor(
        @as(f32, @floatFromInt(bg.r)) / 255.0,
        @as(f32, @floatFromInt(bg.g)) / 255.0,
        @as(f32, @floatFromInt(bg.b)) / 255.0,
        @as(f32, @floatFromInt(bg.a)) / 255.0,
    );
    gl.Clear(gl.c.GL_COLOR_BUFFER_BIT);
    const src = texture_draw.fullTextureSrcRect(target.texture);
    const dest = types.Rect{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(target.logical_width),
        .height = @floatFromInt(target.logical_height),
    };
    gl.Disable(gl.c.GL_BLEND);
    draw_ops.drawTextureRect(
        self,
        target.texture,
        src,
        dest,
        Color.white.toRgba(),
        types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 },
        .linear_premul,
    );
    gl.Enable(gl.c.GL_BLEND);
}

fn performanceDeltaMs(start: u64, end: u64, freq: f64) f64 {
    if (end <= start or freq <= 0.0) return 0.0;
    return (@as(f64, @floatFromInt(end - start)) * 1000.0) / freq;
}

fn refreshWindowSizes(window: *gl.c.SDL_Window) WindowSizes {
    const display_metrics = platform_window.collectDisplayMetrics(window);
    return .{
        .width = display_metrics.window_w,
        .height = display_metrics.window_h,
        .render_width = display_metrics.drawable_w,
        .render_height = display_metrics.drawable_h,
    };
}

fn sceneTargetContractSnapshot(self: anytype) SceneTargetContract {
    return renderer_root.sceneTargetContractFromDisplayMetrics(platform_window.collectDisplayMetrics(self.window));
}

fn noteSceneTargetRecreateFailure(self: anytype) void {
    self.scene_target.invalidation.target_recreate_failure = true;
    self.scene_target.ready = false;
    renderer_root.logSceneTargetState(
        app_logger.logger("renderer.scene_target"),
        "recreate_failed",
        self.scene_target.contract,
        self.scene_target.invalidation,
        self.scene_target.ready,
    );
}

fn clearSceneTargetInvalidation(self: anytype) void {
    self.scene_target.invalidation = .{};
    self.scene_target.ready = true;
    renderer_root.logSceneTargetState(
        app_logger.logger("renderer.scene_target"),
        "ready",
        self.scene_target.contract,
        self.scene_target.invalidation,
        self.scene_target.ready,
    );
}

fn ensureSceneTarget(self: anytype, filter: i32) bool {
    const contract = self.scene_target.contract;
    if (contract.logical_width <= 0 or contract.logical_height <= 0 or
        contract.drawable_width <= 0 or contract.drawable_height <= 0)
    {
        noteSceneTargetRecreateFailure(self);
        return false;
    }

    const recreated = self.ensureRenderTargetScaled(
        &self.scene_target.target,
        contract.logical_width,
        contract.logical_height,
        filter,
    );
    if (self.scene_target.target == null) {
        noteSceneTargetRecreateFailure(self);
        return false;
    }
    if (recreated or !self.scene_target.ready) {
        clearSceneTargetInvalidation(self);
    }
    return recreated;
}

fn prepareSceneTarget(self: anytype, filter: i32) void {
    const recreated = ensureSceneTarget(self, filter);
    if (self.scene_target.target == null or !recreated) return;

    if (!self.beginRenderTarget(self.scene_target.target)) {
        noteSceneTargetRecreateFailure(self);
        return;
    }
    gl.Disable(gl.c.GL_SCISSOR_TEST);
    const bg = self.theme.background.toRgba();
    gl.ClearColor(
        @as(f32, @floatFromInt(bg.r)) / 255.0,
        @as(f32, @floatFromInt(bg.g)) / 255.0,
        @as(f32, @floatFromInt(bg.b)) / 255.0,
        @as(f32, @floatFromInt(bg.a)) / 255.0,
    );
    gl.Clear(gl.c.GL_COLOR_BUFFER_BIT);
    self.bindDefaultTarget();
}
