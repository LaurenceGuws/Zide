const std = @import("std");
const input_actions = @import("../../../input/input_actions.zig");
const shared_types = @import("../../../types/mod.zig");

pub const ModalLayout = struct {
    card: shared_types.layout.Rect,
    confirm_button: shared_types.layout.Rect,
    cancel_button: shared_types.layout.Rect,
};

pub const Decision = enum {
    none,
    confirm,
    cancel,
    consume,
};

pub fn decideInput(
    actions: []const input_actions.InputAction,
    input_batch: *const shared_types.input.InputBatch,
    modal: ModalLayout,
) Decision {
    const close_action_pressed = blk: {
        for (actions) |action| {
            if (action.kind == .terminal_close_tab) break :blk true;
        }
        break :blk false;
    };

    const confirm_pressed = close_action_pressed or
        input_batch.keyPressed(.enter) or
        input_batch.keyPressed(.kp_enter) or
        (input_batch.keyPressed(.y) and input_batch.mods.isEmpty());
    if (confirm_pressed) return .confirm;

    const cancel_pressed = input_batch.keyPressed(.escape) or
        (input_batch.keyPressed(.n) and input_batch.mods.isEmpty());
    if (cancel_pressed) return .cancel;

    if (input_batch.mousePressed(.left)) {
        const mx = input_batch.mouse_pos.x;
        const my = input_batch.mouse_pos.y;
        if (pointInRect(mx, my, modal.confirm_button)) return .confirm;
        if (pointInRect(mx, my, modal.cancel_button)) return .cancel;
        if (!pointInRect(mx, my, modal.card)) return .cancel;
        return .consume;
    }

    return .none;
}

fn pointInRect(x: f32, y: f32, rect: shared_types.layout.Rect) bool {
    return x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height;
}

test "terminal close confirm decision maps key presses" {
    var batch = shared_types.input.InputBatch.init(std.testing.allocator);
    defer batch.deinit();
    batch.key_pressed[@intFromEnum(shared_types.input.Key.enter)] = true;

    const modal: ModalLayout = .{
        .card = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .confirm_button = .{ .x = 60, .y = 60, .width = 20, .height = 20 },
        .cancel_button = .{ .x = 30, .y = 60, .width = 20, .height = 20 },
    };

    try std.testing.expectEqual(Decision.confirm, decideInput(&.{}, &batch, modal));
}

test "terminal close confirm decision consumes in-card click and cancels outside click" {
    var batch = shared_types.input.InputBatch.init(std.testing.allocator);
    defer batch.deinit();
    batch.mouse_pressed[@intFromEnum(shared_types.input.MouseButton.left)] = true;
    batch.mouse_pos = .{ .x = 10, .y = 10 };

    const modal: ModalLayout = .{
        .card = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .confirm_button = .{ .x = 60, .y = 60, .width = 20, .height = 20 },
        .cancel_button = .{ .x = 30, .y = 60, .width = 20, .height = 20 },
    };

    try std.testing.expectEqual(Decision.consume, decideInput(&.{}, &batch, modal));
    batch.mouse_pos = .{ .x = 150, .y = 150 };
    try std.testing.expectEqual(Decision.cancel, decideInput(&.{}, &batch, modal));
}

