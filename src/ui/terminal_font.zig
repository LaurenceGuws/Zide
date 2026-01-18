const std = @import("std");

const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("ft2build.h");
    @cInclude("freetype/freetype.h");
    @cInclude("freetype/ftglyph.h");
    @cInclude("harfbuzz/hb.h");
    @cInclude("harfbuzz/hb-ft.h");
});

pub const AllowSquareGlyphOverflow = enum {
    never,
    always,
    when_followed_by_space,
};

pub const Glyph = struct {
    rect: c.Rectangle,
    bearing_x: i32,
    bearing_y: i32,
    advance: f32,
    width: i32,
    height: i32,
};

pub const Rgba = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const GlyphError = error{
    HbShapeFailed,
    FtLoadFailed,
    FtRenderFailed,
    AtlasFull,
    OutOfMemory,
};

pub const TerminalFont = struct {
    allocator: std.mem.Allocator,
    ft_library: c.FT_Library,
    ft_face: c.FT_Face,
    hb_font: *c.hb_font_t,
    texture: c.Texture2D,
    atlas_width: i32,
    atlas_height: i32,
    pen_x: i32,
    pen_y: i32,
    row_h: i32,
    padding: i32,
    glyphs: std.AutoHashMap(u32, Glyph),
    glyph_order: std.ArrayList(u32),
    max_glyphs: usize,
    upload_buffer: []u8,
    upload_buffer_capacity: usize,
    ascent: f32,
    descent: f32,
    line_height: f32,
    cell_width: f32,
    use_lcd: bool,
    overflow_policy: AllowSquareGlyphOverflow,

    pub fn init(allocator: std.mem.Allocator, path: [*:0]const u8, size: f32) !TerminalFont {
        var ft_library: c.FT_Library = null;
        if (c.FT_Init_FreeType(&ft_library) != 0) return error.FtInitFailed;
        errdefer _ = c.FT_Done_FreeType(ft_library);

        var ft_face: c.FT_Face = null;
        if (c.FT_New_Face(ft_library, path, 0, &ft_face) != 0) return error.FtFaceFailed;
        errdefer _ = c.FT_Done_Face(ft_face);
        if (c.FT_Set_Pixel_Sizes(ft_face, 0, @intFromFloat(size)) != 0) return error.FtSizeFailed;

        const hb_font = c.hb_ft_font_create(ft_face, null) orelse return error.HbInitFailed;
        errdefer c.hb_font_destroy(hb_font);

        const metrics = ft_face.*.size.*.metrics;
        const ascent_raw = @as(f32, @floatFromInt(metrics.ascender >> 6));
        const descent_raw = @as(f32, @floatFromInt(@abs(metrics.descender >> 6)));
        const line_height_raw = @as(f32, @floatFromInt(metrics.height >> 6));

        // Use typical ASCII glyphs to avoid oversized cell widths.
        var cell_width: f32 = 0;
        const max_advance = @as(f32, @floatFromInt(metrics.max_advance >> 6));
        if (max_advance > 0) {
            cell_width = max_advance;
        }
        const samples = [_]u32{ 'M', 'W', 'd' };
        for (samples) |cp| {
            // HarfBuzz advance
            const buffer = c.hb_buffer_create();
            defer c.hb_buffer_destroy(buffer);
            c.hb_buffer_add_utf32(buffer, &cp, 1, 0, 1);
            c.hb_buffer_guess_segment_properties(buffer);
            c.hb_shape(hb_font, buffer, null, 0);
            var sample_len: c_uint = 0;
            const sample_pos = c.hb_buffer_get_glyph_positions(buffer, &sample_len);
            if (sample_len > 0) {
                const adv = @as(f32, @floatFromInt(sample_pos[0].x_advance)) / 64.0;
                if (adv > cell_width) cell_width = adv;
            }

            // FreeType metrics for visual width (bitmap + bearing)
            if (c.FT_Load_Char(ft_face, cp, c.FT_LOAD_DEFAULT) == 0) {
                const slot = ft_face.*.glyph;
                const metric_w = @as(f32, @floatFromInt(slot.*.metrics.width >> 6));
                const bearing = @as(f32, @floatFromInt(@max(0, slot.*.bitmap_left)));
                const visual = metric_w + bearing;
                if (visual > cell_width) cell_width = visual;
                const adv_ft = @as(f32, @floatFromInt(slot.*.advance.x >> 6));
                if (adv_ft > cell_width) cell_width = adv_ft;
            }
        }

        if (cell_width <= 0) {
            cell_width = max_advance;
        }
        if (cell_width <= 0) {
            cell_width = size * 0.6;
        }
        const cell_width_px = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(cell_width)))));

        const ascent_px = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(ascent_raw)))));
        const descent_px = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(descent_raw)))));
        const line_height_px = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(line_height_raw)))));

        const atlas_width: i32 = 2048;
        const atlas_height: i32 = 2048;
        const padding: i32 = 1;

        const image = c.GenImageColor(atlas_width, atlas_height, .{ .r = 0, .g = 0, .b = 0, .a = 0 });
        const texture = c.LoadTextureFromImage(image);
        c.UnloadImage(image);
        c.SetTextureFilter(texture, c.TEXTURE_FILTER_POINT);

        return .{
            .allocator = allocator,
            .ft_library = ft_library,
            .ft_face = ft_face,
            .hb_font = hb_font,
            .texture = texture,
            .atlas_width = atlas_width,
            .atlas_height = atlas_height,
            .pen_x = padding,
            .pen_y = padding,
            .row_h = 0,
            .padding = padding,
            .glyphs = std.AutoHashMap(u32, Glyph).init(allocator),
            .glyph_order = .empty,
            .max_glyphs = 2048,
            .upload_buffer = &[_]u8{},
            .upload_buffer_capacity = 0,
            .ascent = ascent_px,
            .descent = descent_px,
            .line_height = if (line_height_px > 0) line_height_px else ascent_px + descent_px,
            .cell_width = if (cell_width_px > 0) cell_width_px else size * 0.6,
            .use_lcd = std.c.getenv("ZIDE_FONT_LCD") != null,
            .overflow_policy = blk: {
                if (std.c.getenv("ZIDE_GLYPH_OVERFLOW")) |raw| {
                    const s = std.mem.sliceTo(raw, 0);
                    if (std.mem.eql(u8, s, "never")) break :blk .never;
                    if (std.mem.eql(u8, s, "always")) break :blk .always;
                }
                break :blk .when_followed_by_space;
            },
        };
    }

    pub fn deinit(self: *TerminalFont) void {
        self.glyphs.deinit();
        self.glyph_order.deinit(self.allocator);
        if (self.upload_buffer_capacity > 0) {
            self.allocator.free(self.upload_buffer);
        }
        c.UnloadTexture(self.texture);
        c.hb_font_destroy(self.hb_font);
        _ = c.FT_Done_Face(self.ft_face);
        _ = c.FT_Done_FreeType(self.ft_library);
    }

    pub fn setAtlasFilterPoint(self: *TerminalFont) void {
        c.SetTextureFilter(self.texture, c.TEXTURE_FILTER_POINT);
    }

    pub fn drawGlyph(self: *TerminalFont, codepoint: u32, x: f32, y: f32, cell_width: f32, cell_height: f32, followed_by_space: bool, color: Rgba) void {
        if (codepoint == 0) return;
        const glyph = self.getGlyph(codepoint) catch return;
        const baseline = y + self.ascent;

        const glyph_w = @as(f32, @floatFromInt(glyph.width));
        const glyph_h = @as(f32, @floatFromInt(glyph.height));

        // Check if codepoint is in Private Use Area (PUA) or symbol ranges.
        // These are typically icons that should be allowed to overflow.
        const is_symbol_glyph = (codepoint >= 0xE000 and codepoint <= 0xF8FF) or // BMP PUA (Nerd Font)
            (codepoint >= 0xF0000 and codepoint <= 0xFFFFD) or // Supplementary PUA-A
            (codepoint >= 0x100000 and codepoint <= 0x10FFFD) or // Supplementary PUA-B
            (codepoint >= 0x2700 and codepoint <= 0x27BF) or // Dingbats (❯, etc.)
            (codepoint >= 0x2600 and codepoint <= 0x26FF); // Misc Symbols

        const aspect = if (cell_height > 0) glyph_w / cell_height else 0.0;
        const is_square_or_wide = aspect >= 0.7;
        const allow_width_overflow = if (is_symbol_glyph) true else if (is_square_or_wide) switch (self.overflow_policy) {
            .never => false,
            .always => true,
            .when_followed_by_space => followed_by_space,
        } else false;

        const scale = if (!allow_width_overflow and glyph_w > cell_width and glyph_w > 0) cell_width / glyph_w else 1.0;
        const scaled_w = glyph_w * scale;
        const scaled_h = glyph_h * scale;

        const bearing = @as(f32, @floatFromInt(glyph.bearing_x));

        // For symbol/icon glyphs: center in cell with left bias to prevent right clipping.
        if (is_symbol_glyph) {
            // Higher ratio = more left shift = less right overflow.
            // 0.5 = centered, 0.7 = biased left, 1.0 = right-aligned
            const draw_x = @max(x, x + (cell_width - scaled_w) * 0.7);
            const draw_y = baseline - @as(f32, @floatFromInt(glyph.bearing_y)) * scale;
            const snapped_x = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(draw_x)))));
            const snapped_y = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(draw_y)))));
            if (scale == 1.0) {
                c.DrawTextureRec(self.texture, glyph.rect, .{ .x = snapped_x, .y = snapped_y }, .{
                    .r = color.r,
                    .g = color.g,
                    .b = color.b,
                    .a = color.a,
                });
            } else {
                const dest = c.Rectangle{ .x = snapped_x, .y = snapped_y, .width = scaled_w, .height = scaled_h };
                c.DrawTexturePro(self.texture, glyph.rect, dest, .{ .x = 0, .y = 0 }, 0, .{
                    .r = color.r,
                    .g = color.g,
                    .b = color.b,
                    .a = color.a,
                });
            }
            return;
        }

        // Normal glyph: draw at bearing position, clamped to not go left of cell.
        const draw_x = if (allow_width_overflow) x + bearing * scale else @max(x, x + bearing * scale);
        const draw_y = baseline - @as(f32, @floatFromInt(glyph.bearing_y)) * scale;
        const snapped_x = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(draw_x)))));
        const snapped_y = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(draw_y)))));
        if (scale == 1.0) {
            c.DrawTextureRec(self.texture, glyph.rect, .{ .x = snapped_x, .y = snapped_y }, .{
                .r = color.r,
                .g = color.g,
                .b = color.b,
                .a = color.a,
            });
        } else {
            const dest = c.Rectangle{ .x = snapped_x, .y = snapped_y, .width = scaled_w, .height = scaled_h };
            c.DrawTexturePro(self.texture, glyph.rect, dest, .{ .x = 0, .y = 0 }, 0, .{
                .r = color.r,
                .g = color.g,
                .b = color.b,
                .a = color.a,
            });
        }
    }

    fn getGlyph(self: *TerminalFont, codepoint: u32) GlyphError!*Glyph {
        if (self.glyphs.getPtr(codepoint)) |glyph| return glyph;

        try self.rasterizeGlyph(codepoint, true);
        return self.glyphs.getPtr(codepoint).?;
    }

    fn rasterizeGlyph(self: *TerminalFont, codepoint: u32, allow_compact: bool) GlyphError!void {
        const buffer = c.hb_buffer_create();
        defer c.hb_buffer_destroy(buffer);
        c.hb_buffer_add_utf32(buffer, &codepoint, 1, 0, 1);
        c.hb_buffer_guess_segment_properties(buffer);
        c.hb_shape(self.hb_font, buffer, null, 0);

        var length: c_uint = 0;
        const infos = c.hb_buffer_get_glyph_infos(buffer, &length);
        const positions = c.hb_buffer_get_glyph_positions(buffer, &length);
        if (length == 0) return error.HbShapeFailed;

        const glyph_id = infos[0].codepoint;
        const load_flags: c_int = if (self.use_lcd) c.FT_LOAD_DEFAULT | c.FT_LOAD_TARGET_LCD else c.FT_LOAD_DEFAULT;
        if (c.FT_Load_Glyph(self.ft_face, glyph_id, load_flags) != 0) return error.FtLoadFailed;
        const render_mode: c.FT_Render_Mode = if (self.use_lcd) c.FT_RENDER_MODE_LCD else c.FT_RENDER_MODE_NORMAL;
        if (c.FT_Render_Glyph(self.ft_face.*.glyph, render_mode) != 0) {
            if (self.use_lcd and c.FT_Render_Glyph(self.ft_face.*.glyph, c.FT_RENDER_MODE_NORMAL) == 0) {
                // fall back to grayscale
            } else {
                return error.FtRenderFailed;
            }
        }

        const slot = self.ft_face.*.glyph;
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
                    // Try to compact and retry once.
                    try self.compactAtlas();
                    try self.rasterizeGlyph(codepoint, false);
                    return;
                }
                return error.AtlasFull;
            }

            const pixel_count = @as(usize, @intCast(width * height));
            const needed = pixel_count * 4;
            if (needed > self.upload_buffer_capacity) {
                if (self.upload_buffer_capacity > 0) {
                    self.allocator.free(self.upload_buffer);
                }
                self.upload_buffer = try self.allocator.alloc(u8, needed);
                self.upload_buffer_capacity = needed;
            }
            const rgba = self.upload_buffer[0..needed];

            const gamma = 1.0 / 2.2;

            var y: i32 = 0;
            while (y < height) : (y += 1) {
                var x: i32 = 0;
                while (x < width) : (x += 1) {
                    var r: u8 = 0;
                    var g: u8 = 0;
                    var b: u8 = 0;
                    var a: u8 = 0;
                    if (bitmap.pixel_mode == c.FT_PIXEL_MODE_LCD) {
                        const base = @as(usize, @intCast(y * @as(i32, @intCast(bitmap.pitch)) + x * 3));
                        r = bitmap.buffer[base + 0];
                        g = bitmap.buffer[base + 1];
                        b = bitmap.buffer[base + 2];
                        a = @max(r, @max(g, b));
                    } else {
                        const src_idx = @as(usize, @intCast(y * @as(i32, @intCast(bitmap.pitch)) + x));
                        a = bitmap.buffer[src_idx];
                        r = a;
                        g = a;
                        b = a;
                    }
                    const rf = std.math.pow(f32, @as(f32, @floatFromInt(r)) / 255.0, gamma);
                    const gf = std.math.pow(f32, @as(f32, @floatFromInt(g)) / 255.0, gamma);
                    const bf = std.math.pow(f32, @as(f32, @floatFromInt(b)) / 255.0, gamma);
                    const af = std.math.pow(f32, @as(f32, @floatFromInt(a)) / 255.0, gamma);
                    const dst_idx = @as(usize, @intCast((y * width + x) * 4));
                    rgba[dst_idx] = @intFromFloat(@min(255.0, rf * 255.0));
                    rgba[dst_idx + 1] = @intFromFloat(@min(255.0, gf * 255.0));
                    rgba[dst_idx + 2] = @intFromFloat(@min(255.0, bf * 255.0));
                    rgba[dst_idx + 3] = @intFromFloat(@min(255.0, af * 255.0));
                }
            }

            const rec = c.Rectangle{
                .x = @floatFromInt(self.pen_x),
                .y = @floatFromInt(self.pen_y),
                .width = @floatFromInt(width),
                .height = @floatFromInt(height),
            };
            c.UpdateTextureRec(self.texture, rec, rgba.ptr);

            if (height > self.row_h) self.row_h = height;
            const advance = @as(f32, @floatFromInt(positions[0].x_advance)) / 64.0;
            const glyph = Glyph{
                .rect = rec,
                .bearing_x = slot.*.bitmap_left,
                .bearing_y = slot.*.bitmap_top,
                .advance = if (advance > 0) advance else @as(f32, @floatFromInt(slot.*.advance.x)) / 64.0,
                .width = width,
                .height = height,
            };
            if (self.max_glyphs > 0 and self.glyphs.count() >= self.max_glyphs) {
                if (self.glyph_order.items.len > 0) {
                    const evict = self.glyph_order.orderedRemove(0);
                    _ = self.glyphs.remove(evict);
                }
            }
            try self.glyphs.put(codepoint, glyph);
            try self.glyph_order.append(self.allocator, codepoint);
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
        };
        if (self.max_glyphs > 0 and self.glyphs.count() >= self.max_glyphs) {
            if (self.glyph_order.items.len > 0) {
                const evict = self.glyph_order.orderedRemove(0);
                _ = self.glyphs.remove(evict);
            }
        }
        try self.glyphs.put(codepoint, glyph);
        try self.glyph_order.append(self.allocator, codepoint);
        return;
    }

    fn compactAtlas(self: *TerminalFont) GlyphError!void {
        var old_order = try self.glyph_order.clone(self.allocator);
        defer old_order.deinit(self.allocator);

        self.glyphs.clearRetainingCapacity();
        self.glyph_order.clearRetainingCapacity();

        self.pen_x = self.padding;
        self.pen_y = self.padding;
        self.row_h = 0;

        const image = c.GenImageColor(self.atlas_width, self.atlas_height, .{ .r = 0, .g = 0, .b = 0, .a = 0 });
        c.UnloadTexture(self.texture);
        self.texture = c.LoadTextureFromImage(image);
        c.UnloadImage(image);
        c.SetTextureFilter(self.texture, c.TEXTURE_FILTER_POINT);

        const count = old_order.items.len;
        var kept: usize = 0;
        var idx: usize = 0;
        while (idx < count and kept < self.max_glyphs) : (idx += 1) {
            const codepoint = old_order.items[count - 1 - idx];
            if (self.glyphs.contains(codepoint)) continue;
            try self.rasterizeGlyph(codepoint, false);
            kept += 1;
        }
    }
};
