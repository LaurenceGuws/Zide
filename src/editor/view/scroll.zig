const editor_mod = @import("../editor.zig");

const Editor = editor_mod.Editor;

pub const VisualLinesFn = *const fn (ctx: *anyopaque, line_idx: usize, cols: usize) usize;

pub const VisualLinePos = struct {
    line_idx: usize,
    seg_idx: usize,
    cols: usize,
};

pub fn updateHorizontalScrollFromMouse(
    editor: *Editor,
    mouse_x: f32,
    track_x: f32,
    available: f32,
    grab_offset: f32,
    max_scroll: usize,
) void {
    const clamped_x = @min(@max(mouse_x - grab_offset, track_x), track_x + available);
    const ratio = if (available > 0) (clamped_x - track_x) / available else 0;
    editor.scroll_col = @as(usize, @intFromFloat(@round(@as(f32, @floatFromInt(max_scroll)) * ratio)));
}

pub fn updateVerticalScrollFromMouse(
    editor: *Editor,
    mouse_y: f32,
    track_y: f32,
    available: f32,
    grab_offset: f32,
    max_scroll: usize,
) void {
    const clamped_y = @min(@max(mouse_y - grab_offset, track_y), track_y + available);
    const ratio = if (available > 0) (clamped_y - track_y) / available else 0;
    editor.scroll_line = @as(usize, @intFromFloat(@round(@as(f32, @floatFromInt(max_scroll)) * ratio)));
    editor.scroll_row_offset = 0;
}

pub fn cursorRowOffset(
    editor: *Editor,
    cursor_line: usize,
    cursor_seg: usize,
    cols: usize,
    ctx: *anyopaque,
    visualLinesForLine: VisualLinesFn,
) i32 {
    const scroll_line = editor.scroll_line;
    const scroll_seg = editor.scroll_row_offset;
    if (cursor_line == scroll_line) {
        return @as(i32, @intCast(cursor_seg)) - @as(i32, @intCast(scroll_seg));
    }
    if (cursor_line > scroll_line) {
        var offset: i32 = 0;
        var line = scroll_line;
        var seg = scroll_seg;
        while (line < cursor_line) : (line += 1) {
            const lines = visualLinesForLine(ctx, line, cols);
            const available = if (lines > seg) lines - seg else 0;
            offset += @as(i32, @intCast(available));
            seg = 0;
        }
        offset += @as(i32, @intCast(cursor_seg));
        return offset;
    }

    var offset: i32 = 0;
    var line = cursor_line;
    var seg = cursor_seg;
    while (line < scroll_line) : (line += 1) {
        const lines = visualLinesForLine(ctx, line, cols);
        const available = if (lines > seg) lines - seg else 0;
        offset += @as(i32, @intCast(available));
        seg = 0;
    }
    offset += @as(i32, @intCast(scroll_seg));
    return -offset;
}

pub fn lineForVisualRow(
    editor: *Editor,
    visual_row: usize,
    cols: usize,
    wrap_enabled: bool,
    ctx: *anyopaque,
    visualLinesForLine: VisualLinesFn,
) ?VisualLinePos {
    const line_count = editor.lineCount();
    if (line_count == 0) return null;
    if (cols == 0) return null;
    if (!wrap_enabled) {
        const line = editor.scroll_line + visual_row;
        if (line >= line_count) return null;
        return .{ .line_idx = line, .seg_idx = 0, .cols = cols };
    }

    var line = editor.scroll_line;
    var seg = editor.scroll_row_offset;
    if (line >= line_count) {
        line = line_count - 1;
        seg = 0;
    }

    var remaining = visual_row;
    while (line < line_count) {
        const lines = visualLinesForLine(ctx, line, cols);
        const available = if (lines > seg) lines - seg else 0;
        if (remaining < available) {
            return .{ .line_idx = line, .seg_idx = seg + remaining, .cols = cols };
        }
        remaining -= available;
        line += 1;
        seg = 0;
    }
    return null;
}

pub fn scrollVisual(
    editor: *Editor,
    delta_rows: i32,
    cols: usize,
    wrap_enabled: bool,
    ctx: *anyopaque,
    visualLinesForLine: VisualLinesFn,
) void {
    if (delta_rows == 0) return;
    const line_count = editor.lineCount();
    if (line_count == 0) return;
    if (cols == 0) return;
    if (!wrap_enabled) {
        if (delta_rows > 0) {
            editor.scroll_line = @min(editor.scroll_line + @as(usize, @intCast(delta_rows)), line_count - 1);
        } else {
            const delta_abs: usize = @intCast(-delta_rows);
            editor.scroll_line = if (editor.scroll_line > delta_abs) editor.scroll_line - delta_abs else 0;
        }
        editor.scroll_row_offset = 0;
        return;
    }

    var line = editor.scroll_line;
    var seg = editor.scroll_row_offset;
    if (line >= line_count) {
        line = line_count - 1;
        seg = 0;
    }

    if (delta_rows > 0) {
        var remaining: usize = @intCast(delta_rows);
        while (remaining > 0 and line < line_count) {
            const lines = visualLinesForLine(ctx, line, cols);
            const available = if (lines > seg) lines - seg else 0;
            if (remaining < available) {
                seg += remaining;
                remaining = 0;
                break;
            }
            remaining -= available;
            if (line + 1 >= line_count) {
                seg = 0;
                break;
            }
            line += 1;
            seg = 0;
        }
    } else {
        var remaining: usize = @intCast(-delta_rows);
        while (remaining > 0) {
            if (line == 0 and seg == 0) break;
            if (seg >= remaining) {
                seg -= remaining;
                remaining = 0;
                break;
            }
            remaining -= seg;
            if (line == 0) {
                seg = 0;
                break;
            }
            line -= 1;
            const lines = visualLinesForLine(ctx, line, cols);
            seg = if (lines > 0) lines - 1 else 0;
            if (remaining > 0) {
                remaining -= 1;
            }
        }
    }

    editor.scroll_line = line;
    editor.scroll_row_offset = seg;
}
