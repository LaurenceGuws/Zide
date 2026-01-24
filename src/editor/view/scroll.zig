const editor_mod = @import("../editor.zig");

const Editor = editor_mod.Editor;

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
    visualLinesForLine: *const fn (usize, usize) usize,
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
            const lines = visualLinesForLine(line, cols);
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
        const lines = visualLinesForLine(line, cols);
        const available = if (lines > seg) lines - seg else 0;
        offset += @as(i32, @intCast(available));
        seg = 0;
    }
    offset += @as(i32, @intCast(scroll_seg));
    return -offset;
}
