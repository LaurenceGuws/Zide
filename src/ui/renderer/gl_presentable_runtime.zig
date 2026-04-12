const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const draw_ops = @import("draw_ops.zig");
const gl_backend = @import("gl_backend.zig");
const gl = @import("gl.zig");
const metal_text_sample_runtime = @import("metal_text_sample_runtime.zig");
const presentable_contract = @import("presentable_contract.zig");
const texture_draw = @import("texture_draw.zig");
const types = @import("types.zig");

const TerminalPresentableRefreshResult = @import("backend_dispatch.zig").TerminalPresentableRefreshResult;
const RenderTarget = gl_backend.RenderTarget;
const PresentableDraw = presentable_contract.PresentableDraw;
const PresentableInfo = presentable_contract.PresentableInfo;
const ResolvedPresentableDraw = presentable_contract.ResolvedPresentableDraw;

fn presentableTargetSlot(renderer: anytype) *?RenderTarget {
    return gl_backend.terminalPresentableTargetSlot(renderer);
}

fn presentableTarget(renderer: anytype) ?RenderTarget {
    return presentableTargetSlot(renderer).*;
}

fn terminalScrollTargetSlot(renderer: anytype) *?RenderTarget {
    return gl_backend.terminalScrollPresentableTargetSlot(renderer);
}

pub fn ensurePresentable(renderer: anytype, width: i32, height: i32) bool {
    if (!renderer.capabilities().retained_targets) return false;
    const recreated = gl_backend.ensureRenderTargetScaledForRenderer(
        renderer,
        presentableTargetSlot(renderer),
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
}

pub fn refreshTerminalPresentable(
    renderer: anytype,
    plan: presentable_contract.TerminalPresentPlan,
    ctx: ?*const anyopaque,
    body: *const fn (?*const anyopaque, @TypeOf(renderer)) void,
) TerminalPresentableRefreshResult {
    _ = plan;
    if (!renderer.capabilities().retained_targets) return .unsupported;
    if (!gl_backend.beginRenderTarget(renderer, presentableTarget(renderer))) return .target_unavailable;
    defer restoreCompositionTarget(renderer);
    body(ctx, renderer);
    // Flush any surface draws recorded during the body (e.g. kitty-above images)
    // into the retained FBO now, before restoreCompositionTarget switches to the
    // scene target.  Without this, deferred SurfaceDraws are replayed later
    // against the scene target and end up underneath the presentable blit.
    gl_backend.flushQueuedSurfaceDrawsNow(renderer);
    return .refreshed;
}

pub fn drawPresentableBackdrop(renderer: anytype, x: f32, y: f32, w: f32, h: f32, color: types.Rgba) void {
    if (w <= 0 or h <= 0) return;
    _ = gl_backend.consumeRecordedSurfaceDrawInSurfacePhase(renderer, .{ .solid = .{
        .dest_rect = .{
            .x = renderer.logicalLengthToRaster(x),
            .y = renderer.logicalLengthToRaster(y),
            .width = renderer.logicalLengthToRaster(w),
            .height = renderer.logicalLengthToRaster(h),
        },
        .color = color,
        .clip_rect = if (renderer.currentClipRect()) |clip|
            metal_text_sample_runtime.pixelClipRect(renderer, clip)
        else
            null,
    } });
}

pub fn drawPresentable(renderer: anytype, draw: PresentableDraw) void {
    if (!renderer.capabilities().retained_targets) return;
    if (presentableTarget(renderer)) |target| {
        const resolved = presentable_contract.resolveDraw(draw, null, null) orelse return;
        drawResolvedPresentable(renderer, target, resolved);
    }
}

fn drawResolvedPresentable(renderer: anytype, target: RenderTarget, draw: ResolvedPresentableDraw) void {
    const snapped_x = snapToDevicePixel(draw.x, renderer.scale.render_scale);
    const snapped_y = snapToDevicePixel(draw.y, renderer.scale.render_scale);
    const src = texture_draw.logicalTextureSrcRect(
        target.texture,
        @floatFromInt(target.logical_width),
        @floatFromInt(target.logical_height),
        draw.source_width,
        draw.source_height,
    );
    const dest = types.Rect{
        .x = snapped_x,
        .y = snapped_y,
        .width = draw.width,
        .height = draw.height,
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
}

pub fn scrollPresentable(renderer: anytype, dx: i32, dy: i32) bool {
    if (!renderer.capabilities().retained_targets) return false;
    if (presentableTarget(renderer)) |target| {
        return gl_backend.scrollRenderTarget(
            renderer,
            presentableTarget(renderer),
            terminalScrollTargetSlot(renderer),
            dx,
            dy,
            target.logical_width,
            target.logical_height,
        );
    }
    return false;
}

pub fn presentableInfo(renderer: anytype) ?PresentableInfo {
    const target = presentableTarget(renderer) orelse return null;
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
