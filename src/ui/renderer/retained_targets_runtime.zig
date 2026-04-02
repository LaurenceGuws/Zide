const std = @import("std");
const draw_ops = @import("draw_ops.zig");
const gl = @import("gl.zig");
const gl_backend = @import("gl_backend.zig");
const scene_frame_runtime = @import("scene_frame_runtime.zig");
const texture_draw = @import("texture_draw.zig");
const types = @import("types.zig");
const app_logger = @import("../../app_logger.zig");
const renderer_root = @import("../renderer.zig");

const Color = renderer_root.Color;
const RenderTarget = gl_backend.RenderTarget;

pub const RetainedTargetState = struct {
    terminal: ?RenderTarget = null,
    terminal_scroll: ?RenderTarget = null,
    editor: ?RenderTarget = null,
    drawing_editor: bool = false,
};

pub fn deinit(self: anytype) void {
    self.destroyRenderTarget(&self.retained_targets.terminal);
    self.destroyRenderTarget(&self.retained_targets.terminal_scroll);
    self.destroyRenderTarget(&self.retained_targets.editor);
}

fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
}

pub fn ensureTerminalTexture(self: anytype, width: i32, height: i32) bool {
    const recreated = self.ensureRenderTargetScaled(&self.retained_targets.terminal, width, height, gl.c.GL_NEAREST);
    _ = self.ensureRenderTargetScaled(&self.retained_targets.terminal_scroll, width, height, gl.c.GL_NEAREST);
    return recreated;
}

pub fn ensureEditorTexture(self: anytype, width: i32, height: i32) bool {
    return self.ensureRenderTargetScaled(&self.retained_targets.editor, width, height, gl.c.GL_NEAREST);
}

pub fn beginTerminalTexture(self: anytype) bool {
    return self.beginRenderTarget(self.retained_targets.terminal);
}

pub fn endTerminalTexture(self: anytype) void {
    scene_frame_runtime.restoreMainCompositionTarget(self);
}

pub fn beginEditorTexture(self: anytype) bool {
    scene_frame_runtime.noteEditorTextureUpdate(self);
    self.retained_targets.drawing_editor = true;
    return self.beginRenderTarget(self.retained_targets.editor);
}

pub fn endEditorTexture(self: anytype) void {
    self.retained_targets.drawing_editor = false;
    scene_frame_runtime.restoreMainCompositionTarget(self);
}

pub fn drawTerminalTexture(self: anytype, x: f32, y: f32, width: f32, height: f32) void {
    if (self.retained_targets.terminal) |target| {
        const snapped_x = snapToDevicePixel(x, self.scale.render_scale);
        const snapped_y = snapToDevicePixel(y, self.scale.render_scale);
        const src = texture_draw.fullTextureSrcRect(target.texture);
        const dest = types.Rect{
            .x = snapped_x,
            .y = snapped_y,
            .width = width,
            .height = height,
        };
        const log = app_logger.logger("renderer.terminal_present");
        if (log.enabled_file or log.enabled_console) {
            log.logf(
                .info,
                "draw tex={d} tex_px={d}x{d} target_logical={d}x{d} src_rect={d:.2},{d:.2} {d:.2}x{d:.2} dest={d:.2},{d:.2} {d:.2}x{d:.2} framebuffer={d}x{d} target_px={d}x{d} window={d}x{d} render_scale={d:.3}",
                .{
                    target.texture.id,
                    target.texture.width,
                    target.texture.height,
                    target.logical_width,
                    target.logical_height,
                    src.x,
                    src.y,
                    src.width,
                    src.height,
                    dest.x,
                    dest.y,
                    dest.width,
                    dest.height,
                    self.render_width,
                    self.render_height,
                    self.target_pixel_width,
                    self.target_pixel_height,
                    self.width,
                    self.height,
                    self.scale.render_scale,
                },
            );
        }
        draw_ops.drawTextureRect(self, target.texture, src, dest, Color.white.toRgba(), types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 }, .linear_premul);
    }
}

pub fn scrollTerminalTexture(self: anytype, dx: i32, dy: i32) bool {
    if (self.retained_targets.terminal) |target| {
        return gl_backend.scrollRenderTarget(
            self,
            self.retained_targets.terminal,
            &self.retained_targets.terminal_scroll,
            dx,
            dy,
            target.logical_width,
            target.logical_height,
        );
    }
    return false;
}

pub fn drawEditorTexture(self: anytype, x: f32, y: f32) void {
    if (self.retained_targets.editor) |target| {
        scene_frame_runtime.noteEditorTextureBlit(self);
        const snapped_x = snapToDevicePixel(x, self.scale.render_scale);
        const snapped_y = snapToDevicePixel(y, self.scale.render_scale);
        const src = texture_draw.fullTextureSrcRect(target.texture);
        const dest = types.Rect{
            .x = snapped_x,
            .y = snapped_y,
            .width = @floatFromInt(target.logical_width),
            .height = @floatFromInt(target.logical_height),
        };
        draw_ops.drawTextureRect(self, target.texture, src, dest, Color.white.toRgba(), types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 }, .linear_premul);
    }
}
