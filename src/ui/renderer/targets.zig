const gl_backend = @import("gl_backend.zig");

pub const RenderTarget = gl_backend.RenderTarget;

pub fn bindDefaultTarget(renderer: anytype) void {
    gl_backend.bindDefaultTarget(renderer);
}

pub fn beginRenderTarget(renderer: anytype, target: ?RenderTarget) bool {
    return gl_backend.beginRenderTarget(renderer, target);
}

pub fn scrollRenderTarget(renderer: anytype, target: ?RenderTarget, dx: i32, dy: i32, width: i32, height: i32) bool {
    return gl_backend.scrollRenderTarget(renderer, target, dx, dy, width, height);
}

pub fn ensureRenderTarget(target: *?RenderTarget, width: i32, height: i32, logical_width: i32, logical_height: i32, filter: i32) bool {
    return gl_backend.ensureRenderTarget(target, width, height, logical_width, logical_height, filter);
}

pub fn destroyRenderTarget(target: *?RenderTarget) void {
    gl_backend.destroyRenderTarget(target);
}

pub fn updateProjection(renderer: anytype, width: i32, height: i32) void {
    gl_backend.updateProjection(renderer, width, height);
}
