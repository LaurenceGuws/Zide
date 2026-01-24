const editor_mod = @import("../editor.zig");
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
