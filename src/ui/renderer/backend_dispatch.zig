const bootstrap_contract = @import("bootstrap_contract.zig");
const types = @import("types.zig");
const gl_backend = @import("gl_backend.zig");
const gl_clip_runtime = @import("gl_clip_runtime.zig");
const gl_presentable_runtime = @import("gl_presentable_runtime.zig");
const gl_surface_runtime = @import("gl_surface_runtime.zig");
const metal_backend = @import("metal_backend.zig");
const metal_clip_runtime = @import("metal_clip_runtime.zig");
const metal_presentable_runtime = @import("metal_presentable_runtime.zig");
const metal_surface_runtime = @import("metal_surface_runtime.zig");
const surface_draw = @import("surface_draw.zig");
const presentable_contract = @import("presentable_contract.zig");
const platform_window = @import("../../platform/window_metrics.zig");
const GpuImageRef = surface_draw.GpuImageRef;
const TerminalPresentPath = presentable_contract.TerminalPresentPath;

pub const RetainedPresentableUpdateResult = enum {
    updated,
    unavailable,
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
        terminalPresentPath: *const fn (*const RendererType) TerminalPresentPath,
        ensurePresentable: *const fn (*RendererType, i32, i32) bool,
        updateRetainedPresentable: *const fn (*RendererType, ?*const anyopaque, *const fn (?*const anyopaque, *RendererType) void) RetainedPresentableUpdateResult,
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
    const OpenGl = OpenGlDispatch(
        RendererType,
        FrameSubmission,
        RendererCapabilities,
        PresentableDraw,
        PresentableInfo,
        RawImageFormat,
        SceneTargetInvalidation,
        WindowChangeMask,
    );
    const Metal = MetalDispatch(
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
                .terminalPresentPath = OpenGl.terminalPresentPath,
                .ensurePresentable = OpenGl.ensurePresentable,
                .updateRetainedPresentable = OpenGl.updateRetainedPresentable,
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
                .terminalPresentPath = Metal.terminalPresentPath,
                .ensurePresentable = Metal.ensurePresentable,
                .updateRetainedPresentable = Metal.updateRetainedPresentable,
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
    };
}

pub fn bootstrapOpsFor(comptime BackendEnum: type, backend: BackendEnum) bootstrap_contract.BackendBootstrapOps {
    return switch (backend) {
        .opengl => gl_backend.bootstrapOps(),
        .metal => metal_backend.bootstrapOps(),
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
        fn terminalPresentPath(_: *const RendererType) TerminalPresentPath {
            return .retained_surface;
        }
        fn updateRetainedPresentable(
            renderer: *RendererType,
            ctx: ?*const anyopaque,
            body: *const fn (?*const anyopaque, *RendererType) void,
        ) RetainedPresentableUpdateResult {
            return gl_presentable_runtime.updateRetainedPresentable(renderer, ctx, body);
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
        fn terminalPresentPath(_: *const RendererType) TerminalPresentPath {
            return .direct_surface;
        }
        fn updateRetainedPresentable(
            renderer: *RendererType,
            ctx: ?*const anyopaque,
            body: *const fn (?*const anyopaque, *RendererType) void,
        ) RetainedPresentableUpdateResult {
            return metal_presentable_runtime.updateRetainedPresentable(renderer, ctx, body);
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
