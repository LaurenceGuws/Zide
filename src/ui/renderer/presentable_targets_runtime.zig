const std = @import("std");
const draw_ops = @import("draw_ops.zig");
const gl = @import("gl.zig");
const gl_backend = @import("gl_backend.zig");
const presentable_target = @import("presentable_target.zig");
const scene_frame_runtime = @import("scene_frame_runtime.zig");
const texture_draw = @import("texture_draw.zig");
const types = @import("types.zig");
const app_logger = @import("../../app_logger.zig");
const renderer_root = @import("../renderer.zig");

const Color = renderer_root.Color;
const PresentableTarget = presentable_target.PresentableTarget;

pub const PresentableTargetState = struct {
    terminal: ?PresentableTarget = null,
    terminal_scroll: ?PresentableTarget = null,
    editor: ?PresentableTarget = null,
};

pub const PresentableSurface = enum {
    terminal,
    editor,
};

pub const PresentableDraw = struct {
    x: f32,
    y: f32,
    width: ?f32 = null,
    height: ?f32 = null,
    source_width: ?f32 = null,
    source_height: ?f32 = null,
    generation: ?u64 = null,
};

pub fn deinit(self: anytype) void {
    self.destroyRenderTarget(&self.presentable_targets.terminal);
    self.destroyRenderTarget(&self.presentable_targets.terminal_scroll);
    self.destroyRenderTarget(&self.presentable_targets.editor);
}

fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
}

pub fn ensurePresentable(self: anytype, surface: PresentableSurface, width: i32, height: i32) bool {
    if (!self.capabilities().retained_targets) return false;
    switch (surface) {
        .terminal => {
            const recreated = self.ensureRenderTargetScaled(&self.presentable_targets.terminal, width, height, gl.c.GL_NEAREST);
            _ = self.ensureRenderTargetScaled(&self.presentable_targets.terminal_scroll, width, height, gl.c.GL_NEAREST);
            return recreated;
        },
        .editor => {
            return self.ensureRenderTargetScaled(&self.presentable_targets.editor, width, height, gl.c.GL_NEAREST);
        },
    }
}

pub fn beginPresentable(self: anytype, surface: PresentableSurface) bool {
    if (!self.capabilities().retained_targets) return false;
    switch (surface) {
        .terminal => return self.beginRenderTarget(self.presentable_targets.terminal),
        .editor => {
            scene_frame_runtime.notePresentableUpdate(self, .editor);
            return self.beginRenderTarget(self.presentable_targets.editor);
        },
    }
}

pub fn presentableAvailable(self: anytype, surface: PresentableSurface) bool {
    if (!self.capabilities().retained_targets) return false;
    return switch (surface) {
        .terminal => self.presentable_targets.terminal != null,
        .editor => self.presentable_targets.editor != null,
    };
}

pub fn endPresentable(self: anytype, surface: PresentableSurface) void {
    if (!self.capabilities().retained_targets) return;
    switch (surface) {
        .terminal => {},
        .editor => scene_frame_runtime.notePresentableEnded(self, .editor),
    }
    scene_frame_runtime.restoreMainCompositionTarget(self);
}

pub fn drawPresentable(self: anytype, surface: PresentableSurface, draw: PresentableDraw) void {
    if (!self.capabilities().retained_targets) return;
    switch (surface) {
        .terminal => if (self.presentable_targets.terminal) |target| {
            scene_frame_runtime.notePresentableDraw(self, .terminal, draw.generation);
            const width = draw.width orelse return;
            const height = draw.height orelse return;
            const source_width = draw.source_width orelse width;
            const source_height = draw.source_height orelse height;
            const snapped_x = snapToDevicePixel(draw.x, self.scale.render_scale);
            const snapped_y = snapToDevicePixel(draw.y, self.scale.render_scale);
            const src = texture_draw.logicalTextureSrcRect(
                target.texture,
                @floatFromInt(target.logical_width),
                @floatFromInt(target.logical_height),
                source_width,
                source_height,
            );
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
        },
        .editor => if (self.presentable_targets.editor) |target| {
            scene_frame_runtime.notePresentableDraw(self, .editor, null);
            const snapped_x = snapToDevicePixel(draw.x, self.scale.render_scale);
            const snapped_y = snapToDevicePixel(draw.y, self.scale.render_scale);
            const width = draw.width orelse @as(f32, @floatFromInt(target.logical_width));
            const height = draw.height orelse @as(f32, @floatFromInt(target.logical_height));
            const source_width = draw.source_width orelse width;
            const source_height = draw.source_height orelse height;
            const src = texture_draw.logicalTextureSrcRect(
                target.texture,
                @floatFromInt(target.logical_width),
                @floatFromInt(target.logical_height),
                source_width,
                source_height,
            );
            const dest = types.Rect{
                .x = snapped_x,
                .y = snapped_y,
                .width = width,
                .height = height,
            };
            draw_ops.drawTextureRect(self, target.texture, src, dest, Color.white.toRgba(), types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 }, .linear_premul);
        },
    }
}

pub fn scrollPresentable(self: anytype, surface: PresentableSurface, dx: i32, dy: i32) bool {
    if (!self.capabilities().retained_targets) return false;
    if (surface != .terminal) return false;
    if (self.presentable_targets.terminal) |target| {
        return gl_backend.scrollRenderTarget(
            self,
            self.presentable_targets.terminal,
            &self.presentable_targets.terminal_scroll,
            dx,
            dy,
            target.logical_width,
            target.logical_height,
        );
    }
    return false;
}
