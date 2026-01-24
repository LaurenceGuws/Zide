const std = @import("std");

pub fn viewportColumns(editor_width: i32, gutter_width: f32, char_width: f32) usize {
    const content_width = @max(0, editor_width - @as(i32, @intFromFloat(gutter_width)));
    if (char_width <= 0) return 0;
    return @as(usize, @intFromFloat(@as(f32, @floatFromInt(content_width)) / char_width));
}

pub fn lineWidthForDisplay(line_len: usize, width_cached: usize, has_selection: bool) usize {
    if (line_len == 0) return 1;
    if (width_cached == 0 and has_selection) return 1;
    return width_cached;
}

pub fn maxScrollForLine(line_width: usize, cols: usize) usize {
    return if (line_width > cols) line_width - cols else 0;
}

test "viewport columns ignores negative content width" {
    try std.testing.expectEqual(@as(usize, 0), viewportColumns(0, 50, 8));
    try std.testing.expectEqual(@as(usize, 0), viewportColumns(10, 50, 8));
}

test "line width fallback for empty or selected line" {
    try std.testing.expectEqual(@as(usize, 1), lineWidthForDisplay(0, 0, false));
    try std.testing.expectEqual(@as(usize, 1), lineWidthForDisplay(1, 0, true));
    try std.testing.expectEqual(@as(usize, 3), lineWidthForDisplay(3, 3, false));
}

test "max scroll width" {
    try std.testing.expectEqual(@as(usize, 0), maxScrollForLine(10, 10));
    try std.testing.expectEqual(@as(usize, 5), maxScrollForLine(15, 10));
}
