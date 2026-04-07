const backend_dispatch = @import("backend_dispatch.zig");
const backend_runtime_bundle = @import("backend_runtime_bundle.zig");

pub fn Host(
    comptime RendererType: type,
    comptime FrameSubmission: type,
    comptime RendererCapabilities: type,
    comptime PresentableSurface: type,
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
            PresentableSurface,
            PresentableDraw,
            PresentableInfo,
            RawImageFormat,
            SceneTargetInvalidation,
            WindowChangeMask,
        );

        ops: BackendOps,
        runtime: backend_runtime_bundle.Bundle = .{},
    };
}
