const std = @import("std");
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("raylib.h");
});
const TerminalFont = @import("terminal_font.zig").TerminalFont;

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

pub const Theme = struct {
    background: Color = Color.bg,
    foreground: Color = Color.fg,
    selection: Color = Color.selection,
    cursor: Color = Color.fg,
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

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    width: c_int,
    height: c_int,
    font: c.Font,
    font_size: f32,
    char_width: f32,
    char_height: f32,
    terminal_cell_width: f32,
    terminal_cell_height: f32,
    terminal_font: TerminalFont,
    theme: Theme,

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
            .terminal_cell_width = font_size * 0.6,
            .terminal_cell_height = font_size * 1.2,
            .terminal_font = undefined,
            .theme = .{},
        };

        // Load app font with Nerd Font glyphs if available
        renderer.loadFontWithGlyphs(allocator, "assets/fonts/IosevkaTermNerdFont-Regular.ttf", font_size);
        renderer.terminal_font = try TerminalFont.init(allocator, "assets/fonts/IosevkaTermNerdFont-Regular.ttf", font_size);
        renderer.terminal_cell_width = renderer.terminal_font.cell_width;
        renderer.terminal_cell_height = renderer.terminal_font.line_height;

        return renderer;
    }

    pub fn deinit(self: *Renderer) void {
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

        const glyphs = allocator.alloc(c_int, total) catch return;
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
        if (file_data == null or data_size == 0) return;
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
        if (font_data == null or glyph_count == 0) return;

        var recs: [*c]c.Rectangle = null;
        const padding: c_int = 2;
        const image = c.GenImageFontAtlas(font_data, &recs, glyph_count, @intFromFloat(size), padding, 0);
        const texture = c.LoadTextureFromImage(image);
        c.UnloadImage(image);

        if (texture.id != 0) {
            if (self.font.texture.id != c.GetFontDefault().texture.id) {
                c.UnloadFont(self.font);
            }
            self.font = .{
                .baseSize = @intFromFloat(size),
                .glyphCount = glyph_count,
                .glyphPadding = padding,
                .texture = texture,
                .recs = recs,
                .glyphs = font_data,
            };
            self.font_size = size;
            const measure = c.MeasureTextEx(self.font, "M", size, 0);
            self.char_width = measure.x;
            self.char_height = measure.y;
            // Terminal metrics are managed by TerminalFont
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

        c.ClearBackground(self.theme.background.toRaylib());
    }

    pub fn endFrame(_: *Renderer) void {
        c.EndDrawing();
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

    pub fn drawText(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
        if (text.len == 0) return;

        // Need null-terminated string for raylib
        var buf: [1024]u8 = undefined;
        const len = @min(text.len, buf.len - 1);
        @memcpy(buf[0..len], text[0..len]);
        buf[len] = 0;

        c.DrawTextEx(self.font, &buf, .{ .x = x, .y = y }, self.font_size, 0, color.toRaylib());
        c.DrawTextEx(self.font, &buf, .{ .x = x + 0.3, .y = y }, self.font_size, 0, color.toRaylib());
    }

    pub fn drawChar(self: *Renderer, char: u8, x: f32, y: f32, color: Color) void {
        var buf = [2]u8{ char, 0 };
        c.DrawTextEx(self.font, &buf, .{ .x = x, .y = y }, self.font_size, 0, color.toRaylib());
        c.DrawTextEx(self.font, &buf, .{ .x = x + 0.3, .y = y }, self.font_size, 0, color.toRaylib());
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
        const line_y = y;
        const text_x = x + gutter_width + 8;

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

        // Draw text
        self.drawText(text, text_x, line_y, self.theme.foreground);
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
        fg: Color,
        bg: Color,
        bold: bool,
        is_cursor: bool,
    ) void {
        // Draw background
        self.drawRect(
            @intFromFloat(x),
            @intFromFloat(y),
            @intFromFloat(self.terminal_cell_width),
            @intFromFloat(self.terminal_cell_height),
            if (is_cursor) fg else bg,
        );

        // Draw character
        if (codepoint != 0) {
            const text_color = if (is_cursor) bg else fg;
            _ = bold; // TODO: handle bold with different font weight
            self.terminal_font.drawGlyph(codepoint, x, y, .{
                .r = text_color.r,
                .g = text_color.g,
                .b = text_color.b,
                .a = text_color.a,
            });
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

    pub fn getMousePos(self: *Renderer) struct { x: f32, y: f32 } {
        _ = self;
        const pos = c.GetMousePosition();
        return .{ .x = pos.x, .y = pos.y };
    }

    pub fn isMouseButtonPressed(self: *Renderer, button: c_int) bool {
        _ = self;
        return c.IsMouseButtonPressed(button);
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
pub const KEY_LEFT_CONTROL = c.KEY_LEFT_CONTROL;
pub const KEY_RIGHT_CONTROL = c.KEY_RIGHT_CONTROL;
pub const KEY_LEFT_SHIFT = c.KEY_LEFT_SHIFT;
pub const KEY_RIGHT_SHIFT = c.KEY_RIGHT_SHIFT;
pub const KEY_LEFT_ALT = c.KEY_LEFT_ALT;
pub const KEY_RIGHT_ALT = c.KEY_RIGHT_ALT;
pub const KEY_S = c.KEY_S;
pub const KEY_Z = c.KEY_Z;
pub const KEY_Y = c.KEY_Y;
pub const KEY_C = c.KEY_C;
pub const KEY_V = c.KEY_V;
pub const KEY_X = c.KEY_X;
pub const KEY_A = c.KEY_A;
pub const KEY_F = c.KEY_F;
pub const KEY_G = c.KEY_G;
pub const KEY_N = c.KEY_N;
pub const KEY_O = c.KEY_O;
pub const KEY_P = c.KEY_P;
pub const KEY_Q = c.KEY_Q;
pub const KEY_W = c.KEY_W;
pub const KEY_GRAVE = c.KEY_GRAVE;

pub const MOUSE_LEFT = c.MOUSE_BUTTON_LEFT;
pub const MOUSE_RIGHT = c.MOUSE_BUTTON_RIGHT;
pub const MOUSE_MIDDLE = c.MOUSE_BUTTON_MIDDLE;
