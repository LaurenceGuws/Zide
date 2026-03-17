const std = @import("std");
const scrollbar_mod = @import("../../ui/widgets/editor_scrollbar.zig");

pub const FrameMetrics = struct {
    gutter_width: f32,
    text_start_x: f32,
    visible_lines: usize,
};

pub const ScrollbarMetrics = struct {
    visible_lines: usize,
    max_line_width: usize,
    total_lines: usize,
};

pub fn gutterWidth(ui_scale: f32) f32 {
    return 50 * ui_scale;
}

pub fn textStartX(origin_x: f32, gutter_width: f32, ui_scale: f32) f32 {
    return origin_x + gutter_width + 8 * ui_scale;
}

pub fn visibleLineCount(height: f32, char_height: f32) usize {
    if (height <= 0 or char_height <= 0) return 0;
    return @as(usize, @intFromFloat(height / char_height));
}

pub fn frameMetrics(origin_x: f32, height: f32, ui_scale: f32, char_height: f32) FrameMetrics {
    const gutter = gutterWidth(ui_scale);
    return .{
        .gutter_width = gutter,
        .text_start_x = textStartX(origin_x, gutter, ui_scale),
        .visible_lines = visibleLineCount(height, char_height),
    };
}

pub fn scrollbarMetrics(height: f32, char_height: f32, max_line_width: usize, total_lines: usize) ScrollbarMetrics {
    return .{
        .visible_lines = visibleLineCount(height, char_height),
        .max_line_width = max_line_width,
        .total_lines = total_lines,
    };
}

pub fn horizontalScrollbarGeometry(
    ui_scale: f32,
    gutter_width: f32,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    mouse: anytype,
    metrics: ScrollbarMetrics,
    cols: usize,
    scroll_col: usize,
    dragging: bool,
) scrollbar_mod.HorizontalGeometry {
    return scrollbar_mod.computeHorizontal(
        ui_scale,
        gutter_width,
        x,
        y,
        width,
        height,
        mouse,
        metrics.max_line_width,
        cols,
        metrics.total_lines,
        metrics.visible_lines,
        scroll_col,
        dragging,
    );
}

pub fn verticalScrollbarGeometry(
    ui_scale: f32,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    mouse: anytype,
    metrics: ScrollbarMetrics,
    scroll_line: usize,
    dragging: bool,
) scrollbar_mod.VerticalGeometry {
    return scrollbar_mod.computeVertical(
        ui_scale,
        x,
        y,
        width,
        height,
        mouse,
        metrics.visible_lines,
        metrics.total_lines,
        scroll_line,
        dragging,
    );
}

test "frame metrics keep gutter text start and visible line math aligned" {
    const metrics = frameMetrics(10, 64, 2.0, 16);
    try std.testing.expectEqual(@as(f32, 100), metrics.gutter_width);
    try std.testing.expectEqual(@as(f32, 126), metrics.text_start_x);
    try std.testing.expectEqual(@as(usize, 4), metrics.visible_lines);
}

test "visible line count clamps invalid geometry to zero" {
    try std.testing.expectEqual(@as(usize, 0), visibleLineCount(0, 16));
    try std.testing.expectEqual(@as(usize, 0), visibleLineCount(10, 0));
}

test "scrollbar metrics and geometry stay aligned" {
    const metrics = scrollbarMetrics(64, 16, 40, 20);
    try std.testing.expectEqual(@as(usize, 4), metrics.visible_lines);
    try std.testing.expectEqual(@as(usize, 40), metrics.max_line_width);
    try std.testing.expectEqual(@as(usize, 20), metrics.total_lines);

    const mouse = struct { x: f32 = 0, y: f32 = 0 }{};
    const h = horizontalScrollbarGeometry(1.0, 50, 0, 0, 300, 64, mouse, metrics, 20, 3, false);
    try std.testing.expect(h.visible);
    const v = verticalScrollbarGeometry(1.0, 0, 0, 300, 64, mouse, metrics, 2, false);
    try std.testing.expect(v.visible);
}

test "horizontal scrollbar geometry hides when content fits viewport" {
    const metrics = scrollbarMetrics(64, 16, 20, 4);
    const mouse = struct { x: f32 = 0, y: f32 = 0 }{};
    const h = horizontalScrollbarGeometry(1.0, 50, 0, 0, 300, 64, mouse, metrics, 20, 0, false);
    try std.testing.expect(!h.visible);
}

test "horizontal scrollbar geometry accounts for vertical scrollbar width" {
    const metrics = scrollbarMetrics(64, 16, 80, 20);
    const mouse = struct { x: f32 = 0, y: f32 = 0 }{};
    const h = horizontalScrollbarGeometry(1.0, 50, 0, 0, 300, 64, mouse, metrics, 20, 10, false);

    try std.testing.expect(h.visible);
    try std.testing.expect(h.track_w < 250);
    try std.testing.expect(h.thumb_w >= 32);
    try std.testing.expect(h.thumb_x >= h.track_x);
    try std.testing.expect(h.thumb_x + h.thumb_w <= h.track_x + h.track_w + 0.001);
}

test "vertical scrollbar geometry clamps scroll line to max scroll" {
    const metrics = scrollbarMetrics(64, 16, 80, 20);
    const mouse = struct { x: f32 = 299, y: f32 = 32 }{};
    const v = verticalScrollbarGeometry(1.0, 0, 0, 300, 64, mouse, metrics, 999, false);

    try std.testing.expect(v.visible);
    try std.testing.expectEqual(@as(usize, 16), v.max_scroll);
    try std.testing.expectEqual(@as(usize, 16), v.effective_scroll_line);
    try std.testing.expect(v.thumb.thumb_y >= v.scrollbar_y);
    try std.testing.expect(v.thumb.thumb_y + v.thumb.thumb_h <= v.scrollbar_y + v.scrollbar_h + 0.001);
}
