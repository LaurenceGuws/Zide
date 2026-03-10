const std = @import("std");
const syntax_mod = @import("../../editor/syntax.zig");
const selection_mod = @import("../../editor/view/selection.zig");
const draw_list_mod = @import("../../editor/render/draw_list.zig");
const app_logger = @import("../../app_logger.zig");
const scrollbar_mod = @import("editor_scrollbar.zig");

const HighlightToken = syntax_mod.HighlightToken;
const SelectionRange = selection_mod.SelectionRange;
const EditorDrawList = draw_list_mod.EditorDrawList;
const TextOp = draw_list_mod.TextOp;
const RectOp = draw_list_mod.RectOp;
const CursorOp = draw_list_mod.CursorOp;

pub const ByteRange = struct { start: usize, end: usize };

pub fn packColor(color: anytype) u32 {
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

pub fn addRectOp(list: *EditorDrawList, x: f32, y: f32, w: f32, h: f32, color: anytype) bool {
    list.add(.{ .rect = RectOp{ .x = x, .y = y, .w = w, .h = h, .color = packColor(color) } }) catch |err| {
        const log = app_logger.logger("editor.draw");
        log.logf(.warning, "draw list rect append failed err={s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn addTextOp(list: *EditorDrawList, x: f32, y: f32, text: []const u8, color: anytype, disable_programming_ligatures: bool) bool {
    list.add(.{ .text = TextOp{ .x = x, .y = y, .text = text, .color = packColor(color), .bg_color = 0, .disable_programming_ligatures = disable_programming_ligatures } }) catch |err| {
        const log = app_logger.logger("editor.draw");
        log.logf(.warning, "draw list text append failed err={s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn addTextOpBg(list: *EditorDrawList, x: f32, y: f32, text: []const u8, color: anytype, bg: anytype, disable_programming_ligatures: bool) bool {
    list.add(.{ .text = TextOp{ .x = x, .y = y, .text = text, .color = packColor(color), .bg_color = packColor(bg), .disable_programming_ligatures = disable_programming_ligatures } }) catch |err| {
        const log = app_logger.logger("editor.draw");
        log.logf(.warning, "draw list text-bg append failed err={s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn addCursorOp(list: *EditorDrawList, x: f32, y: f32, h: f32, color: anytype) bool {
    list.add(.{ .cursor = CursorOp{ .x = x, .y = y, .h = h, .color = packColor(color) } }) catch |err| {
        const log = app_logger.logger("editor.draw");
        log.logf(.warning, "draw list cursor append failed err={s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn drawExtraCarets(
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

pub fn addExtraCaretOps(
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

pub fn selectionStateHash(editor: anytype) u64 {
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

pub fn rowBandForRow(base_y: f32, row: usize, h: f32) RowBand {
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

pub fn selectionBandForRowBand(band: RowBand) RowBand {
    return .{
        .y_i = band.y_i,
        .h_i = band.h_i + 1,
        .y_f = band.y_f,
        .h_f = band.h_f + 1.0,
    };
}

pub fn softSelectionColor(base: anytype) @TypeOf(base) {
    var color = base;
    color.a = @min(@as(u8, 132), color.a);
    return color;
}

fn softSelectionInset(scale: f32) f32 {
    return @max(1.0, std.math.floor(scale * 0.75));
}

const SelectionCornerMask = struct {
    top_left_outward: bool = false,
    top_right_outward: bool = false,
    bottom_left_outward: bool = false,
    bottom_right_outward: bool = false,
    top_left_inward: bool = false,
    top_right_inward: bool = false,
    bottom_left_inward: bool = false,
    bottom_right_inward: bool = false,
};

fn drawTopSelectionScanline(r: anytype, x: f32, y: f32, w: f32, color: anytype, left_inset: f32, right_inset: f32) void {
    const line_x = x + left_inset;
    const line_w = w - left_inset - right_inset;
    if (line_w <= 0) return;
    r.drawRect(@intFromFloat(line_x), @intFromFloat(y), @intFromFloat(line_w), 1, color);
}

pub fn drawSoftSelectionRect(r: anytype, x: f32, y: f32, w: f32, h: f32, color: anytype, mask: SelectionCornerMask) void {
    if (w <= 0 or h <= 0) return;
    const style = r.editorSelectionOverlayStyle();
    if (!style.smooth_enabled) {
        r.drawRect(@intFromFloat(x), @intFromFloat(y), @intFromFloat(w), @intFromFloat(h), color);
        return;
    }
    const smooth_active = mask.top_left_outward or mask.top_right_outward or mask.bottom_left_outward or mask.bottom_right_outward or mask.top_left_inward or mask.top_right_inward or mask.bottom_left_inward or mask.bottom_right_inward;
    const inset_x: f32 = style.corner_px orelse softSelectionInset(r.uiScaleFactor());
    const pad_x: f32 = if (smooth_active) (style.pad_px orelse @max(1.0, std.math.round(r.uiScaleFactor() * 0.5))) else 0.0;
    const draw_x = x + inset_x - pad_x;
    const draw_y = y;
    const draw_w = @max(1.0, w - inset_x * 2.0 + pad_x * 2.0);
    const draw_h = h;
    const corner = @max(1.0, @min(inset_x, std.math.floor(draw_h / 4.0)));
    const cornerDelta = struct {
        fn resolve(outward: bool, inward: bool, amount: f32) f32 {
            if (outward) return amount;
            if (inward) return -amount;
            return 0.0;
        }
    }.resolve;
    const top_left_inset = cornerDelta(mask.top_left_outward, mask.top_left_inward, corner);
    const top_right_inset = cornerDelta(mask.top_right_outward, mask.top_right_inward, corner);
    const bottom_left_inset = cornerDelta(mask.bottom_left_outward, mask.bottom_left_inward, corner);
    const bottom_right_inset = cornerDelta(mask.bottom_right_outward, mask.bottom_right_inward, corner);
    const compensatedInset = struct {
        fn apply(value: f32, pad: f32) f32 {
            if (value > 0.0) return @max(0.0, value - pad);
            if (value < 0.0) return value - pad;
            return 0.0;
        }
    }.apply;
    const top_left_edge = compensatedInset(top_left_inset, pad_x);
    const top_right_edge = compensatedInset(top_right_inset, pad_x);
    const bottom_left_edge = compensatedInset(bottom_left_inset, pad_x);
    const bottom_right_edge = compensatedInset(bottom_right_inset, pad_x);
    const draw_h_i = @as(i32, @intFromFloat(draw_h));

    if (draw_h_i <= 1) {
        drawTopSelectionScanline(
            r,
            draw_x,
            draw_y,
            draw_w,
            color,
            if (top_left_edge != 0.0) top_left_edge else bottom_left_edge,
            if (top_right_edge != 0.0) top_right_edge else bottom_right_edge,
        );
        return;
    }
    if (draw_h_i == 2) {
        drawTopSelectionScanline(r, draw_x, draw_y, draw_w, color, top_left_edge, top_right_edge);
        drawTopSelectionScanline(r, draw_x, draw_y + 1.0, draw_w, color, bottom_left_edge, bottom_right_edge);
        return;
    }

    if (top_left_edge == 0 and top_right_edge == 0 and bottom_left_edge == 0 and bottom_right_edge == 0) {
        r.drawRect(@intFromFloat(draw_x), @intFromFloat(draw_y), @intFromFloat(draw_w), @intFromFloat(draw_h), color);
        return;
    }

    drawTopSelectionScanline(r, draw_x, draw_y, draw_w, color, top_left_edge, top_right_edge);
    r.drawRect(@intFromFloat(draw_x), @intFromFloat(draw_y + 1.0), @intFromFloat(draw_w), @intFromFloat(draw_h - 2.0), color);
    drawTopSelectionScanline(r, draw_x, draw_y + draw_h - 1.0, draw_w, color, bottom_left_edge, bottom_right_edge);
}

pub fn addSoftSelectionRectOp(list: *EditorDrawList, r: anytype, x: f32, y: f32, w: f32, h: f32, color: anytype, mask: SelectionCornerMask) bool {
    if (w <= 0 or h <= 0) return true;
    const style = r.editorSelectionOverlayStyle();
    if (!style.smooth_enabled) return addRectOp(list, x, y, w, h, color);

    const smooth_active = mask.top_left_outward or mask.top_right_outward or mask.bottom_left_outward or mask.bottom_right_outward or mask.top_left_inward or mask.top_right_inward or mask.bottom_left_inward or mask.bottom_right_inward;
    const inset_x: f32 = style.corner_px orelse softSelectionInset(r.uiScaleFactor());
    const pad_x: f32 = if (smooth_active) (style.pad_px orelse @max(1.0, std.math.round(r.uiScaleFactor() * 0.5))) else 0.0;
    const draw_x = x + inset_x - pad_x;
    const draw_y = y;
    const draw_w = @max(1.0, w - inset_x * 2.0 + pad_x * 2.0);
    const draw_h = h;
    const corner = @max(1.0, @min(inset_x, std.math.floor(draw_h / 4.0)));
    const cornerDelta = struct {
        fn resolve(outward: bool, inward: bool, amount: f32) f32 {
            if (outward) return amount;
            if (inward) return -amount;
            return 0.0;
        }
    }.resolve;
    const top_left_inset = cornerDelta(mask.top_left_outward, mask.top_left_inward, corner);
    const top_right_inset = cornerDelta(mask.top_right_outward, mask.top_right_inward, corner);
    const bottom_left_inset = cornerDelta(mask.bottom_left_outward, mask.bottom_left_inward, corner);
    const bottom_right_inset = cornerDelta(mask.bottom_right_outward, mask.bottom_right_inward, corner);
    const compensatedInset = struct {
        fn apply(value: f32, pad: f32) f32 {
            if (value > 0.0) return @max(0.0, value - pad);
            if (value < 0.0) return value - pad;
            return 0.0;
        }
    }.apply;
    const top_left_edge = compensatedInset(top_left_inset, pad_x);
    const top_right_edge = compensatedInset(top_right_inset, pad_x);
    const bottom_left_edge = compensatedInset(bottom_left_inset, pad_x);
    const bottom_right_edge = compensatedInset(bottom_right_inset, pad_x);
    const draw_h_i = @as(i32, @intFromFloat(draw_h));

    if (draw_h_i <= 1) {
        const left_inset = if (top_left_edge != 0.0) top_left_edge else bottom_left_edge;
        const right_inset = if (top_right_edge != 0.0) top_right_edge else bottom_right_edge;
        const line_x = draw_x + left_inset;
        const line_w = draw_w - left_inset - right_inset;
        if (line_w <= 0) return true;
        return addRectOp(list, line_x, draw_y, line_w, 1.0, color);
    }
    if (draw_h_i == 2) {
        var ok = true;
        const top_x = draw_x + top_left_edge;
        const top_w = draw_w - top_left_edge - top_right_edge;
        if (top_w > 0) ok = ok and addRectOp(list, top_x, draw_y, top_w, 1.0, color);
        const bottom_x = draw_x + bottom_left_edge;
        const bottom_w = draw_w - bottom_left_edge - bottom_right_edge;
        if (bottom_w > 0) ok = ok and addRectOp(list, bottom_x, draw_y + 1.0, bottom_w, 1.0, color);
        return ok;
    }

    if (top_left_edge == 0 and top_right_edge == 0 and bottom_left_edge == 0 and bottom_right_edge == 0) {
        return addRectOp(list, draw_x, draw_y, draw_w, draw_h, color);
    }

    var ok = true;
    const top_x = draw_x + top_left_edge;
    const top_w = draw_w - top_left_edge - top_right_edge;
    if (top_w > 0) ok = ok and addRectOp(list, top_x, draw_y, top_w, 1.0, color);
    ok = ok and addRectOp(list, draw_x, draw_y + 1.0, draw_w, draw_h - 2.0, color);
    const bottom_x = draw_x + bottom_left_edge;
    const bottom_w = draw_w - bottom_left_edge - bottom_right_edge;
    if (bottom_w > 0) ok = ok and addRectOp(list, bottom_x, draw_y + draw_h - 1.0, bottom_w, 1.0, color);
    return ok;
}

const NeighborEdgeState = struct {
    left_connected: bool = false,
    right_connected: bool = false,
    left_inward: bool = false,
    right_inward: bool = false,
};

fn accumulateNeighborEdgeState(state: *NeighborEdgeState, sel_start: usize, sel_end: usize, neighbor_start: usize, neighbor_end: usize) void {
    if (neighbor_end <= neighbor_start) return;
    const overlaps_left_edge = neighbor_start <= sel_start and neighbor_end > sel_start;
    const overlaps_right_edge = neighbor_start < sel_end and neighbor_end >= sel_end;
    if (overlaps_left_edge) state.left_connected = true;
    if (overlaps_right_edge) state.right_connected = true;
    if (neighbor_start < sel_start and neighbor_end > sel_start) state.left_inward = true;
    if (neighbor_end > sel_end and neighbor_start < sel_end) state.right_inward = true;
}

fn lineNeighborEdgeState(editor: anytype, line_idx: usize, sel_start: usize, sel_end: usize) NeighborEdgeState {
    var state: NeighborEdgeState = .{};
    const mergeSelection = struct {
        fn apply(state_local: *NeighborEdgeState, line_idx_local: usize, sel_start_local: usize, sel_end_local: usize, selection: anytype) void {
            const norm = selection.normalized();
            if (norm.isEmpty()) return;
            if (line_idx_local < norm.start.line or line_idx_local > norm.end.line) return;
            const neighbor_start: usize = if (line_idx_local == norm.start.line) norm.start.col else 0;
            const neighbor_end: usize = if (line_idx_local == norm.end.line) norm.end.col else std.math.maxInt(usize);
            accumulateNeighborEdgeState(state_local, sel_start_local, sel_end_local, neighbor_start, neighbor_end);
        }
    }.apply;

    if (editor.selection) |sel| mergeSelection(&state, line_idx, sel_start, sel_end, sel);
    for (editor.selections.items) |sel| mergeSelection(&state, line_idx, sel_start, sel_end, sel);
    return state;
}

pub fn selectionCornerMaskForSegment(
    editor: anytype,
    line_idx: usize,
    cols: usize,
    line_width: usize,
    seg: usize,
    total_visual_lines: usize,
    seg_start_col: usize,
    seg_end_col: usize,
    range: SelectionRange,
) SelectionCornerMask {
    const sel_start = @max(range.start_col, seg_start_col);
    const sel_end = @min(range.end_col, seg_end_col);
    if (sel_end <= sel_start) return .{};

    var top_state: NeighborEdgeState = .{};
    if (seg > 0 and cols > 0) {
        const prev_seg = seg - 1;
        const prev_seg_start = prev_seg * cols;
        const prev_seg_end = @min(line_width, prev_seg_start + cols);
        const prev_start = @max(range.start_col, prev_seg_start);
        const prev_end = @min(range.end_col, prev_seg_end);
        accumulateNeighborEdgeState(&top_state, sel_start, sel_end, prev_start, prev_end);
    } else if (seg == 0 and line_idx > 0 and range.start_col == 0) {
        top_state = lineNeighborEdgeState(editor, line_idx - 1, sel_start, sel_end);
    }

    var bottom_state: NeighborEdgeState = .{};
    if (seg + 1 < total_visual_lines and cols > 0) {
        const next_seg = seg + 1;
        const next_seg_start = next_seg * cols;
        const next_seg_end = @min(line_width, next_seg_start + cols);
        const next_start = @max(range.start_col, next_seg_start);
        const next_end = @min(range.end_col, next_seg_end);
        accumulateNeighborEdgeState(&bottom_state, sel_start, sel_end, next_start, next_end);
    } else if (seg + 1 >= total_visual_lines and line_idx + 1 < editor.lineCount() and range.end_col >= line_width) {
        bottom_state = lineNeighborEdgeState(editor, line_idx + 1, sel_start, sel_end);
    }

    return .{
        .top_left_outward = !top_state.left_connected,
        .top_right_outward = !top_state.right_connected,
        .bottom_left_outward = !bottom_state.left_connected,
        .bottom_right_outward = !bottom_state.right_connected,
        .top_left_inward = top_state.left_inward,
        .top_right_inward = top_state.right_inward,
        .bottom_left_inward = bottom_state.left_inward,
        .bottom_right_inward = bottom_state.right_inward,
    };
}

pub fn searchHighlightColor(theme: anytype) @TypeOf(theme.selection) {
    var color = if (@hasField(@TypeOf(theme), "ui_accent")) theme.ui_accent else theme.selection;
    color.a = 80;
    return color;
}

pub fn activeSearchHighlightColor(theme: anytype) @TypeOf(theme.selection) {
    var color = if (@hasField(@TypeOf(theme), "ui_accent")) theme.ui_accent else theme.selection;
    color.a = 152;
    return color;
}

pub fn searchActiveByteRange(editor: anytype) ?ByteRange {
    const active = editor.searchActiveMatch() orelse return null;
    return .{ .start = active.start, .end = active.end };
}

pub fn rangeContains(haystack: ByteRange, needle: ByteRange) bool {
    return needle.start >= haystack.start and needle.end <= haystack.end;
}

pub fn flushDrawList(list: *EditorDrawList, r: anytype) void {
    const ColorType = @TypeOf(r.theme.foreground);
    for (list.ops.items) |op| {
        switch (op) {
            .rect => |rect| r.drawRect(
                @intFromFloat(rect.x),
                @intFromFloat(rect.y),
                @intFromFloat(rect.w),
                @intFromFloat(rect.h),
                unpackColor(ColorType, rect.color),
            ),
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
                const color = unpackColor(ColorType, cursor.color);
                const scale = r.uiScaleFactor();
                const edge_inset: i32 = @max(0, @as(i32, @intFromFloat(std.math.floor(scale * 0.5))));
                const stroke: i32 = @max(1, @as(i32, @intFromFloat(std.math.round(scale))));
                const x_i: i32 = @as(i32, @intFromFloat(cursor.x)) + edge_inset;
                const cursor_h_i: i32 = @as(i32, @intFromFloat(cursor.h));
                const h_i: i32 = @max(1, cursor_h_i - edge_inset * 2);
                const y_i: i32 = @as(i32, @intFromFloat(cursor.y)) + @divFloor(@max(0, cursor_h_i - h_i), 2);
                r.drawRect(x_i, y_i, stroke, h_i, color);
            },
        }
    }
}

pub fn drawEditorScrollbars(
    widget: anytype,
    r: anytype,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    visible_lines: usize,
    total_lines: usize,
    cols: usize,
    mouse: anytype,
    list: ?*EditorDrawList,
) void {
    const scale = r.uiScaleFactor();
    const max_line_width = widget.editor.maxLineWidthCached();

    const h = scrollbar_mod.computeHorizontal(
        scale,
        widget.gutter_width,
        x,
        y,
        width,
        height,
        mouse,
        max_line_width,
        cols,
        total_lines,
        visible_lines,
        widget.editor.scroll_col,
        false,
    );
    if (h.visible) {
        if (widget.editor.scroll_col != h.effective_scroll_col) widget.editor.scroll_col = h.effective_scroll_col;
        drawHorizontalScrollbar(r, h, list);
    }

    const v = scrollbar_mod.computeVertical(
        scale,
        x,
        y,
        width,
        height,
        mouse,
        visible_lines,
        total_lines,
        widget.editor.scroll_line,
        false,
    );
    if (v.visible) {
        if (widget.editor.scroll_line != v.effective_scroll_line) widget.editor.scroll_line = v.effective_scroll_line;
        drawVerticalScrollbar(r, v, list);
    }
}

fn drawHorizontalScrollbar(r: anytype, h: scrollbar_mod.HorizontalGeometry, list: ?*EditorDrawList) void {
    const show_track = h.focus_t > 0.01;
    if (show_track) {
        if (list) |ops| {
            _ = addRectOp(ops, h.track_x, h.track_max_y, h.track_w, h.track_max_h, r.theme.line_number_bg);
        } else {
            r.drawRect(@intFromFloat(h.track_x), @intFromFloat(h.track_max_y), @intFromFloat(h.track_w), @intFromFloat(h.track_max_h), r.theme.line_number_bg);
        }
    }
    const inset: f32 = if (show_track) blk: {
        const inset_limit = @max(0.0, h.track_h * 0.5 - 1.0);
        break :blk @min(@max(1.0, r.uiScaleFactor()), inset_limit);
    } else 0;
    if (list) |ops| {
        _ = addRectOp(ops, h.thumb_x, h.track_y + inset, h.thumb_w, @max(1, h.track_h - inset * 2), r.theme.selection);
    } else {
        r.drawRect(@intFromFloat(h.thumb_x), @intFromFloat(h.track_y + inset), @intFromFloat(h.thumb_w), @intFromFloat(@max(1, h.track_h - inset * 2)), r.theme.selection);
    }
}

fn drawVerticalScrollbar(r: anytype, v: scrollbar_mod.VerticalGeometry, list: ?*EditorDrawList) void {
    const show_track = v.focus_t > 0.01;
    if (show_track) {
        if (list) |ops| {
            _ = addRectOp(ops, v.scrollbar_x, v.scrollbar_y, v.scrollbar_w, v.scrollbar_h, r.theme.line_number_bg);
        } else {
            r.drawRect(@intFromFloat(v.scrollbar_x), @intFromFloat(v.scrollbar_y), @intFromFloat(v.scrollbar_w), @intFromFloat(v.scrollbar_h), r.theme.line_number_bg);
        }
    }
    const inset: f32 = if (show_track) blk: {
        const inset_limit = @max(0.0, v.scrollbar_w * 0.5 - 1.0);
        break :blk @min(@max(1.0, r.uiScaleFactor()), inset_limit);
    } else 0;
    if (list) |ops| {
        _ = addRectOp(ops, v.scrollbar_x + inset, v.thumb.thumb_y, @max(1, v.scrollbar_w - inset * 2), v.thumb.thumb_h, r.theme.selection);
    } else {
        r.drawRect(@intFromFloat(v.scrollbar_x + inset), @intFromFloat(v.thumb.thumb_y), @intFromFloat(@max(1, v.scrollbar_w - inset * 2)), @intFromFloat(v.thumb.thumb_h), r.theme.selection);
    }
}
