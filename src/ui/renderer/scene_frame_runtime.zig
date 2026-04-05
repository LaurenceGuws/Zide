const gl = @import("gl.zig");
const platform_window = @import("../../platform/window_metrics.zig");
const texture_draw = @import("texture_draw.zig");
const draw_ops = @import("draw_ops.zig");
const app_logger = @import("../../app_logger.zig");
const types = @import("types.zig");
const renderer_root = @import("../renderer.zig");

const Color = renderer_root.Color;
const SceneTargetContract = renderer_root.SceneTargetContract;
const SceneTargetInvalidation = renderer_root.SceneTargetInvalidation;
pub const PresentableKind = enum {
    editor,
    terminal,
};

pub const FrameSubmission = struct {
    succeeded: bool,
    sequence: u64,
    terminal_presented: bool = false,
    terminal_presented_generation: ?u64 = null,
};

pub const PresentTrace = struct {
    frame_seq: u64 = 0,
    editor_presentable_update_count: usize = 0,
    editor_presentable_draw_count: usize = 0,
    terminal_presentation_count: usize = 0,
    terminal_presented_generation: ?u64 = null,
    composition_clip_count: usize = 0,
    composition_full_pane_clear: bool = false,
    captured_path: ?[]const u8 = null,
};

pub const MainCompositionTarget = enum {
    default_target,
    offscreen_scene_target,
    backend_surface,
};

pub const PresentState = struct {
    frame_seq: u64 = 0,
    submission_sequence: u64 = 0,
    last_present_counter: u64 = 0,
    last_present_gap_ms: f64 = 0.0,
    last_swap_ms: f64 = 0.0,
    main_composition_target: MainCompositionTarget = .default_target,
    drawing_editor_surface: bool = false,
    trace_current: PresentTrace = .{},
    trace_last: PresentTrace = .{},
    capture_path: ?[]const u8 = null,
    capture_armed: bool = false,
    capture_frame_seq: u64 = 0,
};

pub fn noteCompositionFullPaneClear(self: anytype) void {
    self.present.trace_current.composition_full_pane_clear = true;
}

pub fn noteCompositionClip(self: anytype) void {
    self.present.trace_current.composition_clip_count += 1;
}

pub fn notePresentableUpdate(self: anytype, presentable: PresentableKind) void {
    switch (presentable) {
        .editor => {
            self.present.drawing_editor_surface = true;
            self.present.trace_current.editor_presentable_update_count += 1;
        },
        .terminal => {},
    }
}

pub fn notePresentableDraw(self: anytype, presentable: PresentableKind, generation: ?u64) void {
    switch (presentable) {
        .editor => self.present.trace_current.editor_presentable_draw_count += 1,
        .terminal => noteTerminalPresentation(self, generation),
    }
}

pub fn noteTerminalPresentation(self: anytype, generation: ?u64) void {
    self.present.trace_current.terminal_presentation_count += 1;
    if (generation) |value| self.present.trace_current.terminal_presented_generation = value;
}

pub fn notePresentableEnded(self: anytype, presentable: PresentableKind) void {
    switch (presentable) {
        .editor => self.present.drawing_editor_surface = false,
        .terminal => {},
    }
}

pub fn noteEditorSurfaceFullPaneClear(self: anytype, x: i32, y: i32, w: i32, h: i32) void {
    if (!self.present.drawing_editor_surface) return;
    if (x != 0 or y != 0 or w != self.target_width or h != self.target_height) return;
    noteCompositionFullPaneClear(self);
}

pub fn refreshSceneTargetContract(self: anytype, display_metrics: platform_window.DisplayMetrics) void {
    const log = app_logger.logger("renderer.scene_target");
    const next = renderer_root.sceneTargetContractFromDisplayMetrics(display_metrics);
    if (self.capabilities().scene_composition_mode != .offscreen_scene_target) {
        self.opengl_runtime.scene_target.pending_invalidation = .{};
        self.opengl_runtime.scene_target.contract = next;
        self.opengl_runtime.scene_target.invalidation = .{};
        self.opengl_runtime.scene_target.ready = false;
        if (self.opengl_runtime.scene_target.target != null) {
            self.destroyRenderTarget(&self.opengl_runtime.scene_target.target);
        }
        return;
    }
    const reasons = self.opengl_runtime.scene_target.pending_invalidation;
    self.opengl_runtime.scene_target.pending_invalidation = .{};
    self.opengl_runtime.scene_target.contract = next;
    if (!reasons.any()) return;

    self.opengl_runtime.scene_target.invalidation = reasons;
    self.opengl_runtime.scene_target.ready = false;
    if (self.opengl_runtime.scene_target.target != null) {
        self.destroyRenderTarget(&self.opengl_runtime.scene_target.target);
    }
    renderer_root.logSceneTargetState(log, "invalidate", self.opengl_runtime.scene_target.contract, self.opengl_runtime.scene_target.invalidation, self.opengl_runtime.scene_target.ready);
}

pub fn beginSceneFrame(self: anytype) bool {
    if (self.opengl_runtime.scene_target.target == null) return false;
    if (!self.beginRenderTarget(self.opengl_runtime.scene_target.target)) {
        noteSceneTargetRecreateFailure(self);
        return false;
    }
    return true;
}

pub fn drawSceneTargetToDefault(self: anytype) void {
    const target = self.opengl_runtime.scene_target.target orelse return;
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

pub fn performanceDeltaMs(start: u64, end: u64, freq: f64) f64 {
    if (end <= start or freq <= 0.0) return 0.0;
    return (@as(f64, @floatFromInt(end - start)) * 1000.0) / freq;
}

fn noteSceneTargetRecreateFailure(self: anytype) void {
    self.opengl_runtime.scene_target.invalidation.target_recreate_failure = true;
    self.opengl_runtime.scene_target.ready = false;
    renderer_root.logSceneTargetState(
        app_logger.logger("renderer.scene_target"),
        "recreate_failed",
        self.opengl_runtime.scene_target.contract,
        self.opengl_runtime.scene_target.invalidation,
        self.opengl_runtime.scene_target.ready,
    );
}

fn clearSceneTargetInvalidation(self: anytype) void {
    self.opengl_runtime.scene_target.invalidation = .{};
    self.opengl_runtime.scene_target.ready = true;
    renderer_root.logSceneTargetState(
        app_logger.logger("renderer.scene_target"),
        "ready",
        self.opengl_runtime.scene_target.contract,
        self.opengl_runtime.scene_target.invalidation,
        self.opengl_runtime.scene_target.ready,
    );
}

fn ensureSceneTarget(self: anytype, filter: i32) bool {
    const contract = self.opengl_runtime.scene_target.contract;
    if (contract.logical_width <= 0 or contract.logical_height <= 0 or
        contract.drawable_width <= 0 or contract.drawable_height <= 0)
    {
        noteSceneTargetRecreateFailure(self);
        return false;
    }

    const recreated = self.ensureRenderTargetScaled(
        &self.opengl_runtime.scene_target.target,
        contract.logical_width,
        contract.logical_height,
        filter,
    );
    if (self.opengl_runtime.scene_target.target == null) {
        noteSceneTargetRecreateFailure(self);
        return false;
    }
    if (recreated or !self.opengl_runtime.scene_target.ready) {
        clearSceneTargetInvalidation(self);
    }
    return recreated;
}

pub fn prepareSceneTarget(self: anytype, filter: i32) void {
    const recreated = ensureSceneTarget(self, filter);
    if (self.opengl_runtime.scene_target.target == null or !recreated) return;

    if (!self.beginRenderTarget(self.opengl_runtime.scene_target.target)) {
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
