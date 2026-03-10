const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const terminal_glyphs = @import("../renderer/terminal_glyphs.zig");
const font_atlas = @import("atlas.zig");
const terminal_font = @import("../terminal_font.zig");

const c = terminal_font.c;
const Rect = terminal_font.Rect;
const SpecialGlyphSprite = terminal_font.SpecialGlyphSprite;
const SpecialGlyphSpriteKey = terminal_font.SpecialGlyphSpriteKey;
const SpecialGlyphVariant = terminal_font.SpecialGlyphVariant;

pub fn specialGlyphSpriteKey(
    self: anytype,
    codepoint: u32,
    raster_w_px: i32,
    raster_h_px: i32,
    variant: SpecialGlyphVariant,
) SpecialGlyphSpriteKey {
    const rs = if (self.render_scale > 0.0) self.render_scale else 1.0;
    const rs_milli_f = std.math.round(rs * 1000.0);
    const rs_milli_i: i32 = @intFromFloat(rs_milli_f);
    const rs_milli_u16: u16 = @intCast(@max(0, @min(@as(i32, std.math.maxInt(u16)), rs_milli_i)));
    const cw_u16: u16 = @intCast(@max(0, @min(@as(i32, std.math.maxInt(u16)), raster_w_px)));
    const ch_u16: u16 = @intCast(@max(0, @min(@as(i32, std.math.maxInt(u16)), raster_h_px)));
    return .{
        .codepoint = codepoint,
        .cell_w_px = cw_u16,
        .cell_h_px = ch_u16,
        .render_scale_milli = rs_milli_u16,
        .variant = variant,
    };
}

pub fn getSpecialGlyphSprite(self: anytype, key: SpecialGlyphSpriteKey) ?*SpecialGlyphSprite {
    return self.special_glyph_sprites.getPtr(key);
}

pub fn putSpecialGlyphSprite(self: anytype, key: SpecialGlyphSpriteKey, sprite: SpecialGlyphSprite) !void {
    try self.special_glyph_sprites.put(key, sprite);
}

pub fn getOrCreateSpecialGlyphSprite(
    self: anytype,
    codepoint: u32,
    cell_w_px: i32,
    cell_h_px: i32,
    raster_w_px: i32,
    raster_h_px: i32,
    variant: SpecialGlyphVariant,
) ?*SpecialGlyphSprite {
    const special_log = app_logger.logger("terminal.glyph.special");
    if (cell_w_px <= 0 or cell_h_px <= 0 or raster_w_px <= 0 or raster_h_px <= 0) return null;
    const key = specialGlyphSpriteKey(self, codepoint, raster_w_px, raster_h_px, variant);
    if (self.special_glyph_sprites.getPtr(key)) |existing| return existing;

    const rs = if (self.render_scale > 0.0) self.render_scale else 1.0;
    const width = raster_w_px;
    const height = raster_h_px;
    const needed: usize = @intCast(width * height);
    if (needed == 0) return null;
    if (needed > self.upload_buffer_capacity) {
        if (self.upload_buffer_capacity > 0) {
            self.allocator.free(self.upload_buffer);
        }
        self.upload_buffer = self.allocator.alloc(u8, needed) catch |err| {
            special_log.logf(.warning, "special glyph upload buffer alloc failed bytes={d} err={s}", .{ needed, @errorName(err) });
            return null;
        };
        self.upload_buffer_capacity = needed;
    }
    const mask = self.upload_buffer[0..needed];
    const outline_experiment_enabled = true;
    var path_name: []const u8 = "analytic_v1";
    var rasterized = false;
    if (outline_experiment_enabled and variant == .powerline and isThickPowerlineCodepoint(codepoint)) {
        rasterized = rasterizePowerlineOutlineMask(self, codepoint, width, height, mask);
        if (rasterized) path_name = "outline_ft_v4";
    }
    if (!rasterized) {
        rasterized = terminal_glyphs.rasterizeSpecialGlyphCoverage(codepoint, width, height, mask);
        if (rasterized) path_name = "analytic_v1";
    }
    if (!rasterized) {
        if (variant == .powerline or isPowerlineCodepoint(codepoint)) {
            special_log.logf(.info, "sprite_create_fail cp=U+{X} reason=rasterize_failed cell={d}x{d} raster={d}x{d} rs={d:.3}", .{ codepoint, cell_w_px, cell_h_px, width, height, rs });
        }
        return null;
    }

    var non_zero = false;
    for (mask) |a| {
        if (a != 0) {
            non_zero = true;
            break;
        }
    }
    if (!non_zero) {
        if (variant == .powerline or isPowerlineCodepoint(codepoint)) {
            special_log.logf(.info, "sprite_create_fail cp=U+{X} reason=empty_mask cell={d}x{d} raster={d}x{d} rs={d:.3}", .{ codepoint, cell_w_px, cell_h_px, width, height, rs });
        }
        return null;
    }

    if (self.pen_x + width + self.padding > self.atlas_width) {
        self.pen_x = self.padding;
        self.pen_y += self.row_h + self.padding;
        self.row_h = 0;
    }
    if (self.pen_y + height + self.padding > self.atlas_height) {
        if (variant == .powerline or isPowerlineCodepoint(codepoint)) {
            special_log.logf(.info, "sprite_create_fail cp=U+{X} reason=atlas_full cell={d}x{d} raster={d}x{d} rs={d:.3}", .{ codepoint, cell_w_px, cell_h_px, width, height, rs });
        }
        return null;
    }

    const rec = Rect{
        .x = @floatFromInt(self.pen_x),
        .y = @floatFromInt(self.pen_y),
        .width = @floatFromInt(width),
        .height = @floatFromInt(height),
    };
    font_atlas.updateTextureRegionR8(self.coverage_texture, rec, mask);

    if (height > self.row_h) self.row_h = height;
    self.pen_x += width + self.padding;

    const sprite = SpecialGlyphSprite{
        .rect = rec,
        .bearing_x = 0,
        .bearing_y = height,
        .advance = @floatFromInt(cell_w_px),
        .width = width,
        .height = height,
    };
    self.special_glyph_sprites.put(key, sprite) catch |err| {
        special_log.logf(.warning, "special glyph sprite cache insert failed cp=U+{X} err={s}", .{ codepoint, @errorName(err) });
        return null;
    };
    if (variant == .powerline or isPowerlineCodepoint(codepoint)) {
        special_log.logf(.info, "sprite_create cp=U+{X} variant={s} path={s} cell={d}x{d} raster={d}x{d} rs={d:.3}", .{ codepoint, @tagName(variant), path_name, cell_w_px, cell_h_px, width, height, rs });
    }
    return self.special_glyph_sprites.getPtr(key);
}

fn rasterizePowerlineOutlineMask(
    self: anytype,
    codepoint: u32,
    width: i32,
    height: i32,
    out_alpha: []u8,
) bool {
    if (!isPowerlineCodepoint(codepoint) or width <= 0 or height <= 0) return false;
    const needed: usize = @intCast(width * height);
    if (out_alpha.len < needed) return false;
    @memset(out_alpha[0..needed], 0);

    const face = self.pickFontForCodepoint(codepoint).face;
    const glyph_id = c.FT_Get_Char_Index(face, codepoint);
    if (glyph_id == 0) return false;

    const prev_x_ppem: c_uint = face.*.size.*.metrics.x_ppem;
    const prev_y_ppem: c_uint = face.*.size.*.metrics.y_ppem;
    const internal_h: i32 = @max(1, height * 2);
    if (c.FT_Set_Pixel_Sizes(face, 0, @intCast(internal_h)) != 0) return false;
    defer _ = c.FT_Set_Pixel_Sizes(face, prev_x_ppem, prev_y_ppem);

    var load_flags: c_int = self.ftLoadFlags(false);
    load_flags |= c.FT_LOAD_NO_HINTING;
    if (c.FT_Load_Glyph(face, glyph_id, load_flags) != 0) return false;
    if (c.FT_Render_Glyph(face.*.glyph, c.FT_RENDER_MODE_NORMAL) != 0) return false;

    const slot = face.*.glyph;
    const bitmap = slot.*.bitmap;
    const bmp_w: i32 = @intCast(bitmap.width);
    const bmp_h: i32 = @intCast(bitmap.rows);
    if (bmp_w <= 0 or bmp_h <= 0) return false;

    const pitch_i: i32 = @intCast(bitmap.pitch);
    const pitch_abs: i32 = if (pitch_i < 0) -pitch_i else pitch_i;
    const alphaAt = struct {
        fn call(bitmap_ptr: c.FT_Bitmap, pitch_signed: i32, pitch: i32, x: i32, y: i32) u8 {
            const rows_i: i32 = @intCast(bitmap_ptr.rows);
            const row = if (pitch_signed >= 0) y else (rows_i - 1 - y);
            const idx: usize = @intCast(row * pitch + x);
            return bitmap_ptr.buffer[idx];
        }
    }.call;

    var min_x = bmp_w;
    var min_y = bmp_h;
    var max_x: i32 = -1;
    var max_y: i32 = -1;
    var sy: i32 = 0;
    while (sy < bmp_h) : (sy += 1) {
        var sx: i32 = 0;
        while (sx < bmp_w) : (sx += 1) {
            if (alphaAt(bitmap, pitch_i, pitch_abs, sx, sy) == 0) continue;
            if (sx < min_x) min_x = sx;
            if (sy < min_y) min_y = sy;
            if (sx > max_x) max_x = sx;
            if (sy > max_y) max_y = sy;
        }
    }
    if (max_x < min_x or max_y < min_y) return false;

    const src_w_i = max_x - min_x + 1;
    const src_h_i = max_y - min_y + 1;
    const src_w_f: f32 = @floatFromInt(src_w_i);
    const src_h_f: f32 = @floatFromInt(src_h_i);
    const dst_w_f: f32 = @floatFromInt(width);
    const dst_h_f: f32 = @floatFromInt(height);
    const bilinearSample = struct {
        fn call(
            bitmap_ptr: c.FT_Bitmap,
            pitch_signed: i32,
            pitch: i32,
            min_x_src: i32,
            min_y_src: i32,
            src_w: i32,
            src_h: i32,
            fx_in: f32,
            fy_in: f32,
        ) f32 {
            const fx = std.math.clamp(fx_in, 0.0, @as(f32, @floatFromInt(src_w - 1)));
            const fy = std.math.clamp(fy_in, 0.0, @as(f32, @floatFromInt(src_h - 1)));
            const x0 = @as(i32, @intFromFloat(@floor(fx)));
            const y0 = @as(i32, @intFromFloat(@floor(fy)));
            const x1 = @min(src_w - 1, x0 + 1);
            const y1 = @min(src_h - 1, y0 + 1);
            const tx = fx - @as(f32, @floatFromInt(x0));
            const ty = fy - @as(f32, @floatFromInt(y0));

            const ax0y0 = @as(f32, @floatFromInt(alphaAt(bitmap_ptr, pitch_signed, pitch, min_x_src + x0, min_y_src + y0)));
            const ax1y0 = @as(f32, @floatFromInt(alphaAt(bitmap_ptr, pitch_signed, pitch, min_x_src + x1, min_y_src + y0)));
            const ax0y1 = @as(f32, @floatFromInt(alphaAt(bitmap_ptr, pitch_signed, pitch, min_x_src + x0, min_y_src + y1)));
            const ax1y1 = @as(f32, @floatFromInt(alphaAt(bitmap_ptr, pitch_signed, pitch, min_x_src + x1, min_y_src + y1)));

            const top = ax0y0 + (ax1y0 - ax0y0) * tx;
            const bot = ax0y1 + (ax1y1 - ax0y1) * tx;
            return top + (bot - top) * ty;
        }
    }.call;

    var dy: i32 = 0;
    while (dy < height) : (dy += 1) {
        var dx: i32 = 0;
        while (dx < width) : (dx += 1) {
            const su0 = ((@as(f32, @floatFromInt(dx)) + 0.25) * src_w_f / dst_w_f) - 0.5;
            const su1 = ((@as(f32, @floatFromInt(dx)) + 0.75) * src_w_f / dst_w_f) - 0.5;
            const sv0 = ((@as(f32, @floatFromInt(dy)) + 0.25) * src_h_f / dst_h_f) - 0.5;
            const sv1 = ((@as(f32, @floatFromInt(dy)) + 0.75) * src_h_f / dst_h_f) - 0.5;
            const a00 = bilinearSample(bitmap, pitch_i, pitch_abs, min_x, min_y, src_w_i, src_h_i, su0, sv0);
            const a10 = bilinearSample(bitmap, pitch_i, pitch_abs, min_x, min_y, src_w_i, src_h_i, su1, sv0);
            const a01 = bilinearSample(bitmap, pitch_i, pitch_abs, min_x, min_y, src_w_i, src_h_i, su0, sv1);
            const a11 = bilinearSample(bitmap, pitch_i, pitch_abs, min_x, min_y, src_w_i, src_h_i, su1, sv1);
            const a_f = (a00 + a10 + a01 + a11) * 0.25;
            const a: u8 = @intFromFloat(std.math.round(std.math.clamp(a_f, 0.0, 255.0)));
            out_alpha[@intCast(dy * width + dx)] = a;
        }
    }

    if (codepoint == 0xE0B0) {
        var py: i32 = 0;
        while (py < height) : (py += 1) {
            out_alpha[@intCast(py * width)] = 255;
        }
    } else if (codepoint == 0xE0B2) {
        const edge_x = width - 1;
        var py: i32 = 0;
        while (py < height) : (py += 1) {
            out_alpha[@intCast(py * width + edge_x)] = 255;
        }
    }

    for (out_alpha[0..needed]) |a| {
        if (a != 0) return true;
    }
    return false;
}

fn isPowerlineCodepoint(cp: u32) bool {
    return cp >= 0xE0B0 and cp <= 0xE0BF;
}

fn isThickPowerlineCodepoint(cp: u32) bool {
    return cp == 0xE0B0 or cp == 0xE0B2;
}
