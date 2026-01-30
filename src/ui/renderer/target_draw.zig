const gl = @import("gl.zig");
const types = @import("types.zig");

pub fn drawTarget(
    drawTextureRect: *const fn (ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba) void,
    ctx: *anyopaque,
    target: types.Texture,
    x: f32,
    y: f32,
) void {
    const src = types.Rect{
        .x = 0,
        .y = @floatFromInt(target.height),
        .width = @floatFromInt(target.width),
        .height = -@as(f32, @floatFromInt(target.height)),
    };
    const dest = types.Rect{
        .x = x,
        .y = y,
        .width = @floatFromInt(target.width),
        .height = @floatFromInt(target.height),
    };
    drawTextureRect(ctx, target, src, dest, types.Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 });
}

pub fn nearestFilter() i32 {
    return gl.c.GL_NEAREST;
}
