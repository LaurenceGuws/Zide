const std = @import("std");
const layout = @import("../src/types/mod.zig").layout;

test "widget layout rects store sizes" {
    const rect = layout.Rect{ .x = 1, .y = 2, .width = 3, .height = 4 };
    const wl = layout.WidgetLayout{
        .window = rect,
        .options_bar = rect,
        .tab_bar = rect,
        .side_nav = rect,
        .editor = rect,
        .terminal = rect,
        .status_bar = rect,
    };

    try std.testing.expectEqual(@as(f32, 1), wl.window.x);
    try std.testing.expectEqual(@as(f32, 2), wl.window.y);
    try std.testing.expectEqual(@as(f32, 3), wl.window.width);
    try std.testing.expectEqual(@as(f32, 4), wl.window.height);
}
