const std = @import("std");
const terminal_font_mod = @import("../terminal_font.zig");
const metal_backend = @import("metal_backend.zig");
const renderer_root = @import("../renderer.zig");

const TerminalFont = terminal_font_mod.TerminalFont;
const Renderer = renderer_root.Renderer;

pub const SampleTextRequest = struct {
    text: []const u8,
    x: f32,
    y: f32,
};

pub fn appendAsciiRun(
    renderer: *const Renderer,
    font: *TerminalFont,
    request: SampleTextRequest,
    draws: []metal_backend.AtlasSampleDraw,
    draw_count: *usize,
) bool {
    if (request.text.len == 0) return false;

    const render_scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    var pen_x = request.x;
    var drew_any = false;

    for (request.text) |char| {
        if (char == ' ') {
            pen_x += font.cell_width / render_scale;
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
            .dest_y = @max(0, @as(i32, @intFromFloat(std.math.round(renderer.logicalLengthToRaster(request.y))))),
        };
        draw_count.* += 1;
        drew_any = true;
        pen_x += glyph.advance / render_scale;
    }

    return drew_any;
}
