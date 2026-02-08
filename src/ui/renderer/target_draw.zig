const gl = @import("gl.zig");
const texture_draw = @import("texture_draw.zig");
const types = @import("types.zig");

pub fn drawTarget(
    drawTextureRect: *const fn (ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void,
    ctx: *anyopaque,
    target: types.Texture,
    x: f32,
    y: f32,
) void {
    const src = texture_draw.fullTextureSrcRect(target);
    const dest = texture_draw.fullTextureDestRect(target, x, y);
    drawTextureRect(ctx, target, src, dest, types.Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 }, .rgba);
}

pub fn nearestFilter() i32 {
    return gl.c.GL_NEAREST;
}
