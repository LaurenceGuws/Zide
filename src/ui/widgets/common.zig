const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const renderer_tooltip_host = @import("../renderer/renderer_tooltip_host.zig");
const shared_types = @import("../../types/mod.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;

pub const TruncResult = struct {
    drawn_width: f32,
    truncated: bool,
    drawn_len: usize,
};

pub const TruncatedText = struct {
    text: []const u8,
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

pub const TerminalPointerHit = struct {
    row: usize,
    col: usize,
    local_x: f32,
    local_y: f32,
};

pub fn scrollbarWidth(ui_scale: f32) f32 {
    return @max(@as(f32, 6), 6 * ui_scale);
}

pub fn scrollbarHoverWidth(ui_scale: f32) f32 {
    return @max(@as(f32, 12), 16 * ui_scale);
}

pub fn scrollbarHitMargin(ui_scale: f32) f32 {
    return @max(@as(f32, 6), 8 * ui_scale);
}

pub fn scrollbarProximityRange(ui_scale: f32) f32 {
    return @max(@as(f32, 24), 32 * ui_scale);
}

pub fn smoothstep01(t: f32) f32 {
    const tt = std.math.clamp(t, 0.0, 1.0);
    return tt * tt * (3.0 - 2.0 * tt);
}

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

pub fn expApproach(current: f32, target: f32, dt: f32, speed: f32) f32 {
    if (dt <= 0) return current;
    const k = std.math.exp(-speed * dt);
    return target + (current - target) * k;
}

pub fn pointInRect(px: f32, py: f32, x: f32, y: f32, w: f32, h: f32) bool {
    return px >= x and px <= x + w and py >= y and py <= y + h;
}

pub fn terminalVisibleCellHit(view: shared_types.layout.TerminalViewGeometry, mouse_x: f32, mouse_y: f32) ?TerminalPointerHit {
    if (view.rows == 0 or view.cols == 0) return null;
    if (view.cell_width <= 0 or view.cell_height <= 0) return null;
    if (!pointInRect(mouse_x, mouse_y, view.origin_x, view.origin_y, view.viewport_width, view.viewport_height)) return null;

    const local_x = mouse_x - view.origin_x;
    const local_y = mouse_y - view.origin_y;
    if (local_x < 0 or local_y < 0) return null;

    const col = @min(
        @as(usize, @intFromFloat(std.math.floor(local_x / view.cell_width))),
        view.cols - 1,
    );
    const row = @min(
        @as(usize, @intFromFloat(std.math.floor(local_y / view.cell_height))),
        view.rows - 1,
    );
    return .{
        .row = row,
        .col = col,
        .local_x = local_x,
        .local_y = local_y,
    };
}

pub fn computeScrollbarThumb(scrollbar_y: f32, track_h: f32, visible_lines: usize, total_lines: usize, min_thumb_h: f32, ratio: f32) ScrollbarThumb {
    const thumb_h = if (total_lines > visible_lines)
        @max(min_thumb_h, track_h * (@as(f32, @floatFromInt(visible_lines)) / @as(f32, @floatFromInt(total_lines))))
    else
        track_h;
    const available = @max(@as(f32, 1), track_h - thumb_h);
    const thumb_y = scrollbar_y + available * ratio;
    return .{ .thumb_h = thumb_h, .available = available, .thumb_y = thumb_y };
}

pub fn scrollbarTrackRatio(max_scroll_offset: usize, scroll_offset: usize) f32 {
    if (max_scroll_offset == 0) return 1.0;
    return @as(f32, @floatFromInt(max_scroll_offset - scroll_offset)) /
        @as(f32, @floatFromInt(max_scroll_offset));
}

pub fn drawTruncatedText(shell: *Shell, text: []const u8, x: f32, y: f32, color: Color, max_width: f32) TruncResult {
    return drawTruncatedTextImpl(shell, text, x, y, color, max_width, null);
}

pub fn drawTruncatedTextOnBg(shell: *Shell, text: []const u8, x: f32, y: f32, color: Color, bg: Color, max_width: f32) TruncResult {
    return drawTruncatedTextImpl(shell, text, x, y, color, max_width, bg);
}

pub fn truncateText(shell: *Shell, text: []const u8, max_width: f32, out: []u8) TruncatedText {
    if (max_width <= 0 or text.len == 0) {
        return .{ .text = out[0..0], .drawn_width = 0, .truncated = text.len > 0, .drawn_len = 0 };
    }
    const max_chars: usize = @intCast(@max(0, @as(i32, @intFromFloat(max_width / shell.charWidth()))));
    if (max_chars == 0) {
        return .{ .text = out[0..0], .drawn_width = 0, .truncated = text.len > 0, .drawn_len = 0 };
    }

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
        out_len = copyCodepointsLossy(text, &idx, count, out);
        if (idx < text.len) truncated = true;
    } else if (max_chars <= 3) {
        idx = 0;
        out_len = copyCodepointsLossy(text, &idx, max_chars, out);
    } else {
        idx = 0;
        out_len = copyCodepointsLossy(text, &idx, max_chars - 3, out);
        if (out_len + 3 <= out.len) {
            out[out_len + 0] = '.';
            out[out_len + 1] = '.';
            out[out_len + 2] = '.';
            out_len += 3;
        }
    }

    return .{
        .text = out[0..out_len],
        .drawn_width = @as(f32, @floatFromInt(out_len)) * shell.charWidth(),
        .truncated = truncated,
        .drawn_len = out_len,
    };
}

fn drawTruncatedTextImpl(shell: *Shell, text: []const u8, x: f32, y: f32, color: Color, max_width: f32, bg: ?Color) TruncResult {
    var buf: [256]u8 = undefined;
    const truncated = truncateText(shell, text, max_width, buf[0..]);

    if (bg) |background| {
        shell.drawTextOnBg(truncated.text, x, y, color, background);
    } else {
        shell.drawText(truncated.text, x, y, color);
    }
    return .{
        .drawn_width = truncated.drawn_width,
        .truncated = truncated.truncated,
        .drawn_len = truncated.drawn_len,
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

    renderer_tooltip_host.draw(shell.rendererPtr(), text, draw_x, draw_y, w, h, padding, .{
        .bg = theme.ui_panel_overlay,
        .border = theme.ui_border,
        .text = theme.ui_text,
    });
}

test "terminalVisibleCellHit ignores pane remainder outside centered grid" {
    const hit = terminalVisibleCellHit(.{
        .viewport = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .origin_x = 10,
        .origin_y = 20,
        .viewport_width = 80,
        .viewport_height = 60,
        .rows = 3,
        .cols = 4,
        .cell_width = 20,
        .cell_height = 20,
        .baseline_from_top = 15,
    }, 5, 30);
    try std.testing.expect(hit == null);
}

test "terminalVisibleCellHit maps mouse to visible cell coordinates" {
    const hit = terminalVisibleCellHit(.{
        .viewport = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .origin_x = 10,
        .origin_y = 20,
        .viewport_width = 80,
        .viewport_height = 60,
        .rows = 3,
        .cols = 4,
        .cell_width = 20,
        .cell_height = 20,
        .baseline_from_top = 15,
    }, 55, 65).?;
    try std.testing.expectEqual(@as(usize, 2), hit.col);
    try std.testing.expectEqual(@as(usize, 2), hit.row);
}
