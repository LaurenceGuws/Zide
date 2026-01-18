const std = @import("std");
const builtin = @import("builtin");
const compositor = @import("../platform/compositor.zig");

const c = @cImport({
    @cInclude("raylib.h");
});
const TerminalFont = @import("terminal_font.zig").TerminalFont;

// ─────────────────────────────────────────────────────────────────────────────
// Font Selection (change this to test different fonts)
// ─────────────────────────────────────────────────────────────────────────────
pub const FontFamily = enum {
    iosevka,
    jetbrains_mono,
};

/// Change this to switch fonts at compile time
pub const FONT_FAMILY: FontFamily = .jetbrains_mono;

pub const FONT_PATH: [*:0]const u8 = switch (FONT_FAMILY) {
    .iosevka => "assets/fonts/IosevkaTermNerdFont-Regular.ttf",
    .jetbrains_mono => "assets/fonts/JetBrainsMonoNerdFont-Regular.ttf",
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn toRaylib(self: Color) c.Color {
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = self.a };
    }

    pub const black = Color{ .r = 0, .g = 0, .b = 0 };
    pub const white = Color{ .r = 255, .g = 255, .b = 255 };
    pub const gray = Color{ .r = 128, .g = 128, .b = 128 };
    pub const dark_gray = Color{ .r = 40, .g = 42, .b = 54 };
    pub const light_gray = Color{ .r = 68, .g = 71, .b = 90 };

    // Dracula theme colors
    pub const bg = Color{ .r = 40, .g = 42, .b = 54 };
    pub const fg = Color{ .r = 248, .g = 248, .b = 242 };
    pub const selection = Color{ .r = 68, .g = 71, .b = 90 };
    pub const comment = Color{ .r = 98, .g = 114, .b = 164 };
    pub const cyan = Color{ .r = 139, .g = 233, .b = 253 };
    pub const green = Color{ .r = 80, .g = 250, .b = 123 };
    pub const orange = Color{ .r = 255, .g = 184, .b = 108 };
    pub const pink = Color{ .r = 255, .g = 121, .b = 198 };
    pub const purple = Color{ .r = 189, .g = 147, .b = 249 };
    pub const red = Color{ .r = 255, .g = 85, .b = 85 };
    pub const yellow = Color{ .r = 241, .g = 250, .b = 140 };
};

pub const MousePos = struct {
    x: f32,
    y: f32,
};

pub const Theme = struct {
    background: Color = Color.bg,
    foreground: Color = Color.fg,
    selection: Color = Color.selection,
    cursor: Color = Color.fg,
    link: Color = Color.cyan,
    line_number: Color = Color.comment,
    line_number_bg: Color = Color{ .r = 33, .g = 34, .b = 44 },
    current_line: Color = Color{ .r = 50, .g = 52, .b = 66 },

    // Syntax colors
    comment_color: Color = Color.comment,
    string: Color = Color.yellow,
    keyword: Color = Color.pink,
    number: Color = Color.purple,
    function: Color = Color.green,
    variable: Color = Color.fg,
    type_name: Color = Color.cyan,
    operator: Color = Color.pink,
    builtin_color: Color = Color.cyan,
    punctuation: Color = Color.fg,
    constant: Color = Color.purple,
    attribute: Color = Color.green,
    namespace: Color = Color.cyan,
    label: Color = Color.cyan,
    error_token: Color = Color.red,
};

const key_repeat_key_count: usize = 512;
const key_repeat_initial_delay: f64 = 0.45;
const key_repeat_rate: f64 = 30.0;

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    width: c_int,
    height: c_int,
    font: c.Font,
    font_size: f32,
    char_width: f32,
    char_height: f32,
    icon_font: c.Font,
    icon_font_size: f32,
    icon_char_width: f32,
    icon_char_height: f32,
    terminal_cell_width: f32,
    terminal_cell_height: f32,
    terminal_font: TerminalFont,
    terminal_texture: ?c.RenderTexture2D,
    terminal_texture_w: c_int,
    terminal_texture_h: c_int,
    theme: Theme,
    mouse_scale: MousePos,
    wayland_scale_cache: ?f32,
    wayland_scale_last_update: f64,
    key_repeat_next: [key_repeat_key_count]f64,

    fn snapInt(value: f32) c_int {
        return @intFromFloat(std.math.round(value));
    }

    fn snapFloat(value: f32) f32 {
        return @as(f32, @floatFromInt(snapInt(value)));
    }

    pub fn init(allocator: std.mem.Allocator, width: c_int, height: c_int, title: [*:0]const u8) !*Renderer {
        c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE | c.FLAG_VSYNC_HINT);
        c.InitWindow(width, height, title);
        // Note: Don't use SetTargetFPS() - it busy-waits and causes 100% CPU usage.
        // VSync (FLAG_VSYNC_HINT) properly blocks in SwapBuffers instead.

        // Do a dummy frame to let the compositor configure the window (Wayland/tiling WMs)
        // Without this, the first real frame may use wrong dimensions
        c.BeginDrawing();
        c.ClearBackground(c.Color{ .r = 40, .g = 42, .b = 54, .a = 255 }); // Match theme bg
        c.EndDrawing();

        // Now get the actual window size after compositor has configured it
        const actual_width = c.GetScreenWidth();
        const actual_height = c.GetScreenHeight();

        const renderer = try allocator.create(Renderer);

        // Load default monospace font
        const font_size: f32 = 16.0;
        const font = c.GetFontDefault();

        renderer.* = .{
            .allocator = allocator,
            .width = actual_width,
            .height = actual_height,
            .font = font,
            .font_size = font_size,
            .char_width = font_size * 0.6, // Approximate monospace width
            .char_height = font_size * 1.2,
            .icon_font = font,
            .icon_font_size = font_size,
            .icon_char_width = font_size * 0.6,
            .icon_char_height = font_size * 1.2,
            .terminal_cell_width = font_size * 0.6,
            .terminal_cell_height = font_size * 1.2,
            .terminal_font = undefined,
            .terminal_texture = null,
            .terminal_texture_w = 0,
            .terminal_texture_h = 0,
            .theme = .{},
            .mouse_scale = .{ .x = 1.0, .y = 1.0 },
            .wayland_scale_cache = null,
            .wayland_scale_last_update = -1000.0,
            .key_repeat_next = [_]f64{0} ** key_repeat_key_count,
        };

        // Load app font with Nerd Font glyphs if available
        renderer.loadFontWithGlyphs(allocator, FONT_PATH, font_size);
        if (loadFontWithGlyphsAtSize(allocator, FONT_PATH, font_size * 2.0)) |icon_font| {
            renderer.icon_font = icon_font;
            renderer.icon_font_size = font_size * 2.0;
            const measure = c.MeasureTextEx(renderer.icon_font, "M", renderer.icon_font_size, 0);
            renderer.icon_char_width = measure.x;
            renderer.icon_char_height = measure.y;
            c.SetTextureFilter(renderer.icon_font.texture, c.TEXTURE_FILTER_BILINEAR);
        } else {
            renderer.icon_font = renderer.font;
            renderer.icon_font_size = renderer.font_size;
            renderer.icon_char_width = renderer.char_width;
            renderer.icon_char_height = renderer.char_height;
        }
        renderer.terminal_font = try TerminalFont.init(allocator, FONT_PATH, font_size);
        renderer.terminal_font.setAtlasFilterPoint();
        renderer.terminal_cell_width = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(renderer.terminal_font.cell_width)))));
        renderer.terminal_cell_height = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(renderer.terminal_font.line_height)))));

        return renderer;
    }

    pub fn deinit(self: *Renderer) void {
        if (self.font.texture.id != c.GetFontDefault().texture.id) {
            c.UnloadFont(self.font);
        }
        if (self.icon_font.texture.id != c.GetFontDefault().texture.id and self.icon_font.texture.id != self.font.texture.id) {
            c.UnloadFont(self.icon_font);
        }
        if (self.terminal_texture) |rt| {
            c.UnloadRenderTexture(rt);
            self.terminal_texture = null;
        }
        c.CloseWindow();
        self.terminal_font.deinit();
        self.allocator.destroy(self);
    }

    pub fn loadFont(self: *Renderer, path: [*:0]const u8, size: f32) void {
        const font = c.LoadFontEx(path, @intFromFloat(size), null, 0);
        if (font.texture.id != 0) {
            if (self.font.texture.id != c.GetFontDefault().texture.id) {
                c.UnloadFont(self.font);
            }
            self.font = font;
            self.font_size = size;
            // Measure a character to get proper width
            const measure = c.MeasureTextEx(self.font, "M", size, 0);
            self.char_width = measure.x;
            self.char_height = measure.y;
            self.terminal_cell_width = self.char_width;
        }
    }

    pub fn loadFontWithGlyphs(self: *Renderer, allocator: std.mem.Allocator, path: [*:0]const u8, size: f32) void {
        if (loadFontWithGlyphsAtSize(allocator, path, size)) |font| {
            if (self.font.texture.id != c.GetFontDefault().texture.id) {
                c.UnloadFont(self.font);
            }
            self.font = font;
            self.font_size = size;
            const measure = c.MeasureTextEx(self.font, "M", size, 0);
            self.char_width = measure.x;
            self.char_height = measure.y;
            // Terminal metrics are managed by TerminalFont
        }
    }

    fn loadFontWithGlyphsAtSize(allocator: std.mem.Allocator, path: [*:0]const u8, size: f32) ?c.Font {
        const ranges = [_]struct { start: u32, end: u32 }{
            .{ .start = 0x20, .end = 0x7E },   // Basic Latin
            .{ .start = 0xA0, .end = 0xFF },   // Latin-1 Supplement
            .{ .start = 0x2500, .end = 0x257F }, // Box Drawing
            .{ .start = 0x2580, .end = 0x259F }, // Block Elements
            .{ .start = 0x2700, .end = 0x27BF }, // Dingbats (includes ❯)
            .{ .start = 0x2800, .end = 0x28FF }, // Braille Patterns
            .{ .start = 0xE000, .end = 0xF8FF }, // PUA (BMP) - Nerd Font
            .{ .start = 0xF0000, .end = 0xF2FFF }, // PUA-A - Nerd Font v3
        };

        var total: usize = 0;
        for (ranges) |range| {
            total += @as(usize, @intCast(range.end - range.start + 1));
        }

        const glyphs = allocator.alloc(c_int, total) catch return null;
        defer allocator.free(glyphs);

        var idx: usize = 0;
        for (ranges) |range| {
            var codepoint: u32 = range.start;
            while (codepoint <= range.end) : (codepoint += 1) {
                glyphs[idx] = @intCast(codepoint);
                idx += 1;
            }
        }

        // Load font with extra padding to avoid glyph clipping
        var data_size: c_int = 0;
        const file_data = c.LoadFileData(path, &data_size);
        if (file_data == null or data_size == 0) return null;
        defer c.UnloadFileData(file_data);

        var glyph_count: c_int = 0;
        const font_data = c.LoadFontData(
            file_data,
            data_size,
            @intFromFloat(size),
            glyphs.ptr,
            @intCast(total),
            0,
            &glyph_count,
        );
        if (font_data == null or glyph_count == 0) return null;

        var recs: [*c]c.Rectangle = null;
        const padding: c_int = 2;
        const image = c.GenImageFontAtlas(font_data, &recs, glyph_count, @intFromFloat(size), padding, 0);
        const texture = c.LoadTextureFromImage(image);
        c.UnloadImage(image);

        if (texture.id != 0) {
            return .{
                .baseSize = @intFromFloat(size),
                .glyphCount = glyph_count,
                .glyphPadding = padding,
                .texture = texture,
                .recs = recs,
                .glyphs = font_data,
            };
        } else {
            const temp_font = c.Font{
                .baseSize = @intFromFloat(size),
                .glyphCount = glyph_count,
                .glyphPadding = padding,
                .texture = texture,
                .recs = recs,
                .glyphs = font_data,
            };
            c.UnloadFont(temp_font);
            return null;
        }
    }

    pub fn shouldClose(self: *Renderer) bool {
        _ = self;
        return c.WindowShouldClose();
    }

    pub fn beginFrame(self: *Renderer) void {
        c.BeginDrawing();

        // Update dimensions AFTER BeginDrawing (which polls events and updates state)
        self.width = c.GetScreenWidth();
        self.height = c.GetScreenHeight();

        self.updateMouseScale();
        c.ClearBackground(self.theme.background.toRaylib());
    }

    pub fn endFrame(_: *Renderer) void {
        c.EndDrawing();
    }

    pub fn ensureTerminalTexture(self: *Renderer, width: c_int, height: c_int) bool {
        if (width <= 0 or height <= 0) return false;
        if (self.terminal_texture != null and self.terminal_texture_w == width and self.terminal_texture_h == height) {
            return false;
        }
        if (self.terminal_texture) |rt| {
            c.UnloadRenderTexture(rt);
            self.terminal_texture = null;
        }
        const rt = c.LoadRenderTexture(width, height);
        if (rt.texture.id == 0) {
            self.terminal_texture_w = 0;
            self.terminal_texture_h = 0;
            return false;
        }
        c.SetTextureFilter(rt.texture, c.TEXTURE_FILTER_POINT);
        self.terminal_texture = rt;
        self.terminal_texture_w = width;
        self.terminal_texture_h = height;
        return true;
    }

    pub fn beginTerminalTexture(self: *Renderer) bool {
        if (self.terminal_texture) |rt| {
            c.BeginTextureMode(rt);
            return true;
        }
        return false;
    }

    pub fn endTerminalTexture(_: *Renderer) void {
        c.EndTextureMode();
    }

    pub fn drawTerminalTexture(self: *Renderer, x: f32, y: f32) void {
        if (self.terminal_texture) |rt| {
            const rect = c.Rectangle{
                .x = 0,
                .y = 0,
                .width = @as(f32, @floatFromInt(rt.texture.width)),
                .height = -@as(f32, @floatFromInt(rt.texture.height)),
            };
            const pos = c.Vector2{ .x = x, .y = y };
            c.DrawTextureRec(rt.texture, rect, pos, c.WHITE);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Basic drawing primitives
    // ─────────────────────────────────────────────────────────────────────────

    pub fn drawRect(self: *Renderer, x: c_int, y: c_int, w: c_int, h: c_int, color: Color) void {
        _ = self;
        c.DrawRectangle(x, y, w, h, color.toRaylib());
    }

    pub fn drawRectOutline(self: *Renderer, x: c_int, y: c_int, w: c_int, h: c_int, color: Color) void {
        _ = self;
        c.DrawRectangleLines(x, y, w, h, color.toRaylib());
    }

    pub fn setClipboardText(self: *Renderer, text: [*:0]const u8) void {
        _ = self;
        c.SetClipboardText(text);
    }

    pub fn getClipboardText(self: *Renderer) ?[]const u8 {
        _ = self;
        const ptr = c.GetClipboardText();
        if (ptr == null) return null;
        const cstr: [*:0]const u8 = @ptrCast(ptr);
        const slice = std.mem.span(cstr);
        if (slice.len == 0) return null;
        return slice;
    }

    pub fn drawText(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
        if (text.len == 0) return;

        // Need null-terminated string for raylib
        var buf: [1024]u8 = undefined;
        const len = @min(text.len, buf.len - 1);
        @memcpy(buf[0..len], text[0..len]);
        buf[len] = 0;

        c.DrawTextEx(self.font, &buf, .{ .x = x, .y = y }, self.font_size, 0, color.toRaylib());
    }

    pub fn drawTextSized(self: *Renderer, text: []const u8, x: f32, y: f32, size: f32, color: Color) void {
        if (text.len == 0) return;

        // Need null-terminated string for raylib
        var buf: [1024]u8 = undefined;
        const len = @min(text.len, buf.len - 1);
        @memcpy(buf[0..len], text[0..len]);
        buf[len] = 0;

        c.DrawTextEx(self.font, &buf, .{ .x = x, .y = y }, size, 0, color.toRaylib());
    }

    pub fn drawIconText(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
        if (text.len == 0) return;

        var buf: [1024]u8 = undefined;
        const len = @min(text.len, buf.len - 1);
        @memcpy(buf[0..len], text[0..len]);
        buf[len] = 0;

        c.DrawTextEx(self.icon_font, &buf, .{ .x = x, .y = y }, self.icon_font_size, 0, color.toRaylib());
    }

    pub fn measureIconTextWidth(self: *Renderer, text: []const u8) f32 {
        if (text.len == 0) return 0;
        var buf: [1024]u8 = undefined;
        const len = @min(text.len, buf.len - 1);
        @memcpy(buf[0..len], text[0..len]);
        buf[len] = 0;
        const measure = c.MeasureTextEx(self.icon_font, &buf, self.icon_font_size, 0);
        return measure.x;
    }

    pub fn drawChar(self: *Renderer, char: u8, x: f32, y: f32, color: Color) void {
        var buf = [2]u8{ char, 0 };
        c.DrawTextEx(self.font, &buf, .{ .x = x, .y = y }, self.font_size, 0, color.toRaylib());
    }

    pub fn drawLine(self: *Renderer, x1: c_int, y1: c_int, x2: c_int, y2: c_int, color: Color) void {
        _ = self;
        c.DrawLine(x1, y1, x2, y2, color.toRaylib());
    }

    pub fn beginClip(self: *Renderer, x: c_int, y: c_int, w: c_int, h: c_int) void {
        _ = self;
        c.BeginScissorMode(x, y, w, h);
    }

    pub fn endClip(self: *Renderer) void {
        _ = self;
        c.EndScissorMode();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Editor-specific drawing
    // ─────────────────────────────────────────────────────────────────────────

    pub fn drawEditorLine(
        self: *Renderer,
        line_num: usize,
        text: []const u8,
        y: f32,
        x: f32,
        gutter_width: f32,
        content_width: f32,
        is_current: bool,
    ) void {
        self.drawEditorLineBase(line_num, y, x, gutter_width, content_width, is_current);
        self.drawText(text, x + gutter_width + 8, y, self.theme.foreground);
    }

    pub fn drawEditorLineBase(
        self: *Renderer,
        line_num: usize,
        y: f32,
        x: f32,
        gutter_width: f32,
        content_width: f32,
        is_current: bool,
    ) void {
        const line_y = y;

        // Draw current line highlight
        if (is_current) {
            self.drawRect(
                @intFromFloat(x + gutter_width),
                @intFromFloat(line_y),
                @intFromFloat(content_width - gutter_width),
                @intFromFloat(self.char_height),
                self.theme.current_line,
            );
        }

        // Draw line number
        var num_buf: [16]u8 = undefined;
        const num_str = std.fmt.bufPrint(&num_buf, "{d: >4}", .{line_num + 1}) catch return;
        self.drawText(num_str, x + 4, line_y, self.theme.line_number);
    }

    pub fn drawCursor(self: *Renderer, x: f32, y: f32, mode: enum { block, line, underline }) void {
        const w: c_int = switch (mode) {
            .block => @intFromFloat(self.char_width),
            .line => 2,
            .underline => @intFromFloat(self.char_width),
        };
        const h: c_int = switch (mode) {
            .block => @intFromFloat(self.char_height),
            .line => @intFromFloat(self.char_height),
            .underline => 2,
        };
        const cursor_y = switch (mode) {
            .underline => y + self.char_height - 2,
            else => y,
        };

        self.drawRect(@intFromFloat(x), @intFromFloat(cursor_y), w, h, self.theme.cursor);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Terminal drawing
    // ─────────────────────────────────────────────────────────────────────────

    pub fn drawTerminalCell(
        self: *Renderer,
        codepoint: u32,
        x: f32,
        y: f32,
        cell_width: f32,
        cell_height: f32,
        fg: Color,
        bg: Color,
        bold: bool,
        underline: bool,
        is_cursor: bool,
        followed_by_space: bool,
        draw_bg: bool,
    ) void {
        const snapped_x = snapFloat(x);
        const snapped_y = snapFloat(y);
        const snapped_cell_width = snapFloat(cell_width);
        const snapped_cell_height = snapFloat(cell_height);
        const snapped_cell_w_i = snapInt(self.terminal_cell_width);
        const snapped_cell_h_i = snapInt(self.terminal_cell_height);

        // Draw background
        if (draw_bg) {
            self.drawRect(
                snapInt(snapped_x),
                snapInt(snapped_y),
                snapped_cell_w_i,
                snapped_cell_h_i,
                if (is_cursor) fg else bg,
            );
        }

        // Draw character
        if (codepoint != 0) {
            const text_color = if (is_cursor) bg else fg;
            _ = bold; // TODO: handle bold with different font weight
            if (!self.drawTerminalBoxGlyph(codepoint, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, text_color)) {
                self.terminal_font.drawGlyph(codepoint, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, followed_by_space, .{
                    .r = text_color.r,
                    .g = text_color.g,
                    .b = text_color.b,
                    .a = text_color.a,
                });
            }
            if (underline) {
                const underline_y: c_int = snapInt(snapped_y + self.terminal_cell_height - 2);
                self.drawRect(
                    snapInt(snapped_x),
                    underline_y,
                    snapped_cell_w_i,
                    2,
                    text_color,
                );
            }
        }
    }

    fn drawTerminalBoxGlyph(
        self: *Renderer,
        codepoint: u32,
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        color: Color,
    ) bool {
        _ = self;

        const ix = @as(c_int, @intFromFloat(x));
        const iy = @as(c_int, @intFromFloat(y));
        const iw = @as(c_int, @intFromFloat(w));
        const ih = @as(c_int, @intFromFloat(h));
        const mid_x = ix + @divTrunc(iw, 2);
        const mid_y = iy + @divTrunc(ih, 2);
        const thin: c_int = 1;
        const thick: c_int = @max(2, @divTrunc(ih, 6));

        // With integer-snapped cell metrics we avoid gaps, so no extra extension needed.
        const extend: c_int = 0;

        switch (codepoint) {
            0x2500 => { // ─
                c.DrawRectangle(ix, mid_y, iw, thin, color.toRaylib());
                return true;
            },
            0x2501 => { // ━
                c.DrawRectangle(ix, mid_y - @divTrunc(thick, 2), iw, thick, color.toRaylib());
                return true;
            },
            0x2502 => { // │ - full height vertical, extend both ends
                c.DrawRectangle(mid_x, iy - extend, thin, ih + extend * 2, color.toRaylib());
                return true;
            },
            0x2503 => { // ┃
                c.DrawRectangle(mid_x - @divTrunc(thick, 2), iy - extend, thick, ih + extend * 2, color.toRaylib());
                return true;
            },
            0x256d => { // ╭ - rounded corner (treat as light ┌)
                c.DrawRectangle(mid_x, mid_y, iw - (mid_x - ix), thin, color.toRaylib());
                c.DrawRectangle(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color.toRaylib());
                return true;
            },
            0x256e => { // ╮ - rounded corner (treat as light ┐)
                c.DrawRectangle(ix, mid_y, mid_x - ix + thin, thin, color.toRaylib());
                c.DrawRectangle(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color.toRaylib());
                return true;
            },
            0x256f => { // ╯ - rounded corner (treat as light ┘)
                c.DrawRectangle(ix, mid_y, mid_x - ix + thin, thin, color.toRaylib());
                c.DrawRectangle(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color.toRaylib());
                return true;
            },
            0x2570 => { // ╰ - rounded corner (treat as light └)
                c.DrawRectangle(mid_x, mid_y, iw - (mid_x - ix), thin, color.toRaylib());
                c.DrawRectangle(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color.toRaylib());
                return true;
            },
            0x250c => { // ┌ - corner down-right, extend down
                c.DrawRectangle(mid_x, mid_y, iw - (mid_x - ix), thin, color.toRaylib());
                c.DrawRectangle(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color.toRaylib());
                return true;
            },
            0x2510 => { // ┐ - corner down-left, extend down
                c.DrawRectangle(ix, mid_y, mid_x - ix + thin, thin, color.toRaylib());
                c.DrawRectangle(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color.toRaylib());
                return true;
            },
            0x2514 => { // └ - corner up-right, extend up
                c.DrawRectangle(mid_x, mid_y, iw - (mid_x - ix), thin, color.toRaylib());
                c.DrawRectangle(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color.toRaylib());
                return true;
            },
            0x2518 => { // ┘ - corner up-left, extend up
                c.DrawRectangle(ix, mid_y, mid_x - ix + thin, thin, color.toRaylib());
                c.DrawRectangle(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color.toRaylib());
                return true;
            },
            0x2574 => { // ╴ - light left
                c.DrawRectangle(ix, mid_y, mid_x - ix + thin, thin, color.toRaylib());
                return true;
            },
            0x2575 => { // ╵ - light up
                c.DrawRectangle(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color.toRaylib());
                return true;
            },
            0x2576 => { // ╶ - light right
                c.DrawRectangle(mid_x, mid_y, iw - (mid_x - ix), thin, color.toRaylib());
                return true;
            },
            0x2577 => { // ╷ - light down
                c.DrawRectangle(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color.toRaylib());
                return true;
            },
            0x251c => { // ├ - T right, extend both ends
                c.DrawRectangle(mid_x, iy - extend, thin, ih + extend * 2, color.toRaylib());
                c.DrawRectangle(mid_x, mid_y, iw - (mid_x - ix), thin, color.toRaylib());
                return true;
            },
            0x2524 => { // ┤ - T left, extend both ends
                c.DrawRectangle(mid_x, iy - extend, thin, ih + extend * 2, color.toRaylib());
                c.DrawRectangle(ix, mid_y, mid_x - ix + thin, thin, color.toRaylib());
                return true;
            },
            0x252c => { // ┬ - T down, extend down
                c.DrawRectangle(ix, mid_y, iw, thin, color.toRaylib());
                c.DrawRectangle(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color.toRaylib());
                return true;
            },
            0x2534 => { // ┴ - T up, extend up
                c.DrawRectangle(ix, mid_y, iw, thin, color.toRaylib());
                c.DrawRectangle(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color.toRaylib());
                return true;
            },
            0x253c => { // ┼ - cross, extend both ends
                c.DrawRectangle(ix, mid_y, iw, thin, color.toRaylib());
                c.DrawRectangle(mid_x, iy - extend, thin, ih + extend * 2, color.toRaylib());
                return true;
            },
            0x2580 => { // ▀ upper half block
                c.DrawRectangle(ix, iy, iw, @divTrunc(ih, 2), color.toRaylib());
                return true;
            },
            0x2584 => { // ▄ lower half block
                const half = @divTrunc(ih, 2);
                c.DrawRectangle(ix, iy + half, iw, ih - half, color.toRaylib());
                return true;
            },
            0x2588 => { // █ full block
                c.DrawRectangle(ix, iy, iw, ih, color.toRaylib());
                return true;
            },
            else => return false,
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Input handling
    // ─────────────────────────────────────────────────────────────────────────

    pub fn getCharPressed(self: *Renderer) ?u32 {
        _ = self;
        const char = c.GetCharPressed();
        if (char > 0) return @intCast(char);
        return null;
    }

    pub fn getKeyPressed(self: *Renderer) ?c_int {
        _ = self;
        const key = c.GetKeyPressed();
        if (key > 0) return key;
        return null;
    }

    pub fn isKeyDown(self: *Renderer, key: c_int) bool {
        _ = self;
        return c.IsKeyDown(key);
    }

    pub fn isKeyPressed(self: *Renderer, key: c_int) bool {
        _ = self;
        return c.IsKeyPressed(key);
    }

    pub fn isKeyRepeated(self: *Renderer, key: c_int) bool {
        if (key < 0) return false;
        const idx: usize = @intCast(key);
        if (idx >= key_repeat_key_count) {
            return c.IsKeyPressed(key);
        }

        const now = c.GetTime();
        const down = c.IsKeyDown(key);
        if (!down) {
            self.key_repeat_next[idx] = 0;
            return false;
        }

        if (c.IsKeyPressed(key)) {
            self.key_repeat_next[idx] = now + key_repeat_initial_delay;
            return true;
        }

        if (self.key_repeat_next[idx] > 0 and now >= self.key_repeat_next[idx]) {
            const interval: f64 = if (key_repeat_rate > 0.0) 1.0 / key_repeat_rate else 0.05;
            while (self.key_repeat_next[idx] <= now) {
                self.key_repeat_next[idx] += interval;
            }
            return true;
        }

        return false;
    }

    pub fn getMousePos(self: *Renderer) MousePos {
        _ = self;
        const pos = c.GetMousePosition();
        return .{ .x = pos.x, .y = pos.y };
    }

    pub fn getMousePosScaled(_: *Renderer, scale: f32) MousePos {
        const pos = c.GetMousePosition();
        return .{ .x = pos.x * scale, .y = pos.y * scale };
    }

    pub fn getMousePosRaw(self: *Renderer) MousePos {
        _ = self;
        const pos = c.GetMousePosition();
        return .{ .x = pos.x, .y = pos.y };
    }

    pub fn getDpiScale(self: *Renderer) MousePos {
        _ = self;
        const scale = c.GetWindowScaleDPI();
        return .{ .x = scale.x, .y = scale.y };
    }

    pub fn getScreenSize(self: *Renderer) MousePos {
        _ = self;
        return .{
            .x = @as(f32, @floatFromInt(c.GetScreenWidth())),
            .y = @as(f32, @floatFromInt(c.GetScreenHeight())),
        };
    }

    pub fn getMonitorSize(self: *Renderer) MousePos {
        _ = self;
        const monitor = c.GetCurrentMonitor();
        return .{
            .x = @as(f32, @floatFromInt(c.GetMonitorWidth(monitor))),
            .y = @as(f32, @floatFromInt(c.GetMonitorHeight(monitor))),
        };
    }

    fn updateMouseScale(self: *Renderer) void {
        const screen_w = @as(f32, @floatFromInt(c.GetScreenWidth()));
        const screen_h = @as(f32, @floatFromInt(c.GetScreenHeight()));
        const render_w = @as(f32, @floatFromInt(c.GetRenderWidth()));
        const render_h = @as(f32, @floatFromInt(c.GetRenderHeight()));
        var sx: f32 = if (screen_w > 0) render_w / screen_w else 1.0;
        var sy: f32 = if (screen_h > 0) render_h / screen_h else 1.0;

        if (compositor.isWayland()) {
            const now = c.GetTime();
            if (now - self.wayland_scale_last_update > 1.0) {
                self.wayland_scale_cache = compositor.getWaylandScale(self.allocator);
                self.wayland_scale_last_update = now;
            }
            if (self.wayland_scale_cache) |scale| {
                if (scale > 0.0) {
                    sx *= scale;
                    sy *= scale;
                }
            }
        }

        if (std.c.getenv("ZIDE_MOUSE_SCALE")) |raw| {
            const s = std.mem.sliceTo(raw, 0);
            const env_scale = std.fmt.parseFloat(f32, s) catch 1.0;
            sx *= env_scale;
            sy *= env_scale;
        }

        self.mouse_scale = .{ .x = sx, .y = sy };
        c.SetMouseScale(sx, sy);
    }

    pub fn getRenderSize(self: *Renderer) MousePos {
        _ = self;
        return .{
            .x = @as(f32, @floatFromInt(c.GetRenderWidth())),
            .y = @as(f32, @floatFromInt(c.GetRenderHeight())),
        };
    }

    pub fn isMouseButtonPressed(self: *Renderer, button: c_int) bool {
        _ = self;
        return c.IsMouseButtonPressed(button);
    }

    pub fn isMouseButtonDown(self: *Renderer, button: c_int) bool {
        _ = self;
        return c.IsMouseButtonDown(button);
    }

    pub fn isMouseButtonReleased(self: *Renderer, button: c_int) bool {
        _ = self;
        return c.IsMouseButtonReleased(button);
    }

    pub fn getMouseWheelMove(self: *Renderer) f32 {
        _ = self;
        return c.GetMouseWheelMove();
    }

};

/// Poll input events (updates raylib's internal input state)
pub fn pollInputEvents() void {
    c.PollInputEvents();
}

/// Sleep for specified duration (in seconds)
pub fn waitTime(seconds: f64) void {
    c.WaitTime(seconds);
}

/// Get time since window was initialized (seconds)
pub fn getTime() f64 {
    return c.GetTime();
}

/// Configure raylib trace log level before window init.
pub fn setRaylibLogLevel(level: c_int) void {
    c.SetTraceLogLevel(level);
}

/// Check if window was resized (event-based, works with X11/Wayland)
pub fn isWindowResized() bool {
    return c.IsWindowResized();
}

/// Get current screen width
pub fn getScreenWidth() c_int {
    return c.GetScreenWidth();
}

/// Get current screen height
pub fn getScreenHeight() c_int {
    return c.GetScreenHeight();
}

// Raylib key constants
pub const KEY_ENTER = c.KEY_ENTER;
pub const KEY_BACKSPACE = c.KEY_BACKSPACE;
pub const KEY_DELETE = c.KEY_DELETE;
pub const KEY_TAB = c.KEY_TAB;
pub const KEY_ESCAPE = c.KEY_ESCAPE;
pub const KEY_UP = c.KEY_UP;
pub const KEY_DOWN = c.KEY_DOWN;
pub const KEY_LEFT = c.KEY_LEFT;
pub const KEY_RIGHT = c.KEY_RIGHT;
pub const KEY_HOME = c.KEY_HOME;
pub const KEY_END = c.KEY_END;
pub const KEY_PAGE_UP = c.KEY_PAGE_UP;
pub const KEY_PAGE_DOWN = c.KEY_PAGE_DOWN;
pub const KEY_INSERT = c.KEY_INSERT;
pub const KEY_LEFT_CONTROL = c.KEY_LEFT_CONTROL;
pub const KEY_RIGHT_CONTROL = c.KEY_RIGHT_CONTROL;
pub const KEY_LEFT_SHIFT = c.KEY_LEFT_SHIFT;
pub const KEY_RIGHT_SHIFT = c.KEY_RIGHT_SHIFT;
pub const KEY_LEFT_ALT = c.KEY_LEFT_ALT;
pub const KEY_RIGHT_ALT = c.KEY_RIGHT_ALT;
pub const KEY_LEFT_SUPER = c.KEY_LEFT_SUPER;
pub const KEY_RIGHT_SUPER = c.KEY_RIGHT_SUPER;
pub const KEY_ZERO = c.KEY_ZERO;
pub const KEY_ONE = c.KEY_ONE;
pub const KEY_TWO = c.KEY_TWO;
pub const KEY_THREE = c.KEY_THREE;
pub const KEY_FOUR = c.KEY_FOUR;
pub const KEY_FIVE = c.KEY_FIVE;
pub const KEY_SIX = c.KEY_SIX;
pub const KEY_SEVEN = c.KEY_SEVEN;
pub const KEY_EIGHT = c.KEY_EIGHT;
pub const KEY_NINE = c.KEY_NINE;
pub const KEY_SPACE = c.KEY_SPACE;
pub const KEY_MINUS = c.KEY_MINUS;
pub const KEY_EQUAL = c.KEY_EQUAL;
pub const KEY_LEFT_BRACKET = c.KEY_LEFT_BRACKET;
pub const KEY_RIGHT_BRACKET = c.KEY_RIGHT_BRACKET;
pub const KEY_BACKSLASH = c.KEY_BACKSLASH;
pub const KEY_SEMICOLON = c.KEY_SEMICOLON;
pub const KEY_APOSTROPHE = c.KEY_APOSTROPHE;
pub const KEY_GRAVE = c.KEY_GRAVE;
pub const KEY_COMMA = c.KEY_COMMA;
pub const KEY_PERIOD = c.KEY_PERIOD;
pub const KEY_SLASH = c.KEY_SLASH;
pub const KEY_S = c.KEY_S;
pub const KEY_Z = c.KEY_Z;
pub const KEY_Y = c.KEY_Y;
pub const KEY_C = c.KEY_C;
pub const KEY_V = c.KEY_V;
pub const KEY_X = c.KEY_X;
pub const KEY_A = c.KEY_A;
pub const KEY_B = c.KEY_B;
pub const KEY_D = c.KEY_D;
pub const KEY_E = c.KEY_E;
pub const KEY_F = c.KEY_F;
pub const KEY_G = c.KEY_G;
pub const KEY_H = c.KEY_H;
pub const KEY_I = c.KEY_I;
pub const KEY_J = c.KEY_J;
pub const KEY_K = c.KEY_K;
pub const KEY_L = c.KEY_L;
pub const KEY_M = c.KEY_M;
pub const KEY_N = c.KEY_N;
pub const KEY_O = c.KEY_O;
pub const KEY_P = c.KEY_P;
pub const KEY_Q = c.KEY_Q;
pub const KEY_R = c.KEY_R;
pub const KEY_T = c.KEY_T;
pub const KEY_U = c.KEY_U;
pub const KEY_W = c.KEY_W;

pub const MOUSE_LEFT = c.MOUSE_BUTTON_LEFT;
pub const MOUSE_RIGHT = c.MOUSE_BUTTON_RIGHT;
pub const MOUSE_MIDDLE = c.MOUSE_BUTTON_MIDDLE;
