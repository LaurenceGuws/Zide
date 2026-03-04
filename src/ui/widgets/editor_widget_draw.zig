const std = @import("std");
const syntax_mod = @import("../../editor/syntax.zig");
const selection_mod = @import("../../editor/view/selection.zig");
const layout_mod = @import("../../editor/view/layout.zig");
const metrics_mod = @import("../../editor/view/metrics.zig");
const cache_mod = @import("../../editor/render/cache.zig");
const draw_list_mod = @import("../../editor/render/draw_list.zig");
const app_logger = @import("../../app_logger.zig");
const common = @import("common.zig");

const HighlightToken = syntax_mod.HighlightToken;
const TokenKind = syntax_mod.TokenKind;
const SelectionRange = selection_mod.SelectionRange;
const EditorDrawList = draw_list_mod.EditorDrawList;
const TextOp = draw_list_mod.TextOp;
const RectOp = draw_list_mod.RectOp;
const CursorOp = draw_list_mod.CursorOp;
const large_file_fallback_threshold_bytes: usize = 8 * 1024 * 1024;

fn packColor(color: anytype) u32 {
    return @as(u32, color.r) | (@as(u32, color.g) << 8) | (@as(u32, color.b) << 16) | (@as(u32, color.a) << 24);
}

fn unpackColor(comptime ColorType: type, color: u32) ColorType {
    return .{
        .r = @intCast(color & 0xff),
        .g = @intCast((color >> 8) & 0xff),
        .b = @intCast((color >> 16) & 0xff),
        .a = @intCast((color >> 24) & 0xff),
    };
}

fn addRectOp(list: *EditorDrawList, x: f32, y: f32, w: f32, h: f32, color: anytype) bool {
    list.add(.{ .rect = RectOp{ .x = x, .y = y, .w = w, .h = h, .color = packColor(color) } }) catch return false;
    return true;
}

fn addTextOp(list: *EditorDrawList, x: f32, y: f32, text: []const u8, color: anytype, disable_programming_ligatures: bool) bool {
    list.add(.{ .text = TextOp{ .x = x, .y = y, .text = text, .color = packColor(color), .bg_color = 0, .disable_programming_ligatures = disable_programming_ligatures } }) catch return false;
    return true;
}

fn addTextOpBg(list: *EditorDrawList, x: f32, y: f32, text: []const u8, color: anytype, bg: anytype, disable_programming_ligatures: bool) bool {
    list.add(.{ .text = TextOp{ .x = x, .y = y, .text = text, .color = packColor(color), .bg_color = packColor(bg), .disable_programming_ligatures = disable_programming_ligatures } }) catch return false;
    return true;
}

fn addCursorOp(list: *EditorDrawList, x: f32, y: f32, h: f32, color: anytype) bool {
    list.add(.{ .cursor = CursorOp{ .x = x, .y = y, .h = h, .color = packColor(color) } }) catch return false;
    return true;
}

fn drawExtraCarets(
    widget: anytype,
    r: anytype,
    line_idx: usize,
    line_text: []const u8,
    cluster_slice: ?[]const u32,
    seg_start_col: usize,
    seg_end_col: usize,
    line_width: usize,
    seg_y: f32,
    text_start_x: f32,
) void {
    for (widget.editor.selections.items) |sel| {
        const caret = sel.normalized();
        if (!caret.isEmpty()) continue;
        if (caret.start.offset == widget.editor.cursor.offset) continue;
        if (caret.start.line != line_idx) continue;
        const caret_col = selection_mod.visualColumnForByteIndex(line_text, caret.start.col, cluster_slice);
        const in_segment = if (seg_start_col == seg_end_col)
            caret_col == seg_start_col
        else if (caret_col == line_width and seg_end_col == line_width)
            caret_col >= seg_start_col and caret_col <= seg_end_col
        else
            caret_col >= seg_start_col and caret_col < seg_end_col;
        if (!in_segment) continue;
        const local_col = caret_col - seg_start_col;
        const cursor_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r.char_width;
        r.drawCursor(cursor_x, seg_y, .line);
    }
}

fn addExtraCaretOps(
    list: *EditorDrawList,
    widget: anytype,
    r: anytype,
    line_idx: usize,
    line_text: []const u8,
    cluster_slice: ?[]const u32,
    seg_start_col: usize,
    seg_end_col: usize,
    line_width: usize,
    seg_y: f32,
    text_start_x: f32,
) bool {
    var ok = true;
    for (widget.editor.selections.items) |sel| {
        const caret = sel.normalized();
        if (!caret.isEmpty()) continue;
        if (caret.start.offset == widget.editor.cursor.offset) continue;
        if (caret.start.line != line_idx) continue;
        const caret_col = selection_mod.visualColumnForByteIndex(line_text, caret.start.col, cluster_slice);
        const in_segment = if (seg_start_col == seg_end_col)
            caret_col == seg_start_col
        else if (caret_col == line_width and seg_end_col == line_width)
            caret_col >= seg_start_col and caret_col <= seg_end_col
        else
            caret_col >= seg_start_col and caret_col < seg_end_col;
        if (!in_segment) continue;
        const local_col = caret_col - seg_start_col;
        const cursor_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r.char_width;
        ok = ok and addCursorOp(list, cursor_x, seg_y, r.char_height, r.theme.cursor);
    }
    return ok;
}

fn selectionStateHash(editor: anytype) u64 {
    var h: u64 = 1469598103934665603;
    h ^= @as(u64, editor.cursor.offset);
    h *%= 1099511628211;
    if (editor.selection) |sel| {
        h ^= @as(u64, sel.start.offset);
        h *%= 1099511628211;
        h ^= @as(u64, sel.end.offset);
        h *%= 1099511628211;
    }
    h ^= @as(u64, editor.selections.items.len);
    h *%= 1099511628211;
    for (editor.selections.items) |sel| {
        h ^= @as(u64, sel.start.offset);
        h *%= 1099511628211;
        h ^= @as(u64, sel.end.offset);
        h *%= 1099511628211;
    }
    h ^= editor.search_epoch;
    h *%= 1099511628211;
    return h;
}

const RowBand = struct {
    y_i: i32,
    h_i: i32,
    y_f: f32,
    h_f: f32,
};

fn rowBandForRow(base_y: f32, row: usize, h: f32) RowBand {
    const top_f = base_y + @as(f32, @floatFromInt(row)) * h;
    const bottom_f = base_y + @as(f32, @floatFromInt(row + 1)) * h;
    const top = @as(i32, @intFromFloat(std.math.round(top_f)));
    const bottom = @as(i32, @intFromFloat(std.math.round(bottom_f)));
    const hi = @max(1, bottom - top);
    return .{
        .y_i = top,
        .h_i = hi,
        .y_f = @floatFromInt(top),
        .h_f = @floatFromInt(hi),
    };
}

fn selectionBandForRowBand(band: RowBand) RowBand {
    return .{
        .y_i = band.y_i,
        .h_i = band.h_i + 1,
        .y_f = band.y_f,
        .h_f = band.h_f + 1.0,
    };
}

fn searchHighlightColor(theme: anytype) @TypeOf(theme.selection) {
    var color = if (@hasField(@TypeOf(theme), "ui_accent")) theme.ui_accent else theme.selection;
    color.a = 80;
    return color;
}

fn activeSearchHighlightColor(theme: anytype) @TypeOf(theme.selection) {
    var color = if (@hasField(@TypeOf(theme), "ui_accent")) theme.ui_accent else theme.selection;
    color.a = 152;
    return color;
}

fn searchActiveByteRange(editor: anytype) ?ByteRange {
    const active = editor.searchActiveMatch() orelse return null;
    return .{ .start = active.start, .end = active.end };
}

fn rangeContains(haystack: ByteRange, needle: ByteRange) bool {
    return needle.start >= haystack.start and needle.end <= haystack.end;
}

fn flushDrawList(list: *EditorDrawList, r: anytype) void {
    const ColorType = @TypeOf(r.theme.foreground);
    for (list.ops.items) |op| {
        switch (op) {
            .rect => |rect| {
                r.drawRect(
                    @intFromFloat(rect.x),
                    @intFromFloat(rect.y),
                    @intFromFloat(rect.w),
                    @intFromFloat(rect.h),
                    unpackColor(ColorType, rect.color),
                );
            },
            .text => |text| {
                const fg = unpackColor(ColorType, text.color);
                const bg = unpackColor(ColorType, text.bg_color);
                if (bg.a != 0) {
                    r.drawTextMonospaceOnBgPolicy(text.text, text.x, text.y, fg, bg, text.disable_programming_ligatures);
                } else {
                    r.drawTextMonospacePolicy(text.text, text.x, text.y, fg, text.disable_programming_ligatures);
                }
            },
            .cursor => |cursor| {
                r.drawRect(
                    @intFromFloat(cursor.x),
                    @intFromFloat(cursor.y),
                    2,
                    @intFromFloat(cursor.h),
                    unpackColor(ColorType, cursor.color),
                );
            },
        }
    }
}

fn addEditorLineBaseOps(
    list: *EditorDrawList,
    r: anytype,
    line_num: usize,
    y: f32,
    x: f32,
    gutter_width: f32,
    content_width: f32,
    is_current: bool,
    num_buf: *[16]u8,
) bool {
    var ok = true;

    if (is_current) {
        ok = ok and addRectOp(
            list,
            x + gutter_width,
            y,
            content_width - gutter_width,
            r.char_height,
            r.theme.current_line,
        );
        ok = ok and addRectOp(
            list,
            x,
            y,
            gutter_width,
            r.char_height,
            r.theme.current_line,
        );
    }

    const num_str = std.fmt.bufPrint(num_buf, "{d: >4}", .{line_num + 1}) catch return false;
    const pad = 4 * r.uiScaleFactor();
    const line_color = if (is_current) r.theme.foreground else r.theme.line_number;
    const line_bg = if (is_current) r.theme.current_line else r.theme.line_number_bg;
    ok = ok and addTextOpBg(list, x + pad, y, num_str, line_color, line_bg, false);
    return ok;
}

const ByteRange = struct { start: usize, end: usize };

fn xForByteOffset(
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

fn buildSelectionByteRanges(
    line_text: []const u8,
    cluster_slice: ?[]const u32,
    seg_start_col: usize,
    seg_end_col: usize,
    seg_start_byte: usize,
    seg_end_byte: usize,
    ranges: []const SelectionRange,
    out: *[8]ByteRange,
) usize {
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

    // Sort by start (insertion sort) and merge overlaps.
    var i: usize = 1;
    while (i < count) : (i += 1) {
        const key = out[i];
        var j: usize = i;
        while (j > 0 and out[j - 1].start > key.start) : (j -= 1) {
            out[j] = out[j - 1];
        }
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

fn collectSearchByteRanges(
    seg_abs_start: usize,
    seg_abs_end: usize,
    matches: anytype,
    out: *[16]ByteRange,
) usize {
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
        while (j > 0 and out[j - 1].start > key.start) : (j -= 1) {
            out[j] = out[j - 1];
        }
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

fn addTextSliceOpsWithSelectionBg(
    list: *EditorDrawList,
    r: anytype,
    text_start_x: f32,
    y: f32,
    line_text: []const u8,
    seg_start_byte: usize,
    seg_start_vis: usize,
    slice_start: usize,
    slice_end: usize,
    fg: anytype,
    base_bg: anytype,
    selection_bg: anytype,
    sel_ranges: []const ByteRange,
    disable_programming_ligatures: bool,
) bool {
    if (slice_end <= slice_start) return true;
    var ok = true;
    var cursor = slice_start;
    for (sel_ranges) |sr| {
        if (sr.end <= cursor) continue;
        if (sr.start >= slice_end) break;
        if (sr.start > cursor) {
            const a0 = cursor;
            const a1 = @min(sr.start, slice_end);
            const x = xForByteOffset(r, line_text, seg_start_byte, seg_start_vis, a0, text_start_x);
            ok = ok and addTextOpBg(list, x, y, line_text[a0..a1], fg, base_bg, disable_programming_ligatures);
        }
        const b0 = @max(cursor, sr.start);
        const b1 = @min(slice_end, sr.end);
        if (b1 > b0) {
            const x = xForByteOffset(r, line_text, seg_start_byte, seg_start_vis, b0, text_start_x);
            ok = ok and addTextOpBg(list, x, y, line_text[b0..b1], fg, selection_bg, disable_programming_ligatures);
            cursor = b1;
        }
        if (cursor >= slice_end) break;
    }
    if (cursor < slice_end) {
        const x = xForByteOffset(r, line_text, seg_start_byte, seg_start_vis, cursor, text_start_x);
        ok = ok and addTextOpBg(list, x, y, line_text[cursor..slice_end], fg, base_bg, disable_programming_ligatures);
    }
    return ok;
}

fn selectionOverlapBg(
    slice_start: usize,
    slice_end: usize,
    base_bg: anytype,
    selection_bg: anytype,
    sel_ranges: []const ByteRange,
) @TypeOf(base_bg) {
    for (sel_ranges) |sr| {
        if (sr.end <= slice_start) continue;
        if (sr.start >= slice_end) break;
        return selection_bg;
    }
    return base_bg;
}

fn drawTextSliceWithSelectionBg(
    r: anytype,
    text_start_x: f32,
    y: f32,
    line_text: []const u8,
    seg_start_byte: usize,
    seg_start_vis: usize,
    slice_start: usize,
    slice_end: usize,
    fg: anytype,
    base_bg: anytype,
    selection_bg: anytype,
    sel_ranges: []const ByteRange,
    disable_programming_ligatures: bool,
) void {
    if (slice_end <= slice_start) return;
    var cursor = slice_start;
    for (sel_ranges) |sr| {
        if (sr.end <= cursor) continue;
        if (sr.start >= slice_end) break;
        if (sr.start > cursor) {
            const a0 = cursor;
            const a1 = @min(sr.start, slice_end);
            const x = xForByteOffset(r, line_text, seg_start_byte, seg_start_vis, a0, text_start_x);
            r.drawTextMonospaceOnBgPolicy(line_text[a0..a1], x, y, fg, base_bg, disable_programming_ligatures);
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

fn appendHighlightedLineSegmentOps(
    list: *EditorDrawList,
    r: anytype,
    line_text: []const u8,
    y: f32,
    text_x: f32,
    line_start: usize,
    seg_start: usize,
    seg_end: usize,
    seg_start_vis: usize,
    tokens: []HighlightToken,
    base_bg: anytype,
    selection_bg: anytype,
    seg_start_byte: usize,
    sel_ranges: []const ByteRange,
    disable_programming_ligatures: bool,
) bool {
    if (seg_start >= seg_end or line_text.len == 0) return true;

    var ok = true;
    var cursor = seg_start;
    for (tokens) |token| {
        if (token.end <= line_start + seg_start or token.start >= line_start + seg_end) continue;
        const rel_start = if (token.start > line_start) token.start - line_start else 0;
        const start = @max(rel_start, seg_start);
        const end = @min(token.end - line_start, seg_end);
        if (start > cursor) {
            const slice_start = cursor;
            const slice_end = start;
            ok = ok and addTextSliceOpsWithSelectionBg(
                list,
                r,
                text_x,
                y,
                line_text,
                seg_start_byte,
                seg_start_vis,
                slice_start,
                slice_end,
                r.theme.foreground,
                base_bg,
                selection_bg,
                sel_ranges,
                disable_programming_ligatures,
            );
        }
        const slice_start = start;
        const slice_end = end;
        const conceal_text: ?[]const u8 = if (token.conceal != null or token.conceal_lines)
            token.conceal orelse ""
        else
            null;
        var color = colorForToken(r, token.kind);
        if (token.url != null) {
            color = r.theme.link;
        }
        if (conceal_text) |ctext| {
            if (ctext.len > 0) {
                const bg = selectionOverlapBg(slice_start, slice_end, base_bg, selection_bg, sel_ranges);
                const x = xForByteOffset(r, line_text, seg_start, seg_start_vis, slice_start, text_x);
                ok = ok and addTextOpBg(list, x, y, ctext, color, bg, disable_programming_ligatures);
            }
        } else {
            ok = ok and addTextSliceOpsWithSelectionBg(
                list,
                r,
                text_x,
                y,
                line_text,
                seg_start_byte,
                seg_start_vis,
                slice_start,
                slice_end,
                color,
                base_bg,
                selection_bg,
                sel_ranges,
                disable_programming_ligatures,
            );
        }
        if (end > cursor) {
            cursor = end;
        }
    }

    if (cursor < seg_end) {
        const slice_start = cursor;
        ok = ok and addTextSliceOpsWithSelectionBg(
            list,
            r,
            text_x,
            y,
            line_text,
            seg_start_byte,
            seg_start_vis,
            slice_start,
            seg_end,
            r.theme.foreground,
            base_bg,
            selection_bg,
            sel_ranges,
            disable_programming_ligatures,
        );
    }

    return ok;
}

pub fn draw(
    widget: anytype,
    shell: anytype,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    input: anytype,
) void {
    const r = shell.rendererPtr();
    widget.gutter_width = 50 * r.uiScaleFactor();
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    const start_line = widget.editor.scroll_line;
    const start_seg = widget.editor.scroll_row_offset;
    const total_lines = widget.editor.lineCount();
    const end_line = @min(start_line + visible_lines + 1, total_lines);
    var cursor_draw_x: ?f32 = null;
    var cursor_draw_y: ?f32 = null;
    var max_visible_width: usize = 0;
    const cols = widget.viewportColumns(shell);
    const show_vscroll = !widget.wrap_enabled and total_lines > visible_lines;
    var draw_list = EditorDrawList.init(widget.editor.allocator);
    defer draw_list.deinit();

    var highlight_tokens: []HighlightToken = &[_]HighlightToken{};
    var highlight_tokens_allocated = false;
    if (widget.editor.highlighter) |highlighter| {
        if (total_lines > 0 and start_line < total_lines) {
            const range_start = widget.editor.lineStart(start_line);
            const range_end = if (end_line < total_lines) widget.editor.lineStart(end_line) else widget.editor.totalLen();
            const tokens_opt: ?[]HighlightToken = highlighter.highlightRange(range_start, range_end, widget.editor.allocator) catch null;
            if (tokens_opt) |tokens| {
                highlight_tokens = tokens;
                highlight_tokens_allocated = true;
                if (highlight_tokens.len > 1) {
                    std.sort.heap(HighlightToken, highlight_tokens, {}, highlightTokenLessThan);
                }
            }
        }
    }
    defer if (highlight_tokens_allocated) widget.editor.allocator.free(highlight_tokens);

    // Draw gutter background
    r.drawRect(
        @intFromFloat(x),
        @intFromFloat(y),
        @intFromFloat(widget.gutter_width),
        @intFromFloat(height),
        r.theme.line_number_bg,
    );

    // Draw lines
    var line_buf: [4096]u8 = undefined;
    var line_idx = start_line;
    var visual_row: usize = 0;
    var token_idx: usize = 0;
    const text_start_x = x + widget.gutter_width + 8 * r.uiScaleFactor();
    while (line_idx < total_lines and visual_row < visible_lines) : (line_idx += 1) {
        const is_current = line_idx == widget.editor.cursor.line;

        const line_len = widget.editor.lineLen(line_idx);
        var line_alloc: ?[]u8 = null;
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..widget.editor.getLine(line_idx, &line_buf)]
        else blk: {
            const owned = widget.editor.getLineAlloc(line_idx) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| widget.editor.allocator.free(owned);
        const line_start = widget.editor.lineStart(line_idx);
        const line_end = line_start + line_len;

        var cluster_slice: ?[]const u32 = null;
        var cluster_owned = false;
        widget.clusterOffsets(shell, line_idx, line_text, &cluster_slice, &cluster_owned);
        defer if (cluster_owned) {
            if (cluster_slice) |clusters| widget.editor.allocator.free(clusters);
        };

        var tokens: []HighlightToken = &[_]HighlightToken{};
        if (highlight_tokens_allocated) {
            while (token_idx < highlight_tokens.len and highlight_tokens[token_idx].end <= line_start) {
                token_idx += 1;
            }
            var line_token_end = token_idx;
            while (line_token_end < highlight_tokens.len and highlight_tokens[line_token_end].start < line_end) {
                line_token_end += 1;
            }
            tokens = highlight_tokens[token_idx..line_token_end];
        }
        var fallback_tokens_buf: [32]HighlightToken = undefined;
        var effective_tokens = tokens;
        if (tokens.len == 0 and shouldUseLargeFileFallback(widget.editor)) {
            const fallback_count = buildLargeFileFallbackTokens(line_text, line_start, &fallback_tokens_buf);
            effective_tokens = fallback_tokens_buf[0..fallback_count];
        }

        var ranges: [8]SelectionRange = undefined;
        var range_count: usize = 0;
        selection_mod.collectSelectionRanges(widget.editor, line_idx, line_text, cluster_slice, &ranges, &range_count);

        const width_cached = widget.editor.lineWidthCached(line_idx, line_text, cluster_slice);
        const line_width = metrics_mod.lineWidthForDisplay(line_len, width_cached, range_count > 0);
        if (line_width > max_visible_width) {
            max_visible_width = line_width;
        }
        const total_visual_lines = if (widget.wrap_enabled)
            layout_mod.visualLineCountForWidth(cols, line_width)
        else
            1;
        const seg_start_idx = if (widget.wrap_enabled and line_idx == start_line) @min(start_seg, total_visual_lines) else 0;

        var cursor_col_vis: usize = 0;
        var cursor_seg: usize = 0;
        if (is_current) {
            cursor_col_vis = selection_mod.visualColumnForByteIndex(line_text, widget.editor.cursor.col, cluster_slice);
            if (cols > 0 and widget.wrap_enabled) {
                cursor_seg = @min(cursor_col_vis / cols, if (total_visual_lines > 0) total_visual_lines - 1 else 0);
            }
        }

        var seg: usize = seg_start_idx;
        while (seg < total_visual_lines and visual_row < visible_lines) : (seg += 1) {
            const seg_start_col = if (widget.wrap_enabled) seg * cols else widget.editor.scroll_col;
            const seg_end_col = if (widget.wrap_enabled) @min(line_width, seg_start_col + cols) else @min(line_width, seg_start_col + cols);
            // Keep processing empty segments so cached selection overlays are
            // always cleared correctly after deselect/collapse.
            const seg_y = y + @as(f32, @floatFromInt(visual_row)) * r.char_height;
            const seg_band = rowBandForRow(y, visual_row, r.char_height);
            const seg_start_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_start_col, cluster_slice);
            const seg_end_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_end_col, cluster_slice);
            const disable_programming_ligatures = switch (r.editor_disable_ligatures) {
                .never => false,
                .always => true,
                .cursor => is_current and seg == cursor_seg,
            };

            if (seg == seg_start_idx) {
                r.drawEditorLineBase(line_idx, seg_y, x, widget.gutter_width, width, is_current);
            } else if (is_current) {
                r.drawRect(
                    @intFromFloat(x),
                    seg_band.y_i,
                    @intFromFloat(widget.gutter_width),
                    seg_band.h_i,
                    r.theme.current_line,
                );
                r.drawRect(
                    @intFromFloat(x + widget.gutter_width),
                    seg_band.y_i,
                    @intFromFloat(width - widget.gutter_width),
                    seg_band.h_i,
                    r.theme.current_line,
                );
            }

            if (range_count > 0) {
                const sel_band = selectionBandForRowBand(seg_band);
                var r_i: usize = 0;
                while (r_i < range_count) : (r_i += 1) {
                    const range = ranges[r_i];
                    const sel_start = @max(range.start_col, seg_start_col);
                    const sel_end = @min(range.end_col, seg_end_col);
                    if (sel_end <= sel_start) continue;
                    const sel_x = text_start_x + @as(f32, @floatFromInt(sel_start - seg_start_col)) * r.char_width;
                    const sel_w = @as(f32, @floatFromInt(sel_end - sel_start)) * r.char_width;
                    r.drawRect(
                        @intFromFloat(sel_x),
                        sel_band.y_i,
                        @intFromFloat(sel_w),
                        sel_band.h_i,
                        r.theme.selection,
                    );
                }
            }

            var search_ranges: [16]ByteRange = undefined;
            const search_count = collectSearchByteRanges(
                line_start + seg_start_byte,
                line_start + seg_end_byte,
                widget.editor.searchMatches(),
                &search_ranges,
            );
            if (search_count > 0) {
                const search_color = searchHighlightColor(r.theme);
                const active_search = searchActiveByteRange(widget.editor);
                const search_band = selectionBandForRowBand(seg_band);
                for (search_ranges[0..search_count]) |match| {
                    const local_start = match.start - line_start;
                    const local_end = match.end - line_start;
                    const sx = xForByteOffset(r, line_text, seg_start_byte, seg_start_col, local_start, text_start_x);
                    const ex = xForByteOffset(r, line_text, seg_start_byte, seg_start_col, local_end, text_start_x);
                    if (ex <= sx) continue;
                    const draw_color = if (active_search) |active| if (rangeContains(active, match)) activeSearchHighlightColor(r.theme) else search_color else search_color;
                    r.drawRect(
                        @intFromFloat(sx),
                        search_band.y_i,
                        @intFromFloat(ex - sx),
                        search_band.h_i,
                        draw_color,
                    );
                }
            }

            const base_bg = if (is_current) r.theme.current_line else r.theme.background;
            var sel_bytes: [8]ByteRange = undefined;
            const sel_count = if (range_count > 0)
                buildSelectionByteRanges(
                    line_text,
                    cluster_slice,
                    seg_start_col,
                    seg_end_col,
                    seg_start_byte,
                    seg_end_byte,
                    ranges[0..range_count],
                    &sel_bytes,
                )
            else
                0;

            if (effective_tokens.len == 0) {
                drawTextSliceWithSelectionBg(
                    r,
                    text_start_x,
                    seg_y,
                    line_text,
                    seg_start_byte,
                    seg_start_col,
                    seg_start_byte,
                    seg_end_byte,
                    r.theme.foreground,
                    base_bg,
                    r.theme.selection,
                    sel_bytes[0..sel_count],
                    disable_programming_ligatures,
                );
            } else {
                drawHighlightedLineSegment(
                    r,
                    line_text,
                    seg_y,
                    text_start_x,
                    line_start,
                    seg_start_byte,
                    seg_end_byte,
                    seg_start_col,
                    effective_tokens,
                    base_bg,
                    r.theme.selection,
                    sel_bytes[0..sel_count],
                    disable_programming_ligatures,
                );
            }

            if (is_current and seg == cursor_seg) {
                const local_col = cursor_col_vis - seg_start_col;
                cursor_draw_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r.char_width;
                cursor_draw_y = seg_y;
            }
            drawExtraCarets(widget, r, line_idx, line_text, cluster_slice, seg_start_col, seg_end_col, line_width, seg_y, text_start_x);
            visual_row += 1;
        }
    }

    // Draw cursor
    if (cursor_draw_x != null and cursor_draw_y != null) {
        r.drawCursor(cursor_draw_x.?, cursor_draw_y.?, .line);
        if (input.composing_active and input.composing_text.len > 0) {
            const comp_x = cursor_draw_x.?;
            const comp_y = cursor_draw_y.?;
            r.drawTextMonospaceOnBg(input.composing_text, comp_x, comp_y, r.theme.foreground, r.theme.current_line);
            r.drawRect(
                @intFromFloat(comp_x),
                @intFromFloat(comp_y + r.char_height - 2),
                @intFromFloat(@as(f32, @floatFromInt(input.composing_text.len)) * r.char_width),
                2,
                r.theme.selection,
            );
            shell.setTextInputRect(
                @intFromFloat(comp_x),
                @intFromFloat(comp_y),
                @intFromFloat(@as(f32, @floatFromInt(@max(@as(usize, 1), input.composing_text.len))) * r.char_width),
                @intFromFloat(r.char_height),
            );
        } else {
            shell.setTextInputRect(
                @intFromFloat(cursor_draw_x.?),
                @intFromFloat(cursor_draw_y.?),
                @intFromFloat(r.char_width),
                @intFromFloat(r.char_height),
            );
        }
    }

    if (!widget.wrap_enabled) {
        const vscroll_w: f32 = if (show_vscroll) 12 else 0;
        const max_line_width = widget.editor.maxLineWidthCached();
        if (max_line_width > cols) {
            draw_list.clear();
            drawHorizontalScrollbar(widget, r, x, y, width, height, max_line_width, cols, vscroll_w, &draw_list);
            flushDrawList(&draw_list, r);
        }
        if (show_vscroll) {
            draw_list.clear();
            drawVerticalScrollbar(widget, r, x, y, width, height, visible_lines, total_lines, &draw_list);
            flushDrawList(&draw_list, r);
        }
    }
}

pub fn drawCached(
    widget: anytype,
    shell: anytype,
    cache: *cache_mod.EditorRenderCache,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    frame_id: u64,
    input: anytype,
) void {
    _ = input;
    const r = shell.rendererPtr();
    widget.gutter_width = 50 * r.uiScaleFactor();
    if (width <= 0 or height <= 0) return;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    const start_line = widget.editor.scroll_line;
    const start_seg = widget.editor.scroll_row_offset;
    const total_lines = widget.editor.lineCount();
    const cols = widget.viewportColumns(shell);
    if (cols == 0) return;
    const show_vscroll = !widget.wrap_enabled and total_lines > visible_lines;

    const draw_x = x;
    const draw_y = y;
    const origin_x: f32 = 0;
    const origin_y: f32 = 0;
    var draw_list = &cache.draw_list;

    const texture_changed = r.ensureEditorTexture(@intFromFloat(width), @intFromFloat(height));
    var force_redraw = cache.beginFrame(
        frame_id,
        cols,
        widget.wrap_enabled,
        @intFromFloat(width),
        @intFromFloat(height),
        widget.editor.change_tick,
        widget.editor.highlight_epoch,
        widget.editor.scroll_line,
        widget.editor.scroll_row_offset,
        widget.editor.scroll_col,
        selectionStateHash(widget.editor),
    );
    if (texture_changed) force_redraw = true;

    var any_dirty = force_redraw;

    if (force_redraw) {
        if (r.beginEditorTexture()) {
            r.drawRect(0, 0, @intFromFloat(width), @intFromFloat(height), r.theme.background);
            r.drawRect(0, 0, @intFromFloat(widget.gutter_width), @intFromFloat(height), r.theme.line_number_bg);
            r.endEditorTexture();
        }
    }

    var line_buf: [4096]u8 = undefined;
    var line_idx = start_line;
    var visual_row: usize = 0;
    while (line_idx < total_lines and visual_row < visible_lines) : (line_idx += 1) {
        const is_current = line_idx == widget.editor.cursor.line;

        const line_len = widget.editor.lineLen(line_idx);
        var line_alloc: ?[]u8 = null;
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..widget.editor.getLine(line_idx, &line_buf)]
        else blk: {
            const owned = widget.editor.getLineAlloc(line_idx) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| widget.editor.allocator.free(owned);
        const line_start = widget.editor.lineStart(line_idx);
        const line_text_hash = hashLine(line_text);

        var cluster_slice: ?[]const u32 = null;
        var cluster_owned = false;
        widget.clusterOffsets(shell, line_idx, line_text, &cluster_slice, &cluster_owned);
        defer if (cluster_owned) {
            if (cluster_slice) |clusters| widget.editor.allocator.free(clusters);
        };

        const line_end = line_start + line_len;
        const tokens = cache.highlightTokens(
            widget.editor.highlighter,
            line_idx,
            line_start,
            line_end,
            line_text_hash,
            widget.editor.highlight_epoch,
        );
        var fallback_tokens_buf: [32]HighlightToken = undefined;
        var effective_tokens = tokens;
        if (tokens.len == 0 and shouldUseLargeFileFallback(widget.editor)) {
            const fallback_count = buildLargeFileFallbackTokens(line_text, line_start, &fallback_tokens_buf);
            effective_tokens = fallback_tokens_buf[0..fallback_count];
        }

        var ranges: [8]SelectionRange = undefined;
        var range_count: usize = 0;
        selection_mod.collectSelectionRanges(widget.editor, line_idx, line_text, cluster_slice, &ranges, &range_count);

        const width_cached = widget.editor.lineWidthCached(line_idx, line_text, cluster_slice);
        const line_width = metrics_mod.lineWidthForDisplay(line_len, width_cached, range_count > 0);
        const total_visual_lines = if (widget.wrap_enabled)
            cache.wrapLineCount(line_idx, cols, line_width) orelse layout_mod.visualLineCountForWidth(cols, line_width)
        else
            1;

        const seg_start_idx = if (widget.wrap_enabled and line_idx == start_line) @min(start_seg, total_visual_lines) else 0;

        var cursor_col_vis: usize = 0;
        var cursor_seg: usize = 0;
        if (is_current) {
            cursor_col_vis = selection_mod.visualColumnForByteIndex(line_text, widget.editor.cursor.col, cluster_slice);
            if (cols > 0 and widget.wrap_enabled) {
                cursor_seg = @min(cursor_col_vis / cols, if (total_visual_lines > 0) total_visual_lines - 1 else 0);
            }
        }

        var seg: usize = seg_start_idx;
        while (seg < total_visual_lines and visual_row < visible_lines) : (seg += 1) {
            const seg_start_col = if (widget.wrap_enabled) seg * cols else widget.editor.scroll_col;
            const seg_end_col = if (widget.wrap_enabled) @min(line_width, seg_start_col + cols) else @min(line_width, seg_start_col + cols);
            // Keep processing empty segments so cached selection overlays are
            // always cleared correctly after deselect/collapse.
            const seg_y = origin_y + @as(f32, @floatFromInt(visual_row)) * r.char_height;
            const seg_band = rowBandForRow(origin_y, visual_row, r.char_height);
            const seg_start_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_start_col, cluster_slice);
            const seg_end_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_end_col, cluster_slice);
            const disable_programming_ligatures = switch (r.editor_disable_ligatures) {
                .never => false,
                .always => true,
                .cursor => is_current and seg == cursor_seg,
            };

            const seg_hash = hashSegment(
                line_text,
                seg_start_byte,
                seg_end_byte,
                ranges[0..range_count],
                seg_start_col,
                seg_end_col,
                effective_tokens,
                line_start,
                is_current,
                seg == cursor_seg,
                cursor_col_vis,
                seg_start_col,
            );
            const dirty = cache.segmentDirty(.{ .line_idx = line_idx, .seg_idx = seg }, seg_hash);
            if (force_redraw or dirty) {
                any_dirty = true;
                if (r.beginEditorTexture()) {
                    const clip_h = @min(seg_band.h_i + 1, @as(i32, @intFromFloat(height)) - seg_band.y_i);
                    r.beginClip(
                        @intFromFloat(origin_x),
                        seg_band.y_i,
                        @intFromFloat(width),
                        @max(1, clip_h),
                    );
                    draw_list.clear();
                    var list_ok = true;
                    list_ok = list_ok and addRectOp(draw_list, origin_x, seg_band.y_f, width, seg_band.h_f, r.theme.background);
                    list_ok = list_ok and addRectOp(draw_list, origin_x, seg_band.y_f, widget.gutter_width, seg_band.h_f, r.theme.line_number_bg);

                    if (seg == seg_start_idx) {
                        var num_buf: [16]u8 = undefined;
                        list_ok = list_ok and addEditorLineBaseOps(
                            draw_list,
                            r,
                            line_idx,
                            seg_y,
                            origin_x,
                            widget.gutter_width,
                            width,
                            is_current,
                            &num_buf,
                        );
                    } else if (is_current) {
                        list_ok = list_ok and addRectOp(draw_list, origin_x, seg_band.y_f, widget.gutter_width, seg_band.h_f, r.theme.current_line);
                        list_ok = list_ok and addRectOp(draw_list, origin_x + widget.gutter_width, seg_band.y_f, width - widget.gutter_width, seg_band.h_f, r.theme.current_line);
                    }

                    if (range_count > 0) {
                        const sel_band = selectionBandForRowBand(seg_band);
                        var r_i: usize = 0;
                        while (r_i < range_count) : (r_i += 1) {
                            const range = ranges[r_i];
                            const sel_start = @max(range.start_col, seg_start_col);
                            const sel_end = @min(range.end_col, seg_end_col);
                            if (sel_end <= sel_start) continue;
                            const sel_x = origin_x + widget.gutter_width + 8 * r.uiScaleFactor() + @as(f32, @floatFromInt(sel_start - seg_start_col)) * r.char_width;
                            const sel_w = @as(f32, @floatFromInt(sel_end - sel_start)) * r.char_width;
                            list_ok = list_ok and addRectOp(draw_list, sel_x, sel_band.y_f, sel_w, sel_band.h_f, r.theme.selection);
                        }
                    }

                    var search_ranges: [16]ByteRange = undefined;
                    const search_count = collectSearchByteRanges(
                        line_start + seg_start_byte,
                        line_start + seg_end_byte,
                        widget.editor.searchMatches(),
                        &search_ranges,
                    );
                    if (search_count > 0) {
                        const search_color = searchHighlightColor(r.theme);
                        const active_search = searchActiveByteRange(widget.editor);
                        const search_band = selectionBandForRowBand(seg_band);
                        for (search_ranges[0..search_count]) |match| {
                            const local_start = match.start - line_start;
                            const local_end = match.end - line_start;
                            const sx = xForByteOffset(r, line_text, seg_start_byte, seg_start_col, local_start, origin_x + widget.gutter_width + 8 * r.uiScaleFactor());
                            const ex = xForByteOffset(r, line_text, seg_start_byte, seg_start_col, local_end, origin_x + widget.gutter_width + 8 * r.uiScaleFactor());
                            if (ex <= sx) continue;
                            const draw_color = if (active_search) |active| if (rangeContains(active, match)) activeSearchHighlightColor(r.theme) else search_color else search_color;
                            list_ok = list_ok and addRectOp(draw_list, sx, search_band.y_f, ex - sx, search_band.h_f, draw_color);
                        }
                    }

                    const base_bg = if (is_current) r.theme.current_line else r.theme.background;
                    var sel_bytes: [8]ByteRange = undefined;
                    const sel_count = if (range_count > 0)
                        buildSelectionByteRanges(
                            line_text,
                            cluster_slice,
                            seg_start_col,
                            seg_end_col,
                            seg_start_byte,
                            seg_end_byte,
                            ranges[0..range_count],
                            &sel_bytes,
                        )
                    else
                        0;

                    const text_start_x = origin_x + widget.gutter_width + 8 * r.uiScaleFactor();
                    if (effective_tokens.len == 0) {
                        list_ok = list_ok and addTextSliceOpsWithSelectionBg(
                            draw_list,
                            r,
                            text_start_x,
                            seg_y,
                            line_text,
                            seg_start_byte,
                            seg_start_col,
                            seg_start_byte,
                            seg_end_byte,
                            r.theme.foreground,
                            base_bg,
                            r.theme.selection,
                            sel_bytes[0..sel_count],
                            disable_programming_ligatures,
                        );
                    } else {
                        list_ok = list_ok and appendHighlightedLineSegmentOps(
                            draw_list,
                            r,
                            line_text,
                            seg_y,
                            text_start_x,
                            line_start,
                            seg_start_byte,
                            seg_end_byte,
                            seg_start_col,
                            effective_tokens,
                            base_bg,
                            r.theme.selection,
                            seg_start_byte,
                            sel_bytes[0..sel_count],
                            disable_programming_ligatures,
                        );
                    }

                    if (is_current and seg == cursor_seg) {
                        const local_col = cursor_col_vis - seg_start_col;
                        const cursor_draw_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r.char_width;
                        list_ok = list_ok and addCursorOp(draw_list, cursor_draw_x, seg_y, r.char_height, r.theme.cursor);
                    }
                    list_ok = list_ok and addExtraCaretOps(
                        draw_list,
                        widget,
                        r,
                        line_idx,
                        line_text,
                        cluster_slice,
                        seg_start_col,
                        seg_end_col,
                        line_width,
                        seg_y,
                        text_start_x,
                    );

                    if (list_ok) {
                        flushDrawList(draw_list, r);
                    } else {
                        r.drawRect(
                            @intFromFloat(origin_x),
                            seg_band.y_i,
                            @intFromFloat(width),
                            seg_band.h_i,
                            r.theme.background,
                        );
                        r.drawRect(
                            @intFromFloat(origin_x),
                            seg_band.y_i,
                            @intFromFloat(widget.gutter_width),
                            seg_band.h_i,
                            r.theme.line_number_bg,
                        );

                        if (seg == seg_start_idx) {
                            r.drawEditorLineBase(line_idx, seg_y, origin_x, widget.gutter_width, width, is_current);
                        } else if (is_current) {
                            r.drawRect(
                                @intFromFloat(origin_x),
                                seg_band.y_i,
                                @intFromFloat(widget.gutter_width),
                                seg_band.h_i,
                                r.theme.current_line,
                            );
                            r.drawRect(
                                @intFromFloat(origin_x + widget.gutter_width),
                                seg_band.y_i,
                                @intFromFloat(width - widget.gutter_width),
                                seg_band.h_i,
                                r.theme.current_line,
                            );
                        }

                        if (range_count > 0) {
                            const sel_band = selectionBandForRowBand(seg_band);
                            var r_i: usize = 0;
                            while (r_i < range_count) : (r_i += 1) {
                                const range = ranges[r_i];
                                const sel_start = @max(range.start_col, seg_start_col);
                                const sel_end = @min(range.end_col, seg_end_col);
                                if (sel_end <= sel_start) continue;
                                const sel_x = origin_x + widget.gutter_width + 8 * r.uiScaleFactor() + @as(f32, @floatFromInt(sel_start - seg_start_col)) * r.char_width;
                                const sel_w = @as(f32, @floatFromInt(sel_end - sel_start)) * r.char_width;
                                r.drawRect(
                                    @intFromFloat(sel_x),
                                    sel_band.y_i,
                                    @intFromFloat(sel_w),
                                    sel_band.h_i,
                                    r.theme.selection,
                                );
                            }
                        }

                        if (effective_tokens.len == 0) {
                            const seg_base_bg = base_bg;
                            if (sel_count == 0) {
                                r.drawTextMonospaceOnBgPolicy(line_text[seg_start_byte..seg_end_byte], text_start_x, seg_y, r.theme.foreground, seg_base_bg, disable_programming_ligatures);
                            } else {
                                // Draw unselected/selected parts separately for correct correction.
                                var cursor_b: usize = seg_start_byte;
                                for (sel_bytes[0..sel_count]) |sr| {
                                    if (sr.start > cursor_b) {
                                        const x0 = xForByteOffset(r, line_text, seg_start_byte, seg_start_col, cursor_b, text_start_x);
                                        r.drawTextMonospaceOnBgPolicy(line_text[cursor_b..sr.start], x0, seg_y, r.theme.foreground, seg_base_bg, disable_programming_ligatures);
                                    }
                                    const x1 = xForByteOffset(r, line_text, seg_start_byte, seg_start_col, sr.start, text_start_x);
                                    r.drawTextMonospaceOnBgPolicy(line_text[sr.start..sr.end], x1, seg_y, r.theme.foreground, r.theme.selection, disable_programming_ligatures);
                                    cursor_b = sr.end;
                                }
                                if (cursor_b < seg_end_byte) {
                                    const x2 = xForByteOffset(r, line_text, seg_start_byte, seg_start_col, cursor_b, text_start_x);
                                    r.drawTextMonospaceOnBgPolicy(line_text[cursor_b..seg_end_byte], x2, seg_y, r.theme.foreground, seg_base_bg, disable_programming_ligatures);
                                }
                            }
                        } else {
                            drawHighlightedLineSegment(
                                r,
                                line_text,
                                seg_y,
                                text_start_x,
                                line_start,
                                seg_start_byte,
                                seg_end_byte,
                                seg_start_col,
                                effective_tokens,
                                base_bg,
                                r.theme.selection,
                                sel_bytes[0..sel_count],
                                disable_programming_ligatures,
                            );
                        }

                        if (is_current and seg == cursor_seg) {
                            const local_col = cursor_col_vis - seg_start_col;
                            const cursor_draw_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r.char_width;
                            r.drawCursor(cursor_draw_x, seg_y, .line);
                        }
                        drawExtraCarets(widget, r, line_idx, line_text, cluster_slice, seg_start_col, seg_end_col, line_width, seg_y, text_start_x);
                    }

                    r.endClip();
                    r.endEditorTexture();
                }
            }
            visual_row += 1;
        }
    }

    if (!widget.wrap_enabled) {
        const vscroll_w: f32 = if (show_vscroll) 12 else 0;
        const max_line_width = widget.editor.maxLineWidthCached();
        const scroll_hash = hashScrollState(max_line_width, cols, widget.editor.scroll_col, visible_lines, total_lines, widget.editor.scroll_line, show_vscroll);
        if (force_redraw or cache.scrollDirty(scroll_hash)) {
            any_dirty = true;
            if (r.beginEditorTexture()) {
                if (max_line_width > cols) {
                    draw_list.clear();
                    drawHorizontalScrollbar(widget, r, origin_x, origin_y, width, height, max_line_width, cols, vscroll_w, draw_list);
                    flushDrawList(draw_list, r);
                }
                if (show_vscroll) {
                    draw_list.clear();
                    drawVerticalScrollbar(widget, r, origin_x, origin_y, width, height, visible_lines, total_lines, draw_list);
                    flushDrawList(draw_list, r);
                }
                r.endEditorTexture();
            }
        }
    }

    if (any_dirty or force_redraw) {
        r.drawEditorTexture(draw_x, draw_y);
    } else {
        r.drawEditorTexture(draw_x, draw_y);
    }
}

pub fn hashLine(text: []const u8) u64 {
    var h: u64 = 1469598103934665603;
    for (text) |byte| {
        h ^= byte;
        h *%= 1099511628211;
    }
    return h;
}

fn shouldUseLargeFileFallback(editor: anytype) bool {
    if (editor.highlighter != null) return false;
    if (editor.totalLen() < large_file_fallback_threshold_bytes) return false;
    return true;
}

fn isIdentStart(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == '_';
}

fn isIdentContinue(ch: u8) bool {
    return isIdentStart(ch) or (ch >= '0' and ch <= '9');
}

fn isDigit(ch: u8) bool {
    return ch >= '0' and ch <= '9';
}

fn buildLargeFileFallbackTokens(line_text: []const u8, line_start: usize, out: []HighlightToken) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < line_text.len and count < out.len) {
        const ch = line_text[i];
        if ((ch == '/' and i + 1 < line_text.len and line_text[i + 1] == '/') or ch == '#') {
            out[count] = .{
                .start = line_start + i,
                .end = line_start + line_text.len,
                .kind = .comment,
                .priority = 0,
                .conceal = null,
                .url = null,
                .conceal_lines = false,
            };
            count += 1;
            break;
        }
        if (ch == '"') {
            var j = i + 1;
            while (j < line_text.len) : (j += 1) {
                if (line_text[j] == '"' and line_text[j - 1] != '\\') {
                    j += 1;
                    break;
                }
            }
            out[count] = .{
                .start = line_start + i,
                .end = line_start + @min(j, line_text.len),
                .kind = .string,
                .priority = 0,
                .conceal = null,
                .url = null,
                .conceal_lines = false,
            };
            count += 1;
            i = @min(j, line_text.len);
            continue;
        }
        if (isDigit(ch)) {
            var j = i + 1;
            while (j < line_text.len and (isDigit(line_text[j]) or line_text[j] == '_')) : (j += 1) {}
            out[count] = .{
                .start = line_start + i,
                .end = line_start + j,
                .kind = .number,
                .priority = 0,
                .conceal = null,
                .url = null,
                .conceal_lines = false,
            };
            count += 1;
            i = j;
            continue;
        }
        if (isIdentStart(ch)) {
            var j = i + 1;
            while (j < line_text.len and isIdentContinue(line_text[j])) : (j += 1) {}
            i = j;
            continue;
        }
        i += 1;
    }
    return count;
}

pub fn precomputeHighlightTokens(
    widget: anytype,
    cache: *cache_mod.EditorRenderCache,
    shell: anytype,
    height: f32,
    budget_lines: usize,
) void {
    const r = shell.rendererPtr();
    if (budget_lines == 0) return;
    if (height <= 0) return;
    if (widget.editor.highlighter == null) return;
    const total_lines = widget.editor.lineCount();
    if (total_lines == 0) return;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    if (visible_lines == 0) return;

    const start_line = widget.editor.scroll_line;
    const end_line = @min(start_line + visible_lines + 1, total_lines);
    cache.beginHighlightWork(start_line, end_line, widget.editor.highlight_epoch);

    var line_buf: [4096]u8 = undefined;
    var remaining = budget_lines;
    while (remaining > 0) : (remaining -= 1) {
        const next_line = cache.nextHighlightWorkLine() orelse break;
        const line_len = widget.editor.lineLen(next_line);
        var line_alloc: ?[]u8 = null;
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..widget.editor.getLine(next_line, &line_buf)]
        else blk: {
            const owned = widget.editor.getLineAlloc(next_line) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| widget.editor.allocator.free(owned);

        const line_start = widget.editor.lineStart(next_line);
        const line_end = line_start + line_len;
        const line_text_hash = hashLine(line_text);
        _ = cache.highlightTokens(
            widget.editor.highlighter,
            next_line,
            line_start,
            line_end,
            line_text_hash,
            widget.editor.highlight_epoch,
        );
    }
}

pub fn precomputeLineWidths(
    widget: anytype,
    cache: *cache_mod.EditorRenderCache,
    shell: anytype,
    height: f32,
    budget_lines: usize,
) void {
    const r = shell.rendererPtr();
    if (budget_lines == 0) return;
    if (height <= 0) return;
    const total_lines = widget.editor.lineCount();
    if (total_lines == 0) return;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    if (visible_lines == 0) return;

    const start_line = widget.editor.scroll_line;
    const end_line = @min(start_line + visible_lines + 1, total_lines);
    cache.beginLineWidthWork(start_line, end_line, widget.editor.change_tick);

    var line_buf: [4096]u8 = undefined;
    var remaining = budget_lines;
    while (remaining > 0) : (remaining -= 1) {
        const next_line = cache.nextLineWidthWorkLine() orelse break;
        const line_len = widget.editor.lineLen(next_line);
        var line_alloc: ?[]u8 = null;
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..widget.editor.getLine(next_line, &line_buf)]
        else blk: {
            const owned = widget.editor.getLineAlloc(next_line) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| widget.editor.allocator.free(owned);

        var cluster_slice: ?[]const u32 = null;
        var cluster_owned = false;
        widget.clusterOffsets(shell, next_line, line_text, &cluster_slice, &cluster_owned);
        defer if (cluster_owned) {
            if (cluster_slice) |clusters| widget.editor.allocator.free(clusters);
        };

        _ = widget.editor.lineWidthCached(next_line, line_text, cluster_slice);
    }
}

pub fn precomputeWrapCounts(
    widget: anytype,
    cache: *cache_mod.EditorRenderCache,
    shell: anytype,
    height: f32,
    budget_lines: usize,
) void {
    const r = shell.rendererPtr();
    if (!widget.wrap_enabled) return;
    if (budget_lines == 0) return;
    if (height <= 0) return;
    const total_lines = widget.editor.lineCount();
    if (total_lines == 0) return;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    if (visible_lines == 0) return;

    const cols = widget.viewportColumns(shell);
    if (cols == 0) return;
    const start_line = widget.editor.scroll_line;
    const end_line = @min(start_line + visible_lines + 1, total_lines);
    cache.beginWrapWork(start_line, end_line, cols, widget.editor.change_tick);

    var line_buf: [4096]u8 = undefined;
    var remaining = budget_lines;
    while (remaining > 0) : (remaining -= 1) {
        const next_line = cache.nextWrapWorkLine() orelse break;
        const line_len = widget.editor.lineLen(next_line);
        var line_alloc: ?[]u8 = null;
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..widget.editor.getLine(next_line, &line_buf)]
        else blk: {
            const owned = widget.editor.getLineAlloc(next_line) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| widget.editor.allocator.free(owned);

        var cluster_slice: ?[]const u32 = null;
        var cluster_owned = false;
        widget.clusterOffsets(shell, next_line, line_text, &cluster_slice, &cluster_owned);
        defer if (cluster_owned) {
            if (cluster_slice) |clusters| widget.editor.allocator.free(clusters);
        };

        const width_cached = widget.editor.lineWidthCached(next_line, line_text, cluster_slice);
        const line_width = metrics_mod.lineWidthForDisplay(line_len, width_cached, false);
        const count = layout_mod.visualLineCountForWidth(cols, line_width);
        cache.setWrapLineCount(next_line, cols, line_width, count);
    }
}

fn hashSegment(
    line_text: []const u8,
    seg_start_byte: usize,
    seg_end_byte: usize,
    ranges: []const SelectionRange,
    seg_start_col: usize,
    seg_end_col: usize,
    tokens: []const HighlightToken,
    line_start: usize,
    is_current: bool,
    has_cursor: bool,
    cursor_col_vis: usize,
    cursor_seg_start: usize,
) u64 {
    var h: u64 = 1469598103934665603;
    for (line_text[seg_start_byte..seg_end_byte]) |byte| {
        h ^= byte;
        h *%= 1099511628211;
    }
    h ^= @as(u64, @intFromBool(is_current));
    h *%= 1099511628211;
    for (ranges) |range| {
        const sel_start = @max(range.start_col, seg_start_col);
        const sel_end = @min(range.end_col, seg_end_col);
        if (sel_end <= sel_start) continue;
        h ^= @as(u64, sel_start);
        h *%= 1099511628211;
        h ^= @as(u64, sel_end);
        h *%= 1099511628211;
    }
    for (tokens) |token| {
        if (token.end <= line_start) continue;
        const rel_start = if (token.start > line_start) token.start - line_start else 0;
        const t_start = @max(rel_start, seg_start_byte);
        const rel_end = if (token.end > line_start) token.end - line_start else 0;
        const t_end = @min(rel_end, seg_end_byte);
        if (t_end <= t_start) continue;
        h ^= @as(u64, t_start);
        h *%= 1099511628211;
        h ^= @as(u64, t_end);
        h *%= 1099511628211;
        h ^= @as(u64, @intFromEnum(token.kind));
        h *%= 1099511628211;
    }
    if (has_cursor) {
        h ^= 0x9e3779b97f4a7c15;
        h *%= 1099511628211;
        h ^= @as(u64, cursor_col_vis -| cursor_seg_start);
        h *%= 1099511628211;
    }
    return h;
}

fn hashScrollState(
    max_visible_width: usize,
    cols: usize,
    scroll_col: usize,
    visible_lines: usize,
    total_lines: usize,
    scroll_line: usize,
    show_vscroll: bool,
) u64 {
    var h: u64 = 1469598103934665603;
    h ^= @as(u64, max_visible_width);
    h *%= 1099511628211;
    h ^= @as(u64, cols);
    h *%= 1099511628211;
    h ^= @as(u64, scroll_col);
    h *%= 1099511628211;
    h ^= @as(u64, visible_lines);
    h *%= 1099511628211;
    h ^= @as(u64, total_lines);
    h *%= 1099511628211;
    h ^= @as(u64, scroll_line);
    h *%= 1099511628211;
    h ^= @as(u64, @intFromBool(show_vscroll));
    h *%= 1099511628211;
    return h;
}

fn drawHorizontalScrollbar(
    widget: anytype,
    r: anytype,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    max_visible_width: usize,
    cols: usize,
    vscroll_w: f32,
    list: ?*EditorDrawList,
) void {
    if (width <= 0 or height <= 0 or cols == 0) return;
    if (max_visible_width <= cols) return;
    const scale = r.uiScaleFactor();
    const track_h: f32 = 16 * scale;
    const track_y = y + height - track_h;
    const track_x = x + widget.gutter_width;
    const track_w = @max(@as(f32, 1), width - widget.gutter_width - vscroll_w);
    const max_scroll = max_visible_width - cols;
    if (widget.editor.scroll_col > max_scroll) {
        widget.editor.scroll_col = max_scroll;
    }

    const min_thumb_w: f32 = 32 * scale;
    const thumb_w = @max(min_thumb_w, track_w * (@as(f32, @floatFromInt(cols)) / @as(f32, @floatFromInt(max_visible_width))));
    const available = @max(@as(f32, 1), track_w - thumb_w);
    const ratio = if (max_scroll > 0)
        @as(f32, @floatFromInt(widget.editor.scroll_col)) / @as(f32, @floatFromInt(max_scroll))
    else
        0.0;
    const thumb_x = track_x + available * ratio;

    if (list) |ops| {
        _ = addRectOp(ops, track_x, track_y, track_w, track_h, r.theme.line_number_bg);
    } else {
        r.drawRect(
            @intFromFloat(track_x),
            @intFromFloat(track_y),
            @intFromFloat(track_w),
            @intFromFloat(track_h),
            r.theme.line_number_bg,
        );
    }
    const inset: f32 = @max(1, 2 * scale);
    if (list) |ops| {
        _ = addRectOp(ops, thumb_x, track_y + inset, thumb_w, track_h - inset * 2, r.theme.selection);
    } else {
        r.drawRect(
            @intFromFloat(thumb_x),
            @intFromFloat(track_y + inset),
            @intFromFloat(thumb_w),
            @intFromFloat(track_h - inset * 2),
            r.theme.selection,
        );
    }
}

fn drawVerticalScrollbar(
    widget: anytype,
    r: anytype,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    visible_lines: usize,
    total_lines: usize,
    list: ?*EditorDrawList,
) void {
    if (total_lines <= visible_lines or width <= 0 or height <= 0) return;
    const scale = r.uiScaleFactor();
    const scrollbar_w: f32 = 16 * scale;
    const scrollbar_x = x + width - scrollbar_w;
    const scrollbar_y = y;
    const scrollbar_h = height;
    const max_scroll = total_lines - visible_lines;
    if (widget.editor.scroll_line > max_scroll) {
        widget.editor.scroll_line = max_scroll;
    }

    const ratio = if (max_scroll > 0)
        @as(f32, @floatFromInt(widget.editor.scroll_line)) / @as(f32, @floatFromInt(max_scroll))
    else
        0.0;
    const min_thumb_h: f32 = 32 * scale;
    const thumb = common.computeScrollbarThumb(scrollbar_y, scrollbar_h, visible_lines, total_lines, min_thumb_h, ratio);

    if (list) |ops| {
        _ = addRectOp(ops, scrollbar_x, scrollbar_y, scrollbar_w, scrollbar_h, r.theme.line_number_bg);
    } else {
        r.drawRect(
            @intFromFloat(scrollbar_x),
            @intFromFloat(scrollbar_y),
            @intFromFloat(scrollbar_w),
            @intFromFloat(scrollbar_h),
            r.theme.line_number_bg,
        );
    }
    const inset: f32 = @max(1, 2 * scale);
    if (list) |ops| {
        _ = addRectOp(ops, scrollbar_x + inset, thumb.thumb_y, scrollbar_w - inset * 2, thumb.thumb_h, r.theme.selection);
    } else {
        r.drawRect(
            @intFromFloat(scrollbar_x + inset),
            @intFromFloat(thumb.thumb_y),
            @intFromFloat(scrollbar_w - inset * 2),
            @intFromFloat(thumb.thumb_h),
            r.theme.selection,
        );
    }
}

fn drawHighlightedLineSegment(
    r: anytype,
    line_text: []const u8,
    y: f32,
    text_x: f32,
    line_start: usize,
    seg_start: usize,
    seg_end: usize,
    seg_start_vis: usize,
    tokens: []HighlightToken,
    base_bg: anytype,
    selection_bg: anytype,
    sel_ranges: []const ByteRange,
    disable_programming_ligatures: bool,
) void {
    if (seg_start >= seg_end or line_text.len == 0) return;

    var cursor = seg_start;
    for (tokens) |token| {
        if (token.end <= line_start + seg_start or token.start >= line_start + seg_end) continue;
        const start = @max(token.start - line_start, seg_start);
        const end = @min(token.end - line_start, seg_end);
        if (start > cursor) {
            const slice_start = cursor;
            const slice_end = start;
            drawTextSliceWithSelectionBg(
                r,
                text_x,
                y,
                line_text,
                seg_start,
                seg_start_vis,
                slice_start,
                slice_end,
                r.theme.foreground,
                base_bg,
                selection_bg,
                sel_ranges,
                disable_programming_ligatures,
            );
        }
        const slice_start = start;
        const slice_end = end;
        const x = xForByteOffset(r, line_text, seg_start, seg_start_vis, slice_start, text_x);
        const conceal_text: ?[]const u8 = if (token.conceal != null or token.conceal_lines)
            token.conceal orelse ""
        else
            null;
        var color = colorForToken(r, token.kind);
        if (token.url != null) {
            color = r.theme.link;
        }
        if (conceal_text) |text| {
            if (text.len > 0) {
                const bg = selectionOverlapBg(slice_start, slice_end, base_bg, selection_bg, sel_ranges);
                r.drawTextMonospaceOnBgPolicy(text, x, y, color, bg, disable_programming_ligatures);
            }
        } else {
            drawTextSliceWithSelectionBg(
                r,
                text_x,
                y,
                line_text,
                seg_start,
                seg_start_vis,
                slice_start,
                slice_end,
                color,
                base_bg,
                selection_bg,
                sel_ranges,
                disable_programming_ligatures,
            );
        }
        if (end > cursor) {
            cursor = end;
        }
    }

    if (cursor < seg_end) {
        const slice_start = cursor;
        drawTextSliceWithSelectionBg(
            r,
            text_x,
            y,
            line_text,
            seg_start,
            seg_start_vis,
            slice_start,
            seg_end,
            r.theme.foreground,
            base_bg,
            selection_bg,
            sel_ranges,
            disable_programming_ligatures,
        );
    }
}

fn highlightTokenLessThan(_: void, a: HighlightToken, b: HighlightToken) bool {
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
