const gl = @import("gl.zig");
const gl_backend = @import("gl_backend.zig");
const platform_window = @import("../../platform/window_metrics.zig");
const texture_draw = @import("texture_draw.zig");
const draw_ops = @import("draw_ops.zig");
const app_logger = @import("../../app_logger.zig");
const types = @import("types.zig");
const renderer_root = @import("../renderer.zig");

const Color = renderer_root.Color;

pub fn refreshSceneTargetContract(self: anytype, display_metrics: platform_window.DisplayMetrics) void {
    const log = app_logger.logger("renderer.scene_target");
    const next = renderer_root.sceneTargetContractFromDisplayMetrics(display_metrics);
    if (self.capabilities().scene_composition_mode != .offscreen_scene_target) {
        self.opengl_runtime.scene_target.pending_invalidation = .{};
        self.opengl_runtime.scene_target.contract = next;
        self.opengl_runtime.scene_target.invalidation = .{};
        self.opengl_runtime.scene_target.ready = false;
        if (self.opengl_runtime.scene_target.target != null) {
            gl_backend.destroyRenderTarget(&self.opengl_runtime.scene_target.target);
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
        gl_backend.destroyRenderTarget(&self.opengl_runtime.scene_target.target);
    }
    renderer_root.logSceneTargetState(log, "invalidate", self.opengl_runtime.scene_target.contract, self.opengl_runtime.scene_target.invalidation, self.opengl_runtime.scene_target.ready);
}

pub fn beginSceneFrame(self: anytype) bool {
    if (self.opengl_runtime.scene_target.target == null) return false;
    if (!gl_backend.beginRenderTarget(self, self.opengl_runtime.scene_target.target)) {
        noteSceneTargetRecreateFailure(self);
        return false;
    }
    return true;
}

pub fn drawSceneTargetToDefault(self: anytype) void {
    const target = self.opengl_runtime.scene_target.target orelse return;
    gl_backend.bindDefaultTarget(self);
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

pub fn prepareSceneTarget(self: anytype, filter: i32) void {
    const recreated = ensureSceneTarget(self, filter);
    if (self.opengl_runtime.scene_target.target == null or !recreated) return;

    if (!gl_backend.beginRenderTarget(self, self.opengl_runtime.scene_target.target)) {
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
    gl_backend.bindDefaultTarget(self);
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

    const recreated = gl_backend.ensureRenderTargetScaledForRenderer(
        self,
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
