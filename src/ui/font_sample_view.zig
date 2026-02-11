const std = @import("std");

const app_shell = @import("../app_shell.zig");
const terminal_font_mod = @import("terminal_font.zig");
const renderer_mod = @import("renderer.zig");
const draw_ops = @import("renderer/draw_ops.zig");
const iface = @import("renderer/interface.zig");
const text_draw = @import("renderer/text_draw.zig");
const types = @import("renderer/types.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const Renderer = renderer_mod.Renderer;
const TerminalFont = terminal_font_mod.TerminalFont;

pub const FontSampleView = struct {
    allocator: std.mem.Allocator,
    size: f32,
    left: TerminalFont,
    right: TerminalFont,
    left_name: []const u8,
    right_name: []const u8,

    pub fn init(allocator: std.mem.Allocator, renderer: *Renderer) !FontSampleView {
        const render_scale = if (renderer.render_scale > 0.0) renderer.render_scale else 1.0;
        const size = parseEnvF32("ZIDE_FONT_SAMPLE_SIZE", renderer.base_font_size);
        const raster_size = size * render_scale;

        const left_path: [*:0]const u8 = "assets/fonts/JetBrainsMonoNerdFont-Regular.ttf";
        const right_path: [*:0]const u8 = "assets/fonts/IosevkaTermNerdFont-Regular.ttf";

        var left = try TerminalFont.init(
            allocator,
            left_path,
            raster_size,
            iface.SYMBOLS_FALLBACK_PATH,
            iface.UNICODE_SYMBOLS2_PATH,
            iface.UNICODE_SYMBOLS_PATH,
            iface.UNICODE_MONO_PATH,
            iface.UNICODE_SANS_PATH,
            iface.EMOJI_COLOR_FALLBACK_PATH,
            iface.EMOJI_TEXT_FALLBACK_PATH,
            renderer.font_rendering,
        );
        errdefer left.deinit();
        left.render_scale = render_scale;
        left.setAtlasFilterPoint();

        var right = try TerminalFont.init(
            allocator,
            right_path,
            raster_size,
            iface.SYMBOLS_FALLBACK_PATH,
            iface.UNICODE_SYMBOLS2_PATH,
            iface.UNICODE_SYMBOLS_PATH,
            iface.UNICODE_MONO_PATH,
            iface.UNICODE_SANS_PATH,
            iface.EMOJI_COLOR_FALLBACK_PATH,
            iface.EMOJI_TEXT_FALLBACK_PATH,
            renderer.font_rendering,
        );
        errdefer right.deinit();
        right.render_scale = render_scale;
        right.setAtlasFilterPoint();

        return .{
            .allocator = allocator,
            .size = size,
            .left = left,
            .right = right,
            .left_name = "JetBrainsMono",
            .right_name = "IosevkaTerm",
        };
    }

    pub fn deinit(self: *FontSampleView) void {
        self.left.deinit();
        self.right.deinit();
    }

    pub fn update(self: *FontSampleView, renderer: *Renderer, input: anytype) bool {
        // Returns true if the view changed and needs redraw.
        // +/- adjust size and rebuild the sample fonts.
        const mods = input.mods;
        const increase = (input.keyPressed(.equal) and mods.shift) or input.keyPressed(.kp_add);
        const decrease = input.keyPressed(.minus) or input.keyPressed(.kp_subtract);
        if (!increase and !decrease) return false;

        const next = if (increase) self.size + 1.0 else self.size - 1.0;
        const clamped = @max(6.0, @min(64.0, next));
        if (std.math.approxEqAbs(f32, clamped, self.size, 0.001)) return false;

        const render_scale = if (renderer.render_scale > 0.0) renderer.render_scale else 1.0;
        const raster_size = clamped * render_scale;

        const left_path: [*:0]const u8 = "assets/fonts/JetBrainsMonoNerdFont-Regular.ttf";
        const right_path: [*:0]const u8 = "assets/fonts/IosevkaTermNerdFont-Regular.ttf";

        var new_left = TerminalFont.init(
            self.allocator,
            left_path,
            raster_size,
            iface.SYMBOLS_FALLBACK_PATH,
            iface.UNICODE_SYMBOLS2_PATH,
            iface.UNICODE_SYMBOLS_PATH,
            iface.UNICODE_MONO_PATH,
            iface.UNICODE_SANS_PATH,
            iface.EMOJI_COLOR_FALLBACK_PATH,
            iface.EMOJI_TEXT_FALLBACK_PATH,
            renderer.font_rendering,
        ) catch return false;
        errdefer new_left.deinit();
        new_left.render_scale = render_scale;
        new_left.setAtlasFilterPoint();

        var new_right = TerminalFont.init(
            self.allocator,
            right_path,
            raster_size,
            iface.SYMBOLS_FALLBACK_PATH,
            iface.UNICODE_SYMBOLS2_PATH,
            iface.UNICODE_SYMBOLS_PATH,
            iface.UNICODE_MONO_PATH,
            iface.UNICODE_SANS_PATH,
            iface.EMOJI_COLOR_FALLBACK_PATH,
            iface.EMOJI_TEXT_FALLBACK_PATH,
            renderer.font_rendering,
        ) catch {
            new_left.deinit();
            return false;
        };
        new_right.render_scale = render_scale;
        new_right.setAtlasFilterPoint();

        // Swap in new fonts.
        self.left.deinit();
        self.right.deinit();
        self.left = new_left;
        self.right = new_right;
        self.size = clamped;
        return true;
    }

    pub fn draw(self: *FontSampleView, shell: *Shell) void {
        const r = shell.rendererPtr();
        const theme = shell.theme();
        const w = @as(f32, @floatFromInt(shell.width()));
        const h = @as(f32, @floatFromInt(shell.height()));
        if (w <= 0 or h <= 0) return;

        // Render into the offscreen target so we can do linear blending in a
        // controlled way (target is linear; presentation converts to sRGB).
        if (r.ensureEditorTexture(@intFromFloat(w), @intFromFloat(h))) {
            if (r.beginEditorTexture()) {
                r.clearToThemeBackground();
                drawContents(self, r, theme, w, h);
                r.endEditorTexture();
                r.drawEditorTexture(0, 0);
                return;
            }
        }

        // Fallback: draw directly to the window.
        r.drawRect(0, 0, @intFromFloat(w), @intFromFloat(h), theme.background);
        drawContents(self, r, theme, w, h);
    }

    fn drawContents(self: *FontSampleView, r: *Renderer, theme: *const app_shell.Theme, w: f32, h: f32) void {
        const padding: f32 = 16;
        const header_y: f32 = padding;
        const col_gap: f32 = 18;
        const col_w: f32 = @max(0, (w - padding * 2 - col_gap) * 0.5);
        const left_x: f32 = padding;
        const right_x: f32 = padding + col_w + col_gap;

        var title_buf: [160]u8 = undefined;
        const title = std.fmt.bufPrint(
            &title_buf,
            "Font Sample (size={d:.1})  keys: +/-",
            .{self.size},
        ) catch "Font Sample";
        r.drawText(title, padding, header_y, theme.foreground);

        const section_gap: f32 = 10;
        var y_cursor: f32 = header_y + r.char_height * 1.8;

        y_cursor = drawSection(self, r, theme, w, left_x, right_x, y_cursor, col_w, "normal", theme.background, theme.foreground);
        y_cursor += section_gap;
        y_cursor = drawSection(self, r, theme, w, left_x, right_x, y_cursor, col_w, "selection", theme.selection, theme.foreground);
        y_cursor += section_gap;
        _ = drawSection(self, r, theme, w, left_x, right_x, y_cursor, col_w, "cursor", theme.cursor, theme.background);

        _ = h;
    }

    fn drawSection(
        self: *FontSampleView,
        r: *Renderer,
        theme: *const app_shell.Theme,
        w: f32,
        left_x: f32,
        right_x: f32,
        y: f32,
        col_w: f32,
        label: []const u8,
        bg: Color,
        fg: Color,
    ) f32 {
        const section_pad_y: f32 = 8;
        const line_h = self.left.line_height / (if (r.render_scale > 0.0) r.render_scale else 1.0);
        const lines = sampleLines();
        const content_h: f32 = @as(f32, @floatFromInt(lines.len)) * line_h + baselineStressHeight(line_h);
        const section_h: f32 = r.char_height + section_pad_y + content_h + section_pad_y;
        const content_y: f32 = y + r.char_height + section_pad_y;

        r.drawRect(0, @intFromFloat(y), @intFromFloat(w), @intFromFloat(section_h), bg);
        r.drawText(label, 16, y, theme.foreground);

        var bg_rgba = bg.toRgba();
        bg_rgba.a = 255;
        r.text_bg_rgba = bg_rgba;
        drawColumnWithColor(self, r, left_x, content_y, col_w, self.left_name, &self.left, fg);
        drawColumnWithColor(self, r, right_x, content_y, col_w, self.right_name, &self.right, fg);
        r.text_bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };

        return y + section_h;
    }

    fn drawColumn(self: *FontSampleView, r: *Renderer, x: f32, y: f32, w: f32, name: []const u8, font: *TerminalFont) void {
        drawColumnWithColor(self, r, x, y, w, name, font, Color.white);
    }

    fn drawColumnWithColor(self: *FontSampleView, r: *Renderer, x: f32, y: f32, w: f32, name: []const u8, font: *TerminalFont, fg: Color) void {
        _ = w;
        const theme = r.theme;
        const scale = if (r.render_scale > 0.0) r.render_scale else 1.0;

        var header_buf: [192]u8 = undefined;
        const header = std.fmt.bufPrint(
            &header_buf,
            "{s}  line_h={d:.1} cell_w={d:.1}",
            .{ name, font.line_height / scale, font.cell_width / scale },
        ) catch name;
        r.drawText(header, x, y, theme.foreground);

        const start_y = y + r.char_height * 1.6;
        const line_h = font.line_height / scale;

        const lines = sampleLines();
        var row: usize = 0;
        while (row < lines.len) : (row += 1) {
            const text = lines[row];
            drawTextWithFont(r, self.allocator, font, text, x, start_y + @as(f32, @floatFromInt(row)) * line_h, fg);
        }

        var stress_y = start_y + @as(f32, @floatFromInt(lines.len)) * line_h + line_h * 0.5;
        r.drawText("baseline zoom stress: x0.9 x1.0 x1.1", x, stress_y, theme.line_number);
        stress_y += line_h;

        const stress_text = "Baseline probe: iiii llll zzzz vava mMwW 1Il|";
        const zooms = [_]f32{ 0.9, 1.0, 1.1 };
        for (zooms, 0..) |zoom, idx| {
            drawTextWithFontZoom(r, self.allocator, font, stress_text, x, stress_y, fg, zoom);
            if (idx + 1 < zooms.len) {
                stress_y += line_h * zoom + line_h * 0.1;
            }
        }
    }

    fn drawTextWithFont(
        r: *Renderer,
        allocator: std.mem.Allocator,
        font: *TerminalFont,
        text: []const u8,
        x: f32,
        y: f32,
        color: Color,
    ) void {
        const draw_ctx = terminal_font_mod.DrawContext{ .ctx = r, .drawTexture = drawTextureThunk };
        const scale = if (r.render_scale > 0.0) r.render_scale else 1.0;
        text_draw.drawText(allocator, font, draw_ctx.ctx, draw_ctx.drawTexture, text, x, y, font.cell_width / scale, font.line_height / scale, color.toRgba(), true);
    }

    fn drawTextWithFontZoom(
        r: *Renderer,
        allocator: std.mem.Allocator,
        font: *TerminalFont,
        text: []const u8,
        x: f32,
        y: f32,
        color: Color,
        zoom: f32,
    ) void {
        const draw_ctx = terminal_font_mod.DrawContext{ .ctx = r, .drawTexture = drawTextureThunk };
        const scale = if (r.render_scale > 0.0) r.render_scale else 1.0;
        const cell_w = (font.cell_width / scale) * zoom;
        const cell_h = (font.line_height / scale) * zoom;
        text_draw.drawText(allocator, font, draw_ctx.ctx, draw_ctx.drawTexture, text, x, y, cell_w, cell_h, color.toRgba(), true);
    }

    fn baselineStressHeight(line_h: f32) f32 {
        // 1 label + 3 zoomed lines + spacing
        return line_h * 4.8;
    }

    fn drawTextureThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        draw_ops.drawTextureRect(renderer, texture, src, dest, color, renderer.text_bg_rgba, kind);
    }

    fn parseEnvF32(env_key: [:0]const u8, default_value: f32) f32 {
        const raw = std.c.getenv(env_key) orelse return default_value;
        const slice = std.mem.sliceTo(raw, 0);
        if (slice.len == 0) return default_value;
        return std.fmt.parseFloat(f32, slice) catch default_value;
    }

    fn sampleLines() []const []const u8 {
        return &[_][]const u8{
            "The quick brown fox jumps over the lazy dog 0123456789",
            "iiii llll | ||  ..,,;;::  '" ++ "\"" ++ "`",
            "mwMW  O0oO  1Il|  {}[]()  <>  == != <= >=",
            "Ligatures: ->  ~>  =>  ==  ===  !=  !==  <=  >=  <=>",
            "Mixed operators: >>= <<== && || :: .. ... |> <|",
            "Box: \u{2500}\u{2502}\u{250c}\u{2510}\u{2514}\u{2518}  Braille: \u{28ff}",
            "Powerline: \u{e0b0}\u{e0b1}\u{e0b2}\u{e0b3}  Nerd: \u{f120}",
            "Combining: e\u{0301} a\u{0308} n\u{0303}  Emoji: \u{1f600}",
        };
    }
};
