const std = @import("std");
const gl = @import("../renderer/gl.zig");
const types = @import("../renderer/types.zig");

const Rect = types.Rect;
const Texture = types.Texture;
const Glyph = @import("../terminal_font.zig").Glyph;
const GlyphError = @import("../terminal_font.zig").GlyphError;
const app_logger = @import("../../app_logger.zig");
const c = @import("../terminal_font.zig").c;

pub fn setAtlasFilterPoint(self: anytype) void {
    if (self.coverage_texture.id != 0) {
        gl.BindTexture(gl.c.GL_TEXTURE_2D, self.coverage_texture.id);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, gl.c.GL_NEAREST);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, gl.c.GL_NEAREST);
    }
    if (self.color_texture.id != 0) {
        gl.BindTexture(gl.c.GL_TEXTURE_2D, self.color_texture.id);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, gl.c.GL_NEAREST);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, gl.c.GL_NEAREST);
    }
}

pub fn rasterizeGlyphKey(self: anytype, key: anytype, hb_x_advance: c_int, allow_compact: bool) GlyphError!void {
    var face = key.face;
    const want_color = key.want_color;

    const load_flags: c_int = self.ftLoadFlags(want_color);
    if (c.FT_Load_Glyph(face, key.glyph_id, load_flags) != 0) {
        if (self.emoji_color_ft_face != null and face == self.emoji_color_ft_face.? and self.emoji_text_ft_face != null) {
            face = self.emoji_text_ft_face.?;
            if (c.FT_Load_Glyph(face, key.glyph_id, self.ftLoadFlags(false)) != 0) return error.FtLoadFailed;
        } else {
            return error.FtLoadFailed;
        }
    }

    const render_mode: c.FT_Render_Mode = if (self.use_lcd and !want_color) c.FT_RENDER_MODE_LCD else c.FT_RENDER_MODE_NORMAL;
    if (c.FT_Render_Glyph(face.*.glyph, render_mode) != 0) {
        if (self.use_lcd and c.FT_Render_Glyph(face.*.glyph, c.FT_RENDER_MODE_NORMAL) == 0) {} else {
            return error.FtRenderFailed;
        }
    }

    const slot = face.*.glyph;
    const bitmap = slot.*.bitmap;
    const width: i32 = if (bitmap.pixel_mode == c.FT_PIXEL_MODE_LCD) @intCast(bitmap.width / 3) else @intCast(bitmap.width);
    const height: i32 = @intCast(bitmap.rows);

    if (width > 0 and height > 0) {
        if (self.pen_x + width + self.padding > self.atlas_width) {
            self.pen_x = self.padding;
            self.pen_y += self.row_h + self.padding;
            self.row_h = 0;
        }
        if (self.pen_y + height + self.padding > self.atlas_height) {
            if (allow_compact) {
                try compactAtlas(self);
                try rasterizeGlyphKey(self, key, hb_x_advance, false);
                return;
            }
            return error.AtlasFull;
        }

        const pixel_count = @as(usize, @intCast(width * height));
        const is_color_bitmap = bitmap.pixel_mode == c.FT_PIXEL_MODE_BGRA;
        const needed = if (is_color_bitmap) pixel_count * 4 else pixel_count;
        if (needed > self.upload_buffer_capacity) {
            if (self.upload_buffer_capacity > 0) self.allocator.free(self.upload_buffer);
            self.upload_buffer = try self.allocator.alloc(u8, needed);
            self.upload_buffer_capacity = needed;
        }
        const upload = self.upload_buffer[0..needed];

        var y: i32 = 0;
        while (y < height) : (y += 1) {
            var x: i32 = 0;
            while (x < width) : (x += 1) {
                if (is_color_bitmap) {
                    const base = @as(usize, @intCast(y * @as(i32, @intCast(bitmap.pitch)) + x * 4));
                    const b = bitmap.buffer[base + 0];
                    const g = bitmap.buffer[base + 1];
                    const r = bitmap.buffer[base + 2];
                    const a = bitmap.buffer[base + 3];
                    const dst_idx = @as(usize, @intCast((y * width + x) * 4));
                    upload[dst_idx] = r;
                    upload[dst_idx + 1] = g;
                    upload[dst_idx + 2] = b;
                    upload[dst_idx + 3] = a;
                } else {
                    var a: u8 = 0;
                    if (bitmap.pixel_mode == c.FT_PIXEL_MODE_LCD) {
                        const base = @as(usize, @intCast(y * @as(i32, @intCast(bitmap.pitch)) + x * 3));
                        const r = bitmap.buffer[base + 0];
                        const g = bitmap.buffer[base + 1];
                        const b = bitmap.buffer[base + 2];
                        a = @max(r, @max(g, b));
                    } else {
                        const src_idx = @as(usize, @intCast(y * @as(i32, @intCast(bitmap.pitch)) + x));
                        a = bitmap.buffer[src_idx];
                    }
                    const dst_idx = @as(usize, @intCast(y * width + x));
                    upload[dst_idx] = a;
                }
            }
        }

        const rec = Rect{
            .x = @floatFromInt(self.pen_x),
            .y = @floatFromInt(self.pen_y),
            .width = @floatFromInt(width),
            .height = @floatFromInt(height),
        };
        if (is_color_bitmap) {
            updateTextureRegion(self.color_texture, rec, upload);
        } else {
            updateTextureRegionR8(self.coverage_texture, rec, upload);
        }

        if (height > self.row_h) self.row_h = height;
        const advance = @as(f32, @floatFromInt(hb_x_advance)) / 64.0;
        const glyph = Glyph{
            .rect = rec,
            .bearing_x = slot.*.bitmap_left,
            .bearing_y = slot.*.bitmap_top,
            .advance = if (advance > 0) advance else @as(f32, @floatFromInt(slot.*.advance.x)) / 64.0,
            .width = width,
            .height = height,
            .is_color = is_color_bitmap,
        };
        if (self.max_glyphs > 0 and self.glyphs.count() >= self.max_glyphs) {
            if (self.glyph_order.items.len > 0) {
                const evict = self.glyph_order.orderedRemove(0);
                _ = self.glyphs.remove(evict);
            }
        }
        try self.glyphs.put(key, glyph);
        try self.glyph_order.append(self.allocator, key);
        self.pen_x += width + self.padding;
        return;
    }

    const glyph = Glyph{
        .rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
        .bearing_x = 0,
        .bearing_y = 0,
        .advance = @as(f32, @floatFromInt(slot.*.advance.x)) / 64.0,
        .width = 0,
        .height = 0,
        .is_color = false,
    };
    if (self.max_glyphs > 0 and self.glyphs.count() >= self.max_glyphs) {
        if (self.glyph_order.items.len > 0) {
            const evict = self.glyph_order.orderedRemove(0);
            _ = self.glyphs.remove(evict);
        }
    }
    try self.glyphs.put(key, glyph);
    try self.glyph_order.append(self.allocator, key);
}

pub fn compactAtlas(self: anytype) GlyphError!void {
    var old_order = try self.glyph_order.clone(self.allocator);
    defer old_order.deinit(self.allocator);

    self.glyphs.clearRetainingCapacity();
    self.glyph_order.clearRetainingCapacity();
    self.special_glyph_sprites.clearRetainingCapacity();

    self.pen_x = self.padding;
    self.pen_y = self.padding;
    self.row_h = 0;

    if (self.coverage_texture.id != 0) gl.DeleteTextures(1, &self.coverage_texture.id);
    if (self.color_texture.id != 0) gl.DeleteTextures(1, &self.color_texture.id);

    const zero_cov_len: usize = @as(usize, @intCast(self.atlas_width * self.atlas_height));
    const zero_cov_buf = self.allocator.alloc(u8, zero_cov_len) catch return error.OutOfMemory;
    defer self.allocator.free(zero_cov_buf);
    @memset(zero_cov_buf, 0);
    self.coverage_texture = createTextureR8(self.atlas_width, self.atlas_height, zero_cov_buf);

    const zero_col_len: usize = @as(usize, @intCast(self.atlas_width * self.atlas_height * 4));
    const zero_col_buf = self.allocator.alloc(u8, zero_col_len) catch return error.OutOfMemory;
    defer self.allocator.free(zero_col_buf);
    @memset(zero_col_buf, 0);
    self.color_texture = createTexture(self.atlas_width, self.atlas_height, zero_col_buf);

    const count = old_order.items.len;
    var kept: usize = 0;
    var idx: usize = 0;
    while (idx < count and kept < self.max_glyphs) : (idx += 1) {
        const key = old_order.items[count - 1 - idx];
        if (self.glyphs.contains(key)) continue;
        try rasterizeGlyphKey(self, key, 0, false);
        kept += 1;
    }
}

pub fn createTexture(width: i32, height: i32, data: []const u8) Texture {
    var id: gl.GLuint = 0;
    gl.GenTextures(1, &id);
    gl.BindTexture(gl.c.GL_TEXTURE_2D, id);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, gl.c.GL_NEAREST);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, gl.c.GL_NEAREST);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_S, gl.c.GL_CLAMP_TO_EDGE);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_T, gl.c.GL_CLAMP_TO_EDGE);
    gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
    gl.TexImage2D(gl.c.GL_TEXTURE_2D, 0, gl.c.GL_RGBA, width, height, 0, gl.c.GL_RGBA, gl.c.GL_UNSIGNED_BYTE, data.ptr);
    return .{ .id = id, .width = width, .height = height };
}

pub fn createTextureR8(width: i32, height: i32, data: []const u8) Texture {
    var id: gl.GLuint = 0;
    gl.GenTextures(1, &id);
    gl.BindTexture(gl.c.GL_TEXTURE_2D, id);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, gl.c.GL_NEAREST);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, gl.c.GL_NEAREST);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_S, gl.c.GL_CLAMP_TO_EDGE);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_T, gl.c.GL_CLAMP_TO_EDGE);
    gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
    gl.TexImage2D(gl.c.GL_TEXTURE_2D, 0, gl.c.GL_R8, width, height, 0, gl.c.GL_RED, gl.c.GL_UNSIGNED_BYTE, data.ptr);
    return .{ .id = id, .width = width, .height = height };
}

pub fn updateTextureRegion(texture: Texture, rect: Rect, data: []const u8) void {
    const w: i32 = @intFromFloat(rect.width);
    const h: i32 = @intFromFloat(rect.height);
    if (w <= 0 or h <= 0) return;
    gl.BindTexture(gl.c.GL_TEXTURE_2D, texture.id);
    gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
    gl.TexSubImage2D(gl.c.GL_TEXTURE_2D, 0, @intFromFloat(rect.x), @intFromFloat(rect.y), w, h, gl.c.GL_RGBA, gl.c.GL_UNSIGNED_BYTE, data.ptr);
}

pub fn updateTextureRegionR8(texture: Texture, rect: Rect, data: []const u8) void {
    const w: i32 = @intFromFloat(rect.width);
    const h: i32 = @intFromFloat(rect.height);
    if (w <= 0 or h <= 0) return;
    gl.BindTexture(gl.c.GL_TEXTURE_2D, texture.id);
    gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
    gl.TexSubImage2D(gl.c.GL_TEXTURE_2D, 0, @intFromFloat(rect.x), @intFromFloat(rect.y), w, h, gl.c.GL_RED, gl.c.GL_UNSIGNED_BYTE, data.ptr);
}
