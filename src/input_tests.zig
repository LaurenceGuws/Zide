const std = @import("std");
const shared_types = @import("types/mod.zig");

test "input batch append/clear" {
    const allocator = std.testing.allocator;

    var batch = shared_types.input.InputBatch.init(allocator);
    defer batch.deinit();

    try batch.append(.{ .focus = true });
    try std.testing.expectEqual(@as(usize, 1), batch.events.items.len);

    batch.clear();
    try std.testing.expectEqual(@as(usize, 0), batch.events.items.len);
}

test "input batch state helpers" {
    const allocator = std.testing.allocator;

    var batch = shared_types.input.InputBatch.init(allocator);
    defer batch.deinit();

    batch.key_down[@intFromEnum(shared_types.input.Key.enter)] = true;
    batch.key_pressed[@intFromEnum(shared_types.input.Key.tab)] = true;
    batch.key_repeated[@intFromEnum(shared_types.input.Key.backspace)] = true;
    batch.mouse_down[@intFromEnum(shared_types.input.MouseButton.left)] = true;
    batch.mouse_pressed[@intFromEnum(shared_types.input.MouseButton.right)] = true;
    batch.mouse_released[@intFromEnum(shared_types.input.MouseButton.middle)] = true;

    try std.testing.expect(batch.keyDown(.enter));
    try std.testing.expect(batch.keyPressed(.tab));
    try std.testing.expect(batch.keyRepeated(.backspace));
    try std.testing.expect(batch.mouseDown(.left));
    try std.testing.expect(batch.mousePressed(.right));
    try std.testing.expect(batch.mouseReleased(.middle));
}
