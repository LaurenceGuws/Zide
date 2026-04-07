const gl_backend = @import("gl_backend.zig");
const types = @import("types.zig");

pub fn applyClipRect(renderer: anytype, clip: ?types.Rect) void {
    gl_backend.applyClipRect(renderer, clip);
}
