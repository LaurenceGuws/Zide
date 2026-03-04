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

pub fn modalLayout(layout: shared_types.layout.WidgetLayout, ui_scale: f32) ModalLayout {
    const margin = 24.0 * ui_scale;
    const desired_w = 540.0 * ui_scale;
    const card_w = @max(280.0 * ui_scale, @min(desired_w, layout.window.width - margin * 2.0));
    const card_h = 150.0 * ui_scale;
    const card_x = layout.window.x + (layout.window.width - card_w) / 2.0;
    const card_y = layout.window.y + (layout.window.height - card_h) / 2.0;

    const button_h = 34.0 * ui_scale;
    const confirm_w = 178.0 * ui_scale;
    const cancel_w = 128.0 * ui_scale;
    const button_gap = 10.0 * ui_scale;
    const button_y = card_y + card_h - button_h - 14.0 * ui_scale;
    const confirm_x = card_x + card_w - confirm_w - 14.0 * ui_scale;
    const cancel_x = confirm_x - cancel_w - button_gap;

    return .{
        .card = .{
            .x = card_x,
            .y = card_y,
            .width = card_w,
            .height = card_h,
        },
        .confirm_button = .{
            .x = confirm_x,
            .y = button_y,
            .width = confirm_w,
            .height = button_h,
        },
        .cancel_button = .{
            .x = cancel_x,
            .y = button_y,
            .width = cancel_w,
            .height = button_h,
        },
    };
}

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

test "terminal close confirm modal layout stays within window and buttons are inside card" {
    const layout: shared_types.layout.WidgetLayout = .{
        .window = .{ .x = 0, .y = 0, .width = 800, .height = 600 },
        .options_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
        .tab_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
        .side_nav = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
        .editor = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
        .terminal = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
        .status_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    };
    const modal = modalLayout(layout, 1.0);

    try std.testing.expect(modal.card.x >= layout.window.x);
    try std.testing.expect(modal.card.y >= layout.window.y);
    try std.testing.expect(modal.card.x + modal.card.width <= layout.window.x + layout.window.width);
    try std.testing.expect(modal.card.y + modal.card.height <= layout.window.y + layout.window.height);
    try std.testing.expect(pointInRect(modal.confirm_button.x, modal.confirm_button.y, modal.card));
    try std.testing.expect(pointInRect(modal.cancel_button.x, modal.cancel_button.y, modal.card));
}
