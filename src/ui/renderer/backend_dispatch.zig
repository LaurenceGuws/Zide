const builtin = @import("builtin");
const bootstrap_contract = @import("bootstrap_contract.zig");
const std = @import("std");
const backend_runtime_bundle = @import("backend_runtime_bundle.zig");
const types = @import("types.zig");
const gl_backend = @import("gl_backend.zig");
const gl_clip_runtime = @import("gl_clip_runtime.zig");
const gl_presentable_runtime = @import("gl_presentable_runtime.zig");
const opengl_runtime_state = @import("opengl_runtime_state.zig");
const gl_surface_runtime = @import("gl_surface_runtime.zig");
const android_gles_backend = @import("android_gles_backend.zig");
const metal_backend = @import("metal_backend.zig");
const metal_clip_runtime = @import("metal_clip_runtime.zig");
const metal_presentable_runtime = @import("metal_presentable_runtime.zig");
const metal_runtime_state = @import("metal_runtime_state.zig");
const metal_surface_runtime = @import("metal_surface_runtime.zig");
const renderer_frame_host = @import("renderer_frame_host.zig");
const surface_draw = @import("surface_draw.zig");
const window_init = @import("window_init.zig");
const platform_window = @import("../../platform/window_metrics.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const GpuImageRef = surface_draw.GpuImageRef;
const target_has_desktop_backends = !(builtin.target.os.tag == .linux and builtin.target.abi == .android);

pub const TerminalPresentableRefreshResult = enum {
    refreshed,
    target_unavailable,
    unsupported,
};

pub fn BackendOps(
    comptime RendererType: type,
    comptime FrameSubmission: type,
    comptime RendererCapabilities: type,
    comptime PresentableDraw: type,
    comptime PresentableInfo: type,
    comptime RawImageFormat: type,
    comptime SceneTargetInvalidation: type,
    comptime WindowChangeMask: type,
) type {
    const RuntimeOps = struct {
        initStorage: *const fn (std.mem.Allocator) anyerror!backend_runtime_bundle.Bundle,
        deinitStorage: *const fn (*backend_runtime_bundle.Bundle, std.mem.Allocator) void,
        initRuntime: *const fn (*RendererType) anyerror!void,
        deinitRuntime: *const fn (*RendererType) void,
        configureRuntimePolicy: *const fn (*RendererType) void,
        capabilities: *const fn (*const RendererType) RendererCapabilities,
        clearDiagnosticFont: *const fn (*RendererType) void,
        sceneTargetInvalidationForRefresh: *const fn (*RendererType, WindowChangeMask, platform_window.DisplayMetrics) SceneTargetInvalidation,
        mergePendingSceneTargetInvalidation: *const fn (*RendererType, SceneTargetInvalidation) void,
    };

    const FrameOps = struct {
        beginFrame: *const fn (*RendererType) void,
        submitFrame: *const fn (*RendererType) FrameSubmission,
        dumpWindowScreenshotPpm: *const fn (*RendererType, []const u8) anyerror!void,
        dumpWindowScreenshotPpmSized: *const fn (*RendererType, []const u8, i32, i32) anyerror!void,
    };

    const PresentableOps = struct {
        ensurePresentable: *const fn (*RendererType, i32, i32) bool,
        refreshTerminalPresentable: *const fn (*RendererType, ?*const anyopaque, *const fn (?*const anyopaque, *RendererType) void) TerminalPresentableRefreshResult,
        drawPresentableBackdrop: *const fn (*RendererType, f32, f32, f32, f32, types.Rgba) void,
        drawPresentable: *const fn (*RendererType, PresentableDraw) void,
        scrollPresentable: *const fn (*RendererType, i32, i32) bool,
        presentableInfo: *const fn (*RendererType) ?PresentableInfo,
    };

    const ClipOps = struct {
        applyClipRect: *const fn (*RendererType, ?types.Rect) void,
    };

    const TerminalDrawOps = struct {
        addTerminalRect: *const fn (*RendererType, i32, i32, i32, i32, types.Rgba) void,
        addTerminalGlyphRect: *const fn (*RendererType, i32, i32, i32, i32, types.Rgba) void,
        addTerminalGlyphQuad: *const fn (*RendererType, types.Texture, types.Rect, types.Rect, types.Rgba, types.TextureKind) void,
    };

    const ImageDrawOps = struct {
        createPersistentImageFromRgba: *const fn (*RendererType, i32, i32, []const u8) ?GpuImageRef,
        createPersistentImageFromRgb: *const fn (*RendererType, i32, i32, []const u8) ?GpuImageRef,
        destroyPersistentImage: *const fn (*RendererType, *GpuImageRef) void,
        drawPersistentImage: *const fn (*RendererType, GpuImageRef, ?types.Rect, types.Rect, types.Rgba) bool,
        drawRawImage: *const fn (*RendererType, RawImageFormat, i32, i32, []const u8, types.Rect, types.Rgba) bool,
    };

    const SurfaceOps = struct {
        recordSurfaceDraw: *const fn (*RendererType, surface_draw.SurfaceDraw) bool,
    };

    return struct {
        runtime: RuntimeOps,
        frame: FrameOps,
        presentable: PresentableOps,
        clip: ClipOps,
        terminal_draw: TerminalDrawOps,
        image_draw: ImageDrawOps,
        surface: SurfaceOps,
    };
}

pub fn opsFor(
    comptime RendererType: type,
    comptime BackendEnum: type,
    comptime FrameSubmission: type,
    comptime RendererCapabilities: type,
    comptime PresentableDraw: type,
    comptime PresentableInfo: type,
    comptime RawImageFormat: type,
    comptime SceneTargetInvalidation: type,
    comptime WindowChangeMask: type,
    backend: BackendEnum,
) BackendOps(
    RendererType,
    FrameSubmission,
    RendererCapabilities,
    PresentableDraw,
    PresentableInfo,
    RawImageFormat,
    SceneTargetInvalidation,
    WindowChangeMask,
) {
    const OpenGl = if (target_has_desktop_backends)
        OpenGlDispatch(
            RendererType,
            FrameSubmission,
            RendererCapabilities,
            PresentableDraw,
            PresentableInfo,
            RawImageFormat,
            SceneTargetInvalidation,
            WindowChangeMask,
        )
    else
        UnavailableDesktopDispatch(
            RendererType,
            FrameSubmission,
            RendererCapabilities,
            PresentableDraw,
            PresentableInfo,
            RawImageFormat,
            SceneTargetInvalidation,
            WindowChangeMask,
            .opengl,
        );
    const Metal = if (target_has_desktop_backends)
        MetalDispatch(
            RendererType,
            FrameSubmission,
            RendererCapabilities,
            PresentableDraw,
            PresentableInfo,
            RawImageFormat,
            SceneTargetInvalidation,
            WindowChangeMask,
        )
    else
        UnavailableDesktopDispatch(
            RendererType,
            FrameSubmission,
            RendererCapabilities,
            PresentableDraw,
            PresentableInfo,
            RawImageFormat,
            SceneTargetInvalidation,
            WindowChangeMask,
            .metal,
        );
    const AndroidGles = AndroidGlesDispatch(
        RendererType,
        FrameSubmission,
        RendererCapabilities,
        PresentableDraw,
        PresentableInfo,
        RawImageFormat,
        SceneTargetInvalidation,
        WindowChangeMask,
    );

    return switch (backend) {
        .opengl => .{
            .runtime = .{
                .initStorage = OpenGl.initStorage,
                .deinitStorage = OpenGl.deinitStorage,
                .initRuntime = OpenGl.initRuntime,
                .deinitRuntime = OpenGl.deinitRuntime,
                .configureRuntimePolicy = OpenGl.configureRuntimePolicy,
                .capabilities = OpenGl.capabilities,
                .clearDiagnosticFont = OpenGl.clearDiagnosticFont,
                .sceneTargetInvalidationForRefresh = OpenGl.sceneTargetInvalidationForRefresh,
                .mergePendingSceneTargetInvalidation = OpenGl.mergePendingSceneTargetInvalidation,
            },
            .frame = .{
                .beginFrame = OpenGl.beginFrame,
                .submitFrame = OpenGl.submitFrame,
                .dumpWindowScreenshotPpm = OpenGl.dumpWindowScreenshotPpm,
                .dumpWindowScreenshotPpmSized = OpenGl.dumpWindowScreenshotPpmSized,
            },
            .presentable = .{
                .ensurePresentable = OpenGl.ensurePresentable,
                .refreshTerminalPresentable = OpenGl.refreshTerminalPresentable,
                .drawPresentableBackdrop = OpenGl.drawPresentableBackdrop,
                .drawPresentable = OpenGl.drawPresentable,
                .scrollPresentable = OpenGl.scrollPresentable,
                .presentableInfo = OpenGl.presentableInfo,
            },
            .clip = .{
                .applyClipRect = OpenGl.applyClipRect,
            },
            .terminal_draw = .{
                .addTerminalRect = OpenGl.addTerminalRect,
                .addTerminalGlyphRect = OpenGl.addTerminalGlyphRect,
                .addTerminalGlyphQuad = OpenGl.addTerminalGlyphQuad,
            },
            .image_draw = .{
                .createPersistentImageFromRgba = OpenGl.createPersistentImageFromRgba,
                .createPersistentImageFromRgb = OpenGl.createPersistentImageFromRgb,
                .destroyPersistentImage = OpenGl.destroyPersistentImage,
                .drawPersistentImage = OpenGl.drawPersistentImage,
                .drawRawImage = OpenGl.drawRawImage,
            },
            .surface = .{
                .recordSurfaceDraw = OpenGl.recordSurfaceDraw,
            },
        },
        .metal => .{
            .runtime = .{
                .initStorage = Metal.initStorage,
                .deinitStorage = Metal.deinitStorage,
                .initRuntime = Metal.initRuntime,
                .deinitRuntime = Metal.deinitRuntime,
                .configureRuntimePolicy = Metal.configureRuntimePolicy,
                .capabilities = Metal.capabilities,
                .clearDiagnosticFont = Metal.clearDiagnosticFont,
                .sceneTargetInvalidationForRefresh = Metal.sceneTargetInvalidationForRefresh,
                .mergePendingSceneTargetInvalidation = Metal.mergePendingSceneTargetInvalidation,
            },
            .frame = .{
                .beginFrame = Metal.beginFrame,
                .submitFrame = Metal.submitFrame,
                .dumpWindowScreenshotPpm = Metal.dumpWindowScreenshotPpm,
                .dumpWindowScreenshotPpmSized = Metal.dumpWindowScreenshotPpmSized,
            },
            .presentable = .{
                .ensurePresentable = Metal.ensurePresentable,
                .refreshTerminalPresentable = Metal.refreshTerminalPresentable,
                .drawPresentableBackdrop = Metal.drawPresentableBackdrop,
                .drawPresentable = Metal.drawPresentable,
                .scrollPresentable = Metal.scrollPresentable,
                .presentableInfo = Metal.presentableInfo,
            },
            .clip = .{
                .applyClipRect = Metal.applyClipRect,
            },
            .terminal_draw = .{
                .addTerminalRect = Metal.addTerminalRect,
                .addTerminalGlyphRect = Metal.addTerminalGlyphRect,
                .addTerminalGlyphQuad = Metal.addTerminalGlyphQuad,
            },
            .image_draw = .{
                .createPersistentImageFromRgba = Metal.createPersistentImageFromRgba,
                .createPersistentImageFromRgb = Metal.createPersistentImageFromRgb,
                .destroyPersistentImage = Metal.destroyPersistentImage,
                .drawPersistentImage = Metal.drawPersistentImage,
                .drawRawImage = Metal.drawRawImage,
            },
            .surface = .{
                .recordSurfaceDraw = Metal.recordSurfaceDraw,
            },
        },
        .android_gles => .{
            .runtime = .{
                .initStorage = AndroidGles.initStorage,
                .deinitStorage = AndroidGles.deinitStorage,
                .initRuntime = AndroidGles.initRuntime,
                .deinitRuntime = AndroidGles.deinitRuntime,
                .configureRuntimePolicy = AndroidGles.configureRuntimePolicy,
                .capabilities = AndroidGles.capabilities,
                .clearDiagnosticFont = AndroidGles.clearDiagnosticFont,
                .sceneTargetInvalidationForRefresh = AndroidGles.sceneTargetInvalidationForRefresh,
                .mergePendingSceneTargetInvalidation = AndroidGles.mergePendingSceneTargetInvalidation,
            },
            .frame = .{
                .beginFrame = AndroidGles.beginFrame,
                .submitFrame = AndroidGles.submitFrame,
                .dumpWindowScreenshotPpm = AndroidGles.dumpWindowScreenshotPpm,
                .dumpWindowScreenshotPpmSized = AndroidGles.dumpWindowScreenshotPpmSized,
            },
            .presentable = .{
                .ensurePresentable = AndroidGles.ensurePresentable,
                .refreshTerminalPresentable = AndroidGles.refreshTerminalPresentable,
                .drawPresentableBackdrop = AndroidGles.drawPresentableBackdrop,
                .drawPresentable = AndroidGles.drawPresentable,
                .scrollPresentable = AndroidGles.scrollPresentable,
                .presentableInfo = AndroidGles.presentableInfo,
            },
            .clip = .{
                .applyClipRect = AndroidGles.applyClipRect,
            },
            .terminal_draw = .{
                .addTerminalRect = AndroidGles.addTerminalRect,
                .addTerminalGlyphRect = AndroidGles.addTerminalGlyphRect,
                .addTerminalGlyphQuad = AndroidGles.addTerminalGlyphQuad,
            },
            .image_draw = .{
                .createPersistentImageFromRgba = AndroidGles.createPersistentImageFromRgba,
                .createPersistentImageFromRgb = AndroidGles.createPersistentImageFromRgb,
                .destroyPersistentImage = AndroidGles.destroyPersistentImage,
                .drawPersistentImage = AndroidGles.drawPersistentImage,
                .drawRawImage = AndroidGles.drawRawImage,
            },
            .surface = .{
                .recordSurfaceDraw = AndroidGles.recordSurfaceDraw,
            },
        },
    };
}

pub fn bootstrapOpsFor(comptime BackendEnum: type, backend: BackendEnum) bootstrap_contract.BackendBootstrapOps {
    return switch (backend) {
        .opengl => if (target_has_desktop_backends)
            gl_backend.bootstrapOps()
        else
            unavailableDesktopBootstrapOps(),
        .metal => if (target_has_desktop_backends)
            metal_backend.bootstrapOps()
        else
            unavailableDesktopBootstrapOps(),
        .android_gles => android_gles_backend.bootstrapOps(),
    };
}

fn desktopBootstrapUnavailable(_: bootstrap_contract.RendererRuntimeProfile) bool {
    return false;
}

fn unavailableDesktopConfigureWindowAttributes() !void {
    return error.RendererBackendUnavailable;
}

fn unavailableDesktopRunStartupSmoke(
    _: *sdl_api.c.SDL_Window,
    _: window_init.RenderSurfaceAttachment,
    _: i32,
    _: i32,
) !bool {
    return error.RendererBackendUnavailable;
}

fn unavailableDesktopBootstrapOps() bootstrap_contract.BackendBootstrapOps {
    return .{
        .graphics_binding = .none,
        .supportsRuntimeProfile = desktopBootstrapUnavailable,
        .configureWindowAttributes = unavailableDesktopConfigureWindowAttributes,
        .runStartupSmoke = unavailableDesktopRunStartupSmoke,
    };
}

fn UnavailableDesktopDispatch(
    comptime RendererType: type,
    comptime FrameSubmission: type,
    comptime RendererCapabilities: type,
    comptime PresentableDraw: type,
    comptime PresentableInfo: type,
    comptime RawImageFormat: type,
    comptime SceneTargetInvalidation: type,
    comptime WindowChangeMask: type,
    comptime desktop_backend: anytype,
) type {
    return struct {
        fn initStorage(allocator: std.mem.Allocator) !backend_runtime_bundle.Bundle {
            const storage = if (desktop_backend == .opengl)
                try allocator.create(opengl_runtime_state.State)
            else
                try allocator.create(metal_runtime_state.State);
            storage.* = .{};
            return .{ .storage = storage };
        }
        fn deinitStorage(bundle: *backend_runtime_bundle.Bundle, allocator: std.mem.Allocator) void {
            const storage = bundle.storage orelse return;
            if (desktop_backend == .opengl) {
                allocator.destroy(@as(*opengl_runtime_state.State, @ptrCast(@alignCast(storage))));
            } else {
                allocator.destroy(@as(*metal_runtime_state.State, @ptrCast(@alignCast(storage))));
            }
            bundle.storage = null;
        }
        fn initRuntime(_: *RendererType) !void {
            return error.RendererBackendUnavailable;
        }
        fn deinitRuntime(_: *RendererType) void {}
        fn configureRuntimePolicy(_: *RendererType) void {}
        fn beginFrame(renderer: *RendererType) void {
            renderer_frame_host.noteFrameBeginFailed(renderer);
        }
        fn submitFrame(renderer: *RendererType) FrameSubmission {
            return renderer_frame_host.finishFrameSubmission(renderer, .{
                .kind = .begin_failed,
                .present_ms = 0,
            });
        }
        fn capabilities(_: *const RendererType) RendererCapabilities {
            return .{
                .scene_composition_mode = .direct_main_target,
                .retained_targets = false,
                .terminal_presentation_mode = .direct_main_target,
                .screenshot_mode = .unavailable,
                .text_rendering_mode = .unavailable,
                .planned_text_rendering_mode = .unavailable,
                .kitty_image_mode = .unsupported,
                .atlas_storage_mode = .opengl_textures,
                .planned_atlas_storage_mode = .opengl_textures,
                .raw_image_textures = false,
            };
        }
        fn dumpWindowScreenshotPpm(_: *RendererType, _: []const u8) !void {
            return error.RendererBackendUnavailable;
        }
        fn dumpWindowScreenshotPpmSized(_: *RendererType, _: []const u8, _: i32, _: i32) !void {
            return error.RendererBackendUnavailable;
        }
        fn ensurePresentable(_: *RendererType, _: i32, _: i32) bool {
            return false;
        }
        fn refreshTerminalPresentable(
            _: *RendererType,
            _: ?*const anyopaque,
            _: *const fn (?*const anyopaque, *RendererType) void,
        ) TerminalPresentableRefreshResult {
            return .unsupported;
        }
        fn drawPresentableBackdrop(_: *RendererType, _: f32, _: f32, _: f32, _: f32, _: types.Rgba) void {}
        fn drawPresentable(_: *RendererType, _: PresentableDraw) void {}
        fn scrollPresentable(_: *RendererType, _: i32, _: i32) bool {
            return false;
        }
        fn presentableInfo(_: *RendererType) ?PresentableInfo {
            return null;
        }
        fn applyClipRect(_: *RendererType, _: ?types.Rect) void {}
        fn addTerminalRect(_: *RendererType, _: i32, _: i32, _: i32, _: i32, _: types.Rgba) void {}
        fn addTerminalGlyphRect(_: *RendererType, _: i32, _: i32, _: i32, _: i32, _: types.Rgba) void {}
        fn addTerminalGlyphQuad(_: *RendererType, _: types.Texture, _: types.Rect, _: types.Rect, _: types.Rgba, _: types.TextureKind) void {}
        fn createPersistentImageFromRgba(_: *RendererType, _: i32, _: i32, _: []const u8) ?GpuImageRef {
            return null;
        }
        fn createPersistentImageFromRgb(_: *RendererType, _: i32, _: i32, _: []const u8) ?GpuImageRef {
            return null;
        }
        fn destroyPersistentImage(_: *RendererType, _: *GpuImageRef) void {}
        fn drawPersistentImage(_: *RendererType, _: GpuImageRef, _: ?types.Rect, _: types.Rect, _: types.Rgba) bool {
            return false;
        }
        fn drawRawImage(_: *RendererType, _: RawImageFormat, _: i32, _: i32, _: []const u8, _: types.Rect, _: types.Rgba) bool {
            return false;
        }
        fn recordSurfaceDraw(_: *RendererType, _: surface_draw.SurfaceDraw) bool {
            return false;
        }
        fn clearDiagnosticFont(_: *RendererType) void {}
        fn sceneTargetInvalidationForRefresh(_: *RendererType, _: WindowChangeMask, _: platform_window.DisplayMetrics) SceneTargetInvalidation {
            return .{};
        }
        fn mergePendingSceneTargetInvalidation(_: *RendererType, _: SceneTargetInvalidation) void {}
    };
}

fn OpenGlDispatch(
    comptime RendererType: type,
    comptime FrameSubmission: type,
    comptime RendererCapabilities: type,
    comptime PresentableDraw: type,
    comptime PresentableInfo: type,
    comptime RawImageFormat: type,
    comptime SceneTargetInvalidation: type,
    comptime WindowChangeMask: type,
) type {
    return struct {
        fn initStorage(allocator: std.mem.Allocator) !backend_runtime_bundle.Bundle {
            return backend_runtime_bundle.Bundle.init(allocator, enum { opengl, metal, android_gles }.opengl);
        }
        fn deinitStorage(bundle: *backend_runtime_bundle.Bundle, allocator: std.mem.Allocator) void {
            bundle.deinitStorage(allocator, enum { opengl, metal, android_gles }.opengl);
        }
        fn initRuntime(renderer: *RendererType) !void {
            try gl_backend.initRuntime(renderer);
        }
        fn deinitRuntime(renderer: *RendererType) void {
            gl_backend.deinitRuntime(renderer);
        }
        fn configureRuntimePolicy(renderer: *RendererType) void {
            gl_backend.configureRuntimePolicy(renderer);
        }
        fn beginFrame(renderer: *RendererType) void {
            gl_backend.beginFrame(renderer);
        }
        fn submitFrame(renderer: *RendererType) FrameSubmission {
            return gl_backend.submitFrame(renderer);
        }
        fn capabilities(renderer: *const RendererType) RendererCapabilities {
            return gl_backend.capabilities(renderer);
        }
        fn dumpWindowScreenshotPpm(renderer: *RendererType, path: []const u8) !void {
            return gl_backend.dumpWindowScreenshotPpm(renderer, path);
        }
        fn dumpWindowScreenshotPpmSized(renderer: *RendererType, path: []const u8, out_width: i32, out_height: i32) !void {
            return gl_backend.dumpWindowScreenshotPpmSized(renderer, path, out_width, out_height);
        }
        fn ensurePresentable(renderer: *RendererType, width: i32, height: i32) bool {
            return gl_presentable_runtime.ensurePresentable(renderer, width, height);
        }
        fn refreshTerminalPresentable(
            renderer: *RendererType,
            ctx: ?*const anyopaque,
            body: *const fn (?*const anyopaque, *RendererType) void,
        ) TerminalPresentableRefreshResult {
            return gl_presentable_runtime.refreshTerminalPresentable(renderer, ctx, body);
        }
        fn drawPresentableBackdrop(renderer: *RendererType, x: f32, y: f32, w: f32, h: f32, color: types.Rgba) void {
            gl_presentable_runtime.drawPresentableBackdrop(renderer, x, y, w, h, color);
        }
        fn drawPresentable(renderer: *RendererType, draw: PresentableDraw) void {
            gl_presentable_runtime.drawPresentable(renderer, draw);
        }
        fn scrollPresentable(renderer: *RendererType, dx: i32, dy: i32) bool {
            return gl_presentable_runtime.scrollPresentable(renderer, dx, dy);
        }
        fn presentableInfo(renderer: *RendererType) ?PresentableInfo {
            return gl_presentable_runtime.presentableInfo(renderer);
        }
        fn applyClipRect(renderer: *RendererType, clip: ?types.Rect) void {
            gl_clip_runtime.applyClipRect(renderer, clip);
        }
        fn addTerminalRect(renderer: *RendererType, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
            gl_backend.addTerminalRect(renderer, x, y, w, h, color);
        }
        fn addTerminalGlyphRect(renderer: *RendererType, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
            gl_backend.addTerminalGlyphRect(renderer, x, y, w, h, color);
        }
        fn addTerminalGlyphQuad(renderer: *RendererType, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
            gl_backend.addTerminalGlyphQuad(renderer, texture, src, dest, color, kind);
        }
        fn createPersistentImageFromRgba(renderer: *RendererType, width: i32, height: i32, data: []const u8) ?GpuImageRef {
            return gl_backend.createPersistentImageFromRgba(renderer, width, height, data);
        }
        fn createPersistentImageFromRgb(renderer: *RendererType, width: i32, height: i32, data: []const u8) ?GpuImageRef {
            return gl_backend.createPersistentImageFromRgb(renderer, width, height, data);
        }
        fn destroyPersistentImage(renderer: *RendererType, texture: *GpuImageRef) void {
            gl_backend.destroyPersistentImage(renderer, texture);
        }
        fn drawPersistentImage(renderer: *RendererType, texture: GpuImageRef, source_rect: ?types.Rect, dest: types.Rect, tint: types.Rgba) bool {
            return gl_backend.drawPersistentImage(renderer, texture, source_rect, dest, tint);
        }
        fn drawRawImage(renderer: *RendererType, format: RawImageFormat, width: i32, height: i32, data: []const u8, dest: types.Rect, tint: types.Rgba) bool {
            return switch (format) {
                .rgb => gl_backend.drawRawImageRgb(renderer, width, height, data, dest, tint),
                .rgba => gl_backend.drawRawImageRgba(renderer, width, height, data, dest, tint),
            };
        }
        fn recordSurfaceDraw(renderer: *RendererType, draw: surface_draw.SurfaceDraw) bool {
            return gl_surface_runtime.recordSurfaceDraw(renderer, draw);
        }
        fn clearDiagnosticFont(_: *RendererType) void {}
        fn sceneTargetInvalidationForRefresh(renderer: *RendererType, changes: WindowChangeMask, metrics: platform_window.DisplayMetrics) SceneTargetInvalidation {
            return gl_backend.sceneTargetInvalidationForRefresh(renderer, changes, metrics);
        }
        fn mergePendingSceneTargetInvalidation(renderer: *RendererType, invalidation: SceneTargetInvalidation) void {
            gl_backend.mergePendingSceneTargetInvalidation(renderer, invalidation);
        }
    };
}

fn MetalDispatch(
    comptime RendererType: type,
    comptime FrameSubmission: type,
    comptime RendererCapabilities: type,
    comptime PresentableDraw: type,
    comptime PresentableInfo: type,
    comptime RawImageFormat: type,
    comptime SceneTargetInvalidation: type,
    comptime WindowChangeMask: type,
) type {
    return struct {
        fn initStorage(allocator: std.mem.Allocator) !backend_runtime_bundle.Bundle {
            return backend_runtime_bundle.Bundle.init(allocator, enum { opengl, metal, android_gles }.metal);
        }
        fn deinitStorage(bundle: *backend_runtime_bundle.Bundle, allocator: std.mem.Allocator) void {
            bundle.deinitStorage(allocator, enum { opengl, metal, android_gles }.metal);
        }
        fn initRuntime(renderer: *RendererType) !void {
            try metal_backend.initRuntime(renderer);
        }
        fn deinitRuntime(renderer: *RendererType) void {
            metal_backend.deinitRuntime(renderer);
        }
        fn configureRuntimePolicy(renderer: *RendererType) void {
            metal_backend.configureRuntimePolicy(renderer);
        }
        fn beginFrame(renderer: *RendererType) void {
            metal_backend.beginFrame(renderer);
        }
        fn submitFrame(renderer: *RendererType) FrameSubmission {
            return metal_backend.submitFrame(renderer);
        }
        fn capabilities(renderer: *const RendererType) RendererCapabilities {
            return metal_backend.capabilities(renderer);
        }
        fn dumpWindowScreenshotPpm(renderer: *RendererType, path: []const u8) !void {
            return metal_backend.dumpWindowScreenshotPpm(renderer, path);
        }
        fn dumpWindowScreenshotPpmSized(renderer: *RendererType, path: []const u8, out_width: i32, out_height: i32) !void {
            return metal_backend.dumpWindowScreenshotPpmSized(renderer, path, out_width, out_height);
        }
        fn ensurePresentable(renderer: *RendererType, width: i32, height: i32) bool {
            return metal_presentable_runtime.ensurePresentable(renderer, width, height);
        }
        fn refreshTerminalPresentable(
            renderer: *RendererType,
            ctx: ?*const anyopaque,
            body: *const fn (?*const anyopaque, *RendererType) void,
        ) TerminalPresentableRefreshResult {
            return metal_presentable_runtime.refreshTerminalPresentable(renderer, ctx, body);
        }
        fn drawPresentableBackdrop(renderer: *RendererType, x: f32, y: f32, w: f32, h: f32, color: types.Rgba) void {
            metal_presentable_runtime.drawPresentableBackdrop(renderer, x, y, w, h, color);
        }
        fn drawPresentable(renderer: *RendererType, draw: PresentableDraw) void {
            metal_presentable_runtime.drawPresentable(renderer, draw);
        }
        fn scrollPresentable(renderer: *RendererType, dx: i32, dy: i32) bool {
            return metal_presentable_runtime.scrollPresentable(renderer, dx, dy);
        }
        fn presentableInfo(renderer: *RendererType) ?PresentableInfo {
            return metal_presentable_runtime.presentableInfo(renderer);
        }
        fn applyClipRect(renderer: *RendererType, clip: ?types.Rect) void {
            metal_clip_runtime.applyClipRect(renderer, clip);
        }
        fn addTerminalRect(renderer: *RendererType, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
            metal_backend.addTerminalRect(renderer, x, y, w, h, color);
        }
        fn addTerminalGlyphRect(renderer: *RendererType, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
            metal_backend.addTerminalGlyphRect(renderer, x, y, w, h, color);
        }
        fn addTerminalGlyphQuad(renderer: *RendererType, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
            metal_backend.addTerminalGlyphQuad(renderer, texture, src, dest, color, kind);
        }
        fn createPersistentImageFromRgba(renderer: *RendererType, width: i32, height: i32, data: []const u8) ?GpuImageRef {
            return metal_backend.createPersistentImageFromRgba(renderer, width, height, data);
        }
        fn createPersistentImageFromRgb(renderer: *RendererType, width: i32, height: i32, data: []const u8) ?GpuImageRef {
            return metal_backend.createPersistentImageFromRgb(renderer, width, height, data);
        }
        fn destroyPersistentImage(renderer: *RendererType, texture: *GpuImageRef) void {
            metal_backend.destroyPersistentImage(renderer, texture);
        }
        fn drawPersistentImage(renderer: *RendererType, texture: GpuImageRef, source_rect: ?types.Rect, dest: types.Rect, tint: types.Rgba) bool {
            return metal_backend.drawPersistentImage(renderer, texture, source_rect, dest, tint);
        }
        fn drawRawImage(renderer: *RendererType, format: RawImageFormat, width: i32, height: i32, data: []const u8, dest: types.Rect, tint: types.Rgba) bool {
            return switch (format) {
                .rgb => metal_backend.drawRawImageRgb(renderer, width, height, data, dest, tint),
                .rgba => metal_backend.drawRawImageRgba(renderer, width, height, data, dest, tint),
            };
        }
        fn recordSurfaceDraw(renderer: *RendererType, draw: surface_draw.SurfaceDraw) bool {
            return metal_surface_runtime.recordSurfaceDraw(renderer, draw);
        }
        fn clearDiagnosticFont(renderer: *RendererType) void {
            metal_backend.clearDiagnosticFont(renderer);
        }
        fn sceneTargetInvalidationForRefresh(_: *RendererType, _: WindowChangeMask, _: platform_window.DisplayMetrics) SceneTargetInvalidation {
            return .{};
        }
        fn mergePendingSceneTargetInvalidation(_: *RendererType, _: SceneTargetInvalidation) void {}
    };
}

fn AndroidGlesDispatch(
    comptime RendererType: type,
    comptime FrameSubmission: type,
    comptime RendererCapabilities: type,
    comptime PresentableDraw: type,
    comptime PresentableInfo: type,
    comptime RawImageFormat: type,
    comptime SceneTargetInvalidation: type,
    comptime WindowChangeMask: type,
) type {
    return struct {
        fn initStorage(allocator: std.mem.Allocator) !backend_runtime_bundle.Bundle {
            return backend_runtime_bundle.Bundle.init(allocator, enum { opengl, metal, android_gles }.android_gles);
        }
        fn deinitStorage(bundle: *backend_runtime_bundle.Bundle, allocator: std.mem.Allocator) void {
            bundle.deinitStorage(allocator, enum { opengl, metal, android_gles }.android_gles);
        }
        fn initRuntime(renderer: *RendererType) !void {
            try android_gles_backend.initRuntime(renderer);
        }
        fn deinitRuntime(renderer: *RendererType) void {
            android_gles_backend.deinitRuntime(renderer);
        }
        fn configureRuntimePolicy(renderer: *RendererType) void {
            android_gles_backend.configureRuntimePolicy(renderer);
        }
        fn beginFrame(renderer: *RendererType) void {
            android_gles_backend.beginFrame(renderer);
        }
        fn submitFrame(renderer: *RendererType) FrameSubmission {
            return android_gles_backend.submitFrame(renderer);
        }
        fn capabilities(renderer: *const RendererType) RendererCapabilities {
            return android_gles_backend.capabilities(renderer);
        }
        fn dumpWindowScreenshotPpm(renderer: *RendererType, path: []const u8) !void {
            return android_gles_backend.dumpWindowScreenshotPpm(renderer, path);
        }
        fn dumpWindowScreenshotPpmSized(renderer: *RendererType, path: []const u8, out_width: i32, out_height: i32) !void {
            return android_gles_backend.dumpWindowScreenshotPpmSized(renderer, path, out_width, out_height);
        }
        fn ensurePresentable(renderer: *RendererType, width: i32, height: i32) bool {
            return android_gles_backend.ensurePresentable(renderer, width, height);
        }
        fn refreshTerminalPresentable(
            renderer: *RendererType,
            ctx: ?*const anyopaque,
            body: *const fn (?*const anyopaque, *RendererType) void,
        ) TerminalPresentableRefreshResult {
            return android_gles_backend.refreshTerminalPresentable(renderer, ctx, body);
        }
        fn drawPresentableBackdrop(renderer: *RendererType, x: f32, y: f32, w: f32, h: f32, color: types.Rgba) void {
            android_gles_backend.drawPresentableBackdrop(renderer, x, y, w, h, color);
        }
        fn drawPresentable(renderer: *RendererType, draw: PresentableDraw) void {
            android_gles_backend.drawPresentable(renderer, draw);
        }
        fn scrollPresentable(renderer: *RendererType, dx: i32, dy: i32) bool {
            return android_gles_backend.scrollPresentable(renderer, dx, dy);
        }
        fn presentableInfo(renderer: *RendererType) ?PresentableInfo {
            return android_gles_backend.presentableInfo(renderer);
        }
        fn applyClipRect(renderer: *RendererType, clip: ?types.Rect) void {
            android_gles_backend.applyClipRect(renderer, clip);
        }
        fn addTerminalRect(renderer: *RendererType, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
            android_gles_backend.addTerminalRect(renderer, x, y, w, h, color);
        }
        fn addTerminalGlyphRect(renderer: *RendererType, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
            android_gles_backend.addTerminalGlyphRect(renderer, x, y, w, h, color);
        }
        fn addTerminalGlyphQuad(renderer: *RendererType, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
            android_gles_backend.addTerminalGlyphQuad(renderer, texture, src, dest, color, kind);
        }
        fn createPersistentImageFromRgba(renderer: *RendererType, width: i32, height: i32, data: []const u8) ?GpuImageRef {
            return android_gles_backend.createPersistentImageFromRgba(renderer, width, height, data);
        }
        fn createPersistentImageFromRgb(renderer: *RendererType, width: i32, height: i32, data: []const u8) ?GpuImageRef {
            return android_gles_backend.createPersistentImageFromRgb(renderer, width, height, data);
        }
        fn destroyPersistentImage(renderer: *RendererType, texture: *GpuImageRef) void {
            android_gles_backend.destroyPersistentImage(renderer, texture);
        }
        fn drawPersistentImage(renderer: *RendererType, texture: GpuImageRef, source_rect: ?types.Rect, dest: types.Rect, tint: types.Rgba) bool {
            return android_gles_backend.drawPersistentImage(renderer, texture, source_rect, dest, tint);
        }
        fn drawRawImage(renderer: *RendererType, format: RawImageFormat, width: i32, height: i32, data: []const u8, dest: types.Rect, tint: types.Rgba) bool {
            return android_gles_backend.drawRawImage(renderer, format, width, height, data, dest, tint);
        }
        fn recordSurfaceDraw(renderer: *RendererType, draw: surface_draw.SurfaceDraw) bool {
            return android_gles_backend.recordSurfaceDraw(renderer, draw);
        }
        fn clearDiagnosticFont(renderer: *RendererType) void {
            android_gles_backend.clearDiagnosticFont(renderer);
        }
        fn sceneTargetInvalidationForRefresh(renderer: *RendererType, changes: WindowChangeMask, metrics: platform_window.DisplayMetrics) SceneTargetInvalidation {
            return android_gles_backend.sceneTargetInvalidationForRefresh(renderer, changes, metrics);
        }
        fn mergePendingSceneTargetInvalidation(renderer: *RendererType, invalidation: SceneTargetInvalidation) void {
            android_gles_backend.mergePendingSceneTargetInvalidation(renderer, invalidation);
        }
    };
}
