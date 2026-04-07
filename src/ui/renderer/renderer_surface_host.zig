const metal_text_sample_runtime = @import("metal_text_sample_runtime.zig");
const surface_draw = @import("surface_draw.zig");
const types = @import("types.zig");

pub fn recordSurfaceDraw(renderer: anytype, draw: surface_draw.SurfaceDraw) bool {
    return renderer.backend_ops.surface.recordSurfaceDraw(renderer, draw);
}

pub fn recordSolidSurfaceFromLogicalRect(
    renderer: anytype,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    color: types.Rgba,
) bool {
    const clip = if (renderer.currentClipRect()) |c|
        metal_text_sample_runtime.pixelClipRect(renderer, c)
    else
        null;
    return recordSurfaceDraw(renderer, .{ .solid = .{
        .dest_rect = .{
            .x = renderer.logicalLengthToRaster(x),
            .y = renderer.logicalLengthToRaster(y),
            .width = renderer.logicalLengthToRaster(w),
            .height = renderer.logicalLengthToRaster(h),
        },
        .color = color,
        .clip_rect = clip,
    } });
}
