const builtin = @import("builtin");
const bootstrap_contract = @import("bootstrap_contract.zig");
const capability_contract = @import("capability_contract.zig");
const android_gles_runtime = @import("../../platform/android_gles_runtime.zig");
const native_host = @import("../../platform/native_host.zig");
const present_trace_runtime = @import("present_trace_runtime.zig");
const renderer_frame_host = @import("renderer_frame_host.zig");
const scene_target_state = @import("scene_target_state.zig");
const surface_draw = @import("surface_draw.zig");
const types = @import("types.zig");
const window_init = @import("window_init.zig");
const sdl_api = @import("../../platform/sdl_api.zig");

const target_has_android_gles = builtin.target.os.tag == .linux and builtin.target.abi == .android;

const gl = if (target_has_android_gles) struct {
    extern fn glClearColor(red: f32, green: f32, blue: f32, alpha: f32) void;
    extern fn glClear(mask: u32) void;
} else struct {
    fn glClearColor(_: f32, _: f32, _: f32, _: f32) void {
        unreachable;
    }
    fn glClear(_: u32) void {
        unreachable;
    }
};

const GL_COLOR_BUFFER_BIT: u32 = 0x0000_4000;

pub const RendererCapabilities = capability_contract.RendererCapabilities;
pub const SceneTargetInvalidation = scene_target_state.SceneTargetInvalidation;

fn supportsRuntimeProfileForBootstrap(_: bootstrap_contract.RendererRuntimeProfile) bool {
    return false;
}

pub fn bootstrapOps() bootstrap_contract.BackendBootstrapOps {
    return .{
        .graphics_binding = .none,
        .supportsRuntimeProfile = supportsRuntimeProfileForBootstrap,
        .configureWindowAttributes = configureWindowAttributes,
        .runStartupSmoke = runStartupSmokeForBootstrap,
    };
}

pub fn configureWindowAttributes() !void {}

pub fn runStartupSmokeForBootstrap(
    _: *sdl_api.c.SDL_Window,
    _: window_init.RenderSurfaceAttachment,
    _: i32,
    _: i32,
) !bool {
    return error.AndroidGlesBootstrapUnavailable;
}

pub fn capabilities(_: anytype) RendererCapabilities {
    return .{
        .scene_composition_mode = .direct_main_target,
        .retained_targets = false,
        .terminal_presentation_mode = .direct_main_target,
        .screenshot_mode = .unavailable,
        .text_rendering_mode = .unavailable,
        .planned_text_rendering_mode = .gl_texture_atlas,
        .kitty_image_mode = .unsupported,
        .atlas_storage_mode = .opengl_textures,
        .planned_atlas_storage_mode = .opengl_textures,
        .raw_image_textures = false,
    };
}

pub fn initRuntime(renderer: anytype) !void {
    switch (android_gles_runtime.ensureDisplayContext(&renderer.backend.runtime.androidGlesState().runtime)) {
        .ready => {},
        .init_failed => return error.AndroidGlesInitFailed,
        .surface_failed, .make_current_failed, .swap_failed => return error.AndroidGlesInitFailed,
    }
}

pub fn deinitRuntime(renderer: anytype) void {
    android_gles_runtime.reset(&renderer.backend.runtime.androidGlesState().runtime);
}

pub fn configureRuntimePolicy(_: anytype) void {}

pub fn beginFrame(renderer: anytype) void {
    const state = renderer.backend.runtime.androidGlesState();
    renderer.backend.runtime.androidGlesState().frame_begin_count += 1;
    if (!target_has_android_gles and !builtin.is_test) {
        renderer_frame_host.noteFrameBeginFailed(renderer);
        return;
    }

    const native_window = renderer.render_host.androidNativeWindow() orelse {
        renderer_frame_host.noteFrameBeginFailed(renderer);
        return;
    };
    const epoch = renderer.render_host.surfaceIdentityEpoch();
    const transition = runtimeTransition(state.runtime.bound_epoch, epoch, native_window);
    switch (android_gles_runtime.ensureWindowSurface(&state.runtime, native_window, epoch, transition)) {
        .ready => {},
        .init_failed, .surface_failed, .make_current_failed, .swap_failed => {
            renderer_frame_host.noteFrameBeginFailed(renderer);
            return;
        },
    }
    switch (android_gles_runtime.makeCurrent(&state.runtime)) {
        .ready => {},
        .init_failed, .surface_failed, .make_current_failed, .swap_failed => {
            renderer_frame_host.noteFrameBeginFailed(renderer);
            return;
        },
    }

    renderer.present.main_composition_target = .default_target;
    const bg = renderer.theme.background.toRgba();
    if (!builtin.is_test) {
        gl.glClearColor(
            @as(f32, @floatFromInt(bg.r)) / 255.0,
            @as(f32, @floatFromInt(bg.g)) / 255.0,
            @as(f32, @floatFromInt(bg.b)) / 255.0,
            @as(f32, @floatFromInt(bg.a)) / 255.0,
        );
        gl.glClear(GL_COLOR_BUFFER_BIT);
    }
    renderer_frame_host.noteFrameReady(renderer);
}

pub fn submitFrame(renderer: anytype) present_trace_runtime.FrameSubmission {
    const state = renderer.backend.runtime.androidGlesState();
    state.frame_submit_count += 1;
    if (renderer.present.frame_execution_state != .ready) {
        return renderer_frame_host.finishFrameSubmission(renderer, .{
            .kind = switch (renderer.present.frame_execution_state) {
                .begin_failed => .begin_failed,
                .abandoned => .abandoned,
                .not_attempted => .not_attempted,
                .ready => .submit_failed,
            },
            .present_ms = 0,
        });
    }

    const swap_start = sdl_api.getPerformanceCounter();
    const swap_status = android_gles_runtime.swapBuffers(&state.runtime);
    const swap_end = sdl_api.getPerformanceCounter();
    return renderer_frame_host.finishFrameSubmission(renderer, .{
        .kind = if (swap_status == .ready) .submitted else .submit_failed,
        .present_ms = present_trace_runtime.performanceDeltaMs(swap_start, swap_end, renderer.perf_freq),
    });
}

pub fn dumpWindowScreenshotPpm(_: anytype, _: []const u8) !void {
    return error.AndroidGlesScreenshotUnavailable;
}

pub fn dumpWindowScreenshotPpmSized(_: anytype, _: []const u8, _: i32, _: i32) !void {
    return error.AndroidGlesScreenshotUnavailable;
}

pub fn clearDiagnosticFont(_: anytype) void {}

pub fn sceneTargetInvalidationForRefresh(_: anytype, _: anytype, _: anytype) SceneTargetInvalidation {
    return .{};
}

pub fn mergePendingSceneTargetInvalidation(_: anytype, _: SceneTargetInvalidation) void {}

pub fn ensurePresentable(_: anytype, _: i32, _: i32) bool {
    return false;
}

pub fn refreshTerminalPresentable(
    _: anytype,
    _: ?*const anyopaque,
    _: anytype,
) @import("backend_dispatch.zig").TerminalPresentableRefreshResult {
    return .unsupported;
}

pub fn drawPresentableBackdrop(_: anytype, _: f32, _: f32, _: f32, _: f32, _: types.Rgba) void {}

pub fn drawPresentable(_: anytype, _: anytype) void {}

pub fn scrollPresentable(_: anytype, _: i32, _: i32) bool {
    return false;
}

pub fn presentableInfo(_: anytype) ?@import("presentable_contract.zig").PresentableInfo {
    return null;
}

pub fn applyClipRect(_: anytype, _: ?types.Rect) void {}

pub fn addTerminalRect(_: anytype, _: i32, _: i32, _: i32, _: i32, _: types.Rgba) void {}

pub fn addTerminalGlyphRect(_: anytype, _: i32, _: i32, _: i32, _: i32, _: types.Rgba) void {}

pub fn addTerminalGlyphQuad(_: anytype, _: types.Texture, _: types.Rect, _: types.Rect, _: types.Rgba, _: types.TextureKind) void {}

pub fn createPersistentImageFromRgba(_: anytype, _: i32, _: i32, _: []const u8) ?surface_draw.GpuImageRef {
    return null;
}

pub fn createPersistentImageFromRgb(_: anytype, _: i32, _: i32, _: []const u8) ?surface_draw.GpuImageRef {
    return null;
}

pub fn destroyPersistentImage(_: anytype, _: *surface_draw.GpuImageRef) void {}

pub fn drawPersistentImage(_: anytype, _: surface_draw.GpuImageRef, _: ?types.Rect, _: types.Rect, _: types.Rgba) bool {
    return false;
}

pub fn drawRawImage(_: anytype, _: anytype, _: i32, _: i32, _: []const u8, _: types.Rect, _: types.Rgba) bool {
    return false;
}

pub fn recordSurfaceDraw(_: anytype, _: surface_draw.SurfaceDraw) bool {
    return false;
}

fn runtimeTransition(bound_epoch: u64, current_epoch: u64, native_window: ?*anyopaque) native_host.SurfaceIdentityTransition {
    if (native_window == null) return .retired;
    if (bound_epoch == current_epoch) return .unchanged;
    if (bound_epoch == 0) return .acquired;
    return .replaced;
}
