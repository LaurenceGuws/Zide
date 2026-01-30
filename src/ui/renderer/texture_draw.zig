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

pub fn fullTextureDestRect(texture: types.Texture, x: f32, y: f32) types.Rect {
    return .{
        .x = x,
        .y = y,
        .width = @floatFromInt(texture.width),
        .height = @floatFromInt(texture.height),
    };
}
