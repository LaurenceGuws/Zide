const std = @import("std");

pub fn drawEditorLine(
    self: anytype,
    line_num: usize,
    text: []const u8,
    y: f32,
    x: f32,
    gutter_width: f32,
    content_width: f32,
    is_current: bool,
) void {
    drawEditorLineBase(self, line_num, y, x, gutter_width, content_width, is_current);
    const pad = 8 * self.uiScaleFactor();
    self.drawText(text, x + gutter_width + pad, y, self.theme.foreground);
}

pub fn drawEditorLineBase(
    self: anytype,
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
        self.drawRect(
            @intFromFloat(x),
            @intFromFloat(line_y),
            @intFromFloat(gutter_width),
            @intFromFloat(self.char_height),
            self.theme.current_line,
        );
    }

    // Draw line number
    var num_buf: [16]u8 = undefined;
    const num_str = std.fmt.bufPrint(&num_buf, "{d: >4}", .{line_num + 1}) catch return;
    const pad = 4 * self.uiScaleFactor();
    const line_color = if (is_current) self.theme.foreground else self.theme.line_number;
    self.drawText(num_str, x + pad, line_y, line_color);
}

pub fn drawCursor(self: anytype, x: f32, y: f32, mode: anytype) void {
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
