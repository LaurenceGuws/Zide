const std = @import("std");
const syntax_mod = @import("../../editor/syntax.zig");
const selection_mod = @import("../../editor/view/selection.zig");
const draw_list_mod = @import("../../editor/render/draw_list.zig");
const overlay_mod = @import("editor_widget_draw_overlay.zig");

const HighlightToken = syntax_mod.HighlightToken;
const TokenKind = syntax_mod.TokenKind;
const SelectionRange = selection_mod.SelectionRange;
const EditorDrawList = draw_list_mod.EditorDrawList;
const ByteRange = overlay_mod.ByteRange;

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
        if (conceal_text) |ctext| {
            if (ctext.len > 0) {
                const bg = selectionOverlapBg(start, end, base_bg, selection_bg, sel_ranges);
                const x = xForByteOffset(r, line_text, seg_start, seg_start_vis, start, text_x);
                ok = ok and overlay_mod.addTextOpBg(list, x, y, ctext, color, bg, disable_programming_ligatures);
            }
        } else {
            ok = ok and addTextSliceOpsWithSelectionBg(list, r, text_x, y, line_text, seg_start_byte, seg_start_vis, start, end, color, base_bg, selection_bg, sel_ranges, disable_programming_ligatures);
        }
        if (end > cursor) cursor = end;
    }
    if (cursor < seg_end) {
        ok = ok and addTextSliceOpsWithSelectionBg(list, r, text_x, y, line_text, seg_start_byte, seg_start_vis, cursor, seg_end, r.theme.foreground, base_bg, selection_bg, sel_ranges, disable_programming_ligatures);
    }
    return ok;
}

pub fn drawHighlightedLineSegment(r: anytype, line_text: []const u8, y: f32, text_x: f32, line_start: usize, seg_start: usize, seg_end: usize, seg_start_vis: usize, tokens: []HighlightToken, base_bg: anytype, selection_bg: anytype, sel_ranges: []const ByteRange, disable_programming_ligatures: bool) void {
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
        if (conceal_text) |text| {
            if (text.len > 0) {
                const bg = selectionOverlapBg(start, end, base_bg, selection_bg, sel_ranges);
                r.drawTextMonospaceOnBgPolicy(text, x, y, color, bg, disable_programming_ligatures);
            }
        } else {
            drawTextSliceWithSelectionBg(r, text_x, y, line_text, seg_start, seg_start_vis, start, end, color, base_bg, selection_bg, sel_ranges, disable_programming_ligatures);
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
