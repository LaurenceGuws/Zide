const std = @import("std");
const terminal_font_mod = @import("../terminal_font.zig");
const TerminalFont = terminal_font_mod.TerminalFont;
const hb = terminal_font_mod.c;
const text_draw = @import("text_draw.zig");
const terminal_glyphs = @import("terminal_glyphs.zig");
const terminal_underline = @import("terminal_underline.zig");
const draw_ops = @import("draw_ops.zig");
const font_runtime = @import("font_runtime.zig");
const app_logger = @import("../../app_logger.zig");
const types = @import("types.zig");
const renderer_root = @import("../renderer.zig");

const Color = renderer_root.Color;
const Renderer = renderer_root.Renderer;

fn snapInt(value: f32) i32 {
    return @intFromFloat(std.math.round(value));
}

fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
}

const TextOrigin = struct {
    x: f32,
    y: f32,
};

fn snapTextOrigin(self: *Renderer, x: f32, y: f32) TextOrigin {
    return .{
        .x = snapToDevicePixel(x, self.render_scale),
        .y = snapToDevicePixel(y, self.render_scale),
    };
}

pub fn drawText(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
    const prev = self.text_bg_rgba;
    defer self.text_bg_rgba = prev;
    self.text_bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    drawTextWithFont(self, &self.terminal_font, self.terminal_cell_width, self.terminal_cell_height, text, x, y, color);
}

pub fn drawTextMonospace(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
    drawTextMonospacePolicy(self, text, x, y, color, false);
}

pub fn drawTextMonospacePolicy(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color, disable_programming_ligatures: bool) void {
    const prev = self.text_bg_rgba;
    defer self.text_bg_rgba = prev;
    self.text_bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    drawTextWithFontMonospace(self, &self.terminal_font, self.terminal_cell_width, self.terminal_cell_height, text, x, y, color, disable_programming_ligatures);
}

pub fn drawTextMonospaceOnBg(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
    drawTextMonospaceOnBgPolicy(self, text, x, y, color, bg, false);
}

pub fn drawTextMonospaceOnBgPolicy(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color, bg: Color, disable_programming_ligatures: bool) void {
    const prev = self.text_bg_rgba;
    defer self.text_bg_rgba = prev;
    var bg_rgba = bg.toRgba();
    bg_rgba.a = 255;
    self.text_bg_rgba = bg_rgba;
    drawTextWithFontMonospace(self, &self.terminal_font, self.terminal_cell_width, self.terminal_cell_height, text, x, y, color, disable_programming_ligatures);
}

pub fn drawTextOnBg(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
    const prev = self.text_bg_rgba;
    defer self.text_bg_rgba = prev;
    var bg_rgba = bg.toRgba();
    bg_rgba.a = 255;
    self.text_bg_rgba = bg_rgba;
    drawTextWithFont(self, &self.terminal_font, self.terminal_cell_width, self.terminal_cell_height, text, x, y, color);
}

pub fn drawTextSized(self: *Renderer, text: []const u8, x: f32, y: f32, size: f32, color: Color) void {
    const prev = self.text_bg_rgba;
    defer self.text_bg_rgba = prev;
    self.text_bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    const font = font_runtime.fontForSize(self, size) orelse {
        drawText(self, text, x, y, color);
        return;
    };
    const scale = if (self.render_scale > 0.0) self.render_scale else 1.0;
    drawTextWithFont(self, font, font.cell_width / scale, font.line_height / scale, text, x, y, color);
}

pub fn drawIconText(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
    const prev = self.text_bg_rgba;
    defer self.text_bg_rgba = prev;
    self.text_bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    drawTextWithFont(self, &self.icon_font, self.icon_char_width, self.icon_char_height, text, x, y, color);
}

pub fn measureIconTextWidth(self: *Renderer, text: []const u8) f32 {
    return measureTextWidth(self, &self.icon_font, text);
}

pub fn drawChar(self: *Renderer, char: u8, x: f32, y: f32, color: Color) void {
    var buf = [1]u8{char};
    drawText(self, buf[0..], x, y, color);
}

pub fn drawTerminalCell(self: *Renderer, codepoint: u32, x: f32, y: f32, cell_width: f32, cell_height: f32, fg: Color, bg: Color, underline_color: Color, bold: bool, underline: bool, is_cursor: bool, followed_by_space: bool, draw_bg: bool) void {
    const snapped_x = snapToDevicePixel(x, self.render_scale);
    const snapped_y = snapToDevicePixel(y, self.render_scale);
    const snapped_cell_width = snapToDevicePixel(cell_width, self.render_scale);
    const snapped_cell_height = snapToDevicePixel(cell_height, self.render_scale);
    const snapped_cell_w_i = snapInt(snapped_cell_width);
    const snapped_cell_h_i = snapInt(snapped_cell_height);

    if (draw_bg) {
        self.drawRect(snapInt(snapped_x), snapInt(snapped_y), snapped_cell_w_i, snapped_cell_h_i, if (is_cursor) fg else bg);
    }

    if (codepoint != 0) {
        const text_color = if (is_cursor) bg else fg;
        _ = bold;
        const draw = terminal_font_mod.DrawContext{ .ctx = self, .drawTexture = drawTextureThunk };
        const behind = if (is_cursor) fg else bg;
        var behind_rgba = behind.toRgba();
        behind_rgba.a = 255;
        self.text_bg_rgba = behind_rgba;
        if (!drawTerminalBoxGlyph(self, codepoint, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, text_color)) {
            self.terminal_font.drawGlyph(draw, codepoint, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, followed_by_space, text_color.toRgba());
        }
        if (underline) {
            terminal_underline.drawUnderline(drawRectThunk, self, snapInt(snapped_x), snapInt(snapped_y), snapped_cell_w_i, snapped_cell_h_i, underline_color);
        }
    }
}

pub fn drawTerminalCellGrapheme(self: *Renderer, base: u32, combining: []const u32, x: f32, y: f32, cell_width: f32, cell_height: f32, fg: Color, bg: Color, underline_color: Color, bold: bool, underline: bool, is_cursor: bool, followed_by_space: bool, draw_bg: bool) void {
    if (combining.len == 0) return drawTerminalCell(self, base, x, y, cell_width, cell_height, fg, bg, underline_color, bold, underline, is_cursor, followed_by_space, draw_bg);
    const snapped_x = snapToDevicePixel(x, self.render_scale);
    const snapped_y = snapToDevicePixel(y, self.render_scale);
    const snapped_cell_width = snapToDevicePixel(cell_width, self.render_scale);
    const snapped_cell_height = snapToDevicePixel(cell_height, self.render_scale);
    const snapped_cell_w_i = snapInt(snapped_cell_width);
    const snapped_cell_h_i = snapInt(snapped_cell_height);
    if (draw_bg) self.drawRect(snapInt(snapped_x), snapInt(snapped_y), snapped_cell_w_i, snapped_cell_h_i, if (is_cursor) fg else bg);
    if (base != 0) {
        const text_color = if (is_cursor) bg else fg;
        const draw = terminal_font_mod.DrawContext{ .ctx = self, .drawTexture = drawTextureThunk };
        const behind = if (is_cursor) fg else bg;
        var behind_rgba = behind.toRgba();
        behind_rgba.a = 255;
        self.text_bg_rgba = behind_rgba;
        if (!drawTerminalBoxGlyph(self, base, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, text_color)) {
            self.terminal_font.drawGrapheme(draw, base, combining, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, followed_by_space, text_color.toRgba());
        }
        if (underline) terminal_underline.drawUnderline(drawRectThunk, self, snapInt(snapped_x), snapInt(snapped_y), snapped_cell_w_i, snapped_cell_h_i, underline_color);
    }
}

pub fn drawTerminalCellGraphemeBatched(self: *Renderer, base: u32, combining: []const u32, x: f32, y: f32, cell_width: f32, cell_height: f32, fg: Color, bg: Color, underline_color: Color, bold: bool, underline: bool, is_cursor: bool, followed_by_space: bool, draw_bg: bool) void {
    if (combining.len == 0) return drawTerminalCellBatched(self, base, x, y, cell_width, cell_height, fg, bg, underline_color, bold, underline, is_cursor, followed_by_space, draw_bg);
    const snapped_x = snapToDevicePixel(x, self.render_scale);
    const snapped_y = snapToDevicePixel(y, self.render_scale);
    const snapped_cell_width = snapToDevicePixel(cell_width, self.render_scale);
    const snapped_cell_height = snapToDevicePixel(cell_height, self.render_scale);
    const snapped_cell_w_i = snapInt(snapped_cell_width);
    const snapped_cell_h_i = snapInt(snapped_cell_height);
    if (draw_bg) self.addTerminalRect(snapInt(snapped_x), snapInt(snapped_y), snapped_cell_w_i, snapped_cell_h_i, if (is_cursor) fg else bg);
    if (base != 0) {
        const text_color = if (is_cursor) bg else fg;
        const draw = terminal_font_mod.DrawContext{ .ctx = self, .drawTexture = drawTextureGlyphCacheThunk };
        const behind = if (is_cursor) fg else bg;
        var behind_rgba = behind.toRgba();
        behind_rgba.a = 255;
        self.text_bg_rgba = behind_rgba;
        if (!drawTerminalBoxGlyphBatched(self, base, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, text_color)) {
            self.terminal_font.drawGrapheme(draw, base, combining, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, followed_by_space, text_color.toRgba());
        }
        if (underline) terminal_underline.drawUnderline(addTerminalGlyphRectThunk, self, snapInt(snapped_x), snapInt(snapped_y), snapped_cell_w_i, snapped_cell_h_i, underline_color);
    }
}

pub fn drawTerminalCellBatched(self: *Renderer, codepoint: u32, x: f32, y: f32, cell_width: f32, cell_height: f32, fg: Color, bg: Color, underline_color: Color, bold: bool, underline: bool, is_cursor: bool, followed_by_space: bool, draw_bg: bool) void {
    const snapped_x = snapToDevicePixel(x, self.render_scale);
    const snapped_y = snapToDevicePixel(y, self.render_scale);
    const snapped_cell_width = snapToDevicePixel(cell_width, self.render_scale);
    const snapped_cell_height = snapToDevicePixel(cell_height, self.render_scale);
    const snapped_cell_w_i = snapInt(snapped_cell_width);
    const snapped_cell_h_i = snapInt(snapped_cell_height);
    if (draw_bg) self.addTerminalRect(snapInt(snapped_x), snapInt(snapped_y), snapped_cell_w_i, snapped_cell_h_i, if (is_cursor) fg else bg);
    if (codepoint != 0) {
        const text_color = if (is_cursor) bg else fg;
        _ = bold;
        if (!drawTerminalBoxGlyphBatched(self, codepoint, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, text_color)) {
            const draw = terminal_font_mod.DrawContext{ .ctx = self, .drawTexture = drawTextureGlyphCacheThunk };
            const behind = if (is_cursor) fg else bg;
            var behind_rgba = behind.toRgba();
            behind_rgba.a = 255;
            self.text_bg_rgba = behind_rgba;
            self.terminal_font.drawGlyph(draw, codepoint, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, followed_by_space, text_color.toRgba());
        }
        if (underline) terminal_underline.drawUnderline(addTerminalGlyphRectThunk, self, snapInt(snapped_x), snapInt(snapped_y), snapped_cell_w_i, snapped_cell_h_i, underline_color);
    }
}

fn drawTerminalBoxGlyph(self: *Renderer, codepoint: u32, x: f32, y: f32, w: f32, h: f32, color: Color) bool {
    return terminal_glyphs.drawBoxGlyph(drawRectThunk, self, codepoint, x, y, w, h, color);
}

fn drawTerminalBoxGlyphBatched(self: *Renderer, codepoint: u32, x: f32, y: f32, w: f32, h: f32, color: Color) bool {
    return terminal_glyphs.drawBoxGlyphBatched(addTerminalGlyphRectThunk, self, codepoint, x, y, w, h, color);
}

fn drawTextWithFont(self: *Renderer, font: *TerminalFont, cell_w: f32, cell_h: f32, text: []const u8, x: f32, y: f32, color: Color) void {
    const origin = snapTextOrigin(self, x, y);
    text_draw.drawText(self.allocator, font, self, drawTextureThunk, text, origin.x, origin.y, cell_w, cell_h, color.toRgba(), false);
}

fn drawTextWithFontMonospace(self: *Renderer, font: *TerminalFont, cell_w: f32, cell_h: f32, text: []const u8, x: f32, y: f32, color: Color, disable_programming_ligatures: bool) void {
    const origin = snapTextOrigin(self, x, y);
    if (drawTextWithFontMonospaceShaped(self, font, cell_w, cell_h, text, origin.x, origin.y, color.toRgba(), disable_programming_ligatures)) return;
    text_draw.drawText(self.allocator, font, self, drawTextureThunk, text, origin.x, origin.y, cell_w, cell_h, color.toRgba(), true);
}

fn drawTextWithFontMonospaceShaped(self: *Renderer, font: *TerminalFont, cell_w: f32, cell_h: f32, text: []const u8, x: f32, y: f32, color: types.Rgba, disable_programming_ligatures: bool) bool {
    const log = app_logger.logger("renderer.text");
    if (text.len == 0) return true;
    if (!textLikelyNeedsShaping(text)) {
        var fast_features_buf: [16]hb.hb_feature_t = undefined;
        const fast_features_len = self.collectShapeFeatures(.editor, disable_programming_ligatures, fast_features_buf[0..]);
        if (fast_features_len == 0) return false;
    }
    var codepoints = std.ArrayList(u32).empty;
    defer codepoints.deinit(self.allocator);
    var idx: usize = 0;
    while (idx < text.len) {
        const first = text[idx];
        const seq_len = std.unicode.utf8ByteSequenceLength(first) catch {
            idx += 1;
            codepoints.append(self.allocator, 0xFFFD) catch |err| {
                log.logf(.warning, "shaped text append replacement failed err={s}", .{@errorName(err)});
                return false;
            };
            continue;
        };
        if (idx + seq_len > text.len) {
            idx += 1;
            codepoints.append(self.allocator, 0xFFFD) catch |err| {
                log.logf(.warning, "shaped text append replacement (truncated utf8) failed err={s}", .{@errorName(err)});
                return false;
            };
            continue;
        }
        const cp = std.unicode.utf8Decode(text[idx .. idx + seq_len]) catch 0xFFFD;
        codepoints.append(self.allocator, cp) catch |err| {
            log.logf(.warning, "shaped text codepoint append failed err={s}", .{@errorName(err)});
            return false;
        };
        idx += seq_len;
    }
    if (codepoints.items.len == 0) return true;
    var span_start: usize = 0;
    while (span_start < codepoints.items.len) {
        const start_choice = font.pickFontForCodepoint(codepoints.items[span_start]);
        const span_hb_font = start_choice.hb_font;
        var span_end = span_start + 1;
        while (span_end < codepoints.items.len) : (span_end += 1) {
            const choice = font.pickFontForCodepoint(codepoints.items[span_end]);
            if (choice.hb_font != span_hb_font) break;
        }
        const buffer = hb.hb_buffer_create();
        defer hb.hb_buffer_destroy(buffer);
        hb.hb_buffer_set_content_type(buffer, hb.HB_BUFFER_CONTENT_TYPE_UNICODE);
        var cp_i = span_start;
        while (cp_i < span_end) : (cp_i += 1) {
            const cp = if (codepoints.items[cp_i] == 0) @as(u32, ' ') else codepoints.items[cp_i];
            hb.hb_buffer_add(buffer, cp, @intCast(cp_i - span_start));
        }
        hb.hb_buffer_guess_segment_properties(buffer);
        var shape_features_buf: [16]hb.hb_feature_t = undefined;
        const shape_features_len = self.collectShapeFeatures(.editor, disable_programming_ligatures, shape_features_buf[0..]);
        hb.hb_shape(span_hb_font, buffer, if (shape_features_len > 0) shape_features_buf[0..].ptr else null, @intCast(shape_features_len));
        var length: c_uint = 0;
        const infos = hb.hb_buffer_get_glyph_infos(buffer, &length);
        const positions = hb.hb_buffer_get_glyph_positions(buffer, &length);
        if (length == 0) {
            var fallback_x = x + @as(f32, @floatFromInt(span_start)) * cell_w;
            var j = span_start;
            while (j < span_end) : (j += 1) {
                font.drawGlyph(.{ .ctx = self, .drawTexture = drawTextureThunk }, codepoints.items[j], fallback_x, y, cell_w, cell_h, false, color);
                fallback_x += cell_w;
            }
            span_start = span_end;
            continue;
        }
        const span_len = span_end - span_start;
        self.terminal_shape_first_pen_set.items.len = 0;
        self.terminal_shape_first_pen.items.len = 0;
        self.terminal_shape_first_pen_set.ensureTotalCapacity(self.allocator, span_len) catch |err| {
            log.logf(.warning, "shaped text first-pen-set capacity failed span_len={d} err={s}", .{ span_len, @errorName(err) });
            return false;
        };
        self.terminal_shape_first_pen.ensureTotalCapacity(self.allocator, span_len) catch |err| {
            log.logf(.warning, "shaped text first-pen capacity failed span_len={d} err={s}", .{ span_len, @errorName(err) });
            return false;
        };
        self.terminal_shape_first_pen_set.items.len = span_len;
        self.terminal_shape_first_pen.items.len = span_len;
        @memset(self.terminal_shape_first_pen_set.items, false);
        @memset(self.terminal_shape_first_pen.items, 0);
        const glyph_len: usize = @intCast(length);
        const render_scale = if (font.render_scale > 0.0) font.render_scale else 1.0;
        const inv_scale = 1.0 / render_scale;
        var pen_x: f32 = 0;
        var gi: usize = 0;
        while (gi < glyph_len) : (gi += 1) {
            const cluster_u32 = infos[gi].cluster;
            const pen_before = pen_x;
            pen_x += (@as(f32, @floatFromInt(positions[gi].x_advance)) / 64.0) * inv_scale;
            if (cluster_u32 >= span_len) continue;
            const cluster: usize = @intCast(cluster_u32);
            if (!self.terminal_shape_first_pen_set.items[cluster]) {
                self.terminal_shape_first_pen_set.items[cluster] = true;
                self.terminal_shape_first_pen.items[cluster] = pen_before;
            }
            const pen_rel = pen_before - self.terminal_shape_first_pen.items[cluster];
            const glyph = font.getGlyphById(start_choice.face, infos[gi].codepoint, start_choice.want_color, positions[gi].x_advance) catch continue;
            const cell_x = x + @as(f32, @floatFromInt(span_start + cluster)) * cell_w;
            const baseline = y + font.baseline_from_top * inv_scale;
            const gx_off = (@as(f32, @floatFromInt(positions[gi].x_offset)) / 64.0) * inv_scale;
            const gy_off = (@as(f32, @floatFromInt(positions[gi].y_offset)) / 64.0) * inv_scale;
            const draw_x = cell_x + pen_rel + gx_off + @as(f32, @floatFromInt(glyph.bearing_x)) * inv_scale;
            const draw_y = (baseline - @as(f32, @floatFromInt(glyph.bearing_y)) * inv_scale) - gy_off;
            const dest: types.Rect = .{
                .x = snapToDevicePixel(draw_x, render_scale),
                .y = snapToDevicePixel(draw_y, render_scale),
                .width = @as(f32, @floatFromInt(glyph.width)) * inv_scale,
                .height = @as(f32, @floatFromInt(glyph.height)) * inv_scale,
            };
            const draw_color = if (glyph.is_color) types.Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 } else color;
            if (glyph.is_color) {
                drawTextureThunk(self, font.color_texture, glyph.rect, dest, draw_color, .rgba);
            } else {
                drawTextureThunk(self, font.coverage_texture, glyph.rect, dest, draw_color, .font_coverage);
            }
        }
        span_start = span_end;
    }
    return true;
}

fn textLikelyNeedsShaping(text: []const u8) bool {
    for (text) |b| {
        if (b >= 0x80) return true;
        const is_alnum = (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or (b >= '0' and b <= '9');
        const is_simple = is_alnum or b == ' ' or b == '_' or b == '\t';
        if (!is_simple) return true;
    }
    return false;
}

fn measureTextWidth(self: *Renderer, font: *TerminalFont, text: []const u8) f32 {
    const scale = if (self.render_scale > 0.0) self.render_scale else 1.0;
    return text_draw.measureTextWidth(font, text, font.cell_width / scale);
}

fn drawTextureRectThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
    const self: *Renderer = @ptrCast(@alignCast(ctx));
    draw_ops.drawTextureRect(self, texture, src, dest, color, self.text_bg_rgba, kind);
}

fn drawTextureThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
    drawTextureRectThunk(ctx, texture, src, dest, color, kind);
}

fn drawRectThunk(ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void {
    const self: *Renderer = @ptrCast(@alignCast(ctx));
    self.drawRect(x, y, w, h, color);
}

fn drawTextureGlyphCacheThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
    const renderer: *Renderer = @ptrCast(@alignCast(ctx));
    renderer.terminal_glyph_cache.addQuad(texture, src, dest, color, renderer.text_bg_rgba, kind);
}

fn addTerminalGlyphRectThunk(ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void {
    const renderer: *Renderer = @ptrCast(@alignCast(ctx));
    renderer.addTerminalGlyphRect(x, y, w, h, color);
}
