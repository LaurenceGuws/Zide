const std = @import("std");
const terminal_font_mod = @import("../terminal_font.zig");
const metal_backend = @import("metal_backend.zig");
const renderer_root = @import("../renderer.zig");
const types = @import("types.zig");

const TerminalFont = terminal_font_mod.TerminalFont;
const Renderer = renderer_root.Renderer;

pub const SampleTextRequest = struct {
    pub const LayoutMode = enum {
        glyph_advance,
        monospace_cell,
    };

    text: []const u8,
    x: f32,
    y: f32,
    tint: types.Rgba = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
    layout: LayoutMode = .glyph_advance,
    clip_rect: ?types.Rect = null,
};

fn pixelClipRect(renderer: *const Renderer, clip_rect: types.Rect) ?metal_backend.PixelClipRect {
    const x0 = @as(i32, @intFromFloat(std.math.round(renderer.logicalLengthToRaster(clip_rect.x))));
    const y0 = @as(i32, @intFromFloat(std.math.round(renderer.logicalLengthToRaster(clip_rect.y))));
    const x1 = @as(i32, @intFromFloat(std.math.round(renderer.logicalLengthToRaster(clip_rect.x + clip_rect.width))));
    const y1 = @as(i32, @intFromFloat(std.math.round(renderer.logicalLengthToRaster(clip_rect.y + clip_rect.height))));
    const width = x1 - x0;
    const height = y1 - y0;
    if (width <= 0 or height <= 0) return null;
    return .{
        .x = x0,
        .y = y0,
        .width = width,
        .height = height,
    };
}

pub fn appendAsciiRun(
    renderer: *const Renderer,
    font: *TerminalFont,
    request: SampleTextRequest,
    draws: []metal_backend.AtlasSampleDraw,
    draw_count: *usize,
) bool {
    if (request.text.len == 0) return false;

    const render_scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    const line_height = font.line_height / render_scale;
    const cell_width = font.cell_width / render_scale;
    const clip = if (request.clip_rect) |clip_rect| pixelClipRect(renderer, clip_rect) else null;
    var pen_x = request.x;
    var pen_y = request.y;
    var drew_any = false;

    for (request.text) |char| {
        if (char == '\n') {
            pen_x = request.x;
            pen_y += line_height;
            continue;
        }
        if (char == ' ') {
            pen_x += cell_width;
            continue;
        }

        const codepoint: u32 = char;
        const direct = font.directFastGlyphForCodepoint(codepoint) orelse return drew_any;
        const glyph = font.getGlyphById(direct.face, direct.glyph_id, direct.want_color, false, 0) catch return drew_any;
        if (glyph.rect.width <= 0 or glyph.rect.height <= 0) continue;
        if (draw_count.* >= draws.len) return drew_any;

        draws[draw_count.*] = .{
            .atlas = .color,
            .source_rect = glyph.rect,
            .dest_x = @max(0, @as(i32, @intFromFloat(std.math.round(renderer.logicalLengthToRaster(pen_x))))),
            .dest_y = @max(0, @as(i32, @intFromFloat(std.math.round(renderer.logicalLengthToRaster(pen_y))))),
            .tint = request.tint,
            .clip_rect = clip,
        };
        draw_count.* += 1;
        drew_any = true;
        pen_x += switch (request.layout) {
            .glyph_advance => glyph.advance / render_scale,
            .monospace_cell => cell_width,
        };
    }

    return drew_any;
}
