const surface_draw = @import("surface_draw.zig");
const types = @import("types.zig");

pub fn clearThemeBackground(renderer: anytype) void {
    renderer.backend_ops.clip.clearThemeBackground(renderer);
}

pub fn createPersistentImageFromRgba(renderer: anytype, width: i32, height: i32, data: []const u8) ?surface_draw.GpuImageRef {
    return renderer.backend_ops.image_draw.createPersistentImageFromRgba(renderer, width, height, data);
}

pub fn createPersistentImageFromRgb(renderer: anytype, width: i32, height: i32, data: []const u8) ?surface_draw.GpuImageRef {
    return renderer.backend_ops.image_draw.createPersistentImageFromRgb(renderer, width, height, data);
}

pub fn destroyPersistentImage(renderer: anytype, texture: *surface_draw.GpuImageRef) void {
    renderer.backend_ops.image_draw.destroyPersistentImage(renderer, texture);
}

pub fn drawPersistentImage(
    renderer: anytype,
    texture: surface_draw.GpuImageRef,
    source_rect: ?types.Rect,
    dest: types.Rect,
    tint: types.Rgba,
) bool {
    return renderer.backend_ops.image_draw.drawPersistentImage(renderer, texture, source_rect, dest, tint);
}

pub fn drawRawImage(
    renderer: anytype,
    format: anytype,
    width: i32,
    height: i32,
    data: []const u8,
    dest: types.Rect,
    tint: types.Rgba,
) bool {
    return renderer.backend_ops.image_draw.drawRawImage(renderer, format, width, height, data, dest, tint);
}
