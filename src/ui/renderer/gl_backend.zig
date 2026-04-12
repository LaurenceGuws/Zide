const std = @import("std");
const builtin = @import("builtin");
const gl = @import("gl.zig");
const gl_resources = @import("gl_resources.zig");
const draw_ops = @import("draw_ops.zig");
const shape_utils = @import("shape_utils.zig");
const texture_draw = @import("texture_draw.zig");
const texture_utils = @import("texture_utils.zig");
const capability_contract = @import("capability_contract.zig");
const bootstrap_contract = @import("bootstrap_contract.zig");
const metal_text_sample_runtime = @import("metal_text_sample_runtime.zig");
const presentable_contract = @import("presentable_contract.zig");
const gl_presentable_target = @import("gl_presentable_target.zig");
const scene_target_state = @import("scene_target_state.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const platform_window = @import("../../platform/window_metrics.zig");
const app_logger = @import("../../app_logger.zig");
const types = @import("types.zig");
const surface_draw = @import("surface_draw.zig");
const window_init = @import("window_init.zig");
const screenshot = @import("screenshot.zig");
const present_trace_runtime = @import("present_trace_runtime.zig");
const renderer_clip_host = @import("renderer_clip_host.zig");
const renderer_frame_host = @import("renderer_frame_host.zig");

const sdl = gl.c;

pub const RenderTarget = gl_presentable_target.PresentableTarget;
const PresentableDraw = presentable_contract.PresentableDraw;
const PresentableInfo = presentable_contract.PresentableInfo;
const SceneTargetContract = scene_target_state.SceneTargetContract;
const SceneTargetInvalidation = scene_target_state.SceneTargetInvalidation;
const RendererCapabilities = capability_contract.RendererCapabilities;

fn supportsRuntimeProfileForBootstrap(_: bootstrap_contract.RendererRuntimeProfile) bool {
    return true;
}

pub fn bootstrapOps() bootstrap_contract.BackendBootstrapOps {
    return .{
        .graphics_binding = .opengl,
        .supportsRuntimeProfile = supportsRuntimeProfileForBootstrap,
        .configureWindowAttributes = configureWindowAttributes,
        .runStartupSmoke = runStartupSmokeForBootstrap,
    };
}

pub fn capabilities(renderer: anytype) RendererCapabilities {
    const full_ui = renderer.runtime_profile == .full_ui;
    return .{
        .scene_composition_mode = if (full_ui)
            .offscreen_scene_target
        else
            .direct_main_target,
        .retained_targets = full_ui,
        .terminal_presentation_mode = if (full_ui)
            .retained_surface
        else
            .direct_main_target,
        .screenshot_mode = .direct_window_readback,
        .text_rendering_mode = if (full_ui)
            .gl_texture_atlas
        else
            .unavailable,
        .planned_text_rendering_mode = .gl_texture_atlas,
        .kitty_image_mode = .persistent_textures,
        .atlas_storage_mode = if (full_ui)
            .opengl_textures
        else
            .metal_textures,
        .planned_atlas_storage_mode = .opengl_textures,
        .raw_image_textures = true,
    };
}

pub fn terminalPresentableTargetSlot(renderer: anytype) *?RenderTarget {
    return &renderer.backend.runtime.openglState().targets.presentable_targets.terminal;
}

pub fn terminalScrollPresentableTargetSlot(renderer: anytype) *?RenderTarget {
    return &renderer.backend.runtime.openglState().targets.presentable_targets.terminal_scroll;
}

fn glAttrName(attr: sdl_api.GlAttr) []const u8 {
    return switch (attr) {
        sdl.SDL_GL_CONTEXT_MAJOR_VERSION => "SDL_GL_CONTEXT_MAJOR_VERSION",
        sdl.SDL_GL_CONTEXT_MINOR_VERSION => "SDL_GL_CONTEXT_MINOR_VERSION",
        sdl.SDL_GL_CONTEXT_PROFILE_MASK => "SDL_GL_CONTEXT_PROFILE_MASK",
        sdl.SDL_GL_DOUBLEBUFFER => "SDL_GL_DOUBLEBUFFER",
        sdl.SDL_GL_RED_SIZE => "SDL_GL_RED_SIZE",
        sdl.SDL_GL_GREEN_SIZE => "SDL_GL_GREEN_SIZE",
        sdl.SDL_GL_BLUE_SIZE => "SDL_GL_BLUE_SIZE",
        sdl.SDL_GL_ALPHA_SIZE => "SDL_GL_ALPHA_SIZE",
        sdl.SDL_GL_DEPTH_SIZE => "SDL_GL_DEPTH_SIZE",
        sdl.SDL_GL_STENCIL_SIZE => "SDL_GL_STENCIL_SIZE",
        else => "SDL_GL_ATTR_UNKNOWN",
    };
}

fn requireGlAttribute(attr: sdl_api.GlAttr, value: c_int) !void {
    if (sdl_api.glSetAttribute(attr, value)) return;
    app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_GL_SetAttribute failed attr={s} value={d} err={s}", .{
        glAttrName(attr),
        value,
        sdl_api.getError(),
    });
    return error.SdlGlAttributeFailed;
}

pub fn configureWindowAttributes() !void {
    try requireGlAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    try requireGlAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, 3);
    try requireGlAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, sdl.SDL_GL_CONTEXT_PROFILE_CORE);
    try requireGlAttribute(sdl.SDL_GL_DOUBLEBUFFER, 1);
}

pub fn createBackendContext(window: *sdl.SDL_Window) !?sdl_api.c.SDL_GLContext {
    const gl_context = sdl_api.glCreateContext(window) orelse return error.SdlGlContextFailed;
    if (!sdl_api.glMakeCurrent(window, gl_context)) {
        app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_GL_MakeCurrent failed err={s}", .{sdl_api.getError()});
        return error.SdlGlMakeCurrentFailed;
    }
    if (!sdl_api.glSetSwapInterval(1)) {
        app_logger.logger("sdl.gl").logStdout(.@"error", "SDL_GL_SetSwapInterval failed interval=1 err={s}", .{sdl_api.getError()});
        return error.SdlSwapIntervalFailed;
    }
    try gl.load();
    return gl_context;
}

pub fn initRuntime(renderer: anytype) !void {
    if (renderer.backend.runtime.openglState().context == null) {
        renderer.backend.runtime.openglState().context = try createBackendContext(renderer.window);
    }
    try initGlResources(renderer);
    renderer.backend.runtime.openglState().resources.resources_ready = true;
    try renderer.initFonts();
    renderer.fonts_ready = true;
}

pub fn configureRuntimePolicy(renderer: anytype) void {
    if (!renderer.terminal_render_policy.recent_input_full_publication.force_full_enabled) return;
    if (!sdl_api.glSetSwapInterval(0)) {
        app_logger.logger("sdl.gl").logStdout(.warning, "SDL_GL_SetSwapInterval failed interval=0 err={s}", .{sdl_api.getError()});
    }
}

pub fn runStartupSmokeForBootstrap(window: *sdl.SDL_Window, _: window_init.RenderSurfaceAttachment, _: i32, _: i32) !bool {
    const gl_context = (try createBackendContext(window)) orelse return error.SdlGlContextFailed;
    defer sdl_api.glDeleteContext(gl_context);
    return true;
}

pub fn sceneTargetInvalidationForRefresh(
    renderer: anytype,
    changes: anytype,
    metrics: anytype,
) SceneTargetInvalidation {
    return scene_target_state.invalidationForRefresh(
        renderer.backend.runtime.openglState().targets.scene_target,
        changes,
        metrics,
        renderer.capabilities().scene_composition_mode == .offscreen_scene_target,
    );
}

pub fn refreshSceneTargetContract(renderer: anytype, display_metrics: platform_window.DisplayMetrics) void {
    const log = app_logger.logger("renderer.scene_target");
    const next = scene_target_state.contractFromDisplayMetrics(display_metrics);
    if (renderer.capabilities().scene_composition_mode != .offscreen_scene_target) {
        renderer.backend.runtime.openglState().targets.scene_target.pending_invalidation = .{};
        renderer.backend.runtime.openglState().targets.scene_target.contract = next;
        renderer.backend.runtime.openglState().targets.scene_target.invalidation = .{};
        renderer.backend.runtime.openglState().targets.scene_target.ready = false;
        if (renderer.backend.runtime.openglState().targets.scene_target.target != null) {
            destroyRenderTarget(&renderer.backend.runtime.openglState().targets.scene_target.target);
        }
        return;
    }
    const reasons = renderer.backend.runtime.openglState().targets.scene_target.pending_invalidation;
    renderer.backend.runtime.openglState().targets.scene_target.pending_invalidation = .{};
    renderer.backend.runtime.openglState().targets.scene_target.contract = next;
    if (!reasons.any()) return;

    renderer.backend.runtime.openglState().targets.scene_target.invalidation = reasons;
    renderer.backend.runtime.openglState().targets.scene_target.ready = false;
    if (renderer.backend.runtime.openglState().targets.scene_target.target != null) {
        destroyRenderTarget(&renderer.backend.runtime.openglState().targets.scene_target.target);
    }
    scene_target_state.logState(
        log,
        "invalidate",
        renderer.backend.runtime.openglState().targets.scene_target.contract,
        renderer.backend.runtime.openglState().targets.scene_target.invalidation,
        renderer.backend.runtime.openglState().targets.scene_target.ready,
    );
}

pub fn mergePendingSceneTargetInvalidation(renderer: anytype, invalidation: SceneTargetInvalidation) void {
    renderer.backend.runtime.openglState().targets.scene_target.pending_invalidation.merge(invalidation);
}

pub fn beginSceneFrame(renderer: anytype) bool {
    if (renderer.backend.runtime.openglState().targets.scene_target.target == null) return false;
    if (!beginRenderTarget(renderer, renderer.backend.runtime.openglState().targets.scene_target.target)) {
        noteSceneTargetRecreateFailure(renderer);
        return false;
    }
    return true;
}

pub fn drawSceneTargetToDefault(renderer: anytype) void {
    const target = renderer.backend.runtime.openglState().targets.scene_target.target orelse return;
    bindDefaultTarget(renderer);
    gl.Disable(gl.c.GL_SCISSOR_TEST);
    const bg = renderer.theme.background.toRgba();
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
    draw_ops.drawTextureRectImmediate(
        renderer,
        target.texture,
        src,
        dest,
        .{ .r = 255, .g = 255, .b = 255, .a = 255 },
        .{ .r = 0, .g = 0, .b = 0, .a = 0 },
        .linear_premul,
    );
    gl.Enable(gl.c.GL_BLEND);
}

pub fn beginFrame(renderer: anytype) void {
    clearQueuedSurfaceDraws(renderer);
    refreshSceneTargetContract(renderer, renderer.display_metrics);
    if (renderer.capabilities().scene_composition_mode == .offscreen_scene_target) {
        prepareSceneTarget(renderer, gl.c.GL_NEAREST);
    }
    renderer.present.main_composition_target = switch (renderer.capabilities().scene_composition_mode) {
        .offscreen_scene_target => if (beginSceneFrame(renderer))
            .offscreen_scene_target
        else
            .default_target,
        .direct_main_target => .default_target,
    };
    if (renderer.present.main_composition_target == .default_target) bindDefaultTarget(renderer);
    gl.Disable(gl.c.GL_SCISSOR_TEST);

    const bg = renderer.theme.background.toRgba();
    gl.ClearColor(
        @as(f32, @floatFromInt(bg.r)) / 255.0,
        @as(f32, @floatFromInt(bg.g)) / 255.0,
        @as(f32, @floatFromInt(bg.b)) / 255.0,
        @as(f32, @floatFromInt(bg.a)) / 255.0,
    );
    gl.Clear(gl.c.GL_COLOR_BUFFER_BIT);
    renderer_frame_host.noteFrameReady(renderer);
}

pub fn submitFrame(renderer: anytype) present_trace_runtime.FrameSubmission {
    defer clearQueuedSurfaceDraws(renderer);
    replayFrameCriticalSurfaceDrawsBeforePresent(renderer);
    if (renderer.present.main_composition_target == .offscreen_scene_target) drawSceneTargetToDefault(renderer);
    runDebugCaptureIfArmedAfterComposition(renderer);
    const swap_start = sdl_api.getPerformanceCounter();
    const swap_ok = sdl_api.glSwapWindow(renderer.window);
    if (!swap_ok) {
        app_logger.logger("sdl.gl").logStdout(.warning, "SDL_GL_SwapWindow failed err={s}", .{sdl_api.getError()});
    }
    const swap_end = sdl_api.getPerformanceCounter();
    return renderer_frame_host.finishFrameSubmission(renderer, .{
        .kind = if (swap_ok) .submitted else .submit_failed,
        .present_ms = present_trace_runtime.performanceDeltaMs(swap_start, swap_end, renderer.perf_freq),
    });
}

/// Debug/capture-only submit work. This is intentionally named separately from
/// normal presentation so ordinary frame cost is not mistaken for capture cost.
fn runDebugCaptureIfArmedAfterComposition(renderer: anytype) void {
    if (!renderer.present.capture_armed) return;
    const path = renderer.present.capture_path orelse return;
    dumpWindowScreenshotPpm(renderer, path) catch |err| {
        app_logger.logger("renderer.present").logf(.warning, "capture failed frame_seq={d} path={s} err={s}", .{
            renderer.present.frame_seq,
            path,
            @errorName(err),
        });
    };
    renderer.present.trace_current.captured_path = path;
}

pub fn dumpWindowScreenshotPpm(renderer: anytype, path: []const u8) !void {
    bindDefaultTarget(renderer);
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
    bindDefaultTarget(renderer);
    try screenshot.dumpFramebufferPpmScaled(
        renderer.allocator,
        renderer.render_width,
        renderer.render_height,
        out_width,
        out_height,
        path,
    );
}

pub fn prepareSceneTarget(renderer: anytype, filter: i32) void {
    const recreated = ensureSceneTarget(renderer, filter);
    if (renderer.backend.runtime.openglState().targets.scene_target.target == null or !recreated) return;

    if (!beginRenderTarget(renderer, renderer.backend.runtime.openglState().targets.scene_target.target)) {
        noteSceneTargetRecreateFailure(renderer);
        return;
    }
    gl.Disable(gl.c.GL_SCISSOR_TEST);
    const bg = renderer.theme.background.toRgba();
    gl.ClearColor(
        @as(f32, @floatFromInt(bg.r)) / 255.0,
        @as(f32, @floatFromInt(bg.g)) / 255.0,
        @as(f32, @floatFromInt(bg.b)) / 255.0,
        @as(f32, @floatFromInt(bg.a)) / 255.0,
    );
    gl.Clear(gl.c.GL_COLOR_BUFFER_BIT);
    bindDefaultTarget(renderer);
}

pub fn whiteTexture(renderer: anytype) types.Texture {
    return renderer.backend.runtime.openglState().resources.white_texture;
}

pub fn drawSolidRect(renderer: anytype, x: f32, y: f32, w: f32, h: f32, color: types.Rgba) bool {
    if (w <= 0 or h <= 0) return false;
    const dest = types.Rect{ .x = x, .y = y, .width = w, .height = h };
    const src = texture_draw.unitSrcRect();
    draw_ops.drawTextureRectImmediate(renderer, whiteTexture(renderer), src, dest, color, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .rgba);
    return true;
}

/// Consumes one shared recorded `SurfaceDraw` in the OpenGL surface phase.
/// OpenGL enqueues every `SurfaceDraw` (including `.solid`) and replays the
/// queue at explicit flush boundaries (`flushQueuedSurfaceDrawsNow`, including
/// text entrypoints) and again at `submitFrame`, matching Metal's deferred
/// surface phase at the product level.
/// `.solid` and `.atlas` are supported when the renderer is in a compatible
/// text mode (atlas uses `terminal_font` coverage/color textures). `.raw_image`
/// uses a shared opaque image handle whose `handle` is interpreted here as a GL
/// texture id; the draw does not take ownership.
pub fn consumeRecordedSurfaceDrawInSurfacePhase(renderer: anytype, draw: surface_draw.SurfaceDraw) bool {
    return switch (draw) {
        .solid => |solid| executeRecordedSurfaceFillInSurfacePhase(renderer, solid),
        .atlas => |atlas| executeRecordedSurfaceAtlasBlitInSurfacePhase(renderer, atlas),
        .raw_image => |image| executeRecordedSurfaceRawImageBlitInSurfacePhase(renderer, image),
    };
}

pub fn recordSurfaceDrawForSurfacePhase(renderer: anytype, draw: surface_draw.SurfaceDraw) bool {
    return enqueueSurfaceDrawForSurfacePhase(renderer, draw, false);
}

fn enqueueSurfaceDrawForSurfacePhase(renderer: anytype, draw: surface_draw.SurfaceDraw, owns_raw_image_texture: bool) bool {
    switch (draw) {
        .solid => present_trace_runtime.noteGlSurfaceSolidEnqueue(renderer),
        else => {},
    }
    renderer.backend.runtime.openglState().queued_surface_draws.append(renderer.allocator, .{
        .draw = draw,
        .owns_raw_image_texture = owns_raw_image_texture,
    }) catch return false;
    return true;
}

/// Frame-critical submit replay. OpenGL surface draws may be queued while
/// higher-level code records shared surface work; until that queue is moved to
/// an earlier explicit stage, submit must replay it before scene blit/swap.
fn replayFrameCriticalSurfaceDrawsBeforePresent(renderer: anytype) void {
    for (renderer.backend.runtime.openglState().queued_surface_draws.items) |queued_draw| {
        present_trace_runtime.noteGlSurfaceQueuedReplay(renderer);
        _ = consumeRecordedSurfaceDrawInSurfacePhase(renderer, queued_draw.draw);
    }
}

/// Replay and clear the OpenGL `SurfaceDraw` queue now. Call before any draw
/// path that bypasses `recordSurfaceDraw` (texture/glyph batches, etc.) when
/// ordering must match "surface work first."
pub fn flushQueuedSurfaceDrawsNow(renderer: anytype) void {
    if (renderer.backend.runtime.openglState().queued_surface_draws.items.len == 0) return;
    replayFrameCriticalSurfaceDrawsBeforePresent(renderer);
    clearQueuedSurfaceDraws(renderer);
}

/// Same as [`flushQueuedSurfaceDrawsNow`] but only when the window uses the OpenGL
/// surface attachment (avoids touching GL state on Metal-only bootstrap paths).
pub fn flushQueuedSurfaceDrawsBeforeImmediateWork(renderer: anytype) void {
    switch (renderer.render_surface_attachment) {
        .opengl_window => flushQueuedSurfaceDrawsNow(renderer),
        else => {},
    }
}

fn clearQueuedSurfaceDraws(renderer: anytype) void {
    for (renderer.backend.runtime.openglState().queued_surface_draws.items) |queued_draw| {
        if (!queued_draw.owns_raw_image_texture) continue;
        switch (queued_draw.draw) {
            .raw_image => |raw| {
                var texture = textureFromGpuImageHandle(raw.texture);
                texture_utils.destroyTexture(&texture);
            },
            else => {},
        }
    }
    renderer.backend.runtime.openglState().queued_surface_draws.clearRetainingCapacity();
}

fn executeRecordedSurfaceFillInSurfacePhase(renderer: anytype, fill: surface_draw.SolidColorDraw) bool {
    const x = renderer.rasterLengthToLogical(fill.dest_rect.x);
    const y = renderer.rasterLengthToLogical(fill.dest_rect.y);
    const w = renderer.rasterLengthToLogical(fill.dest_rect.width);
    const h = renderer.rasterLengthToLogical(fill.dest_rect.height);
    if (w <= 0 or h <= 0) return false;
    if (fill.clip_rect) |pc| {
        if (pc.width <= 0 or pc.height <= 0) return false;
        renderer_clip_host.beginClip(
            renderer,
            @intFromFloat(std.math.round(renderer.rasterLengthToLogical(@floatFromInt(pc.x)))),
            @intFromFloat(std.math.round(renderer.rasterLengthToLogical(@floatFromInt(pc.y)))),
            @intFromFloat(std.math.round(renderer.rasterLengthToLogical(@floatFromInt(pc.width)))),
            @intFromFloat(std.math.round(renderer.rasterLengthToLogical(@floatFromInt(pc.height)))),
        );
        defer renderer_clip_host.endClip(renderer);
        return drawSolidRect(renderer, x, y, w, h, fill.color);
    }
    return drawSolidRect(renderer, x, y, w, h, fill.color);
}

fn executeRecordedSurfaceAtlasBlitInSurfacePhase(renderer: anytype, sample: surface_draw.AtlasSampleDraw) bool {
    if (renderer.textRenderingMode() != .gl_texture_atlas) return false;
    const w_px = @as(i32, @intFromFloat(sample.source_rect.width));
    const h_px = @as(i32, @intFromFloat(sample.source_rect.height));
    if (w_px <= 0 or h_px <= 0) return false;
    const tex = switch (sample.atlas) {
        .coverage => renderer.terminal_font.coverageTexture(),
        .color => renderer.terminal_font.colorTexture(),
    };
    if (tex.id == 0 or tex.width <= 0 or tex.height <= 0) return false;
    const dest = types.Rect{
        .x = renderer.rasterLengthToLogical(@floatFromInt(sample.dest_x)),
        .y = renderer.rasterLengthToLogical(@floatFromInt(sample.dest_y)),
        .width = renderer.rasterLengthToLogical(@floatFromInt(w_px)),
        .height = renderer.rasterLengthToLogical(@floatFromInt(h_px)),
    };
    const kind: types.TextureKind = switch (sample.atlas) {
        .coverage => .font_coverage,
        .color => .rgba,
    };
    if (sample.clip_rect) |pc| {
        if (pc.width <= 0 or pc.height <= 0) return false;
        renderer_clip_host.beginClip(
            renderer,
            @intFromFloat(std.math.round(renderer.rasterLengthToLogical(@floatFromInt(pc.x)))),
            @intFromFloat(std.math.round(renderer.rasterLengthToLogical(@floatFromInt(pc.y)))),
            @intFromFloat(std.math.round(renderer.rasterLengthToLogical(@floatFromInt(pc.width)))),
            @intFromFloat(std.math.round(renderer.rasterLengthToLogical(@floatFromInt(pc.height)))),
        );
        defer renderer_clip_host.endClip(renderer);
        draw_ops.drawTextureRectImmediate(renderer, tex, sample.source_rect, dest, sample.tint, sample.bg_rgba, kind);
        return true;
    }
    draw_ops.drawTextureRectImmediate(renderer, tex, sample.source_rect, dest, sample.tint, sample.bg_rgba, kind);
    return true;
}

fn executeRecordedSurfaceRawImageBlitInSurfacePhase(renderer: anytype, img: surface_draw.RawImageDraw) bool {
    const tex = textureFromGpuImageHandle(img.texture);
    if (tex.id == 0 or tex.width <= 0 or tex.height <= 0) return false;
    const source_rect = img.source_rect orelse types.Rect{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(tex.width),
        .height = @floatFromInt(tex.height),
    };
    const x = renderer.rasterLengthToLogical(img.dest_rect.x);
    const y = renderer.rasterLengthToLogical(img.dest_rect.y);
    const w = renderer.rasterLengthToLogical(img.dest_rect.width);
    const h = renderer.rasterLengthToLogical(img.dest_rect.height);
    if (w <= 0 or h <= 0) return false;
    const dest = types.Rect{ .x = x, .y = y, .width = w, .height = h };
    if (img.clip_rect) |pc| {
        if (pc.width <= 0 or pc.height <= 0) return false;
        renderer_clip_host.beginClip(
            renderer,
            @intFromFloat(std.math.round(renderer.rasterLengthToLogical(@floatFromInt(pc.x)))),
            @intFromFloat(std.math.round(renderer.rasterLengthToLogical(@floatFromInt(pc.y)))),
            @intFromFloat(std.math.round(renderer.rasterLengthToLogical(@floatFromInt(pc.width)))),
            @intFromFloat(std.math.round(renderer.rasterLengthToLogical(@floatFromInt(pc.height)))),
        );
        defer renderer_clip_host.endClip(renderer);
        draw_ops.drawTextureRectImmediate(renderer, tex, source_rect, dest, img.tint, img.bg_rgba, .rgba);
        return true;
    }
    draw_ops.drawTextureRectImmediate(renderer, tex, source_rect, dest, img.tint, img.bg_rgba, .rgba);
    return true;
}

fn textureFromGpuImageHandle(texture: surface_draw.GpuImageRef) types.Texture {
    return .{
        .id = @intCast(texture.handle),
        .width = texture.width,
        .height = texture.height,
    };
}

fn gpuImageRefFromTexture(texture: types.Texture) surface_draw.GpuImageRef {
    return .{
        .handle = texture.id,
        .width = texture.width,
        .height = texture.height,
    };
}

pub fn addTerminalRect(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
    draw_ops.addTerminalRect(renderer, x, y, w, h, color);
}

pub fn addTerminalGlyphRect(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
    renderer.terminal_text.glyph_cache.addRect(whiteTexture(renderer), x, y, w, h, color);
}

pub fn addTerminalGlyphQuad(
    renderer: anytype,
    texture: types.Texture,
    src: types.Rect,
    dest: types.Rect,
    color: types.Rgba,
    bg_rgba: types.Rgba,
    kind: types.TextureKind,
) void {
    renderer.terminal_text.glyph_cache.addQuad(texture, src, dest, color, bg_rgba, kind);
}

pub fn createPersistentImageFromRgba(_: anytype, width: i32, height: i32, data: []const u8) ?surface_draw.GpuImageRef {
    const texture = texture_utils.createTextureFromRgba(width, height, data, gl.c.GL_LINEAR) orelse return null;
    return gpuImageRefFromTexture(texture);
}

pub fn createPersistentImageFromRgb(_: anytype, width: i32, height: i32, data: []const u8) ?surface_draw.GpuImageRef {
    const texture = texture_utils.createTextureFromRgb(width, height, data, gl.c.GL_LINEAR) orelse return null;
    return gpuImageRefFromTexture(texture);
}

pub fn destroyPersistentImage(_: anytype, texture: *surface_draw.GpuImageRef) void {
    var gl_texture = textureFromGpuImageHandle(texture.*);
    texture_utils.destroyTexture(&gl_texture);
    texture.* = .{ .handle = 0, .width = 0, .height = 0 };
}

pub fn drawPersistentImage(renderer: anytype, texture: surface_draw.GpuImageRef, source_rect: ?types.Rect, dest: types.Rect, tint: types.Rgba) bool {
    return recordSurfaceDrawForSurfacePhase(renderer, .{ .raw_image = .{
        .texture = texture,
        .source_rect = source_rect,
        .dest_rect = .{
            .x = renderer.logicalLengthToRaster(dest.x),
            .y = renderer.logicalLengthToRaster(dest.y),
            .width = renderer.logicalLengthToRaster(dest.width),
            .height = renderer.logicalLengthToRaster(dest.height),
        },
        .tint = tint,
        .clip_rect = if (renderer.currentClipRect()) |clip_logical|
            metal_text_sample_runtime.pixelClipRect(renderer, clip_logical)
        else
            null,
    } });
}

pub fn applyClipRect(renderer: anytype, clip: ?types.Rect) void {
    const active_clip = clip orelse {
        gl.Disable(gl.c.GL_SCISSOR_TEST);
        return;
    };
    if (active_clip.width <= 0 or active_clip.height <= 0) {
        gl.Enable(gl.c.GL_SCISSOR_TEST);
        gl.Scissor(0, 0, 0, 0);
        return;
    }
    gl.Enable(gl.c.GL_SCISSOR_TEST);
    const scale_x = @as(f32, @floatFromInt(renderer.target_pixel_width)) / @as(f32, @floatFromInt(renderer.target_width));
    const scale_y = @as(f32, @floatFromInt(renderer.target_pixel_height)) / @as(f32, @floatFromInt(renderer.target_height));
    const sx: i32 = @intFromFloat(active_clip.x * scale_x);
    const sy: i32 = @intFromFloat((@as(f32, @floatFromInt(renderer.target_height)) - (active_clip.y + active_clip.height)) * scale_y);
    const sw: i32 = @intFromFloat(active_clip.width * scale_x);
    const sh: i32 = @intFromFloat(active_clip.height * scale_y);
    const log = app_logger.logger("renderer.terminal_present");
    if (log.enabled_file or log.enabled_console) {
        log.logf(
            .info,
            "clip logical={d},{d} {d}x{d} scissor={d},{d} {d}x{d} target_logical={d}x{d} target_px={d}x{d} scale={d:.3},{d:.3}",
            .{
                @as(i32, @intFromFloat(active_clip.x)),
                @as(i32, @intFromFloat(active_clip.y)),
                @as(i32, @intFromFloat(active_clip.width)),
                @as(i32, @intFromFloat(active_clip.height)),
                sx,
                sy,
                sw,
                sh,
                renderer.target_width,
                renderer.target_height,
                renderer.target_pixel_width,
                renderer.target_pixel_height,
                scale_x,
                scale_y,
            },
        );
    }
    gl.Scissor(sx, sy, sw, sh);
}

pub fn bindBatchPipeline(renderer: anytype) void {
    gl.UseProgram(renderer.backend.runtime.openglState().resources.shader_program);
    gl.BindVertexArray(renderer.backend.runtime.openglState().resources.vao);
    gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, renderer.backend.runtime.openglState().resources.vbo);
}

pub fn setTextureKind(renderer: anytype, kind: types.TextureKind) void {
    if (renderer.backend.runtime.openglState().resources.uniform_kind >= 0) {
        gl.Uniform1i(renderer.backend.runtime.openglState().resources.uniform_kind, @intFromEnum(kind));
    }
}

pub fn ensureVboCapacity(renderer: anytype, vertex_count: usize, vertex_size: usize) void {
    if (vertex_count <= renderer.backend.runtime.openglState().resources.vbo_capacity_vertices) return;
    var next_cap = renderer.backend.runtime.openglState().resources.vbo_capacity_vertices * 2;
    if (next_cap < 6) next_cap = 6;
    if (next_cap < vertex_count) next_cap = vertex_count;
    gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, renderer.backend.runtime.openglState().resources.vbo);
    gl.BufferData(
        gl.c.GL_ARRAY_BUFFER,
        @as(gl.GLsizeiptr, @intCast(vertex_size * next_cap)),
        null,
        gl.c.GL_DYNAMIC_DRAW,
    );
    renderer.backend.runtime.openglState().resources.vbo_capacity_vertices = next_cap;
}

pub fn syncTextRenderConfig(renderer: anytype) void {
    if (!renderer.text_render.config_dirty) return;
    if (renderer.backend.runtime.openglState().resources.shader_program == 0) return;
    gl.UseProgram(renderer.backend.runtime.openglState().resources.shader_program);
    if (renderer.backend.runtime.openglState().resources.uniform_text_gamma >= 0) {
        gl.Uniform1f(renderer.backend.runtime.openglState().resources.uniform_text_gamma, renderer.text_render.gamma);
    }
    if (renderer.backend.runtime.openglState().resources.uniform_text_contrast >= 0) {
        gl.Uniform1f(renderer.backend.runtime.openglState().resources.uniform_text_contrast, renderer.text_render.contrast);
    }
    if (renderer.backend.runtime.openglState().resources.uniform_linear_correction >= 0) {
        gl.Uniform1i(renderer.backend.runtime.openglState().resources.uniform_linear_correction, if (renderer.text_render.linear_correction) 1 else 0);
    }
    renderer.text_render.config_dirty = false;
}

fn deinitPresentables(renderer: anytype) void {
    destroyRenderTarget(&renderer.backend.runtime.openglState().targets.presentable_targets.terminal);
    destroyRenderTarget(&renderer.backend.runtime.openglState().targets.presentable_targets.terminal_scroll);
}

fn srgbToLinear(c: f32) f32 {
    if (c <= 0.04045) return c / 12.92;
    return std.math.pow(f32, (c + 0.055) / 1.055, 2.4);
}

fn noteSceneTargetRecreateFailure(renderer: anytype) void {
    renderer.backend.runtime.openglState().targets.scene_target.invalidation.target_recreate_failure = true;
    renderer.backend.runtime.openglState().targets.scene_target.ready = false;
    scene_target_state.logState(
        app_logger.logger("renderer.scene_target"),
        "recreate_failed",
        renderer.backend.runtime.openglState().targets.scene_target.contract,
        renderer.backend.runtime.openglState().targets.scene_target.invalidation,
        renderer.backend.runtime.openglState().targets.scene_target.ready,
    );
}

fn clearSceneTargetInvalidation(renderer: anytype) void {
    renderer.backend.runtime.openglState().targets.scene_target.invalidation = .{};
    renderer.backend.runtime.openglState().targets.scene_target.ready = true;
    scene_target_state.logState(
        app_logger.logger("renderer.scene_target"),
        "ready",
        renderer.backend.runtime.openglState().targets.scene_target.contract,
        renderer.backend.runtime.openglState().targets.scene_target.invalidation,
        renderer.backend.runtime.openglState().targets.scene_target.ready,
    );
}

fn ensureSceneTarget(renderer: anytype, filter: i32) bool {
    const contract: SceneTargetContract = renderer.backend.runtime.openglState().targets.scene_target.contract;
    if (contract.logical_width <= 0 or contract.logical_height <= 0 or
        contract.drawable_width <= 0 or contract.drawable_height <= 0)
    {
        noteSceneTargetRecreateFailure(renderer);
        return false;
    }

    const recreated = ensureRenderTargetScaledForRenderer(
        renderer,
        &renderer.backend.runtime.openglState().targets.scene_target.target,
        contract.logical_width,
        contract.logical_height,
        filter,
    );
    if (renderer.backend.runtime.openglState().targets.scene_target.target == null) {
        noteSceneTargetRecreateFailure(renderer);
        return false;
    }
    if (recreated or !renderer.backend.runtime.openglState().targets.scene_target.ready) {
        clearSceneTargetInvalidation(renderer);
    }
    return recreated;
}

pub fn initGlResources(renderer: anytype) !void {
    const vertex_src =
        "#version 330 core\n" ++
        "layout (location = 0) in vec2 a_pos;\n" ++
        "layout (location = 1) in vec2 a_uv;\n" ++
        "layout (location = 2) in vec4 a_color;\n" ++
        "layout (location = 3) in vec4 a_bg_color;\n" ++
        "out vec2 v_uv;\n" ++
        "out vec4 v_color;\n" ++
        "out vec4 v_bg_color;\n" ++
        "uniform mat4 u_proj;\n" ++
        "void main() {\n" ++
        "    v_uv = a_uv;\n" ++
        "    v_color = a_color;\n" ++
        "    v_bg_color = a_bg_color;\n" ++
        "    gl_Position = u_proj * vec4(a_pos, 0.0, 1.0);\n" ++
        "}\n";
    const fragment_src =
        "#version 330 core\n" ++
        "in vec2 v_uv;\n" ++
        "in vec4 v_color;\n" ++
        "in vec4 v_bg_color;\n" ++
        "out vec4 frag_color;\n" ++
        "uniform sampler2D u_tex;\n" ++
        "uniform int u_kind;\n" ++
        "uniform int u_dst_linear;\n" ++
        "uniform int u_linear_correction;\n" ++
        "uniform float u_text_gamma;\n" ++
        "uniform float u_text_contrast;\n" ++
        "vec3 srgb_to_linear(vec3 c) {\n" ++
        "    bvec3 cutoff = lessThanEqual(c, vec3(0.04045));\n" ++
        "    vec3 higher = pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4));\n" ++
        "    vec3 lower = c / vec3(12.92);\n" ++
        "    return mix(higher, lower, cutoff);\n" ++
        "}\n" ++
        "vec3 linear_to_srgb(vec3 c) {\n" ++
        "    bvec3 cutoff = lessThanEqual(c, vec3(0.0031308));\n" ++
        "    vec3 higher = pow(c, vec3(1.0 / 2.4)) * vec3(1.055) - vec3(0.055);\n" ++
        "    vec3 lower = c * vec3(12.92);\n" ++
        "    return mix(higher, lower, cutoff);\n" ++
        "}\n" ++
        "float luminance(vec3 c) {\n" ++
        "    return dot(c, vec3(0.2126, 0.7152, 0.0722));\n" ++
        "}\n" ++
        "float linear_to_srgb_1(float v) {\n" ++
        "    return v <= 0.0031308 ? v * 12.92 : pow(v, 1.0 / 2.4) * 1.055 - 0.055;\n" ++
        "}\n" ++
        "float srgb_to_linear_1(float v) {\n" ++
        "    return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4);\n" ++
        "}\n" ++
        "vec4 unlinearize_premul(vec4 c) {\n" ++
        "    if (c.a <= 0.0) return vec4(0.0);\n" ++
        "    vec3 rgb = c.rgb / vec3(c.a);\n" ++
        "    rgb = linear_to_srgb(rgb);\n" ++
        "    return vec4(rgb * c.a, c.a);\n" ++
        "}\n" ++
        "void main() {\n" ++
        "    vec4 tex = texture(u_tex, v_uv);\n" ++
        "    if (u_kind == 1) {\n" ++
        "        // Font coverage atlas. Sample the mask and apply it as alpha.\n" ++
        "        float mask = tex.r;\n" ++
        "        mask = pow(mask, u_text_gamma);\n" ++
        "        mask = clamp(mask * u_text_contrast, 0.0, 1.0);\n" ++
        "        vec4 color = v_color;\n" ++
        "        float cov = mask;\n" ++
        "        if (u_dst_linear != 0) {\n" ++
        "            color.rgb = srgb_to_linear(color.rgb);\n" ++
        "        }\n" ++
        "        if (u_dst_linear != 0 && u_linear_correction != 0 && v_bg_color.a > 0.0) {\n" ++
        "            vec3 bg = srgb_to_linear(v_bg_color.rgb);\n" ++
        "            float fg_l = luminance(color.rgb);\n" ++
        "            float bg_l = luminance(bg);\n" ++
        "            if (abs(fg_l - bg_l) > 0.001) {\n" ++
        "                float blend_l = srgb_to_linear_1(linear_to_srgb_1(fg_l) * cov + linear_to_srgb_1(bg_l) * (1.0 - cov));\n" ++
        "                cov = clamp((blend_l - bg_l) / (fg_l - bg_l), 0.0, 1.0);\n" ++
        "            }\n" ++
        "        }\n" ++
        "        float a = cov * v_color.a;\n" ++
        "        // Premultiplied output for correct edge blending.\n" ++
        "        vec4 outc = vec4(color.rgb * a, a);\n" ++
        "        if (u_dst_linear == 0) {\n" ++
        "            outc = unlinearize_premul(outc);\n" ++
        "        }\n" ++
        "        frag_color = outc;\n" ++
        "    } else if (u_kind == 2) {\n" ++
        "        // Linear premultiplied source (e.g. offscreen targets).\n" ++
        "        vec4 outc = tex;\n" ++
        "        if (u_dst_linear == 0) {\n" ++
        "            outc = unlinearize_premul(outc);\n" ++
        "        }\n" ++
        "        frag_color = outc;\n" ++
        "    } else {\n" ++
        "        if (u_dst_linear != 0) {\n" ++
        "            vec4 col = v_color;\n" ++
        "            col.rgb = srgb_to_linear(col.rgb);\n" ++
        "            tex.rgb = srgb_to_linear(tex.rgb);\n" ++
        "            frag_color = tex * col;\n" ++
        "        } else {\n" ++
        "            frag_color = tex * v_color;\n" ++
        "        }\n" ++
        "    }\n" ++
        "}\n";

    const vert = try compileShader(gl.c.GL_VERTEX_SHADER, vertex_src);
    defer gl.DeleteShader(vert);
    const frag = try compileShader(gl.c.GL_FRAGMENT_SHADER, fragment_src);
    defer gl.DeleteShader(frag);
    const program = try linkProgram(vert, frag);
    renderer.backend.runtime.openglState().resources.shader_program = program;
    gl.UseProgram(program);

    renderer.backend.runtime.openglState().resources.uniform_proj = gl.GetUniformLocation(program, "u_proj");
    renderer.backend.runtime.openglState().resources.uniform_tex = gl.GetUniformLocation(program, "u_tex");
    renderer.backend.runtime.openglState().resources.uniform_kind = gl.GetUniformLocation(program, "u_kind");
    renderer.backend.runtime.openglState().resources.uniform_dst_linear = gl.GetUniformLocation(program, "u_dst_linear");
    renderer.backend.runtime.openglState().resources.uniform_linear_correction = gl.GetUniformLocation(program, "u_linear_correction");
    renderer.backend.runtime.openglState().resources.uniform_text_gamma = gl.GetUniformLocation(program, "u_text_gamma");
    renderer.backend.runtime.openglState().resources.uniform_text_contrast = gl.GetUniformLocation(program, "u_text_contrast");
    if (renderer.backend.runtime.openglState().resources.uniform_tex >= 0) gl.Uniform1i(renderer.backend.runtime.openglState().resources.uniform_tex, 0);
    if (renderer.backend.runtime.openglState().resources.uniform_kind >= 0) gl.Uniform1i(renderer.backend.runtime.openglState().resources.uniform_kind, 0);
    if (renderer.backend.runtime.openglState().resources.uniform_dst_linear >= 0) gl.Uniform1i(renderer.backend.runtime.openglState().resources.uniform_dst_linear, 0);
    if (renderer.backend.runtime.openglState().resources.uniform_linear_correction >= 0) gl.Uniform1i(renderer.backend.runtime.openglState().resources.uniform_linear_correction, if (renderer.text_render.linear_correction) 1 else 0);

    // Coverage tuning (applies only to font coverage atlas).
    if (renderer.backend.runtime.openglState().resources.uniform_text_gamma >= 0) gl.Uniform1f(renderer.backend.runtime.openglState().resources.uniform_text_gamma, clampPositive(renderer.text_render.gamma, 1.0));
    if (renderer.backend.runtime.openglState().resources.uniform_text_contrast >= 0) gl.Uniform1f(renderer.backend.runtime.openglState().resources.uniform_text_contrast, clampPositive(renderer.text_render.contrast, 1.0));

    gl.GenVertexArrays(1, &renderer.backend.runtime.openglState().resources.vao);
    gl.GenBuffers(1, &renderer.backend.runtime.openglState().resources.vbo);
    gl.BindVertexArray(renderer.backend.runtime.openglState().resources.vao);
    gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, renderer.backend.runtime.openglState().resources.vbo);
    gl.BufferData(
        gl.c.GL_ARRAY_BUFFER,
        gl_resources.computeBufferBytes(@sizeOf(@TypeOf(renderer.batch.vertices.items[0])), 6),
        null,
        gl.c.GL_DYNAMIC_DRAW,
    );
    renderer.backend.runtime.openglState().resources.vbo_capacity_vertices = 6;

    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(0, 2, gl.c.GL_FLOAT, gl.c.GL_FALSE, @sizeOf(@TypeOf(renderer.batch.vertices.items[0])), @ptrFromInt(0));
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(
        1,
        2,
        gl.c.GL_FLOAT,
        gl.c.GL_FALSE,
        @sizeOf(@TypeOf(renderer.batch.vertices.items[0])),
        @ptrFromInt(2 * @sizeOf(f32)),
    );
    gl.EnableVertexAttribArray(2);
    gl.VertexAttribPointer(
        2,
        4,
        gl.c.GL_FLOAT,
        gl.c.GL_FALSE,
        @sizeOf(@TypeOf(renderer.batch.vertices.items[0])),
        @ptrFromInt(4 * @sizeOf(f32)),
    );

    gl.EnableVertexAttribArray(3);
    gl.VertexAttribPointer(
        3,
        4,
        gl.c.GL_FLOAT,
        gl.c.GL_FALSE,
        @sizeOf(@TypeOf(renderer.batch.vertices.items[0])),
        @ptrFromInt(8 * @sizeOf(f32)),
    );

    gl.Enable(gl.c.GL_BLEND);
    gl.BlendFunc(gl.c.GL_SRC_ALPHA, gl.c.GL_ONE_MINUS_SRC_ALPHA);
    gl.Disable(gl.c.GL_DEPTH_TEST);
    gl.Disable(gl.c.GL_CULL_FACE);

    renderer.backend.runtime.openglState().resources.white_texture = createSolidTexture(1, 1, .{ 255, 255, 255, 255 });
    updateProjection(renderer, renderer.render_width, renderer.render_height);
}

fn clampPositive(v: f32, fallback: f32) f32 {
    if (std.math.isFinite(v) and v > 0.0) return v;
    return fallback;
}

pub fn bindDefaultTarget(renderer: anytype) void {
    gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, 0);
    renderer.text_render.dst_linear_active = false;
    renderer.target_pixel_width = renderer.render_width;
    renderer.target_pixel_height = renderer.render_height;
    updateProjection(renderer, renderer.width, renderer.height);
    if (renderer.backend.runtime.openglState().resources.uniform_dst_linear >= 0) {
        gl.UseProgram(renderer.backend.runtime.openglState().resources.shader_program);
        gl.Uniform1i(renderer.backend.runtime.openglState().resources.uniform_dst_linear, 0);
    }
}

pub fn beginRenderTarget(renderer: anytype, target: ?RenderTarget) bool {
    if (target) |t| {
        gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, t.fbo);
        renderer.text_render.dst_linear_active = true;
        renderer.target_pixel_width = t.texture.width;
        renderer.target_pixel_height = t.texture.height;
        updateProjection(renderer, t.logical_width, t.logical_height);
        if (renderer.backend.runtime.openglState().resources.uniform_dst_linear >= 0) {
            gl.UseProgram(renderer.backend.runtime.openglState().resources.shader_program);
            gl.Uniform1i(renderer.backend.runtime.openglState().resources.uniform_dst_linear, 1);
        }
        return true;
    }
    return false;
}

pub fn ensureRenderTargetScaledForRenderer(
    renderer: anytype,
    target: *?RenderTarget,
    logical_width: i32,
    logical_height: i32,
    filter: i32,
) bool {
    const scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    const width = @max(1, @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(logical_width)) * scale))));
    const height = @max(1, @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(logical_height)) * scale))));
    return ensureRenderTarget(target, width, height, logical_width, logical_height, filter);
}

pub fn scrollRenderTarget(
    renderer: anytype,
    target: ?RenderTarget,
    scratch: *?RenderTarget,
    dx: i32,
    dy: i32,
    width: i32,
    height: i32,
) bool {
    if (target == null) return false;
    if (dx == 0 and dy == 0) return true;
    const t = target.?;
    if (width <= 0 or height <= 0) return false;
    const abs_dx: i32 = if (dx < 0) -dx else dx;
    const abs_dy: i32 = if (dy < 0) -dy else dy;
    if (abs_dx >= width or abs_dy >= height) return false;
    if (!ensureRenderTarget(
        scratch,
        t.texture.width,
        t.texture.height,
        t.logical_width,
        t.logical_height,
        gl.c.GL_NEAREST,
    )) return false;
    const scratch_target = scratch.* orelse return false;

    const copy_w: i32 = width - abs_dx;
    const copy_h: i32 = height - abs_dy;
    const src_x: i32 = if (dx > 0) dx else 0;
    const src_y: i32 = if (dy > 0) dy else 0;
    const dst_x: i32 = if (dx > 0) 0 else -dx;
    const dst_y: i32 = if (dy > 0) 0 else -dy;

    gl.BindFramebuffer(gl.c.GL_READ_FRAMEBUFFER, t.fbo);
    gl.BindFramebuffer(gl.c.GL_DRAW_FRAMEBUFFER, scratch_target.fbo);
    gl.BlitFramebuffer(
        src_x,
        src_y,
        src_x + copy_w,
        src_y + copy_h,
        dst_x,
        dst_y,
        dst_x + copy_w,
        dst_y + copy_h,
        gl.c.GL_COLOR_BUFFER_BIT,
        gl.c.GL_NEAREST,
    );

    gl.BindFramebuffer(gl.c.GL_READ_FRAMEBUFFER, scratch_target.fbo);
    gl.BindFramebuffer(gl.c.GL_DRAW_FRAMEBUFFER, t.fbo);
    gl.BlitFramebuffer(
        0,
        0,
        width,
        height,
        0,
        0,
        width,
        height,
        gl.c.GL_COLOR_BUFFER_BIT,
        gl.c.GL_NEAREST,
    );

    gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, t.fbo);
    renderer.target_pixel_width = t.texture.width;
    renderer.target_pixel_height = t.texture.height;
    updateProjection(renderer, t.logical_width, t.logical_height);
    return true;
}

pub fn ensureRenderTarget(target: *?RenderTarget, width: i32, height: i32, logical_width: i32, logical_height: i32, filter: i32) bool {
    if (width <= 0 or height <= 0 or logical_width <= 0 or logical_height <= 0) return false;
    if (target.*) |t| {
        if (t.texture.width == width and t.texture.height == height and t.logical_width == logical_width and t.logical_height == logical_height) return false;
        destroyRenderTarget(target);
    }

    const texture = createTextureEmpty(width, height, filter);
    var fbo: gl.GLuint = 0;
    gl.GenFramebuffers(1, &fbo);
    gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, fbo);
    gl.FramebufferTexture2D(gl.c.GL_FRAMEBUFFER, gl.c.GL_COLOR_ATTACHMENT0, gl.c.GL_TEXTURE_2D, texture.id, 0);
    const status = gl.CheckFramebufferStatus(gl.c.GL_FRAMEBUFFER);
    gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, 0);
    if (status != gl.c.GL_FRAMEBUFFER_COMPLETE) {
        gl.DeleteFramebuffers(1, &fbo);
        gl.DeleteTextures(1, &texture.id);
        return false;
    }

    target.* = .{ .texture = texture, .fbo = fbo, .logical_width = logical_width, .logical_height = logical_height };
    return true;
}

pub fn destroyRenderTarget(target: *?RenderTarget) void {
    if (target.*) |t| {
        gl.DeleteFramebuffers(1, &t.fbo);
        gl.DeleteTextures(1, &t.texture.id);
        target.* = null;
    }
}

pub fn deinitRuntime(renderer: anytype) void {
    clearQueuedSurfaceDraws(renderer);
    renderer.backend.runtime.openglState().queued_surface_draws.deinit(renderer.allocator);
    deinitPresentables(renderer);
    destroyRenderTarget(&renderer.backend.runtime.openglState().targets.scene_target.target);
    if (renderer.backend.runtime.openglState().resources.resources_ready and renderer.backend.runtime.openglState().resources.white_texture.id != 0) {
        gl.DeleteTextures(1, &renderer.backend.runtime.openglState().resources.white_texture.id);
    }
    if (renderer.backend.runtime.openglState().resources.resources_ready) {
        gl_resources.destroy(.{
            .shader_program = renderer.backend.runtime.openglState().resources.shader_program,
            .vao = renderer.backend.runtime.openglState().resources.vao,
            .vbo = renderer.backend.runtime.openglState().resources.vbo,
            .uniform_proj = renderer.backend.runtime.openglState().resources.uniform_proj,
            .uniform_tex = renderer.backend.runtime.openglState().resources.uniform_tex,
        });
    }
    if (renderer.backend.runtime.openglState().context) |context| sdl_api.glDeleteContext(context);
}

pub fn updateProjection(renderer: anytype, width: i32, height: i32) void {
    renderer.target_width = width;
    renderer.target_height = height;
    const viewport_w = if (renderer.target_pixel_width > 0) renderer.target_pixel_width else width;
    const viewport_h = if (renderer.target_pixel_height > 0) renderer.target_pixel_height else height;
    gl.Viewport(0, 0, viewport_w, viewport_h);
    if (renderer.backend.runtime.openglState().resources.uniform_proj >= 0) {
        const w = @as(f32, @floatFromInt(width));
        const h = @as(f32, @floatFromInt(height));
        const proj = [_]f32{
            2.0 / w, 0,        0, 0,
            0,       -2.0 / h, 0, 0,
            0,       0,        1, 0,
            -1,      1,        0, 1,
        };
        gl.UseProgram(renderer.backend.runtime.openglState().resources.shader_program);
        gl.UniformMatrix4fv(renderer.backend.runtime.openglState().resources.uniform_proj, 1, gl.c.GL_FALSE, &proj);
    }
}

fn compileShader(kind: gl.GLenum, source: []const u8) !gl.GLuint {
    const shader = gl.CreateShader(kind);
    const src_ptr: [*]const gl.GLchar = @ptrCast(source.ptr);
    const src_len: gl.GLint = @intCast(source.len);
    const lengths = [_]gl.GLint{src_len};
    gl.ShaderSource(shader, 1, @ptrCast(&src_ptr), @ptrCast(&lengths));
    gl.CompileShader(shader);
    var status: gl.GLint = 0;
    gl.GetShaderiv(shader, gl.c.GL_COMPILE_STATUS, &status);
    if (status == 0) {
        var log_buf: [1024]u8 = undefined;
        var len: gl.GLsizei = 0;
        gl.GetShaderInfoLog(shader, log_buf.len, &len, @ptrCast(&log_buf));
        return error.GlShaderCompileFailed;
    }
    return shader;
}

fn linkProgram(vert: gl.GLuint, frag: gl.GLuint) !gl.GLuint {
    const program = gl.CreateProgram();
    gl.AttachShader(program, vert);
    gl.AttachShader(program, frag);
    gl.LinkProgram(program);
    var status: gl.GLint = 0;
    gl.GetProgramiv(program, gl.c.GL_LINK_STATUS, &status);
    if (status == 0) {
        var log_buf: [1024]u8 = undefined;
        var len: gl.GLsizei = 0;
        gl.GetProgramInfoLog(program, log_buf.len, &len, @ptrCast(&log_buf));
        return error.GlProgramLinkFailed;
    }
    return program;
}

fn createSolidTexture(width: i32, height: i32, rgba: [4]u8) types.Texture {
    var id: gl.GLuint = 0;
    gl.GenTextures(1, &id);
    gl.BindTexture(gl.c.GL_TEXTURE_2D, id);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, gl.c.GL_NEAREST);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, gl.c.GL_NEAREST);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_S, gl.c.GL_CLAMP_TO_EDGE);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_T, gl.c.GL_CLAMP_TO_EDGE);
    gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
    gl.TexImage2D(
        gl.c.GL_TEXTURE_2D,
        0,
        gl.c.GL_RGBA,
        width,
        height,
        0,
        gl.c.GL_RGBA,
        gl.c.GL_UNSIGNED_BYTE,
        &rgba,
    );
    return .{ .id = id, .width = width, .height = height };
}

fn createTextureEmpty(width: i32, height: i32, filter: i32) types.Texture {
    var id: gl.GLuint = 0;
    gl.GenTextures(1, &id);
    gl.BindTexture(gl.c.GL_TEXTURE_2D, id);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, filter);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, filter);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_S, gl.c.GL_CLAMP_TO_EDGE);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_T, gl.c.GL_CLAMP_TO_EDGE);
    gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
    gl.TexImage2D(
        gl.c.GL_TEXTURE_2D,
        0,
        gl.c.GL_RGBA,
        width,
        height,
        0,
        gl.c.GL_RGBA,
        gl.c.GL_UNSIGNED_BYTE,
        null,
    );
    return .{ .id = id, .width = width, .height = height };
}

pub fn drawRawImageRgba(renderer: anytype, width: i32, height: i32, data: []const u8, dest: types.Rect, tint: types.Rgba) bool {
    if (width <= 0 or height <= 0) return false;
    if (@as(usize, @intCast(width * height * 4)) > data.len) return false;
    if (dest.width <= 0 or dest.height <= 0) return false;
    const clip_rect = if (renderer.currentClipRect()) |clip_logical|
        metal_text_sample_runtime.pixelClipRect(renderer, clip_logical)
    else
        null;
    if (clip_rect) |pc| {
        if (pc.width <= 0 or pc.height <= 0) return false;
    }
    const tex = texture_utils.createTextureFromRgba(width, height, data, gl.c.GL_NEAREST) orelse return false;
    if (!enqueueSurfaceDrawForSurfacePhase(renderer, .{ .raw_image = .{
        .texture = .{
            .handle = tex.id,
            .width = tex.width,
            .height = tex.height,
        },
        .source_rect = null,
        .dest_rect = .{
            .x = renderer.logicalLengthToRaster(dest.x),
            .y = renderer.logicalLengthToRaster(dest.y),
            .width = renderer.logicalLengthToRaster(dest.width),
            .height = renderer.logicalLengthToRaster(dest.height),
        },
        .tint = tint,
        .clip_rect = clip_rect,
    } }, true)) {
        var cleanup = tex;
        texture_utils.destroyTexture(&cleanup);
        return false;
    }
    return true;
}

pub fn drawRawImageRgb(renderer: anytype, width: i32, height: i32, data: []const u8, dest: types.Rect, tint: types.Rgba) bool {
    if (width <= 0 or height <= 0) return false;
    if (@as(usize, @intCast(width * height * 3)) > data.len) return false;
    if (dest.width <= 0 or dest.height <= 0) return false;
    const clip_rect = if (renderer.currentClipRect()) |clip_logical|
        metal_text_sample_runtime.pixelClipRect(renderer, clip_logical)
    else
        null;
    if (clip_rect) |pc| {
        if (pc.width <= 0 or pc.height <= 0) return false;
    }
    const tex = texture_utils.createTextureFromRgb(width, height, data, gl.c.GL_NEAREST) orelse return false;
    if (!enqueueSurfaceDrawForSurfacePhase(renderer, .{ .raw_image = .{
        .texture = .{
            .handle = tex.id,
            .width = tex.width,
            .height = tex.height,
        },
        .source_rect = null,
        .dest_rect = .{
            .x = renderer.logicalLengthToRaster(dest.x),
            .y = renderer.logicalLengthToRaster(dest.y),
            .width = renderer.logicalLengthToRaster(dest.width),
            .height = renderer.logicalLengthToRaster(dest.height),
        },
        .tint = tint,
        .clip_rect = clip_rect,
    } }, true)) {
        var cleanup = tex;
        texture_utils.destroyTexture(&cleanup);
        return false;
    }
    return true;
}
