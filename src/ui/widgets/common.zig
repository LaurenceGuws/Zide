const std = @import("std");
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

pub const ScrollbarThumb = struct {
    thumb_h: f32,
    available: f32,
    thumb_y: f32,
};

pub fn computeScrollbarThumb(scrollbar_y: f32, track_h: f32, visible_lines: usize, total_lines: usize, min_thumb_h: f32, ratio: f32) ScrollbarThumb {
    const thumb_h = if (total_lines > visible_lines)
        @max(min_thumb_h, track_h * (@as(f32, @floatFromInt(visible_lines)) / @as(f32, @floatFromInt(total_lines))))
    else
        track_h;
    const available = @max(@as(f32, 1), track_h - thumb_h);
    const thumb_y = scrollbar_y + available * ratio;
    return .{ .thumb_h = thumb_h, .available = available, .thumb_y = thumb_y };
}

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

    var idx: usize = 0;
    var count: usize = 0;
    var truncated = false;
    while (true) {
        const cp = nextCodepointLossy(text, &idx) orelse break;
        count += 1;
        if (count > max_chars) {
            truncated = true;
            break;
        }
        _ = cp;
    }

    if (!truncated) {
        idx = 0;
        out_len = copyCodepointsLossy(text, &idx, count, buf[0..]);
        if (idx < text.len) truncated = true;
    } else if (max_chars <= 3) {
        idx = 0;
        out_len = copyCodepointsLossy(text, &idx, max_chars, buf[0..]);
    } else {
        idx = 0;
        out_len = copyCodepointsLossy(text, &idx, max_chars - 3, buf[0..]);
        if (out_len + 3 <= buf.len) {
            buf[out_len + 0] = '.';
            buf[out_len + 1] = '.';
            buf[out_len + 2] = '.';
            out_len += 3;
        }
    }

    shell.drawText(buf[0..out_len], x, y, color);
    return .{
        .drawn_width = @as(f32, @floatFromInt(out_len)) * shell.charWidth(),
        .truncated = truncated,
        .drawn_len = out_len,
    };
}

fn nextCodepointLossy(text: []const u8, idx: *usize) ?u32 {
    if (idx.* >= text.len) return null;
    const first = text[idx.*];
    const seq_len = std.unicode.utf8ByteSequenceLength(first) catch {
        idx.* += 1;
        return 0xFFFD;
    };
    if (idx.* + seq_len > text.len) {
        idx.* += 1;
        return 0xFFFD;
    }
    const slice = text[idx.* .. idx.* + seq_len];
    const cp = std.unicode.utf8Decode(slice) catch {
        idx.* += 1;
        return 0xFFFD;
    };
    idx.* += seq_len;
    return cp;
}

fn copyCodepointsLossy(text: []const u8, idx: *usize, max_count: usize, buf: []u8) usize {
    var out_len: usize = 0;
    var count: usize = 0;
    while (count < max_count) {
        const cp = nextCodepointLossy(text, idx) orelse break;
        var tmp: [4]u8 = undefined;
        const safe = if (cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF)) 0xFFFD else cp;
        const len = std.unicode.utf8Encode(@intCast(safe), &tmp) catch 0;
        if (len == 0 or out_len + len > buf.len) break;
        @memcpy(buf[out_len .. out_len + len], tmp[0..len]);
        out_len += len;
        count += 1;
    }
    return out_len;
}

pub fn drawTooltip(shell: *Shell, text: []const u8, x: f32, y: f32) void {
    if (text.len == 0) return;
    const theme = shell.theme();
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

    shell.drawRect(@intFromFloat(draw_x), @intFromFloat(draw_y), @intFromFloat(w), @intFromFloat(h), theme.ui_panel_overlay);
    shell.drawRectOutline(@intFromFloat(draw_x), @intFromFloat(draw_y), @intFromFloat(w), @intFromFloat(h), theme.ui_border);
    shell.drawText(text, draw_x + padding, draw_y + padding, theme.foreground);
}
