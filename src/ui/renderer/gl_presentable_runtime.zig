const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const draw_ops = @import("draw_ops.zig");
const gl_backend = @import("gl_backend.zig");
const gl = @import("gl.zig");
const presentable_contract = @import("presentable_contract.zig");
const texture_draw = @import("texture_draw.zig");
const types = @import("types.zig");

const RenderTarget = gl_backend.RenderTarget;
const PresentableDraw = presentable_contract.PresentableDraw;
const PresentableInfo = presentable_contract.PresentableInfo;
const PresentableSurface = presentable_contract.PresentableSurface;

fn presentableTargetSlot(renderer: anytype, surface: PresentableSurface) *?RenderTarget {
    return switch (surface) {
        .terminal => &renderer.backend_runtime.opengl.presentable_targets.terminal,
        .editor => &renderer.backend_runtime.opengl.presentable_targets.editor,
    };
}

fn presentableTarget(renderer: anytype, surface: PresentableSurface) ?RenderTarget {
    return presentableTargetSlot(renderer, surface).*;
}

fn terminalScrollTargetSlot(renderer: anytype) *?RenderTarget {
    return &renderer.backend_runtime.opengl.presentable_targets.terminal_scroll;
}

pub fn ensurePresentable(renderer: anytype, surface: PresentableSurface, width: i32, height: i32) bool {
    if (!renderer.capabilities().retained_targets) return false;
    switch (surface) {
        .terminal => {
            const recreated = gl_backend.ensureRenderTargetScaledForRenderer(
                renderer,
                presentableTargetSlot(renderer, .terminal),
                width,
                height,
                gl.c.GL_NEAREST,
            );
            _ = gl_backend.ensureRenderTargetScaledForRenderer(
                renderer,
                terminalScrollTargetSlot(renderer),
                width,
                height,
                gl.c.GL_NEAREST,
            );
            return recreated;
        },
        .editor => {
            return gl_backend.ensureRenderTargetScaledForRenderer(
                renderer,
                presentableTargetSlot(renderer, .editor),
                width,
                height,
                gl.c.GL_NEAREST,
            );
        },
    }
}

pub fn beginPresentable(renderer: anytype, surface: PresentableSurface) bool {
    if (!renderer.capabilities().retained_targets) return false;
    return switch (surface) {
        .terminal => gl_backend.beginRenderTarget(renderer, presentableTarget(renderer, .terminal)),
        .editor => gl_backend.beginRenderTarget(renderer, presentableTarget(renderer, .editor)),
    };
}

pub fn presentableAvailable(renderer: anytype, surface: PresentableSurface) bool {
    if (!renderer.capabilities().retained_targets) return false;
    return presentableTarget(renderer, surface) != null;
}

pub fn endPresentable(renderer: anytype, _: PresentableSurface) void {
    if (!renderer.capabilities().retained_targets) return;
    restoreCompositionTarget(renderer);
}

pub fn drawPresentable(renderer: anytype, surface: PresentableSurface, draw: PresentableDraw) void {
    if (!renderer.capabilities().retained_targets) return;
    switch (surface) {
        .terminal => if (presentableTarget(renderer, .terminal)) |target| {
            const width = draw.width orelse return;
            const height = draw.height orelse return;
            const source_width = draw.source_width orelse width;
            const source_height = draw.source_height orelse height;
            const snapped_x = snapToDevicePixel(draw.x, renderer.scale.render_scale);
            const snapped_y = snapToDevicePixel(draw.y, renderer.scale.render_scale);
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
                        renderer.render_width,
                        renderer.render_height,
                        renderer.target_pixel_width,
                        renderer.target_pixel_height,
                        renderer.width,
                        renderer.height,
                        renderer.scale.render_scale,
                    },
                );
            }
            draw_ops.drawTextureRect(
                renderer,
                target.texture,
                src,
                dest,
                .{ .r = 255, .g = 255, .b = 255, .a = 255 },
                .{ .r = 0, .g = 0, .b = 0, .a = 0 },
                .linear_premul,
            );
        },
        .editor => if (presentableTarget(renderer, .editor)) |target| {
            const snapped_x = snapToDevicePixel(draw.x, renderer.scale.render_scale);
            const snapped_y = snapToDevicePixel(draw.y, renderer.scale.render_scale);
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
            draw_ops.drawTextureRect(
                renderer,
                target.texture,
                src,
                dest,
                .{ .r = 255, .g = 255, .b = 255, .a = 255 },
                .{ .r = 0, .g = 0, .b = 0, .a = 0 },
                .linear_premul,
            );
        },
    }
}

pub fn scrollPresentable(renderer: anytype, surface: PresentableSurface, dx: i32, dy: i32) bool {
    if (!renderer.capabilities().retained_targets) return false;
    if (surface != .terminal) return false;
    if (presentableTarget(renderer, .terminal)) |target| {
        return gl_backend.scrollRenderTarget(
            renderer,
            presentableTarget(renderer, .terminal),
            terminalScrollTargetSlot(renderer),
            dx,
            dy,
            target.logical_width,
            target.logical_height,
        );
    }
    return false;
}

pub fn presentableInfo(renderer: anytype, surface: PresentableSurface) ?PresentableInfo {
    const target = presentableTarget(renderer, surface) orelse return null;
    return .{
        .width_px = target.texture.width,
        .height_px = target.texture.height,
        .logical_width = target.logical_width,
        .logical_height = target.logical_height,
    };
}

fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
}

fn restoreCompositionTarget(renderer: anytype) void {
    if (renderer.present.main_composition_target == .offscreen_scene_target) {
        if (!gl_backend.beginSceneFrame(renderer)) {
            renderer.present.main_composition_target = .default_target;
            gl_backend.bindDefaultTarget(renderer);
        }
        return;
    }
    gl_backend.bindDefaultTarget(renderer);
}
