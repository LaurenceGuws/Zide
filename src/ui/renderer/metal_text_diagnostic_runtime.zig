const std = @import("std");
const renderer_root = @import("../renderer.zig");

const Renderer = renderer_root.Renderer;

pub const Placement = struct {
    dest_x: i32,
    dest_y: i32,
};

pub fn previewPlacement(renderer: *const Renderer, margin_logical: f32) Placement {
    const geometry = renderer.uiGeometryContext();
    const scale = if (geometry.ui_scale > 0.0) geometry.ui_scale else 1.0;
    const inset = @max(8, @as(i32, @intFromFloat(std.math.round(margin_logical * scale))));
    return .{
        .dest_x = inset,
        .dest_y = inset,
    };
}
