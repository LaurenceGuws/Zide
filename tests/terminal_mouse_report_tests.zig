const std = @import("std");
const mouse_report = @import("../src/terminal/input/mouse_report.zig");

test "x10 mouse coord encoding saturates on overflow" {
    try std.testing.expectEqual(@as(u8, 33), mouse_report.mouseEncodeCoordX10(0));
    try std.testing.expectEqual(@as(u8, 255), mouse_report.mouseEncodeCoordX10(10_000));
}
