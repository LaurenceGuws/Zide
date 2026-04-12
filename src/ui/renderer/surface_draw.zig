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
    bg_rgba: types.Rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    clip_rect: ?PixelClipRect = null,
};

/// Backend-neutral image handle for shared draw payloads.
/// OpenGL stores the texture id in `handle`.
/// Metal stores the `MTLTexture*` pointer bits in `handle`.
pub const GpuImageRef = struct {
    handle: usize,
    width: i32,
    height: i32,
};

pub const RawImageDraw = struct {
    texture: GpuImageRef,
    source_rect: ?types.Rect = null,
    dest_rect: types.Rect,
    tint: types.Rgba = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
    bg_rgba: types.Rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
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
