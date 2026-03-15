const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const terminal_font_mod = @import("../terminal_font.zig");
const types = @import("types.zig");

const TerminalFont = terminal_font_mod.TerminalFont;

pub fn drawText(
    allocator: std.mem.Allocator,
    font: *TerminalFont,
    ctx: *anyopaque,
    drawTexture: *const fn (ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void,
    text: []const u8,
    x: f32,
    y: f32,
    cell_w: f32,
    cell_h: f32,
    color: types.Rgba,
    monospace: bool,
) void {
    const log = app_logger.logger("renderer.text");
    if (text.len == 0) return;

    var codepoints = std.ArrayList(u32).empty;
    defer codepoints.deinit(allocator);
    var cp_idx: usize = 0;
    while (true) {
        const cp = nextCodepointLossy(text, &cp_idx) orelse break;
        _ = codepoints.append(allocator, cp) catch |err| blk: {
            log.logf(.warning, "text codepoint append failed cp={d} err={s}", .{ cp, @errorName(err) });
            break :blk 0;
        };
    }
    if (codepoints.items.len == 0) return;

    var cursor_x = x;
    var visual_col: usize = 0;
    const draw = terminal_font_mod.DrawContext{
        .ctx = ctx,
        .drawTexture = drawTexture,
    };
    var idx: usize = 0;
    while (idx < codepoints.items.len) : (idx += 1) {
        const cp = codepoints.items[idx];
        if (cp == '\t') {
            if (monospace) {
                const tab_width: usize = 4;
                visual_col += tab_width - (visual_col % tab_width);
                cursor_x = x + @as(f32, @floatFromInt(visual_col)) * cell_w;
            } else {
                cursor_x += cell_w * 4.0;
            }
            continue;
        }
        const next = if (idx + 1 < codepoints.items.len) codepoints.items[idx + 1] else 0;
        const followed_by_space = next == ' ';
        font.drawGlyph(draw, cp, cursor_x, y, cell_w, cell_h, followed_by_space, color);
        if (monospace) {
            visual_col += 1;
            cursor_x += cell_w;
        } else {
            const adv = font.glyphAdvance(cp) catch cell_w;
            cursor_x += if (adv > 0) adv else cell_w;
        }
    }
}

pub fn measureTextWidth(font: *TerminalFont, text: []const u8, fallback_cell_w: f32) f32 {
    if (text.len == 0) return 0;
    var width: f32 = 0;
    var idx: usize = 0;
    while (true) {
        const cp = nextCodepointLossy(text, &idx) orelse break;
        if (cp == '\t') {
            width += fallback_cell_w * 4.0;
            continue;
        }
        const adv = font.glyphAdvance(cp) catch fallback_cell_w;
        width += if (adv > 0) adv else fallback_cell_w;
    }
    return width;
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
