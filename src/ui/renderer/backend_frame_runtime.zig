const opengl_frame_runtime = @import("opengl_frame_runtime.zig");
const metal_frame_runtime = @import("metal_frame_runtime.zig");
const renderer_root = @import("../renderer.zig");

const FrameSubmission = renderer_root.FrameSubmission;

pub fn beginFrame(renderer: anytype) void {
    renderer.clearQueuedSurfaceDraws();
    switch (renderer.backend) {
        .opengl => opengl_frame_runtime.beginFrame(renderer),
        .metal => metal_frame_runtime.beginFrame(renderer),
    }
}

pub fn submitFrame(renderer: anytype) FrameSubmission {
    return switch (renderer.backend) {
        .opengl => opengl_frame_runtime.submitFrame(renderer),
        .metal => metal_frame_runtime.submitFrame(renderer),
    };
}
