const gl_backend = @import("gl_backend.zig");

pub fn flushQueuedSurfaceDrawsBeforeDependentSurfaceWork(renderer: anytype) void {
    gl_backend.flushQueuedSurfaceDrawsBeforeImmediateWork(renderer);
}
