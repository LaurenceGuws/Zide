const std = @import("std");
const layout = @import("../../types/mod.zig").layout;

pub const Placement = struct {
    dest_x: i32,
    dest_y: i32,
};

pub fn previewPlacement(geometry: layout.UiGeometryContext, margin_logical: f32) Placement {
    const scale = if (geometry.ui_scale > 0.0) geometry.ui_scale else 1.0;
    const inset = @max(8, @as(i32, @intFromFloat(std.math.round(margin_logical * scale))));
    return .{
        .dest_x = inset,
        .dest_y = inset,
    };
}
