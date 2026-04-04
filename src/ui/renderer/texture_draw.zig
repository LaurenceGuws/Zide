const std = @import("std");
const types = @import("types.zig");

pub fn unitSrcRect() types.Rect {
    return .{ .x = 0, .y = 0, .width = 1, .height = 1 };
}

pub fn fullTextureSrcRect(texture: types.Texture) types.Rect {
    return .{
        .x = 0,
        .y = @floatFromInt(texture.height),
        .width = @floatFromInt(texture.width),
        .height = -@as(f32, @floatFromInt(texture.height)),
    };
}

pub fn logicalTextureSrcRect(
    texture: types.Texture,
    target_logical_width: f32,
    target_logical_height: f32,
    logical_width: f32,
    logical_height: f32,
) types.Rect {
    const full_width = @as(f32, @floatFromInt(texture.width));
    const full_height = @as(f32, @floatFromInt(texture.height));
    if (target_logical_width <= 0 or target_logical_height <= 0) return fullTextureSrcRect(texture);

    const cropped_width = std.math.clamp(full_width * (logical_width / target_logical_width), 0.0, full_width);
    const cropped_height = std.math.clamp(full_height * (logical_height / target_logical_height), 0.0, full_height);
    return .{
        .x = 0,
        .y = cropped_height,
        .width = cropped_width,
        .height = -cropped_height,
    };
}

pub fn fullTextureDestRect(texture: types.Texture, x: f32, y: f32) types.Rect {
    return .{
        .x = x,
        .y = y,
        .width = @floatFromInt(texture.width),
        .height = @floatFromInt(texture.height),
    };
}

test "logicalTextureSrcRect crops proportionally to logical size" {
    const texture = types.Texture{ .id = 1, .width = 320, .height = 160 };
    const rect = logicalTextureSrcRect(texture, 200.0, 100.0, 150.0, 50.0);
    try std.testing.expectEqual(@as(f32, 0.0), rect.x);
    try std.testing.expectEqual(@as(f32, 80.0), rect.y);
    try std.testing.expectEqual(@as(f32, 240.0), rect.width);
    try std.testing.expectEqual(@as(f32, -80.0), rect.height);
}
