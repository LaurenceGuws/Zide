const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const editor_mod = @import("../editor.zig");
const types = @import("../types.zig");
const layout_mod = @import("layout.zig");
const selection_mod = @import("selection.zig");

const Editor = editor_mod.Editor;

pub const LineScratch = struct {
    buf: []u8,
};

pub const LineSlice = struct {
    text: []const u8,
    owned: ?[]u8,
};

pub const ClusterSlice = struct {
    clusters: ?[]const u32,
    owned: bool,
};

pub const LineProvider = struct {
    ctx: *anyopaque,
    getLineText: *const fn (ctx: *anyopaque, line_idx: usize, scratch: *LineScratch) LineSlice,
    getClusters: *const fn (ctx: *anyopaque, line_idx: usize, line_text: []const u8) ClusterSlice,
    freeLineText: *const fn (ctx: *anyopaque, owned: []u8) void,
    freeClusters: *const fn (ctx: *anyopaque, owned: []const u32) void,
};

const LineData = struct {
    text: []const u8,
    clusters: ?[]const u32,
    width: usize,
    len: usize,
    owned_text: ?[]u8,
    owned_clusters: bool,
};

pub fn cursorSegmentForLine(
    editor: *Editor,
    line_idx: usize,
    cols: usize,
    provider: *const LineProvider,
    scratch: *LineScratch,
) ?usize {
    if (line_idx >= editor.lineCount()) return null;
    var line = lineData(editor, provider, line_idx, scratch);
    defer releaseLineData(provider, &line);

    const col_vis = selection_mod.visualColumnForByteIndex(line.text, editor.cursor.col, line.clusters);
    const total_visual_lines = layout_mod.visualLineCountForWidth(cols, line.width);
    if (total_visual_lines == 0) return 0;
    return @min(col_vis / cols, total_visual_lines - 1);
}

pub fn moveCursorVisual(
    editor: *Editor,
    delta: i32,
    cols: usize,
    wrap_enabled: bool,
    provider: *const LineProvider,
    scratch_a: *LineScratch,
    scratch_b: *LineScratch,
) bool {
    if (!wrap_enabled) {
        const line_count = editor.lineCount();
        if (line_count == 0) return false;
        if (cols == 0) return false;

        var cur_line = editor.cursor.line;
        var cur_col_byte = editor.cursor.col;
        if (cur_line >= line_count) {
            cur_line = line_count - 1;
            cur_col_byte = editor.lineLen(cur_line);
        }

        var cur = lineData(editor, provider, cur_line, scratch_a);
        defer releaseLineData(provider, &cur);

        const cur_vis_col = selection_mod.visualColumnForByteIndex(cur.text, cur_col_byte, cur.clusters);
        const preferred_vis_col = editor.preferred_visual_col orelse cur_vis_col;
        if (editor.preferred_visual_col == null) {
            editor.preferred_visual_col = preferred_vis_col;
        }

        const target_line: usize = if (delta < 0) blk: {
            if (cur_line == 0) return false;
            break :blk cur_line - 1;
        } else blk: {
            if (cur_line + 1 >= line_count) return false;
            break :blk cur_line + 1;
        };

        var target = lineData(editor, provider, target_line, scratch_b);
        defer releaseLineData(provider, &target);

        const target_col_vis = @min(preferred_vis_col, target.width);
        const target_col_byte = selection_mod.byteIndexForVisualColumn(target.text, target_col_vis, target.clusters);
        editor.setCursorPreservePreferred(target_line, target_col_byte);
        return true;
    }

    const line_count = editor.lineCount();
    if (line_count == 0) return false;
    if (cols == 0) return false;

    var cur_line = editor.cursor.line;
    var cur_col_byte = editor.cursor.col;
    if (cur_line >= line_count) {
        cur_line = line_count - 1;
        cur_col_byte = editor.lineLen(cur_line);
    }

    var cur = lineData(editor, provider, cur_line, scratch_a);
    defer releaseLineData(provider, &cur);

    const cur_vis_col = selection_mod.visualColumnForByteIndex(cur.text, cur_col_byte, cur.clusters);
    const preferred_vis_col = editor.preferred_visual_col orelse cur_vis_col;
    if (editor.preferred_visual_col == null) {
        editor.preferred_visual_col = preferred_vis_col;
    }
    const cur_visual_lines = layout_mod.visualLineCountForWidth(cols, cur.width);
    const cur_seg = if (cur_visual_lines == 0) 0 else @min(cur_vis_col / cols, cur_visual_lines - 1);
    const cur_seg_col = cur_vis_col - cur_seg * cols;

    var target_line = cur_line;
    var target_seg: usize = cur_seg;
    var target_use_preferred = false;
    if (delta < 0) {
        if (cur_seg > 0) {
            target_seg = cur_seg - 1;
        } else if (cur_line > 0) {
            target_line = cur_line - 1;
            target_use_preferred = true;
        } else {
            return false;
        }
    } else {
        if (cur_seg + 1 < cur_visual_lines) {
            target_seg = cur_seg + 1;
        } else if (cur_line + 1 < line_count) {
            target_line = cur_line + 1;
            target_use_preferred = true;
        } else {
            return false;
        }
    }

    var target: LineData = cur;
    var use_target_data = false;
    if (target_line != cur_line) {
        target = lineData(editor, provider, target_line, scratch_b);
        use_target_data = true;
    }
    defer if (use_target_data) releaseLineData(provider, &target);

    const target_visual_lines = layout_mod.visualLineCountForWidth(cols, target.width);
    if (target_use_preferred and target_visual_lines > 0) {
        target_seg = @min(preferred_vis_col / cols, target_visual_lines - 1);
    }
    if (target_seg >= target_visual_lines) {
        target_seg = if (target_visual_lines > 0) target_visual_lines - 1 else 0;
    }
    const target_seg_start = target_seg * cols;
    const target_seg_len = if (target.width > target_seg_start) @min(cols, target.width - target_seg_start) else 0;
    const desired_seg_col = if (target_use_preferred)
        @min(preferred_vis_col - target_seg_start, target_seg_len)
    else
        @min(cur_seg_col, target_seg_len);
    const target_col_vis = target_seg_start + desired_seg_col;
    const target_col_byte = selection_mod.byteIndexForVisualColumn(target.text, target_col_vis, target.clusters);

    editor.setCursorPreservePreferred(target_line, target_col_byte);
    return true;
}

pub fn moveCaretSetVisual(
    editor: *Editor,
    delta: i32,
    cols: usize,
    wrap_enabled: bool,
    provider: *const LineProvider,
    scratch_a: *LineScratch,
    scratch_b: *LineScratch,
) !bool {
    if (editor.selections.items.len == 0) {
        return moveCursorVisual(editor, delta, cols, wrap_enabled, provider, scratch_a, scratch_b);
    }

    for (editor.selections.items) |sel| {
        if (!sel.normalized().isEmpty()) {
            return moveCursorVisual(editor, delta, cols, wrap_enabled, provider, scratch_a, scratch_b);
        }
    }

    var caret_offsets = std.ArrayList(usize).empty;
    defer caret_offsets.deinit(editor.allocator);
    try caret_offsets.append(editor.allocator, editor.cursor.offset);
    for (editor.selections.items) |sel| {
        const caret = sel.normalized();
        if (std.mem.indexOfScalar(usize, caret_offsets.items, caret.start.offset) != null) continue;
        try caret_offsets.append(editor.allocator, caret.start.offset);
    }

    var changed = false;
    for (caret_offsets.items) |*offset| {
        const current: types.CursorPos = .{
            .line = editor.buffer.lineIndexForOffset(offset.*),
            .col = offset.* - editor.buffer.lineStart(editor.buffer.lineIndexForOffset(offset.*)),
            .offset = offset.*,
        };
        if (moveVisualFromPos(editor, current, delta, cols, wrap_enabled, provider, scratch_a, scratch_b)) |target| {
            if (target.offset != offset.*) changed = true;
            offset.* = target.offset;
        }
    }

    if (!changed) return false;

    editor.preferred_visual_col = null;
    editor.selection = null;
    editor.clearSelections();
    for (caret_offsets.items) |offset| {
        const line = editor.buffer.lineIndexForOffset(offset);
        const line_start = editor.buffer.lineStart(line);
        const caret = types.CursorPos{
            .line = line,
            .col = offset - line_start,
            .offset = offset,
        };
        try editor.addSelection(.{ .start = caret, .end = caret });
    }
    try editor.normalizeSelections();
    if (editor.selections.items.len > 0) {
        editor.cursor = editor.selections.items[0].start;
        for (editor.selections.items) |sel| {
            if (sel.start.offset == caret_offsets.items[0]) {
                editor.cursor = sel.start;
                break;
            }
        }
    }
    return true;
}

pub fn extendSelectionVisual(
    editor: *Editor,
    delta: i32,
    cols: usize,
    wrap_enabled: bool,
    provider: *const LineProvider,
    scratch_a: *LineScratch,
    scratch_b: *LineScratch,
) bool {
    const log = app_logger.logger("editor.cursor");
    if (editor.hasSelectionSetState() and !editor.hasRectangularSelectionState()) {
        var anchor_offsets = std.ArrayList(usize).empty;
        defer anchor_offsets.deinit(editor.allocator);
        var head_offsets = std.ArrayList(usize).empty;
        defer head_offsets.deinit(editor.allocator);
        editor.collectSelectionAnchorsAndHeads(&anchor_offsets, &head_offsets) catch |err| {
            log.logf(.warning, "extendSelectionVisual collectSelectionAnchorsAndHeads failed err={s}", .{@errorName(err)});
            return false;
        };

        var target_offsets = std.ArrayList(usize).empty;
        defer target_offsets.deinit(editor.allocator);
        var changed = false;
        for (head_offsets.items) |offset| {
            const line = editor.buffer.lineIndexForOffset(offset);
            const current: types.CursorPos = .{
                .line = line,
                .col = offset - editor.buffer.lineStart(line),
                .offset = offset,
            };
            const target = moveVisualFromPos(editor, current, delta, cols, wrap_enabled, provider, scratch_a, scratch_b) orelse current;
            if (target.offset != offset) changed = true;
            target_offsets.append(editor.allocator, target.offset) catch |err| {
                log.logf(.warning, "extendSelectionVisual target offset append failed err={s}", .{@errorName(err)});
                return false;
            };
        }
        if (!changed) return false;
        editor.restoreExtendedCaretSelections(anchor_offsets.items, target_offsets.items) catch |err| {
            log.logf(.warning, "extendSelectionVisual restoreExtendedCaretSelections failed err={s}", .{@errorName(err)});
            return false;
        };
        return true;
    }

    const anchor = if (editor.selection) |sel| sel.start else editor.cursor;
    const current = editor.cursor;
    const target = moveVisualFromPos(editor, current, delta, cols, wrap_enabled, provider, scratch_a, scratch_b) orelse return false;

    editor.preferred_visual_col = null;
    editor.clearSelections();
    editor.cursor = target;
    if (anchor.offset == target.offset) {
        editor.selection = null;
    } else {
        editor.selection = .{ .start = anchor, .end = target };
    }
    return true;
}

fn moveVisualFromPos(
    editor: *Editor,
    current: types.CursorPos,
    delta: i32,
    cols: usize,
    wrap_enabled: bool,
    provider: *const LineProvider,
    scratch_a: *LineScratch,
    scratch_b: *LineScratch,
) ?types.CursorPos {
    const line_count = editor.lineCount();
    if (line_count == 0 or cols == 0) return null;

    var cur = lineData(editor, provider, current.line, scratch_a);
    defer releaseLineData(provider, &cur);

    const cur_vis_col = selection_mod.visualColumnForByteIndex(cur.text, current.col, cur.clusters);

    if (!wrap_enabled) {
        const target_line: usize = if (delta < 0) blk: {
            if (current.line == 0) return null;
            break :blk current.line - 1;
        } else blk: {
            if (current.line + 1 >= line_count) return null;
            break :blk current.line + 1;
        };

        var target = lineData(editor, provider, target_line, scratch_b);
        defer releaseLineData(provider, &target);

        const target_col_vis = @min(cur_vis_col, target.width);
        const target_col_byte = selection_mod.byteIndexForVisualColumn(target.text, target_col_vis, target.clusters);
        const line_start = editor.lineStart(target_line);
        return .{ .line = target_line, .col = target_col_byte, .offset = line_start + target_col_byte };
    }

    const cur_visual_lines = layout_mod.visualLineCountForWidth(cols, cur.width);
    const cur_seg = if (cur_visual_lines == 0) 0 else @min(cur_vis_col / cols, cur_visual_lines - 1);
    const cur_seg_col = cur_vis_col - cur_seg * cols;

    var target_line = current.line;
    var target_seg: usize = cur_seg;
    var target_use_preferred = false;
    if (delta < 0) {
        if (cur_seg > 0) {
            target_seg = cur_seg - 1;
        } else if (current.line > 0) {
            target_line = current.line - 1;
            target_use_preferred = true;
        } else {
            return null;
        }
    } else {
        if (cur_seg + 1 < cur_visual_lines) {
            target_seg = cur_seg + 1;
        } else if (current.line + 1 < line_count) {
            target_line = current.line + 1;
            target_use_preferred = true;
        } else {
            return null;
        }
    }

    var target: LineData = cur;
    var use_target_data = false;
    if (target_line != current.line) {
        target = lineData(editor, provider, target_line, scratch_b);
        use_target_data = true;
    }
    defer if (use_target_data) releaseLineData(provider, &target);

    const target_visual_lines = layout_mod.visualLineCountForWidth(cols, target.width);
    if (target_use_preferred and target_visual_lines > 0) {
        target_seg = @min(cur_vis_col / cols, target_visual_lines - 1);
    }
    if (target_seg >= target_visual_lines) {
        target_seg = if (target_visual_lines > 0) target_visual_lines - 1 else 0;
    }
    const target_seg_start = target_seg * cols;
    const target_seg_len = if (target.width > target_seg_start) @min(cols, target.width - target_seg_start) else 0;
    const desired_seg_col = if (target_use_preferred)
        @min(cur_vis_col - target_seg_start, target_seg_len)
    else
        @min(cur_seg_col, target_seg_len);
    const target_col_vis = target_seg_start + desired_seg_col;
    const target_col_byte = selection_mod.byteIndexForVisualColumn(target.text, target_col_vis, target.clusters);
    const line_start = editor.lineStart(target_line);
    return .{ .line = target_line, .col = target_col_byte, .offset = line_start + target_col_byte };
}

fn lineData(
    editor: *Editor,
    provider: *const LineProvider,
    line_idx: usize,
    scratch: *LineScratch,
) LineData {
    const line_slice = provider.getLineText(provider.ctx, line_idx, scratch);
    const cluster_slice = provider.getClusters(provider.ctx, line_idx, line_slice.text);
    const width_cached = editor.lineWidthCached(line_idx, line_slice.text, cluster_slice.clusters);
    const line_width = if (line_slice.text.len == 0) 1 else width_cached;
    return .{
        .text = line_slice.text,
        .clusters = cluster_slice.clusters,
        .width = line_width,
        .len = line_slice.text.len,
        .owned_text = line_slice.owned,
        .owned_clusters = cluster_slice.owned,
    };
}

fn releaseLineData(provider: *const LineProvider, data: *LineData) void {
    if (data.owned_text) |owned| {
        provider.freeLineText(provider.ctx, owned);
    }
    if (data.owned_clusters) {
        if (data.clusters) |clusters| {
            provider.freeClusters(provider.ctx, clusters);
        }
    }
}
