const backend_dispatch = @import("backend_dispatch.zig");
const backend_runtime_bundle = @import("backend_runtime_bundle.zig");
const presentable_contract = @import("presentable_contract.zig");
const surface_draw = @import("surface_draw.zig");
const std = @import("std");

pub fn Host(
    comptime RendererType: type,
    comptime BackendEnum: type,
    comptime FrameSubmission: type,
    comptime RendererCapabilities: type,
    comptime PresentableDraw: type,
    comptime PresentableInfo: type,
    comptime RawImageFormat: type,
    comptime SceneTargetInvalidation: type,
    comptime WindowChangeMask: type,
) type {
    return struct {
        const BackendOps = backend_dispatch.BackendOps(
            RendererType,
            FrameSubmission,
            RendererCapabilities,
            PresentableDraw,
            PresentableInfo,
            RawImageFormat,
            SceneTargetInvalidation,
            WindowChangeMask,
        );

        kind: BackendEnum,
        ops: BackendOps,
        runtime: backend_runtime_bundle.Bundle = .{},

        pub fn initRuntimeStorage(self: *@This(), allocator: std.mem.Allocator) !void {
            self.runtime = try self.ops.runtime.initStorage(allocator);
        }

        pub fn deinitRuntimeStorage(self: *@This(), allocator: std.mem.Allocator) void {
            self.ops.runtime.deinitStorage(&self.runtime, allocator);
        }

        pub fn configureRuntimePolicy(self: @This(), renderer: *RendererType) void {
            self.ops.runtime.configureRuntimePolicy(renderer);
        }

        pub fn initRuntime(self: @This(), renderer: *RendererType) !void {
            try self.ops.runtime.initRuntime(renderer);
        }

        pub fn deinitRuntime(self: @This(), renderer: *RendererType) void {
            self.ops.runtime.deinitRuntime(renderer);
        }

        pub fn isKind(self: @This(), kind: BackendEnum) bool {
            return self.kind == kind;
        }

        pub fn capabilities(self: @This(), renderer: *const RendererType) RendererCapabilities {
            return self.ops.runtime.capabilities(renderer);
        }

        pub fn clearDiagnosticFont(self: @This(), renderer: *RendererType) void {
            self.ops.runtime.clearDiagnosticFont(renderer);
        }

        pub fn sceneTargetInvalidationForRefresh(
            self: @This(),
            renderer: *RendererType,
            changes: WindowChangeMask,
            metrics: anytype,
        ) SceneTargetInvalidation {
            return self.ops.runtime.sceneTargetInvalidationForRefresh(renderer, changes, metrics);
        }

        pub fn mergePendingSceneTargetInvalidation(
            self: @This(),
            renderer: *RendererType,
            invalidation: SceneTargetInvalidation,
        ) void {
            self.ops.runtime.mergePendingSceneTargetInvalidation(renderer, invalidation);
        }

        pub fn beginFrame(self: @This(), renderer: *RendererType) void {
            self.ops.frame.beginFrame(renderer);
        }

        pub fn submitFrame(self: @This(), renderer: *RendererType) FrameSubmission {
            return self.ops.frame.submitFrame(renderer);
        }

        pub fn dumpWindowScreenshotPpm(self: @This(), renderer: *RendererType, path: []const u8) !void {
            return self.ops.frame.dumpWindowScreenshotPpm(renderer, path);
        }

        pub fn dumpWindowScreenshotPpmSized(self: @This(), renderer: *RendererType, path: []const u8, out_width: i32, out_height: i32) !void {
            return self.ops.frame.dumpWindowScreenshotPpmSized(renderer, path, out_width, out_height);
        }

        pub fn terminalPresentPath(self: @This(), renderer: *const RendererType) presentable_contract.TerminalPresentPath {
            return self.ops.presentable.terminalPresentPath(renderer);
        }

        pub fn ensurePresentable(self: @This(), renderer: *RendererType, width: i32, height: i32) bool {
            return self.ops.presentable.ensurePresentable(renderer, width, height);
        }

        pub fn updateRetainedPresentable(
            self: @This(),
            renderer: *RendererType,
            ctx: ?*const anyopaque,
            body: *const fn (?*const anyopaque, *RendererType) void,
        ) backend_dispatch.RetainedPresentableUpdateResult {
            return self.ops.presentable.updateRetainedPresentable(renderer, ctx, body);
        }

        pub fn drawPresentableBackdrop(self: @This(), renderer: *RendererType, x: f32, y: f32, w: f32, h: f32, color: anytype) void {
            self.ops.presentable.drawPresentableBackdrop(renderer, x, y, w, h, color);
        }

        pub fn drawPresentable(self: @This(), renderer: *RendererType, draw: PresentableDraw) void {
            self.ops.presentable.drawPresentable(renderer, draw);
        }

        pub fn scrollPresentable(self: @This(), renderer: *RendererType, dx: i32, dy: i32) bool {
            return self.ops.presentable.scrollPresentable(renderer, dx, dy);
        }

        pub fn presentableInfo(self: @This(), renderer: *RendererType) ?PresentableInfo {
            return self.ops.presentable.presentableInfo(renderer);
        }

        pub fn applyClipRect(self: @This(), renderer: *RendererType, clip: anytype) void {
            self.ops.clip.applyClipRect(renderer, clip);
        }

        pub fn addTerminalRect(self: @This(), renderer: *RendererType, x: i32, y: i32, w: i32, h: i32, color: anytype) void {
            self.ops.terminal_draw.addTerminalRect(renderer, x, y, w, h, color);
        }

        pub fn addTerminalGlyphRect(self: @This(), renderer: *RendererType, x: i32, y: i32, w: i32, h: i32, color: anytype) void {
            self.ops.terminal_draw.addTerminalGlyphRect(renderer, x, y, w, h, color);
        }

        pub fn addTerminalGlyphQuad(
            self: @This(),
            renderer: *RendererType,
            texture: anytype,
            src: anytype,
            dest: anytype,
            color: anytype,
            kind: anytype,
        ) void {
            self.ops.terminal_draw.addTerminalGlyphQuad(renderer, texture, src, dest, color, kind);
        }

        pub fn createPersistentImageFromRgba(self: @This(), renderer: *RendererType, width: i32, height: i32, data: []const u8) ?surface_draw.GpuImageRef {
            return self.ops.image_draw.createPersistentImageFromRgba(renderer, width, height, data);
        }

        pub fn createPersistentImageFromRgb(self: @This(), renderer: *RendererType, width: i32, height: i32, data: []const u8) ?surface_draw.GpuImageRef {
            return self.ops.image_draw.createPersistentImageFromRgb(renderer, width, height, data);
        }

        pub fn destroyPersistentImage(self: @This(), renderer: *RendererType, texture: *surface_draw.GpuImageRef) void {
            self.ops.image_draw.destroyPersistentImage(renderer, texture);
        }

        pub fn drawPersistentImage(
            self: @This(),
            renderer: *RendererType,
            texture: surface_draw.GpuImageRef,
            source_rect: anytype,
            dest: anytype,
            tint: anytype,
        ) bool {
            return self.ops.image_draw.drawPersistentImage(renderer, texture, source_rect, dest, tint);
        }

        pub fn drawRawImage(
            self: @This(),
            renderer: *RendererType,
            format: RawImageFormat,
            width: i32,
            height: i32,
            data: []const u8,
            dest: anytype,
            tint: anytype,
        ) bool {
            return self.ops.image_draw.drawRawImage(renderer, format, width, height, data, dest, tint);
        }

        pub fn recordSurfaceDraw(self: @This(), renderer: *RendererType, draw: anytype) bool {
            return self.ops.surface.recordSurfaceDraw(renderer, draw);
        }
    };
}
