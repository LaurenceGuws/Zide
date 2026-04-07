const std = @import("std");
const types = @import("types.zig");

pub fn addTerminalRect(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: anytype) void {
    renderer.backend.ops.terminal_draw.addTerminalRect(renderer, x, y, w, h, color.toRgba());
}

pub fn addTerminalRectLogical(renderer: anytype, x: f32, y: f32, w: f32, h: f32, color: anytype) void {
    if (w <= 0 or h <= 0) return;
    const qx = renderer.quantizeLogicalHorizontalAxis(x, w);
    const qy = renderer.quantizeLogicalVerticalAxis(y, h);
    addTerminalRect(
        renderer,
        @intFromFloat(std.math.round(qx.origin)),
        @intFromFloat(std.math.round(qy.origin)),
        @intFromFloat(std.math.round(qx.size)),
        @intFromFloat(std.math.round(qy.size)),
        color,
    );
}

pub fn addTerminalGlyphRect(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: anytype) void {
    renderer.backend.ops.terminal_draw.addTerminalGlyphRect(renderer, x, y, w, h, color.toRgba());
}

pub fn addTerminalGlyphQuad(renderer: anytype, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
    renderer.backend.ops.terminal_draw.addTerminalGlyphQuad(renderer, texture, src, dest, color, kind);
}
