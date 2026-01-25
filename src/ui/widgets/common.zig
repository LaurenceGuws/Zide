const app_shell = @import("../../app_shell.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;

pub const TruncResult = struct {
    drawn_width: f32,
    truncated: bool,
    drawn_len: usize,
};

pub const Tooltip = struct {
    text: []const u8,
    x: f32,
    y: f32,
};

pub fn drawTruncatedText(shell: *Shell, text: []const u8, x: f32, y: f32, color: Color, max_width: f32) TruncResult {
    if (max_width <= 0 or text.len == 0) {
        return .{ .drawn_width = 0, .truncated = text.len > 0, .drawn_len = 0 };
    }
    const max_chars: usize = @intCast(@max(0, @as(i32, @intFromFloat(max_width / shell.charWidth()))));
    if (max_chars == 0) {
        return .{ .drawn_width = 0, .truncated = text.len > 0, .drawn_len = 0 };
    }

    var buf: [256]u8 = undefined;
    var out_len: usize = 0;
    const truncated = text.len > max_chars;
    if (text.len <= max_chars) {
        out_len = @min(text.len, buf.len);
        @memcpy(buf[0..out_len], text[0..out_len]);
    } else if (max_chars <= 3) {
        out_len = @min(max_chars, buf.len);
        @memcpy(buf[0..out_len], text[0..out_len]);
    } else {
        const prefix_len = @min(max_chars - 3, buf.len - 3);
        @memcpy(buf[0..prefix_len], text[0..prefix_len]);
        buf[prefix_len + 0] = '.';
        buf[prefix_len + 1] = '.';
        buf[prefix_len + 2] = '.';
        out_len = prefix_len + 3;
    }

    shell.drawText(buf[0..out_len], x, y, color);
    return .{
        .drawn_width = @as(f32, @floatFromInt(out_len)) * shell.charWidth(),
        .truncated = truncated,
        .drawn_len = out_len,
    };
}

pub fn drawTooltip(shell: *Shell, text: []const u8, x: f32, y: f32) void {
    if (text.len == 0) return;
    const padding: f32 = 6;
    const text_w = @as(f32, @floatFromInt(text.len)) * shell.charWidth();
    const text_h = shell.charHeight();
    const w = text_w + padding * 2;
    const h = text_h + padding * 2;

    const max_w = @as(f32, @floatFromInt(shell.width()));
    const max_h = @as(f32, @floatFromInt(shell.height()));
    var draw_x = x + 12;
    var draw_y = y + 12;
    if (draw_x + w > max_w) draw_x = max_w - w - 4;
    if (draw_y + h > max_h) draw_y = max_h - h - 4;
    if (draw_x < 4) draw_x = 4;
    if (draw_y < 4) draw_y = 4;

    const bg = Color{ .r = 24, .g = 25, .b = 33, .a = 235 };
    shell.drawRect(@intFromFloat(draw_x), @intFromFloat(draw_y), @intFromFloat(w), @intFromFloat(h), bg);
    shell.drawRectOutline(@intFromFloat(draw_x), @intFromFloat(draw_y), @intFromFloat(w), @intFromFloat(h), Color.light_gray);
    shell.drawText(text, draw_x + padding, draw_y + padding, Color.fg);
}
