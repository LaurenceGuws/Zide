const std = @import("std");
const syntax_mod = @import("../../editor/syntax.zig");
const selection_mod = @import("../../editor/view/selection.zig");
const draw_list_mod = @import("../../editor/render/draw_list.zig");
const overlay_mod = @import("editor_widget_draw_overlay.zig");
const renderer_mod = @import("../renderer.zig");

const HighlightToken = syntax_mod.HighlightToken;
const TokenKind = syntax_mod.TokenKind;
const SelectionRange = selection_mod.SelectionRange;
const EditorDrawList = draw_list_mod.EditorDrawList;
const ByteRange = overlay_mod.ByteRange;
const EditorTextStyleFlags = renderer_mod.EditorTextStyleFlags;

pub fn xForByteOffset(
    r: anytype,
    line_text: []const u8,
    seg_start_byte: usize,
    seg_start_vis: usize,
    byte_index: usize,
    text_x: f32,
) f32 {
    const target = @min(byte_index, line_text.len);
    if (target <= seg_start_byte) return text_x;

    var idx = seg_start_byte;
    var vis = seg_start_vis;
    while (idx < target) {
        const first = line_text[idx];
        if (first == '\t') {
            const tab_width: usize = 4;
            vis += tab_width - (vis % tab_width);
            idx += 1;
            continue;
        }
        if (first < 0x80) {
            vis += 1;
            idx += 1;
            continue;
        }
        const seq_len = std.unicode.utf8ByteSequenceLength(first) catch {
            vis += 1;
            idx += 1;
            continue;
        };
        if (idx + seq_len > line_text.len) {
            vis += 1;
            idx += 1;
            continue;
        }
        vis += 1;
        idx += seq_len;
    }
    return text_x + @as(f32, @floatFromInt(vis - seg_start_vis)) * r.char_width;
}

pub fn buildSelectionByteRanges(line_text: []const u8, cluster_slice: ?[]const u32, seg_start_col: usize, seg_end_col: usize, seg_start_byte: usize, seg_end_byte: usize, ranges: []const SelectionRange, out: *[8]ByteRange) usize {
    var count: usize = 0;
    for (ranges) |range| {
        const sel_start_col = @max(range.start_col, seg_start_col);
        const sel_end_col = @min(range.end_col, seg_end_col);
        if (sel_end_col <= sel_start_col) continue;
        const sel_start_byte = selection_mod.byteIndexForVisualColumn(line_text, sel_start_col, cluster_slice);
        const sel_end_byte = selection_mod.byteIndexForVisualColumn(line_text, sel_end_col, cluster_slice);
        const s = @max(seg_start_byte, sel_start_byte);
        const e = @min(seg_end_byte, sel_end_byte);
        if (e <= s) continue;
        if (count < out.len) {
            out[count] = .{ .start = s, .end = e };
            count += 1;
        }
    }
    var i: usize = 1;
    while (i < count) : (i += 1) {
        const key = out[i];
        var j: usize = i;
        while (j > 0 and out[j - 1].start > key.start) : (j -= 1) out[j] = out[j - 1];
        out[j] = key;
    }
    var merged: usize = 0;
    var k: usize = 0;
    while (k < count) : (k += 1) {
        const r = out[k];
        if (merged == 0) {
            out[0] = r;
            merged = 1;
            continue;
        }
        const last = &out[merged - 1];
        if (r.start <= last.end) {
            if (r.end > last.end) last.end = r.end;
        } else {
            out[merged] = r;
            merged += 1;
        }
    }
    return merged;
}

pub fn collectSearchByteRanges(seg_abs_start: usize, seg_abs_end: usize, matches: anytype, out: *[16]ByteRange) usize {
    if (seg_abs_end <= seg_abs_start) return 0;
    var count: usize = 0;
    for (matches) |m| {
        if (m.end <= seg_abs_start) continue;
        if (m.start >= seg_abs_end) break;
        const s = @max(seg_abs_start, m.start);
        const e = @min(seg_abs_end, m.end);
        if (e <= s) continue;
        if (count < out.len) {
            out[count] = .{ .start = s, .end = e };
            count += 1;
        }
    }
    var i: usize = 1;
    while (i < count) : (i += 1) {
        const key = out[i];
        var j: usize = i;
        while (j > 0 and out[j - 1].start > key.start) : (j -= 1) out[j] = out[j - 1];
        out[j] = key;
    }
    var merged: usize = 0;
    var k: usize = 0;
    while (k < count) : (k += 1) {
        const r = out[k];
        if (merged == 0) {
            out[0] = r;
            merged = 1;
            continue;
        }
        const last = &out[merged - 1];
        if (r.start <= last.end) {
            if (r.end > last.end) last.end = r.end;
        } else {
            out[merged] = r;
            merged += 1;
        }
    }
    return merged;
}

pub fn addTextSliceOpsWithSelectionBg(list: *EditorDrawList, r: anytype, text_start_x: f32, y: f32, line_text: []const u8, seg_start_byte: usize, seg_start_vis: usize, slice_start: usize, slice_end: usize, fg: anytype, base_bg: anytype, selection_bg: anytype, sel_ranges: []const ByteRange, disable_programming_ligatures: bool) bool {
    if (slice_end <= slice_start) return true;
    var ok = true;
    var cursor = slice_start;
    for (sel_ranges) |sr| {
        if (sr.end <= cursor) continue;
        if (sr.start >= slice_end) break;
        if (sr.start > cursor) {
            const x = xForByteOffset(r, line_text, seg_start_byte, seg_start_vis, cursor, text_start_x);
            ok = ok and overlay_mod.addTextOpBg(list, x, y, line_text[cursor..@min(sr.start, slice_end)], fg, base_bg, disable_programming_ligatures);
        }
        const b0 = @max(cursor, sr.start);
        const b1 = @min(slice_end, sr.end);
        if (b1 > b0) {
            const x = xForByteOffset(r, line_text, seg_start_byte, seg_start_vis, b0, text_start_x);
            ok = ok and overlay_mod.addTextOpBg(list, x, y, line_text[b0..b1], fg, selection_bg, disable_programming_ligatures);
            cursor = b1;
        }
        if (cursor >= slice_end) break;
    }
    if (cursor < slice_end) {
        const x = xForByteOffset(r, line_text, seg_start_byte, seg_start_vis, cursor, text_start_x);
        ok = ok and overlay_mod.addTextOpBg(list, x, y, line_text[cursor..slice_end], fg, base_bg, disable_programming_ligatures);
    }
    return ok;
}

fn selectionOverlapBg(slice_start: usize, slice_end: usize, base_bg: anytype, selection_bg: anytype, sel_ranges: []const ByteRange) @TypeOf(base_bg) {
    for (sel_ranges) |sr| {
        if (sr.end <= slice_start) continue;
        if (sr.start >= slice_end) break;
        return selection_bg;
    }
    return base_bg;
}

fn tokenStyleInfo(r: anytype, kind: TokenKind) struct {
    flags: EditorTextStyleFlags,
    underline_color: ?@TypeOf(r.theme.foreground),
} {
    const idx = @intFromEnum(kind);
    if (idx >= r.theme.syntax_style_flags.len) {
        return .{ .flags = .{}, .underline_color = null };
    }
    return .{
        .flags = r.theme.syntax_style_flags[idx],
        .underline_color = r.theme.syntax_special_colors[idx],
    };
}

fn drawTextDecorations(r: anytype, x: f32, y: f32, width: f32, color: anytype, flags: EditorTextStyleFlags) void {
    if (width <= 0 or (!flags.underline and !flags.undercurl and !flags.strikethrough)) return;
    const scale = r.uiScaleFactor();
    const thickness = @max(1, @as(i32, @intFromFloat(std.math.round(@max(scale, 1.0)))));
    const x_i = @as(i32, @intFromFloat(std.math.round(x)));
    const y_i = @as(i32, @intFromFloat(std.math.round(y)));
    const w_i = @max(1, @as(i32, @intFromFloat(std.math.round(width))));
    const h_i = @max(1, @as(i32, @intFromFloat(std.math.round(r.char_height))));
    if (flags.undercurl) {
        const baseline_y = y_i + h_i - thickness - 1;
        drawUndercurl(r, x_i, baseline_y, w_i, thickness, color);
    } else if (flags.underline) {
        r.drawRect(x_i, y_i + h_i - thickness, w_i, thickness, color);
    }
    if (flags.strikethrough) {
        r.drawRect(x_i, y_i + @divFloor(h_i, 2), w_i, thickness, color);
    }
}

fn drawStyledTextOnBg(r: anytype, text: []const u8, x: f32, y: f32, fg: anytype, bg: anytype, flags: EditorTextStyleFlags, disable_programming_ligatures: bool) void {
    r.drawTextMonospaceOnBgStyledPolicy(text, x, y, fg, bg, disable_programming_ligatures, flags.italic);
    if (flags.bold) r.drawTextMonospaceOnBgStyledPolicy(text, x + 1.0, y, fg, bg, disable_programming_ligatures, flags.italic);
}

fn addTextDecorationOps(list: *EditorDrawList, r: anytype, x: f32, y: f32, width: f32, color: anytype, flags: EditorTextStyleFlags) bool {
    if (width <= 0 or (!flags.underline and !flags.undercurl and !flags.strikethrough)) return true;
    const thickness = @max(1.0, std.math.round(@max(r.uiScaleFactor(), 1.0)));
    var ok = true;
    if (flags.undercurl) {
        ok = ok and addUndercurlOps(list, x, y + r.char_height - thickness - 1.0, width, thickness, color);
    } else if (flags.underline) {
        ok = ok and overlay_mod.addRectOp(list, x, y + r.char_height - thickness, width, thickness, color);
    }
    if (flags.strikethrough) {
        ok = ok and overlay_mod.addRectOp(list, x, y + std.math.floor(r.char_height * 0.5), width, thickness, color);
    }
    return ok;
}

fn drawUndercurl(r: anytype, x_i: i32, baseline_y: i32, width_i: i32, thickness: i32, color: anytype) void {
    if (width_i <= 0) return;
    const amplitude = @max(1, thickness);
    const step = @max(2, thickness * 2);
    var pos: i32 = 0;
    while (pos < width_i) : (pos += step) {
        const seg_w = @min(step, width_i - pos);
        if (seg_w <= 0) break;
        const half = @max(1, @divFloor(seg_w, 2));
        r.drawRect(x_i + pos, baseline_y, half, thickness, color);
        const tail_w = seg_w - half;
        if (tail_w > 0) {
            r.drawRect(x_i + pos + half, baseline_y + amplitude, tail_w, thickness, color);
        }
    }
}

fn addUndercurlOps(list: *EditorDrawList, x: f32, baseline_y: f32, width: f32, thickness: f32, color: anytype) bool {
    if (width <= 0) return true;
    const thickness_px = @max(1.0, thickness);
    const amplitude = thickness_px;
    const step = @max(2.0, thickness_px * 2.0);
    var ok = true;
    var pos: f32 = 0.0;
    while (pos < width) : (pos += step) {
        const seg_w = @min(step, width - pos);
        if (seg_w <= 0) break;
        const half = @max(1.0, std.math.floor(seg_w * 0.5));
        ok = ok and overlay_mod.addRectOp(list, x + pos, baseline_y, half, thickness_px, color);
        const tail_w = seg_w - half;
        if (tail_w > 0) {
            ok = ok and overlay_mod.addRectOp(list, x + pos + half, baseline_y + amplitude, tail_w, thickness_px, color);
        }
    }
    return ok;
}

fn addStyledTextOpBg(list: *EditorDrawList, x: f32, y: f32, text: []const u8, fg: anytype, bg: anytype, flags: EditorTextStyleFlags, disable_programming_ligatures: bool) bool {
    list.add(.{ .text = .{
        .x = x,
        .y = y,
        .text = text,
        .color = overlay_mod.packColor(fg),
        .bg_color = overlay_mod.packColor(bg),
        .disable_programming_ligatures = disable_programming_ligatures,
        .bold = flags.bold,
        .italic = flags.italic,
    } }) catch return false;
    return true;
}

pub fn drawTextSliceWithSelectionBg(r: anytype, text_start_x: f32, y: f32, line_text: []const u8, seg_start_byte: usize, seg_start_vis: usize, slice_start: usize, slice_end: usize, fg: anytype, base_bg: anytype, selection_bg: anytype, sel_ranges: []const ByteRange, disable_programming_ligatures: bool) void {
    if (slice_end <= slice_start) return;
    var cursor = slice_start;
    for (sel_ranges) |sr| {
        if (sr.end <= cursor) continue;
        if (sr.start >= slice_end) break;
        if (sr.start > cursor) {
            const x = xForByteOffset(r, line_text, seg_start_byte, seg_start_vis, cursor, text_start_x);
            r.drawTextMonospaceOnBgPolicy(line_text[cursor..@min(sr.start, slice_end)], x, y, fg, base_bg, disable_programming_ligatures);
        }
        const b0 = @max(cursor, sr.start);
        const b1 = @min(slice_end, sr.end);
        if (b1 > b0) {
            const x = xForByteOffset(r, line_text, seg_start_byte, seg_start_vis, b0, text_start_x);
            r.drawTextMonospaceOnBgPolicy(line_text[b0..b1], x, y, fg, selection_bg, disable_programming_ligatures);
            cursor = b1;
        }
        if (cursor >= slice_end) break;
    }
    if (cursor < slice_end) {
        const x = xForByteOffset(r, line_text, seg_start_byte, seg_start_vis, cursor, text_start_x);
        r.drawTextMonospaceOnBgPolicy(line_text[cursor..slice_end], x, y, fg, base_bg, disable_programming_ligatures);
    }
}

pub fn appendHighlightedLineSegmentOps(list: *EditorDrawList, r: anytype, line_text: []const u8, y: f32, text_x: f32, line_start: usize, seg_start: usize, seg_end: usize, seg_start_vis: usize, tokens: []HighlightToken, base_bg: anytype, selection_bg: anytype, seg_start_byte: usize, sel_ranges: []const ByteRange, disable_programming_ligatures: bool) bool {
    if (seg_start >= seg_end or line_text.len == 0) return true;
    var ok = true;
    var cursor = seg_start;
    for (tokens) |token| {
        if (token.end <= line_start + seg_start or token.start >= line_start + seg_end) continue;
        const rel_start = if (token.start > line_start) token.start - line_start else 0;
        const start = @max(rel_start, seg_start);
        const end = @min(token.end - line_start, seg_end);
        if (start > cursor) {
            ok = ok and addTextSliceOpsWithSelectionBg(list, r, text_x, y, line_text, seg_start_byte, seg_start_vis, cursor, start, r.theme.foreground, base_bg, selection_bg, sel_ranges, disable_programming_ligatures);
        }
        const conceal_text: ?[]const u8 = if (token.conceal != null or token.conceal_lines) token.conceal orelse "" else null;
        var color = colorForToken(r, token.kind);
        if (token.url != null) color = r.theme.link;
        const style = tokenStyleInfo(r, token.kind);
        const decoration_color = style.underline_color orelse color;
        if (conceal_text) |ctext| {
            if (ctext.len > 0) {
                const bg = selectionOverlapBg(start, end, base_bg, selection_bg, sel_ranges);
                const x = xForByteOffset(r, line_text, seg_start, seg_start_vis, start, text_x);
                ok = ok and addStyledTextOpBg(list, x, y, ctext, color, bg, style.flags, disable_programming_ligatures);
                ok = ok and addTextDecorationOps(list, r, x, y, @as(f32, @floatFromInt(ctext.len)) * r.char_width, decoration_color, style.flags);
            }
        } else {
            const start_x = xForByteOffset(r, line_text, seg_start, seg_start_vis, start, text_x);
            const end_x = xForByteOffset(r, line_text, seg_start, seg_start_vis, end, text_x);
            const bg = selectionOverlapBg(start, end, base_bg, selection_bg, sel_ranges);
            ok = ok and addStyledTextOpBg(list, start_x, y, line_text[start..end], color, bg, style.flags, disable_programming_ligatures);
            ok = ok and addTextDecorationOps(list, r, start_x, y, end_x - start_x, decoration_color, style.flags);
        }
        if (end > cursor) cursor = end;
    }
    if (cursor < seg_end) {
        ok = ok and addTextSliceOpsWithSelectionBg(list, r, text_x, y, line_text, seg_start_byte, seg_start_vis, cursor, seg_end, r.theme.foreground, base_bg, selection_bg, sel_ranges, disable_programming_ligatures);
    }
    return ok;
}

pub fn drawHighlightedLineSegment(r: anytype, line_text: []const u8, y: f32, text_x: f32, line_start: usize, seg_start: usize, seg_end: usize, seg_start_vis: usize, tokens: []const HighlightToken, base_bg: anytype, selection_bg: anytype, sel_ranges: []const ByteRange, disable_programming_ligatures: bool) void {
    if (seg_start >= seg_end or line_text.len == 0) return;
    var cursor = seg_start;
    for (tokens) |token| {
        if (token.end <= line_start + seg_start or token.start >= line_start + seg_end) continue;
        const start = @max(token.start - line_start, seg_start);
        const end = @min(token.end - line_start, seg_end);
        if (start > cursor) {
            drawTextSliceWithSelectionBg(r, text_x, y, line_text, seg_start, seg_start_vis, cursor, start, r.theme.foreground, base_bg, selection_bg, sel_ranges, disable_programming_ligatures);
        }
        const x = xForByteOffset(r, line_text, seg_start, seg_start_vis, start, text_x);
        const conceal_text: ?[]const u8 = if (token.conceal != null or token.conceal_lines) token.conceal orelse "" else null;
        var color = colorForToken(r, token.kind);
        if (token.url != null) color = r.theme.link;
        const style = tokenStyleInfo(r, token.kind);
        const decoration_color = style.underline_color orelse color;
        if (conceal_text) |text| {
            if (text.len > 0) {
                const bg = selectionOverlapBg(start, end, base_bg, selection_bg, sel_ranges);
                drawStyledTextOnBg(r, text, x, y, color, bg, style.flags, disable_programming_ligatures);
                drawTextDecorations(r, x, y, @as(f32, @floatFromInt(text.len)) * r.char_width, decoration_color, style.flags);
            }
        } else {
            const bg = selectionOverlapBg(start, end, base_bg, selection_bg, sel_ranges);
            drawStyledTextOnBg(r, line_text[start..end], x, y, color, bg, style.flags, disable_programming_ligatures);
            const end_x = xForByteOffset(r, line_text, seg_start, seg_start_vis, end, text_x);
            drawTextDecorations(r, x, y, end_x - x, decoration_color, style.flags);
        }
        if (end > cursor) cursor = end;
    }
    if (cursor < seg_end) {
        drawTextSliceWithSelectionBg(r, text_x, y, line_text, seg_start, seg_start_vis, cursor, seg_end, r.theme.foreground, base_bg, selection_bg, sel_ranges, disable_programming_ligatures);
    }
}

pub fn highlightTokenLessThan(_: void, a: HighlightToken, b: HighlightToken) bool {
    return syntax_mod.highlightTokenLessThanStable(a, b);
}

fn colorForToken(r: anytype, kind: TokenKind) @TypeOf(r.theme.foreground) {
    return switch (kind) {
        .comment => r.theme.comment_color,
        .string => r.theme.string,
        .keyword => r.theme.keyword,
        .number => r.theme.number,
        .function => r.theme.function,
        .variable => r.theme.variable,
        .type_name => r.theme.type_name,
        .operator => r.theme.operator,
        .builtin => r.theme.builtin_color,
        .punctuation => r.theme.punctuation,
        .constant => r.theme.constant,
        .attribute => r.theme.attribute,
        .namespace => r.theme.namespace,
        .label => r.theme.label,
        .link => r.theme.link,
        .error_token => r.theme.error_token,
        .preproc => r.theme.preproc,
        .macro => r.theme.macro,
        .escape => r.theme.escape,
        .keyword_control => r.theme.keyword_control,
        .function_method => r.theme.function_method,
        .type_builtin => r.theme.type_builtin,
        else => r.theme.foreground,
    };
}
