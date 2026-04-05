const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const terminal_font = @import("../terminal_font.zig");

const c = terminal_font.c;
const DrawContext = terminal_font.DrawContext;
const Glyph = terminal_font.Glyph;
const GlyphError = terminal_font.GlyphError;
const Rect = terminal_font.Rect;
const Rgba = terminal_font.Rgba;

pub fn drawGlyph(
    self: anytype,
    draw: DrawContext,
    codepoint: u32,
    x: f32,
    y: f32,
    cell_width: f32,
    cell_height: f32,
    followed_by_space: bool,
    color: Rgba,
    italic: bool,
) void {
    if (codepoint == 0) return;
    const glyph = getGlyphForCodepoint(self, codepoint, italic) catch |err| {
        app_logger.logger("terminal.glyph").logf(.debug, "drawGlyph getGlyphForCodepoint failed cp=U+{X} err={s}", .{ codepoint, @errorName(err) });
        return;
    };
    const render_scale = if (self.render_scale > 0.0) self.render_scale else 1.0;
    const inv_scale = 1.0 / render_scale;
    const baseline = y + self.baseline_from_top * inv_scale;

    const glyph_w = @as(f32, @floatFromInt(glyph.width)) * inv_scale;
    const glyph_h = @as(f32, @floatFromInt(glyph.height)) * inv_scale;
    const is_symbol_glyph = isSymbolGlyph(codepoint);
    _ = cell_width;
    _ = cell_height;
    _ = followed_by_space;
    const allow_width_overflow = is_symbol_glyph;
    const overflow_scale_x: f32 = 1.0;
    const scaled_w = glyph_w * overflow_scale_x;
    const scaled_h = glyph_h;

    const bearing = @as(f32, @floatFromInt(glyph.bearing_x)) * inv_scale;
    const bearing_y = @as(f32, @floatFromInt(glyph.bearing_y)) * inv_scale;
    const draw_color = if (glyph.is_color) Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 } else color;

    if (is_symbol_glyph) {
        const draw_x = @max(x, x + bearing * overflow_scale_x);
        const draw_y = baseline - bearing_y;
        const axis_x = quantizeHorizontalAxis(draw_x, scaled_w, render_scale);
        const axis_y = quantizeVerticalAxis(draw_y, scaled_h, render_scale);
        const dest = Rect{
            .x = axis_x.origin,
            .y = axis_y.origin,
            .width = axis_x.size,
            .height = axis_y.size,
        };
        if (glyph.is_color) {
            draw.drawTexture(draw.ctx, self.colorTexture(), glyph.rect, dest, draw_color, .rgba);
        } else {
            draw.drawTexture(draw.ctx, self.coverageTexture(), glyph.rect, dest, draw_color, .font_coverage);
        }
        return;
    }

    const draw_x = if (allow_width_overflow) x + bearing * overflow_scale_x else @max(x, x + bearing * overflow_scale_x);
    const draw_y = baseline - bearing_y;
    const axis_x = quantizeHorizontalAxis(draw_x, scaled_w, render_scale);
    const axis_y = quantizeVerticalAxis(draw_y, scaled_h, render_scale);
    const dest = Rect{
        .x = axis_x.origin,
        .y = axis_y.origin,
        .width = axis_x.size,
        .height = axis_y.size,
    };
    if (glyph.is_color) {
        draw.drawTexture(draw.ctx, self.colorTexture(), glyph.rect, dest, draw_color, .rgba);
    } else {
        draw.drawTexture(draw.ctx, self.coverageTexture(), glyph.rect, dest, draw_color, .font_coverage);
    }
}

pub fn drawGrapheme(
    self: anytype,
    draw: DrawContext,
    base: u32,
    combining: []const u32,
    x: f32,
    y: f32,
    cell_width: f32,
    cell_height: f32,
    followed_by_space: bool,
    color: Rgba,
    italic: bool,
) void {
    if (base == 0) return;
    if (combining.len == 0) {
        drawGlyph(self, draw, base, x, y, cell_width, cell_height, followed_by_space, color, italic);
        return;
    }

    const choice = self.pickFontForCodepoint(base);
    const face = choice.face;
    const hb_font = choice.hb_font;
    var cps_buf: [3]u32 = .{ base, 0, 0 };
    var cps_len: usize = 1;
    for (combining) |cp| {
        if (cps_len >= cps_buf.len) break;
        cps_buf[cps_len] = cp;
        cps_len += 1;
    }

    const buffer = c.hb_buffer_create();
    defer c.hb_buffer_destroy(buffer);
    c.hb_buffer_add_utf32(buffer, &cps_buf, @intCast(cps_len), 0, @intCast(cps_len));
    c.hb_buffer_guess_segment_properties(buffer);
    c.hb_shape(hb_font, buffer, null, 0);

    var length: c_uint = 0;
    const infos = c.hb_buffer_get_glyph_infos(buffer, &length);
    const positions = c.hb_buffer_get_glyph_positions(buffer, &length);
    if (length == 0) return;

    const render_scale = if (self.render_scale > 0.0) self.render_scale else 1.0;
    const inv_scale = 1.0 / render_scale;
    const baseline = y + self.baseline_from_top * inv_scale;
    const is_symbol_glyph = isSymbolGlyph(base);

    var pen_x: f32 = 0;
    var i: usize = 0;
    while (i < length) : (i += 1) {
        const glyph = self.getGlyphById(face, infos[i].codepoint, choice.want_color, italic, positions[i].x_advance) catch continue;
        const gx_off = (@as(f32, @floatFromInt(positions[i].x_offset)) / 64.0) * inv_scale;
        const gy_off = (@as(f32, @floatFromInt(positions[i].y_offset)) / 64.0) * inv_scale;
        const origin_x = x + pen_x + gx_off;

        const glyph_w = @as(f32, @floatFromInt(glyph.width)) * inv_scale;
        const glyph_h = @as(f32, @floatFromInt(glyph.height)) * inv_scale;
        const bearing_x = @as(f32, @floatFromInt(glyph.bearing_x)) * inv_scale;
        const bearing_y = @as(f32, @floatFromInt(glyph.bearing_y)) * inv_scale;

        const allow_width_overflow = is_symbol_glyph;
        const overflow_scale_x: f32 = 1.0;
        const scaled_w = glyph_w * overflow_scale_x;
        const scaled_h = glyph_h;

        const draw_x = if (allow_width_overflow) origin_x + bearing_x * overflow_scale_x else @max(x, origin_x + bearing_x * overflow_scale_x);
        const draw_y = (baseline - bearing_y) - gy_off;
        const axis_x = quantizeHorizontalAxis(draw_x, scaled_w, render_scale);
        const axis_y = quantizeVerticalAxis(draw_y, scaled_h, render_scale);
        const dest = Rect{
            .x = axis_x.origin,
            .y = axis_y.origin,
            .width = axis_x.size,
            .height = axis_y.size,
        };

        const draw_color = if (glyph.is_color) Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 } else color;
        if (glyph.is_color) {
            draw.drawTexture(draw.ctx, self.colorTexture(), glyph.rect, dest, draw_color, .rgba);
        } else {
            draw.drawTexture(draw.ctx, self.coverageTexture(), glyph.rect, dest, draw_color, .font_coverage);
        }

        pen_x += (@as(f32, @floatFromInt(positions[i].x_advance)) / 64.0) * inv_scale;
    }
}

pub fn glyphAdvance(self: anytype, codepoint: u32, italic: bool) GlyphError!f32 {
    const glyph = try getGlyphForCodepoint(self, codepoint, italic);
    const render_scale = if (self.render_scale > 0.0) self.render_scale else 1.0;
    return glyph.advance / render_scale;
}

pub fn getGlyphForCodepoint(self: anytype, codepoint: u32, italic: bool) GlyphError!*Glyph {
    if (codepoint == 0) return error.FtLoadFailed;

    const choice = self.pickFontForCodepoint(codepoint);
    const buffer = c.hb_buffer_create();
    defer c.hb_buffer_destroy(buffer);
    c.hb_buffer_add_utf32(buffer, &codepoint, 1, 0, 1);
    c.hb_buffer_guess_segment_properties(buffer);
    c.hb_shape(choice.hb_font, buffer, null, 0);

    var length: c_uint = 0;
    const infos = c.hb_buffer_get_glyph_infos(buffer, &length);
    const positions = c.hb_buffer_get_glyph_positions(buffer, &length);
    if (length == 0) return error.HbShapeFailed;

    return self.getGlyphById(choice.face, infos[0].codepoint, choice.want_color, italic, positions[0].x_advance);
}

fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    if (!std.math.approxEqAbs(f32, scale, std.math.round(scale), 0.0001)) {
        return value;
    }
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
}

fn snapVerticalDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
}

const QuantizedAxis = struct {
    origin: f32,
    size: f32,
};

fn quantizeHorizontalAxis(origin: f32, size: f32, render_scale: f32) QuantizedAxis {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    const snapped_origin = snapToDevicePixel(origin, render_scale);
    const snapped_end = snapToDevicePixel(origin + size, render_scale);
    return .{
        .origin = snapped_origin,
        .size = @max(1.0 / scale, snapped_end - snapped_origin),
    };
}

fn quantizeVerticalAxis(origin: f32, size: f32, render_scale: f32) QuantizedAxis {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    const snapped_origin = snapVerticalDevicePixel(origin, render_scale);
    return .{
        .origin = snapped_origin,
        .size = @max(1.0 / scale, size),
    };
}

fn isSymbolGlyph(codepoint: u32) bool {
    return (codepoint >= 0xE000 and codepoint <= 0xF8FF) or
        (codepoint >= 0xF0000 and codepoint <= 0xFFFFD) or
        (codepoint >= 0x100000 and codepoint <= 0x10FFFD) or
        (codepoint >= 0x2700 and codepoint <= 0x27BF) or
        (codepoint >= 0x2600 and codepoint <= 0x26FF);
}
