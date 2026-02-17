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

pub const SpecialGlyphVariant = enum(u8) {
    generic = 0,
    powerline = 1,
    shade = 2,
    box = 3,
    braille = 4,
    branch = 5,
    legacy = 6,
};

pub const SpecialGlyphSpriteKey = struct {
    codepoint: u32,
    cell_w_px: u16,
    cell_h_px: u16,
    // Quantized render scale so cache keys remain stable and hashable.
    render_scale_milli: u16,
    variant: SpecialGlyphVariant,
};

pub const SpecialGlyphSprite = struct {
    rect: Rect,
    bearing_x: i32,
    bearing_y: i32,
    advance: f32,
    width: i32,
    height: i32,
};
