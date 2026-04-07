const gl_backend = @import("gl_backend.zig");
const surface_draw = @import("surface_draw.zig");

pub fn enqueueSurfaceDraw(renderer: anytype, draw: surface_draw.SurfaceDraw) bool {
    return gl_backend.submitSurfaceDrawImmediate(renderer, draw);
}
