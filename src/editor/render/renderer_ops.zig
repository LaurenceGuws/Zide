const std = @import("std");
const app_logger = @import("../../app_logger.zig");

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
    self.drawTextMonospace(text, x + gutter_width + pad, y, self.theme.foreground);
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
    const num_str = std.fmt.bufPrint(&num_buf, "{d: >4}", .{line_num + 1}) catch |err| {
        app_logger.logger("editor.draw").logf(.warning, "drawEditorLineBase line number format failed line={d} err={s}", .{ line_num + 1, @errorName(err) });
        return;
    };
    const pad = 4 * self.uiScaleFactor();
    const line_color = if (is_current) self.theme.foreground else self.theme.line_number;
    self.drawTextMonospace(num_str, x + pad, line_y, line_color);
}

pub fn drawCursor(self: anytype, x: f32, y: f32, mode: anytype) void {
    const scale = self.uiScaleFactor();
    const edge_inset: c_int = @max(0, @as(c_int, @intFromFloat(std.math.floor(scale * 0.5))));
    const stroke: c_int = @max(1, @as(c_int, @intFromFloat(std.math.round(scale))));

    const x_i: c_int = @intFromFloat(x);
    const y_i: c_int = @intFromFloat(y);
    const char_w_i: c_int = @max(1, @as(c_int, @intFromFloat(self.char_width)));
    const char_h_i: c_int = @max(1, @as(c_int, @intFromFloat(self.char_height)));

    switch (mode) {
        .block => {
            self.drawRect(x_i, y_i, char_w_i, char_h_i, self.theme.cursor);
        },
        .line => {
            const draw_x = x_i + edge_inset;
            const draw_h = @max(1, char_h_i - edge_inset * 2);
            const draw_y = y_i + @divFloor(char_h_i - draw_h, 2);
            self.drawRect(draw_x, draw_y, stroke, draw_h, self.theme.cursor);
        },
        .underline => {
            const draw_x = x_i + edge_inset;
            const draw_w = @max(1, char_w_i - edge_inset * 2);
            const draw_y = y_i + char_h_i - stroke - edge_inset;
            self.drawRect(draw_x, draw_y, draw_w, stroke, self.theme.cursor);
        },
    }
}
