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

const Frame = struct {
    mouse_x: f32,
    mouse_y: f32,
    scroll_y: f32,
    key_down: []const shared_types.input.Key,
    key_pressed: []const shared_types.input.Key,
    key_repeated: []const shared_types.input.Key,
    mouse_down: []const shared_types.input.MouseButton,
    mouse_pressed: []const shared_types.input.MouseButton,
    mouse_released: []const shared_types.input.MouseButton,
};

fn applyFrame(batch: *shared_types.input.InputBatch, frame: Frame) void {
    batch.clear();
    batch.mouse_pos = .{ .x = frame.mouse_x, .y = frame.mouse_y };
    batch.scroll = .{ .x = 0, .y = frame.scroll_y };
    for (frame.key_down) |key| {
        batch.key_down[@intFromEnum(key)] = true;
    }
    for (frame.key_pressed) |key| {
        batch.key_pressed[@intFromEnum(key)] = true;
    }
    for (frame.key_repeated) |key| {
        batch.key_repeated[@intFromEnum(key)] = true;
    }
    for (frame.mouse_down) |button| {
        batch.mouse_down[@intFromEnum(button)] = true;
    }
    for (frame.mouse_pressed) |button| {
        batch.mouse_pressed[@intFromEnum(button)] = true;
    }
    for (frame.mouse_released) |button| {
        batch.mouse_released[@intFromEnum(button)] = true;
    }
}

test "input replay harness applies frames" {
    const allocator = std.testing.allocator;
    var batch = shared_types.input.InputBatch.init(allocator);
    defer batch.deinit();

    const frames = [_]Frame{
        .{
            .mouse_x = 12,
            .mouse_y = 34,
            .scroll_y = 1,
            .key_down = &.{ .a },
            .key_pressed = &.{ .enter },
            .key_repeated = &.{},
            .mouse_down = &.{},
            .mouse_pressed = &.{},
            .mouse_released = &.{},
        },
        .{
            .mouse_x = 12,
            .mouse_y = 40,
            .scroll_y = -2,
            .key_down = &.{ .a, .left },
            .key_pressed = &.{},
            .key_repeated = &.{ .left },
            .mouse_down = &.{},
            .mouse_pressed = &.{},
            .mouse_released = &.{},
        },
    };

    applyFrame(&batch, frames[0]);
    try std.testing.expectEqual(@as(f32, 12), batch.mouse_pos.x);
    try std.testing.expectEqual(@as(f32, 34), batch.mouse_pos.y);
    try std.testing.expectEqual(@as(f32, 1), batch.scroll.y);
    try std.testing.expect(batch.keyDown(.a));
    try std.testing.expect(batch.keyPressed(.enter));
    try std.testing.expect(!batch.keyRepeated(.a));

    const snap = batch.snapshot();
    try std.testing.expectEqual(@as(f32, 12), snap.mouse_pos.x);
    try std.testing.expectEqual(@as(f32, 34), snap.mouse_pos.y);

    applyFrame(&batch, frames[1]);
    try std.testing.expectEqual(@as(f32, 40), batch.mouse_pos.y);
    try std.testing.expectEqual(@as(f32, -2), batch.scroll.y);
    try std.testing.expect(batch.keyDown(.left));
    try std.testing.expect(batch.keyRepeated(.left));
}

test "input replay harness supports mouse drag sequence" {
    const allocator = std.testing.allocator;
    var batch = shared_types.input.InputBatch.init(allocator);
    defer batch.deinit();

    const frames = [_]Frame{
        .{
            .mouse_x = 10,
            .mouse_y = 10,
            .scroll_y = 0,
            .key_down = &.{},
            .key_pressed = &.{},
            .key_repeated = &.{},
            .mouse_down = &.{ .left },
            .mouse_pressed = &.{ .left },
            .mouse_released = &.{},
        },
        .{
            .mouse_x = 18,
            .mouse_y = 12,
            .scroll_y = 0,
            .key_down = &.{},
            .key_pressed = &.{},
            .key_repeated = &.{},
            .mouse_down = &.{ .left },
            .mouse_pressed = &.{},
            .mouse_released = &.{},
        },
        .{
            .mouse_x = 20,
            .mouse_y = 14,
            .scroll_y = 0,
            .key_down = &.{},
            .key_pressed = &.{},
            .key_repeated = &.{},
            .mouse_down = &.{},
            .mouse_pressed = &.{},
            .mouse_released = &.{ .left },
        },
    };

    applyFrame(&batch, frames[0]);
    try std.testing.expect(batch.mouseDown(.left));
    try std.testing.expect(batch.mousePressed(.left));
    try std.testing.expectEqual(@as(f32, 10), batch.mouse_pos.x);
    try std.testing.expectEqual(@as(f32, 10), batch.mouse_pos.y);

    applyFrame(&batch, frames[1]);
    try std.testing.expect(batch.mouseDown(.left));
    try std.testing.expect(!batch.mousePressed(.left));
    try std.testing.expectEqual(@as(f32, 18), batch.mouse_pos.x);
    try std.testing.expectEqual(@as(f32, 12), batch.mouse_pos.y);

    applyFrame(&batch, frames[2]);
    try std.testing.expect(!batch.mouseDown(.left));
    try std.testing.expect(batch.mouseReleased(.left));
    try std.testing.expectEqual(@as(f32, 20), batch.mouse_pos.x);
    try std.testing.expectEqual(@as(f32, 14), batch.mouse_pos.y);
}
