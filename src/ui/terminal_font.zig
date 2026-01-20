const std = @import("std");
const app_logger = @import("../app_logger.zig");
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("ft2build.h");
    @cInclude("freetype/freetype.h");
    @cInclude("freetype/ftglyph.h");
    @cInclude("harfbuzz/hb.h");
    @cInclude("harfbuzz/hb-ft.h");
});

const fc = if (builtin.target.os.tag == .linux) @cImport({
    @cInclude("fontconfig/fontconfig.h");
}) else struct {};
// TODO(macOS): Add CoreText-based fallback resolution for missing glyphs.
// TODO(Windows): Add DirectWrite-based fallback resolution for missing glyphs.

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
    is_color: bool,
};

pub const Rgba = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const FacePair = struct {
    face: ?c.FT_Face = null,
    hb: ?*c.hb_font_t = null,
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
    symbols_ft_face: ?c.FT_Face,
    unicode_symbols2_ft_face: ?c.FT_Face,
    unicode_symbols_ft_face: ?c.FT_Face,
    unicode_mono_ft_face: ?c.FT_Face,
    unicode_sans_ft_face: ?c.FT_Face,
    emoji_color_ft_face: ?c.FT_Face,
    emoji_text_ft_face: ?c.FT_Face,
    hb_font: *c.hb_font_t,
    symbols_hb_font: ?*c.hb_font_t,
    unicode_symbols2_hb_font: ?*c.hb_font_t,
    unicode_symbols_hb_font: ?*c.hb_font_t,
    unicode_mono_hb_font: ?*c.hb_font_t,
    unicode_sans_hb_font: ?*c.hb_font_t,
    emoji_color_hb_font: ?*c.hb_font_t,
    emoji_text_hb_font: ?*c.hb_font_t,
    fc_enabled: bool,
    fc_config: ?*fc.FcConfig,
    system_fallback_by_cp: std.AutoHashMap(u32, ?[]u8),
    system_faces: std.StringHashMapUnmanaged(FacePair),
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

    pub fn init(
        allocator: std.mem.Allocator,
        path: [*:0]const u8,
        size: f32,
        symbols_path: ?[*:0]const u8,
        unicode_symbols2_path: ?[*:0]const u8,
        unicode_symbols_path: ?[*:0]const u8,
        unicode_mono_path: ?[*:0]const u8,
        unicode_sans_path: ?[*:0]const u8,
        emoji_color_path: ?[*:0]const u8,
        emoji_text_path: ?[*:0]const u8,
    ) !TerminalFont {
        var ft_library: c.FT_Library = null;
        if (c.FT_Init_FreeType(&ft_library) != 0) return error.FtInitFailed;
        errdefer _ = c.FT_Done_FreeType(ft_library);

        var ft_face: c.FT_Face = null;
        if (c.FT_New_Face(ft_library, path, 0, &ft_face) != 0) return error.FtFaceFailed;
        errdefer _ = c.FT_Done_Face(ft_face);
        if (c.FT_Set_Pixel_Sizes(ft_face, 0, @intFromFloat(size)) != 0) return error.FtSizeFailed;

        const hb_font = c.hb_ft_font_create(ft_face, null) orelse return error.HbInitFailed;
        errdefer c.hb_font_destroy(hb_font);

        const loadFace = struct {
            fn call(
                library: c.FT_Library,
                fpath: ?[*:0]const u8,
                size_px: f32,
                name: []const u8,
                log: app_logger.Logger,
                allow_fixed_size: bool,
            ) FacePair {
                if (fpath) |path_c| {
                    const path_str = std.mem.sliceTo(path_c, 0);
                    if (log.enabled_file or log.enabled_console) {
                        if (std.fs.cwd().access(path_str, .{})) |_| {
                            log.logf("font load: {s} path={s}", .{ name, path_str });
                        } else |err| {
                            log.logf("font load: {s} path={s} access_err={s}", .{ name, path_str, @errorName(err) });
                        }
                    }
                    var fb_face: c.FT_Face = null;
                    const new_face_err = c.FT_New_Face(library, path_c, 0, &fb_face);
                    if (new_face_err == 0) {
                        const size_err = c.FT_Set_Pixel_Sizes(fb_face, 0, @intFromFloat(size_px));
                        if (size_err != 0 and allow_fixed_size and fb_face.*.num_fixed_sizes > 0) {
                            var best_idx: c_int = 0;
                            var best_delta: u32 = std.math.maxInt(u32);
                            var idx: c_int = 0;
                            while (idx < fb_face.*.num_fixed_sizes) : (idx += 1) {
                                const s = fb_face.*.available_sizes[@intCast(idx)];
                                const delta: u32 = @intCast(@abs(@as(i32, @intCast(s.height)) - @as(i32, @intFromFloat(size_px))));
                                if (delta < best_delta) {
                                    best_delta = delta;
                                    best_idx = idx;
                                }
                            }
                            _ = c.FT_Select_Size(fb_face, best_idx);
                        } else if (size_err != 0 and (log.enabled_file or log.enabled_console)) {
                            log.logf("font load failed: {s} set_pixel_sizes err={d}", .{ name, size_err });
                        }
                        if (size_err == 0 or (allow_fixed_size and fb_face.*.num_fixed_sizes > 0)) {
                            if (c.hb_ft_font_create(fb_face, null)) |fb_hb| {
                                return .{ .face = fb_face, .hb = fb_hb };
                            }
                            if (log.enabled_file or log.enabled_console) {
                                log.logf("font load failed: {s} hb_ft_font_create returned null", .{name});
                            }
                        }
                        _ = c.FT_Done_Face(fb_face);
                    } else if (log.enabled_file or log.enabled_console) {
                        log.logf("font load failed: {s} FT_New_Face err={d}", .{ name, new_face_err });
                    }
                } else if (log.enabled_file or log.enabled_console) {
                    log.logf("font load skipped: {s} path not set", .{name});
                }
                return .{};
            }
        }.call;

        const log = app_logger.logger("terminal.font");
        const symbols_pair = loadFace(ft_library, symbols_path, size, "symbols", log, false);
        const unicode_symbols2_pair = loadFace(ft_library, unicode_symbols2_path, size, "unicode_symbols2", log, false);
        const unicode_symbols_pair = loadFace(ft_library, unicode_symbols_path, size, "unicode_symbols", log, false);
        const unicode_mono_pair = loadFace(ft_library, unicode_mono_path, size, "unicode_mono", log, false);
        const unicode_sans_pair = loadFace(ft_library, unicode_sans_path, size, "unicode_sans", log, false);
        const emoji_color_pair = loadFace(ft_library, emoji_color_path, size, "emoji_color", log, true);
        const emoji_text_pair = loadFace(ft_library, emoji_text_path, size, "emoji_text", log, false);

        var fc_enabled = false;
        var fc_config: ?*fc.FcConfig = null;
        if (builtin.target.os.tag == .linux) {
            if (fc.FcInit() != 0) {
                fc_enabled = true;
                fc_config = fc.FcConfigGetCurrent();
            } else if (log.enabled_file or log.enabled_console) {
                log.logf("fontconfig init failed", .{});
            }
        }

        if (log.enabled_file or log.enabled_console) {
            const cp_arrow: u32 = 0x21E1; // ⇡
            const cp_braille: u32 = 0x28FF; // ⣿
            const cp_emoji: u32 = 0x1F600; // 😀
            const has_cp = struct {
                fn call(face_opt: ?c.FT_Face, cp: u32) bool {
                    if (face_opt) |face| return c.FT_Get_Char_Index(face, cp) != 0;
                    return false;
                }
            }.call;

            log.logf(
                "font load: primary={d} symbols={d} sym2={d} sym={d} mono={d} sans={d} emoji_color={d} emoji_text={d}",
                .{
                    @as(u8, if (ft_face != null) 1 else 0),
                    @as(u8, if (symbols_pair.face != null) 1 else 0),
                    @as(u8, if (unicode_symbols2_pair.face != null) 1 else 0),
                    @as(u8, if (unicode_symbols_pair.face != null) 1 else 0),
                    @as(u8, if (unicode_mono_pair.face != null) 1 else 0),
                    @as(u8, if (unicode_sans_pair.face != null) 1 else 0),
                    @as(u8, if (emoji_color_pair.face != null) 1 else 0),
                    @as(u8, if (emoji_text_pair.face != null) 1 else 0),
                },
            );
            log.logf(
                "glyph coverage: ⇡ p={d} sym={d} s2={d} s={d} m={d} sans={d} | ⣿ p={d} sym={d} s2={d} s={d} m={d} sans={d} | 😀 p={d} sym={d} s2={d} s={d} m={d} sans={d} ec={d} et={d}",
                .{
                    @as(u8, if (has_cp(ft_face, cp_arrow)) 1 else 0),
                    @as(u8, if (has_cp(symbols_pair.face, cp_arrow)) 1 else 0),
                    @as(u8, if (has_cp(unicode_symbols2_pair.face, cp_arrow)) 1 else 0),
                    @as(u8, if (has_cp(unicode_symbols_pair.face, cp_arrow)) 1 else 0),
                    @as(u8, if (has_cp(unicode_mono_pair.face, cp_arrow)) 1 else 0),
                    @as(u8, if (has_cp(unicode_sans_pair.face, cp_arrow)) 1 else 0),
                    @as(u8, if (has_cp(ft_face, cp_braille)) 1 else 0),
                    @as(u8, if (has_cp(symbols_pair.face, cp_braille)) 1 else 0),
                    @as(u8, if (has_cp(unicode_symbols2_pair.face, cp_braille)) 1 else 0),
                    @as(u8, if (has_cp(unicode_symbols_pair.face, cp_braille)) 1 else 0),
                    @as(u8, if (has_cp(unicode_mono_pair.face, cp_braille)) 1 else 0),
                    @as(u8, if (has_cp(unicode_sans_pair.face, cp_braille)) 1 else 0),
                    @as(u8, if (has_cp(ft_face, cp_emoji)) 1 else 0),
                    @as(u8, if (has_cp(symbols_pair.face, cp_emoji)) 1 else 0),
                    @as(u8, if (has_cp(unicode_symbols2_pair.face, cp_emoji)) 1 else 0),
                    @as(u8, if (has_cp(unicode_symbols_pair.face, cp_emoji)) 1 else 0),
                    @as(u8, if (has_cp(unicode_mono_pair.face, cp_emoji)) 1 else 0),
                    @as(u8, if (has_cp(unicode_sans_pair.face, cp_emoji)) 1 else 0),
                    @as(u8, if (has_cp(emoji_color_pair.face, cp_emoji)) 1 else 0),
                    @as(u8, if (has_cp(emoji_text_pair.face, cp_emoji)) 1 else 0),
                },
            );
        }

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
            .symbols_ft_face = symbols_pair.face,
            .unicode_symbols2_ft_face = unicode_symbols2_pair.face,
            .unicode_symbols_ft_face = unicode_symbols_pair.face,
            .unicode_mono_ft_face = unicode_mono_pair.face,
            .unicode_sans_ft_face = unicode_sans_pair.face,
            .emoji_color_ft_face = emoji_color_pair.face,
            .emoji_text_ft_face = emoji_text_pair.face,
            .hb_font = hb_font,
            .symbols_hb_font = symbols_pair.hb,
            .unicode_symbols2_hb_font = unicode_symbols2_pair.hb,
            .unicode_symbols_hb_font = unicode_symbols_pair.hb,
            .unicode_mono_hb_font = unicode_mono_pair.hb,
            .unicode_sans_hb_font = unicode_sans_pair.hb,
            .emoji_color_hb_font = emoji_color_pair.hb,
            .emoji_text_hb_font = emoji_text_pair.hb,
            .fc_enabled = fc_enabled,
            .fc_config = fc_config,
            .system_fallback_by_cp = std.AutoHashMap(u32, ?[]u8).init(allocator),
            .system_faces = .{},
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
        self.system_fallback_by_cp.deinit();

        var face_it = self.system_faces.iterator();
        while (face_it.next()) |entry| {
            if (entry.value_ptr.*.hb) |hb| c.hb_font_destroy(hb);
            if (entry.value_ptr.*.face) |face| _ = c.FT_Done_Face(face);
            self.allocator.free(entry.key_ptr.*);
        }
        self.system_faces.deinit(self.allocator);

        c.UnloadTexture(self.texture);
        if (self.symbols_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.symbols_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
        if (self.unicode_symbols2_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.unicode_symbols2_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
        if (self.unicode_symbols_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.unicode_symbols_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
        if (self.unicode_mono_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.unicode_mono_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
        if (self.unicode_sans_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.unicode_sans_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
        if (self.emoji_color_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.emoji_color_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
        if (self.emoji_text_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.emoji_text_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
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
        const draw_color = if (glyph.is_color)
            Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 }
        else
            color;

        if (is_symbol_glyph) {
            const draw_x = @max(x, x + bearing * scale);
            const draw_y = baseline - @as(f32, @floatFromInt(glyph.bearing_y)) * scale;
            const snapped_x = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(draw_x)))));
            const snapped_y = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(draw_y)))));
            if (scale == 1.0) {
                c.DrawTextureRec(self.texture, glyph.rect, .{ .x = snapped_x, .y = snapped_y }, .{
                    .r = draw_color.r,
                    .g = draw_color.g,
                    .b = draw_color.b,
                    .a = draw_color.a,
                });
            } else {
                const dest = c.Rectangle{ .x = snapped_x, .y = snapped_y, .width = scaled_w, .height = scaled_h };
                c.DrawTexturePro(self.texture, glyph.rect, dest, .{ .x = 0, .y = 0 }, 0, .{
                    .r = draw_color.r,
                    .g = draw_color.g,
                    .b = draw_color.b,
                    .a = draw_color.a,
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
                .r = draw_color.r,
                .g = draw_color.g,
                .b = draw_color.b,
                .a = draw_color.a,
            });
        } else {
            const dest = c.Rectangle{ .x = snapped_x, .y = snapped_y, .width = scaled_w, .height = scaled_h };
            c.DrawTexturePro(self.texture, glyph.rect, dest, .{ .x = 0, .y = 0 }, 0, .{
                .r = draw_color.r,
                .g = draw_color.g,
                .b = draw_color.b,
                .a = draw_color.a,
            });
        }
    }

    fn getGlyph(self: *TerminalFont, codepoint: u32) GlyphError!*Glyph {
        if (self.glyphs.getPtr(codepoint)) |glyph| return glyph;

        try self.rasterizeGlyph(codepoint, true);
        return self.glyphs.getPtr(codepoint).?;
    }

    fn hasGlyph(face: c.FT_Face, codepoint: u32) bool {
        return c.FT_Get_Char_Index(face, codepoint) != 0;
    }

    fn preferSymbols(codepoint: u32) bool {
        return (codepoint >= 0xE000 and codepoint <= 0xF8FF) or // PUA (Nerd Font)
            (codepoint >= 0xF0000 and codepoint <= 0xFFFFD) or // PUA-A
            (codepoint >= 0x100000 and codepoint <= 0x10FFFD) or // PUA-B
            (codepoint >= 0x2500 and codepoint <= 0x259F) or // Box Drawing + Block Elements
            (codepoint >= 0x2800 and codepoint <= 0x28FF) or // Braille Patterns
            (codepoint >= 0x1FB00 and codepoint <= 0x1FBFF); // Symbols for Legacy Computing
    }

    fn preferEmoji(codepoint: u32) bool {
        return (codepoint >= 0x1F000 and codepoint <= 0x1FAFF) or // main emoji blocks
            (codepoint >= 0x1F1E6 and codepoint <= 0x1F1FF) or // regional indicators
            (codepoint >= 0x2600 and codepoint <= 0x27BF); // misc symbols/dingbats
    }

    fn preferUnicode(codepoint: u32) bool {
        return (codepoint >= 0x2500 and codepoint <= 0x259F) or // Box Drawing + Block Elements
            (codepoint >= 0x2190 and codepoint <= 0x21FF) or // Arrows
            (codepoint >= 0x2800 and codepoint <= 0x28FF) or // Braille Patterns
            (codepoint >= 0x1FB00 and codepoint <= 0x1FBFF); // Symbols for Legacy Computing
    }

    fn pickPreferred(self: *TerminalFont, codepoint: u32) struct { face: ?c.FT_Face, hb: ?*c.hb_font_t } {
        if (preferSymbols(codepoint)) {
            if (self.symbols_ft_face) |face| {
                if (self.symbols_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
        }
        if (preferUnicode(codepoint)) {
            if (self.unicode_symbols2_ft_face) |face| {
                if (self.unicode_symbols2_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
            if (self.unicode_symbols_ft_face) |face| {
                if (self.unicode_symbols_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
            if (self.unicode_mono_ft_face) |face| {
                if (self.unicode_mono_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
            if (self.unicode_sans_ft_face) |face| {
                if (self.unicode_sans_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
        }
        if (preferEmoji(codepoint)) {
            if (self.emoji_color_ft_face) |face| {
                if (self.emoji_color_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
            if (self.emoji_text_ft_face) |face| {
                if (self.emoji_text_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
        }
        return .{ .face = null, .hb = null };
    }

    fn pickFallback(self: *TerminalFont, codepoint: u32) struct { face: ?c.FT_Face, hb: ?*c.hb_font_t } {
        if (self.symbols_ft_face) |face| {
            if (self.symbols_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }
        if (self.unicode_symbols2_ft_face) |face| {
            if (self.unicode_symbols2_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }
        if (self.unicode_symbols_ft_face) |face| {
            if (self.unicode_symbols_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }
        if (self.unicode_mono_ft_face) |face| {
            if (self.unicode_mono_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }
        if (self.unicode_sans_ft_face) |face| {
            if (self.unicode_sans_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }
        if (self.emoji_color_ft_face) |face| {
            if (self.emoji_color_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }
        if (self.emoji_text_ft_face) |face| {
            if (self.emoji_text_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }

        return .{ .face = null, .hb = null };
    }

    fn systemFallback(self: *TerminalFont, codepoint: u32) ?FacePair {
        if (!self.fc_enabled or self.fc_config == null) return null;
        if (self.system_fallback_by_cp.get(codepoint)) |cached| {
            if (cached) |path| {
                if (self.system_faces.get(path)) |pair| return pair;
            }
            return null;
        }

        var result: ?FacePair = null;
        const pattern = fc.FcPatternCreate() orelse return null;
        defer fc.FcPatternDestroy(pattern);

        const charset = fc.FcCharSetCreate() orelse return null;
        defer fc.FcCharSetDestroy(charset);
        _ = fc.FcCharSetAddChar(charset, codepoint);
        _ = fc.FcPatternAddCharSet(pattern, fc.FC_CHARSET, charset);
        _ = fc.FcPatternAddBool(pattern, fc.FC_SCALABLE, 1);

        if (self.fc_config) |cfg| {
            _ = fc.FcConfigSubstitute(cfg, pattern, fc.FcMatchPattern);
        }
        fc.FcDefaultSubstitute(pattern);

        var res: fc.FcResult = fc.FcResultMatch;
        const match = fc.FcFontMatch(self.fc_config, pattern, &res);
        if (match == null) {
            _ = self.system_fallback_by_cp.put(codepoint, null) catch {};
            return null;
        }
        defer fc.FcPatternDestroy(match);

        var file_ptr: [*c]fc.FcChar8 = null;
        if (fc.FcPatternGetString(match, fc.FC_FILE, 0, &file_ptr) != fc.FcResultMatch) {
            _ = self.system_fallback_by_cp.put(codepoint, null) catch {};
            return null;
        }

        const path = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(file_ptr)), 0);
        const owned = self.allocator.dupe(u8, path) catch return null;
        errdefer self.allocator.free(owned);

        if (self.system_faces.get(owned)) |pair| {
            _ = self.system_fallback_by_cp.put(codepoint, owned) catch {};
            return pair;
        }

        var fb_face: c.FT_Face = null;
        if (c.FT_New_Face(self.ft_library, owned.ptr, 0, &fb_face) != 0) {
            _ = self.system_fallback_by_cp.put(codepoint, null) catch {};
            return null;
        }
        if (c.FT_Set_Pixel_Sizes(fb_face, 0, @intFromFloat(self.line_height)) != 0) {
            _ = c.FT_Done_Face(fb_face);
            _ = self.system_fallback_by_cp.put(codepoint, null) catch {};
            return null;
        }
        const fb_hb = c.hb_ft_font_create(fb_face, null) orelse {
            _ = c.FT_Done_Face(fb_face);
            _ = self.system_fallback_by_cp.put(codepoint, null) catch {};
            return null;
        };

        const pair = FacePair{ .face = fb_face, .hb = fb_hb };
        _ = self.system_faces.put(self.allocator, owned, pair) catch {};
        _ = self.system_fallback_by_cp.put(codepoint, owned) catch {};
        result = pair;
        return result;
    }

    fn rasterizeGlyph(self: *TerminalFont, codepoint: u32, allow_compact: bool) GlyphError!void {
        var face = self.ft_face;
        var hb_font = self.hb_font;
        const preferred = self.pickPreferred(codepoint);
        if (preferred.face) |p_face| {
            if (preferred.hb) |p_hb| {
                face = p_face;
                hb_font = p_hb;
            }
        } else if (!hasGlyph(face, codepoint)) {
            const fallback = self.pickFallback(codepoint);
            if (fallback.face) |fb_face| {
                if (fallback.hb) |fb_hb| {
                    face = fb_face;
                    hb_font = fb_hb;
                }
            }
            if (!hasGlyph(face, codepoint)) {
                if (self.systemFallback(codepoint)) |pair| {
                    if (pair.face) |sf_face| {
                        if (pair.hb) |sf_hb| {
                            face = sf_face;
                            hb_font = sf_hb;
                        }
                    }
                }
            }
        }

        const buffer = c.hb_buffer_create();
        defer c.hb_buffer_destroy(buffer);
        c.hb_buffer_add_utf32(buffer, &codepoint, 1, 0, 1);
        c.hb_buffer_guess_segment_properties(buffer);
        c.hb_shape(hb_font, buffer, null, 0);

        var length: c_uint = 0;
        const infos = c.hb_buffer_get_glyph_infos(buffer, &length);
        const positions = c.hb_buffer_get_glyph_positions(buffer, &length);
        if (length == 0) return error.HbShapeFailed;

        const glyph_id = infos[0].codepoint;
        const is_color_face = c.FT_HAS_COLOR(face) or (self.emoji_color_ft_face != null and face == self.emoji_color_ft_face.?);
        const want_color = is_color_face;
        const load_flags: c_int = blk: {
            var flags: c_int = c.FT_LOAD_DEFAULT;
            if (want_color) flags |= c.FT_LOAD_COLOR;
            if (self.use_lcd and !want_color) flags |= c.FT_LOAD_TARGET_LCD;
            break :blk flags;
        };
        if (c.FT_Load_Glyph(face, glyph_id, load_flags) != 0) {
            if (self.emoji_color_ft_face != null and face == self.emoji_color_ft_face.? and self.emoji_text_ft_face != null and self.emoji_text_hb_font != null) {
                face = self.emoji_text_ft_face.?;
                hb_font = self.emoji_text_hb_font.?;
                if (c.FT_Load_Glyph(face, glyph_id, c.FT_LOAD_DEFAULT) != 0) return error.FtLoadFailed;
            } else {
                return error.FtLoadFailed;
            }
        }
        const render_mode: c.FT_Render_Mode = if (self.use_lcd and !want_color) c.FT_RENDER_MODE_LCD else c.FT_RENDER_MODE_NORMAL;
        if (c.FT_Render_Glyph(face.*.glyph, render_mode) != 0) {
            if (self.use_lcd and c.FT_Render_Glyph(face.*.glyph, c.FT_RENDER_MODE_NORMAL) == 0) {
                // fall back to grayscale
            } else {
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

            var y: i32 = 0;
            while (y < height) : (y += 1) {
                var x: i32 = 0;
                while (x < width) : (x += 1) {
                    var r: u8 = 0;
                    var g: u8 = 0;
                    var b: u8 = 0;
                    var a: u8 = 0;
                    if (bitmap.pixel_mode == c.FT_PIXEL_MODE_BGRA) {
                        const base = @as(usize, @intCast(y * @as(i32, @intCast(bitmap.pitch)) + x * 4));
                        b = bitmap.buffer[base + 0];
                        g = bitmap.buffer[base + 1];
                        r = bitmap.buffer[base + 2];
                        a = bitmap.buffer[base + 3];
                    } else if (bitmap.pixel_mode == c.FT_PIXEL_MODE_LCD) {
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
                    const dst_idx = @as(usize, @intCast((y * width + x) * 4));
                    if (bitmap.pixel_mode == c.FT_PIXEL_MODE_BGRA) {
                        rgba[dst_idx] = r;
                        rgba[dst_idx + 1] = g;
                        rgba[dst_idx + 2] = b;
                        rgba[dst_idx + 3] = a;
                    } else {
                        const gamma = 1.0 / 2.2;
                        const rf = std.math.pow(f32, @as(f32, @floatFromInt(r)) / 255.0, gamma);
                        const gf = std.math.pow(f32, @as(f32, @floatFromInt(g)) / 255.0, gamma);
                        const bf = std.math.pow(f32, @as(f32, @floatFromInt(b)) / 255.0, gamma);
                        const af = std.math.pow(f32, @as(f32, @floatFromInt(a)) / 255.0, gamma);
                        rgba[dst_idx] = @intFromFloat(@min(255.0, rf * 255.0));
                        rgba[dst_idx + 1] = @intFromFloat(@min(255.0, gf * 255.0));
                        rgba[dst_idx + 2] = @intFromFloat(@min(255.0, bf * 255.0));
                        rgba[dst_idx + 3] = @intFromFloat(@min(255.0, af * 255.0));
                    }
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
                .is_color = bitmap.pixel_mode == c.FT_PIXEL_MODE_BGRA,
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
            .is_color = false,
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
