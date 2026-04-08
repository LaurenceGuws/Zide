const backend_dispatch = @import("backend_dispatch.zig");
const backend_runtime_bundle = @import("backend_runtime_bundle.zig");
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
    };
}
