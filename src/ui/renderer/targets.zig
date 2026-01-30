const gl_backend = @import("gl_backend.zig");

pub const RenderTarget = gl_backend.RenderTarget;

pub fn bindDefaultTarget(renderer: anytype) void {
    gl_backend.bindDefaultTarget(renderer);
}

pub fn beginRenderTarget(renderer: anytype, target: ?RenderTarget) bool {
    return gl_backend.beginRenderTarget(renderer, target);
}

pub fn ensureRenderTarget(target: *?RenderTarget, width: i32, height: i32, filter: i32) bool {
    return gl_backend.ensureRenderTarget(target, width, height, filter);
}

pub fn destroyRenderTarget(target: *?RenderTarget) void {
    gl_backend.destroyRenderTarget(target);
}

pub fn updateProjection(renderer: anytype, width: i32, height: i32) void {
    gl_backend.updateProjection(renderer, width, height);
}
