const types = @import("types.zig");

pub const PixelClipRect = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

pub const AtlasTextureSource = enum {
    coverage,
    color,
};

pub const AtlasSampleDraw = struct {
    atlas: AtlasTextureSource = .color,
    source_rect: types.Rect,
    dest_x: i32,
    dest_y: i32,
    tint: types.Rgba = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
    clip_rect: ?PixelClipRect = null,
};

/// Metal path: `texture` is an `MTLTexture*`; dimensions match the texture.
/// OpenGL path: immediate `SurfaceDraw.raw_image` uses `types.Texture` without
/// ownership transfer (caller keeps the GL texture alive through the draw).
pub const MetalRawImageTexture = struct {
    texture: *anyopaque,
    width: i32,
    height: i32,
};

pub const RawImageTexture = union(enum) {
    metal: MetalRawImageTexture,
    opengl: types.Texture,
};

pub const RawImageDraw = struct {
    texture: RawImageTexture,
    source_rect: ?types.Rect = null,
    dest_rect: types.Rect,
    tint: types.Rgba = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
    clip_rect: ?PixelClipRect = null,
};

pub const SolidColorDraw = struct {
    dest_rect: types.Rect,
    color: types.Rgba,
    clip_rect: ?PixelClipRect = null,
};

pub const SurfaceDraw = union(enum) {
    atlas: AtlasSampleDraw,
    raw_image: RawImageDraw,
    solid: SolidColorDraw,
};
