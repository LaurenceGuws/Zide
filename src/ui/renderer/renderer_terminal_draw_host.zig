const types = @import("types.zig");

pub fn addTerminalRect(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: anytype) void {
    renderer.backend_ops.terminal_draw.addTerminalRect(renderer, x, y, w, h, color.toRgba());
}

pub fn addTerminalGlyphRect(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: anytype) void {
    renderer.backend_ops.terminal_draw.addTerminalGlyphRect(renderer, x, y, w, h, color.toRgba());
}

pub fn addTerminalGlyphQuad(renderer: anytype, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
    renderer.backend_ops.terminal_draw.addTerminalGlyphQuad(renderer, texture, src, dest, color, kind);
}
