const std = @import("std");
const syntax_mod = @import("../../editor/syntax.zig");
const text_columns_mod = @import("../../editor/text_columns.zig");
const selection_mod = @import("../../editor/view/selection.zig");
const draw_list_mod = @import("../../editor/render/draw_list.zig");
const overlay_mod = @import("editor_widget_draw_overlay.zig");
const renderer_mod = @import("../renderer.zig");
const renderer_text_host = @import("../renderer/renderer_text_host.zig");

const HighlightToken = syntax_mod.HighlightToken;
const TokenKind = syntax_mod.TokenKind;
const SelectionRange = selection_mod.SelectionRange;
const EditorDrawList = draw_list_mod.EditorDrawList;
const ByteRange = overlay_mod.ByteRange;
const EditorTextStyleFlags = renderer_mod.EditorTextStyleFlags;
const tab_spaces = "    ";

const ImmediateTextEmitter = struct {
    renderer: *renderer_mod.Renderer,

    fn textOnBg(
        self: *@This(),
        x: f32,
        y: f32,
        text: []const u8,
        fg: renderer_mod.Color,
        bg: renderer_mod.Color,
        flags: EditorTextStyleFlags,
        disable_programming_ligatures: bool,
    ) bool {
        renderer_text_host.drawTextMonospaceOnBgStyledPolicy(self.renderer, text, x, y, fg, bg, disable_programming_ligatures, flags.italic);
        if (flags.bold) renderer_text_host.drawTextMonospaceOnBgStyledPolicy(self.renderer, text, x + 1.0, y, fg, bg, disable_programming_ligatures, flags.italic);
        return true;
    }

    fn decorationRect(
        self: *@This(),
        rx: f32,
        ry: f32,
        rw: f32,
        rh: f32,
        color: renderer_mod.Color,
    ) bool {
        overlay_mod.drawEditorSurfaceRect(self.renderer, .overlay, std.math.round(rx), std.math.round(ry), @max(1, std.math.round(rw)), @max(1, std.math.round(rh)), color);
        return true;
    }
};

const DrawListTextEmitter = struct {
    list: *EditorDrawList,

    fn textOnBg(
        self: *@This(),
        x: f32,
        y: f32,
        text: []const u8,
        fg: renderer_mod.Color,
        bg: renderer_mod.Color,
        flags: EditorTextStyleFlags,
        disable_programming_ligatures: bool,
    ) bool {
        self.list.add(.{ .text = .{
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

    fn decorationRect(
        self: *@This(),
        rx: f32,
        ry: f32,
        rw: f32,
        rh: f32,
        color: renderer_mod.Color,
    ) bool {
        return overlay_mod.addRectOp(self.list, rx, ry, rw, rh, color);
    }
};

fn visualColumnAtByteOffset(
    line_text: []const u8,
    seg_start_byte: usize,
    seg_start_vis: usize,
    byte_index: usize,
) usize {
    const target = @min(byte_index, line_text.len);
    if (target <= seg_start_byte) return seg_start_vis;

    var idx = seg_start_byte;
    var vis = seg_start_vis;
    while (idx < target) {
        const first = line_text[idx];
        if (first < 0x80) {
            vis += text_columns_mod.cellWidthForCodepoint(first, vis);
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
        const cp = std.unicode.utf8Decode(line_text[idx .. idx + seq_len]) catch 0xFFFD;
        vis += text_columns_mod.cellWidthForCodepoint(cp, vis);
        idx += seq_len;
    }
    return vis;
}

fn nextUtf8Len(text: []const u8, idx: usize) usize {
    if (idx >= text.len) return 0;
    const first = text[idx];
    if (first < 0x80) return 1;
    const seq_len = std.unicode.utf8ByteSequenceLength(first) catch return 1;
    if (idx + seq_len > text.len) return 1;
    return seq_len;
}

fn emitExpandedTextSliceOnBg(
    emitter: anytype,
    r: anytype,
    text_start_x: f32,
    y: f32,
    line_text: []const u8,
    seg_start_byte: usize,
    seg_start_vis: usize,
    slice_start: usize,
    slice_end: usize,
    fg: anytype,
    bg: anytype,
    flags: EditorTextStyleFlags,
    disable_programming_ligatures: bool,
) bool {
    var ok = true;
    const Visitor = struct {
        emitter: @TypeOf(emitter),
        y: f32,
        fg: @TypeOf(fg),
        bg: @TypeOf(bg),
        flags: EditorTextStyleFlags,
        disable_programming_ligatures: bool,
        ok: *bool,

        fn emit(self: *@This(), x: f32, text: []const u8) void {
            self.ok.* = self.ok.* and self.emitter.textOnBg(
                x,
                self.y,
                text,
                self.fg,
                self.bg,
                self.flags,
                self.disable_programming_ligatures,
            );
        }
    };
    var visitor = Visitor{
        .emitter = emitter,
        .y = y,
        .fg = fg,
        .bg = bg,
        .flags = flags,
        .disable_programming_ligatures = disable_programming_ligatures,
        .ok = &ok,
    };
    forEachExpandedTextRun(r, text_start_x, line_text, seg_start_byte, seg_start_vis, slice_start, slice_end, &visitor);
    return ok;
}

fn forEachExpandedTextRun(
    r: anytype,
    text_start_x: f32,
    line_text: []const u8,
    seg_start_byte: usize,
    seg_start_vis: usize,
    slice_start: usize,
    slice_end: usize,
    visitor: anytype,
) void {
    if (slice_end <= slice_start) return;
    if (std.mem.indexOfScalar(u8, line_text[slice_start..slice_end], '\t') == null) {
        const x = xForByteOffset(r, line_text, seg_start_byte, seg_start_vis, slice_start, text_start_x);
        visitor.emit(x, line_text[slice_start..slice_end]);
        return;
    }

    var cursor = slice_start;
    var run_start = slice_start;
    var vis = visualColumnAtByteOffset(line_text, seg_start_byte, seg_start_vis, slice_start);
    var run_x = text_start_x + @as(f32, @floatFromInt(vis - seg_start_vis)) * r.editor_char_width;
    while (cursor < slice_end) {
        if (line_text[cursor] == '\t') {
            if (cursor > run_start) {
                visitor.emit(run_x, line_text[run_start..cursor]);
            }
            const width = text_columns_mod.cellWidthForCodepoint('\t', vis);
            visitor.emit(run_x, tab_spaces[0..width]);
            vis += width;
            run_x += @as(f32, @floatFromInt(width)) * r.editor_char_width;
            cursor += 1;
            run_start = cursor;
            continue;
        }
        const seq_len = nextUtf8Len(line_text, cursor);
        const cp = std.unicode.utf8Decode(line_text[cursor .. cursor + seq_len]) catch 0xFFFD;
        vis += text_columns_mod.cellWidthForCodepoint(cp, vis);
        cursor += seq_len;
    }
    if (run_start < slice_end) {
        visitor.emit(run_x, line_text[run_start..slice_end]);
    }
}

fn forEachExpandedStyledTextRun(
    r: anytype,
    text_start_x: f32,
    line_text: []const u8,
    seg_start_byte: usize,
    seg_start_vis: usize,
    slice_start: usize,
    slice_end: usize,
    visitor: anytype,
) void {
    if (slice_end <= slice_start) return;
    if (std.mem.indexOfScalar(u8, line_text[slice_start..slice_end], '\t') == null) {
        const x = xForByteOffset(r, line_text, seg_start_byte, seg_start_vis, slice_start, text_start_x);
        visitor.emit(x, line_text[slice_start..slice_end]);
        return;
    }

    var cursor = slice_start;
    var run_start = slice_start;
    var vis = visualColumnAtByteOffset(line_text, seg_start_byte, seg_start_vis, slice_start);
    var run_x = text_start_x + @as(f32, @floatFromInt(vis - seg_start_vis)) * r.editor_char_width;
    while (cursor < slice_end) {
        if (line_text[cursor] == '\t') {
            if (cursor > run_start) {
                visitor.emit(run_x, line_text[run_start..cursor]);
            }
            const width = text_columns_mod.cellWidthForCodepoint('\t', vis);
            visitor.emit(run_x, tab_spaces[0..width]);
            vis += width;
            run_x += @as(f32, @floatFromInt(width)) * r.editor_char_width;
            cursor += 1;
            run_start = cursor;
            continue;
        }
        const seq_len = nextUtf8Len(line_text, cursor);
        const cp = std.unicode.utf8Decode(line_text[cursor .. cursor + seq_len]) catch 0xFFFD;
        vis += text_columns_mod.cellWidthForCodepoint(cp, vis);
        cursor += seq_len;
    }
    if (run_start < slice_end) {
        visitor.emit(run_x, line_text[run_start..slice_end]);
    }
}

pub fn xForByteOffset(
    r: anytype,
    line_text: []const u8,
    seg_start_byte: usize,
    seg_start_vis: usize,
    byte_index: usize,
    text_x: f32,
) f32 {
    const vis = visualColumnAtByteOffset(line_text, seg_start_byte, seg_start_vis, byte_index);
    return text_x + @as(f32, @floatFromInt(vis - seg_start_vis)) * r.editor_char_width;
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
    var emitter = DrawListTextEmitter{ .list = list };
    return emitTextSliceWithSelectionBg(&emitter, r, text_start_x, y, line_text, seg_start_byte, seg_start_vis, slice_start, slice_end, fg, base_bg, selection_bg, sel_ranges, disable_programming_ligatures);
}

fn emitTextSliceWithSelectionBg(emitter: anytype, r: anytype, text_start_x: f32, y: f32, line_text: []const u8, seg_start_byte: usize, seg_start_vis: usize, slice_start: usize, slice_end: usize, fg: anytype, base_bg: anytype, selection_bg: anytype, sel_ranges: []const ByteRange, disable_programming_ligatures: bool) bool {
    if (slice_end <= slice_start) return true;
    var ok = true;
    var cursor = slice_start;
    for (sel_ranges) |sr| {
        if (sr.end <= cursor) continue;
        if (sr.start >= slice_end) break;
        if (sr.start > cursor) {
            ok = ok and addExpandedTextSliceWithEmitterBg(emitter, r, text_start_x, y, line_text, seg_start_byte, seg_start_vis, cursor, @min(sr.start, slice_end), fg, base_bg, disable_programming_ligatures);
        }
        const b0 = @max(cursor, sr.start);
        const b1 = @min(slice_end, sr.end);
        if (b1 > b0) {
            ok = ok and addExpandedTextSliceWithEmitterBg(emitter, r, text_start_x, y, line_text, seg_start_byte, seg_start_vis, b0, b1, fg, selection_bg, disable_programming_ligatures);
            cursor = b1;
        }
        if (cursor >= slice_end) break;
    }
    if (cursor < slice_end) {
        ok = ok and addExpandedTextSliceWithEmitterBg(emitter, r, text_start_x, y, line_text, seg_start_byte, seg_start_vis, cursor, slice_end, fg, base_bg, disable_programming_ligatures);
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

fn forEachHighlightedSegmentPart(
    r: anytype,
    line_text: []const u8,
    line_start: usize,
    seg_start: usize,
    seg_end: usize,
    seg_start_vis: usize,
    tokens: []const HighlightToken,
    text_x: f32,
    base_bg: anytype,
    selection_bg: anytype,
    sel_ranges: []const ByteRange,
    visitor: anytype,
) void {
    if (seg_start >= seg_end or line_text.len == 0) return;

    var cursor = seg_start;
    for (tokens) |token| {
        if (token.end <= line_start + seg_start or token.start >= line_start + seg_end) continue;
        const rel_start = if (token.start > line_start) token.start - line_start else 0;
        const start = @max(rel_start, seg_start);
        const end = @min(token.end - line_start, seg_end);

        if (start > cursor) {
            visitor.plain(cursor, start, r.theme.foreground, base_bg);
        }

        const conceal_text: ?[]const u8 = if (token.conceal != null or token.conceal_lines) token.conceal orelse "" else null;
        var color = colorForToken(r, token.kind);
        if (token.url != null) color = r.theme.link;
        const style = tokenStyleInfo(r, token.kind);
        const decoration_color = style.underline_color orelse color;

        if (conceal_text) |text| {
            if (text.len > 0) {
                const bg = selectionOverlapBg(start, end, base_bg, selection_bg, sel_ranges);
                const x = xForByteOffset(r, line_text, seg_start, seg_start_vis, start, text_x);
                visitor.conceal(x, text, color, bg, decoration_color, style.flags);
            }
        } else {
            const start_x = xForByteOffset(r, line_text, seg_start, seg_start_vis, start, text_x);
            const end_x = xForByteOffset(r, line_text, seg_start, seg_start_vis, end, text_x);
            const bg = selectionOverlapBg(start, end, base_bg, selection_bg, sel_ranges);
            visitor.highlighted(start, end, color, bg, start_x, end_x, decoration_color, style.flags);
        }

        if (end > cursor) cursor = end;
    }

    if (cursor < seg_end) {
        visitor.plain(cursor, seg_end, r.theme.foreground, base_bg);
    }
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

fn forEachDecorationRect(
    r: anytype,
    x: f32,
    y: f32,
    width: f32,
    flags: EditorTextStyleFlags,
    visitor: anytype,
) void {
    if (width <= 0 or (!flags.underline and !flags.undercurl and !flags.strikethrough)) return;
    const thickness = @max(1.0, std.math.round(@max(r.uiScaleFactor(), 1.0)));
    if (flags.undercurl) {
        forEachUndercurlRect(x, y + r.editor_char_height - thickness - 1.0, width, thickness, visitor);
    } else if (flags.underline) {
        visitor.rect(x, y + r.editor_char_height - thickness, width, thickness);
    }
    if (flags.strikethrough) {
        visitor.rect(x, y + std.math.floor(r.editor_char_height * 0.5), width, thickness);
    }
}

fn addExpandedTextSliceWithEmitterBg(
    emitter: anytype,
    r: anytype,
    text_start_x: f32,
    y: f32,
    line_text: []const u8,
    seg_start_byte: usize,
    seg_start_vis: usize,
    slice_start: usize,
    slice_end: usize,
    fg: anytype,
    bg: anytype,
    disable_programming_ligatures: bool,
) bool {
    if (slice_end <= slice_start) return true;
    return emitExpandedTextSliceOnBg(
        emitter,
        r,
        text_start_x,
        y,
        line_text,
        seg_start_byte,
        seg_start_vis,
        slice_start,
        slice_end,
        fg,
        bg,
        .{},
        disable_programming_ligatures,
    );
}

fn emitStyledTextOnBg(
    emitter: anytype,
    r: anytype,
    text: []const u8,
    x: f32,
    y: f32,
    fg: anytype,
    bg: anytype,
    flags: EditorTextStyleFlags,
    disable_programming_ligatures: bool,
) bool {
    _ = r;
    return emitter.textOnBg(x, y, text, fg, bg, flags, disable_programming_ligatures);
}

fn emitTextDecorations(emitter: anytype, r: anytype, x: f32, y: f32, width: f32, color: anytype, flags: EditorTextStyleFlags) bool {
    var ok = true;
    const Visitor = struct {
        emitter: @TypeOf(emitter),
        color: @TypeOf(color),
        ok: *bool,

        fn rect(self: *@This(), rx: f32, ry: f32, rw: f32, rh: f32) void {
            self.ok.* = self.ok.* and self.emitter.decorationRect(rx, ry, rw, rh, self.color);
        }
    };
    var visitor = Visitor{ .emitter = emitter, .color = color, .ok = &ok };
    if (@TypeOf(emitter.*) == ImmediateTextEmitter) {
        overlay_mod.runImmediateEditorRowBand(
            r,
            .{ .r = r, .x = x, .y = y, .width = width, .flags = flags, .visitor = &visitor },
            struct {
                fn draw(ctx: anytype) void {
                    forEachDecorationRect(ctx.r, ctx.x, ctx.y, ctx.width, ctx.flags, ctx.visitor);
                }
            }.draw,
        );
    } else {
        forEachDecorationRect(r, x, y, width, flags, &visitor);
    }
    return ok;
}

fn drawTextDecorations(r: anytype, x: f32, y: f32, width: f32, color: anytype, flags: EditorTextStyleFlags) void {
    var emitter = ImmediateTextEmitter{ .renderer = r };
    _ = emitTextDecorations(&emitter, r, x, y, width, color, flags);
}

fn addTextDecorationOps(list: *EditorDrawList, r: anytype, x: f32, y: f32, width: f32, color: anytype, flags: EditorTextStyleFlags) bool {
    var emitter = DrawListTextEmitter{ .list = list };
    return emitTextDecorations(&emitter, r, x, y, width, color, flags);
}

fn forEachUndercurlRect(x: f32, baseline_y: f32, width: f32, thickness: f32, visitor: anytype) void {
    if (width <= 0) return;
    const thickness_px = @max(1.0, thickness);
    const amplitude = thickness_px;
    const step = @max(2.0, thickness_px * 2.0);
    var pos: f32 = 0.0;
    while (pos < width) : (pos += step) {
        const seg_w = @min(step, width - pos);
        if (seg_w <= 0) break;
        const half = @max(1.0, std.math.floor(seg_w * 0.5));
        visitor.rect(x + pos, baseline_y, half, thickness_px);
        const tail_w = seg_w - half;
        if (tail_w > 0) {
            visitor.rect(x + pos + half, baseline_y + amplitude, tail_w, thickness_px);
        }
    }
}

pub fn drawTextSliceWithSelectionBg(r: anytype, text_start_x: f32, y: f32, line_text: []const u8, seg_start_byte: usize, seg_start_vis: usize, slice_start: usize, slice_end: usize, fg: anytype, base_bg: anytype, selection_bg: anytype, sel_ranges: []const ByteRange, disable_programming_ligatures: bool) void {
    var emitter = ImmediateTextEmitter{ .renderer = r };
    _ = emitTextSliceWithSelectionBg(&emitter, r, text_start_x, y, line_text, seg_start_byte, seg_start_vis, slice_start, slice_end, fg, base_bg, selection_bg, sel_ranges, disable_programming_ligatures);
}

pub fn appendHighlightedLineSegmentOps(list: *EditorDrawList, r: anytype, line_text: []const u8, y: f32, text_x: f32, line_start: usize, seg_start: usize, seg_end: usize, seg_start_vis: usize, tokens: []HighlightToken, base_bg: anytype, selection_bg: anytype, seg_start_byte: usize, sel_ranges: []const ByteRange, disable_programming_ligatures: bool) bool {
    var emitter = DrawListTextEmitter{ .list = list };
    return emitHighlightedLineSegment(&emitter, r, line_text, y, text_x, line_start, seg_start, seg_end, seg_start_vis, tokens, base_bg, selection_bg, seg_start_byte, sel_ranges, disable_programming_ligatures);
}

fn emitHighlightedLineSegment(emitter: anytype, r: anytype, line_text: []const u8, y: f32, text_x: f32, line_start: usize, seg_start: usize, seg_end: usize, seg_start_vis: usize, tokens: []const HighlightToken, base_bg: anytype, selection_bg: anytype, seg_start_byte: usize, sel_ranges: []const ByteRange, disable_programming_ligatures: bool) bool {
    var ok = true;
    const Visitor = struct {
        emitter: @TypeOf(emitter),
        ok: *bool,
        r: @TypeOf(r),
        line_text: []const u8,
        y: f32,
        text_x: f32,
        seg_start: usize,
        seg_start_byte: usize,
        seg_start_vis: usize,
        selection_bg: @TypeOf(selection_bg),
        sel_ranges: []const ByteRange,
        disable_programming_ligatures: bool,

        fn plain(self: *@This(), start: usize, end: usize, fg: @TypeOf(self.r.theme.foreground), bg: @TypeOf(self.selection_bg)) void {
            self.ok.* = self.ok.* and emitTextSliceWithSelectionBg(
                self.emitter,
                self.r,
                self.text_x,
                self.y,
                self.line_text,
                self.seg_start_byte,
                self.seg_start_vis,
                start,
                end,
                fg,
                bg,
                self.selection_bg,
                self.sel_ranges,
                self.disable_programming_ligatures,
            );
        }

        fn conceal(self: *@This(), x: f32, text: []const u8, fg: @TypeOf(self.r.theme.foreground), bg: @TypeOf(self.selection_bg), decoration_color: @TypeOf(self.r.theme.foreground), flags: EditorTextStyleFlags) void {
            self.ok.* = self.ok.* and emitStyledTextOnBg(self.emitter, self.r, text, x, self.y, fg, bg, flags, self.disable_programming_ligatures);
            self.ok.* = self.ok.* and emitTextDecorations(self.emitter, self.r, x, self.y, @as(f32, @floatFromInt(text.len)) * self.r.editor_char_width, decoration_color, flags);
        }

        fn highlighted(self: *@This(), start: usize, end: usize, fg: @TypeOf(self.r.theme.foreground), bg: @TypeOf(self.selection_bg), start_x: f32, end_x: f32, decoration_color: @TypeOf(self.r.theme.foreground), flags: EditorTextStyleFlags) void {
            self.ok.* = self.ok.* and emitExpandedTextSliceOnBg(
                self.emitter,
                self.r,
                self.text_x,
                self.y,
                self.line_text,
                self.seg_start,
                self.seg_start_vis,
                start,
                end,
                fg,
                bg,
                flags,
                self.disable_programming_ligatures,
            );
            self.ok.* = self.ok.* and emitTextDecorations(self.emitter, self.r, start_x, self.y, end_x - start_x, decoration_color, flags);
        }
    };
    var visitor = Visitor{
        .emitter = emitter,
        .ok = &ok,
        .r = r,
        .line_text = line_text,
        .y = y,
        .text_x = text_x,
        .seg_start = seg_start,
        .seg_start_byte = seg_start_byte,
        .seg_start_vis = seg_start_vis,
        .selection_bg = selection_bg,
        .sel_ranges = sel_ranges,
        .disable_programming_ligatures = disable_programming_ligatures,
    };
    forEachHighlightedSegmentPart(r, line_text, line_start, seg_start, seg_end, seg_start_vis, tokens, text_x, base_bg, selection_bg, sel_ranges, &visitor);
    return ok;
}

pub fn drawHighlightedLineSegment(r: anytype, line_text: []const u8, y: f32, text_x: f32, line_start: usize, seg_start: usize, seg_end: usize, seg_start_vis: usize, tokens: []const HighlightToken, base_bg: anytype, selection_bg: anytype, sel_ranges: []const ByteRange, disable_programming_ligatures: bool) void {
    var emitter = ImmediateTextEmitter{ .renderer = r };
    _ = emitHighlightedLineSegment(&emitter, r, line_text, y, text_x, line_start, seg_start, seg_end, seg_start_vis, tokens, base_bg, selection_bg, seg_start, sel_ranges, disable_programming_ligatures);
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
