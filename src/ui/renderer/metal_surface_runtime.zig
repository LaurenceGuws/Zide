const metal_backend = @import("metal_backend.zig");
const surface_draw = @import("surface_draw.zig");

pub fn enqueueSurfaceDraw(renderer: anytype, draw: surface_draw.SurfaceDraw) bool {
    return metal_backend.appendSurfaceDrawToMetalQueue(renderer, draw);
}
