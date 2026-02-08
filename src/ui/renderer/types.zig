const gl = @import("gl.zig");

pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const Texture = struct {
    id: gl.GLuint,
    width: i32,
    height: i32,
};

pub const TextureKind = enum(u8) {
    rgba = 0,
    font_coverage = 1,
    linear_premul = 2,
};

pub const Rgba = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};
