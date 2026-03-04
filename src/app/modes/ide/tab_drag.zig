const std = @import("std");
const tab_bar = @import("../../../ui/widgets/tab_bar.zig");
const tab_intents = @import("tab_intents.zig");
const shared = @import("../shared/mod.zig");
const shared_types = @import("../../../types/mod.zig");

pub const ReleasePlan = struct {
    intent: ?shared.actions.TabAction,
    handle_click: bool,
    mark_redraw: bool,
    sync_active_tab: bool,
};

pub const DragFrame = struct {
    updated: bool,
    release: ?tab_bar.TabBar.DragEndState,
};

pub fn processDragFrame(
    tabs: *tab_bar.TabBar,
    input_batch: *const shared_types.input.InputBatch,
    mouse: shared_types.input.MousePos,
    bar_x: f32,
    bar_y: f32,
    bar_width: f32,
    enabled: bool,
) DragFrame {
    var frame: DragFrame = .{
        .updated = false,
        .release = null,
    };

    if (enabled and input_batch.mouseDown(.left)) {
        frame.updated = tabs.updateDrag(mouse.x, mouse.y, bar_x, bar_y, bar_width, true);
    }
    if (enabled and input_batch.mouseReleased(.left)) {
        frame.release = tabs.endDrag();
    }

    return frame;
}

pub fn reorderIntentForDragEnd(drag_end: tab_bar.TabBar.DragEndState) ?shared.actions.TabAction {
    return tab_intents.reorderIntentForDrag(.{
        .active = drag_end.active,
        .moved = drag_end.moved,
        .from_index = drag_end.from_index,
        .to_index = drag_end.to_index,
    });
}

pub fn shouldHandleClickAfterDragEnd(drag_end: tab_bar.TabBar.DragEndState) bool {
    return drag_end.active and !drag_end.moved;
}

pub fn shouldMarkRedrawAfterDragEnd(drag_end: tab_bar.TabBar.DragEndState) bool {
    return drag_end.active;
}

pub fn terminalReleasePlan(drag_end: tab_bar.TabBar.DragEndState) ReleasePlan {
    return .{
        .intent = reorderIntentForDragEnd(drag_end),
        .handle_click = shouldHandleClickAfterDragEnd(drag_end),
        .mark_redraw = shouldMarkRedrawAfterDragEnd(drag_end),
        .sync_active_tab = false,
    };
}

pub fn ideEditorReleasePlan(drag_end: tab_bar.TabBar.DragEndState) ReleasePlan {
    const intent = reorderIntentForDragEnd(drag_end);
    const moved = intent != null;
    return .{
        .intent = intent,
        .handle_click = false,
        .mark_redraw = moved,
        .sync_active_tab = moved,
    };
}

test "tab drag helper emits reorder intent only for active moved drag" {
    const none_state: tab_bar.TabBar.DragEndState = .{
        .active = true,
        .moved = false,
        .from_index = 1,
        .to_index = 1,
    };
    try std.testing.expectEqual(@as(?shared.actions.TabAction, null), reorderIntentForDragEnd(none_state));

    const moved_state: tab_bar.TabBar.DragEndState = .{
        .active = true,
        .moved = true,
        .from_index = 3,
        .to_index = 0,
    };
    const intent = reorderIntentForDragEnd(moved_state) orelse return error.TestUnexpectedResult;
    switch (intent) {
        .move => |mv| {
            try std.testing.expectEqual(@as(usize, 3), mv.from_index);
            try std.testing.expectEqual(@as(usize, 0), mv.to_index);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "tab drag helper click and redraw flags follow drag end state" {
    const click_state: tab_bar.TabBar.DragEndState = .{
        .active = true,
        .moved = false,
        .from_index = 0,
        .to_index = 0,
    };
    try std.testing.expect(shouldHandleClickAfterDragEnd(click_state));
    try std.testing.expect(shouldMarkRedrawAfterDragEnd(click_state));

    const inactive_state: tab_bar.TabBar.DragEndState = .{
        .active = false,
        .moved = false,
        .from_index = 0,
        .to_index = 0,
    };
    try std.testing.expect(!shouldHandleClickAfterDragEnd(inactive_state));
    try std.testing.expect(!shouldMarkRedrawAfterDragEnd(inactive_state));
}

test "terminal release plan mirrors existing click+redraw behavior" {
    const click_state: tab_bar.TabBar.DragEndState = .{
        .active = true,
        .moved = false,
        .from_index = 0,
        .to_index = 0,
    };
    const click_plan = terminalReleasePlan(click_state);
    try std.testing.expectEqual(@as(?shared.actions.TabAction, null), click_plan.intent);
    try std.testing.expect(click_plan.handle_click);
    try std.testing.expect(click_plan.mark_redraw);
    try std.testing.expect(!click_plan.sync_active_tab);
}

test "ide editor release plan only marks moved reorder path" {
    const moved_state: tab_bar.TabBar.DragEndState = .{
        .active = true,
        .moved = true,
        .from_index = 2,
        .to_index = 1,
    };
    const moved_plan = ideEditorReleasePlan(moved_state);
    try std.testing.expect(moved_plan.intent != null);
    try std.testing.expect(!moved_plan.handle_click);
    try std.testing.expect(moved_plan.mark_redraw);
    try std.testing.expect(moved_plan.sync_active_tab);

    const idle_state: tab_bar.TabBar.DragEndState = .{
        .active = true,
        .moved = false,
        .from_index = 2,
        .to_index = 2,
    };
    const idle_plan = ideEditorReleasePlan(idle_state);
    try std.testing.expectEqual(@as(?shared.actions.TabAction, null), idle_plan.intent);
    try std.testing.expect(!idle_plan.handle_click);
    try std.testing.expect(!idle_plan.mark_redraw);
    try std.testing.expect(!idle_plan.sync_active_tab);
}

test "drag frame helper reports update and release transitions" {
    var tabs = tab_bar.TabBar.init(std.testing.allocator);
    defer tabs.deinit();
    try tabs.addTab("a", .editor);
    try tabs.addTab("b", .editor);
    _ = tabs.beginDrag(10, 5, 0, 0, 300);

    var batch = shared_types.input.InputBatch.init(std.testing.allocator);
    defer batch.deinit();
    batch.mouse_down[@intFromEnum(shared_types.input.MouseButton.left)] = true;
    batch.mouse_pos = .{ .x = 200, .y = 5 };
    var frame = processDragFrame(&tabs, &batch, batch.mouse_pos, 0, 0, 300, true);
    try std.testing.expect(frame.updated);
    try std.testing.expectEqual(@as(?tab_bar.TabBar.DragEndState, null), frame.release);

    batch.mouse_down[@intFromEnum(shared_types.input.MouseButton.left)] = false;
    batch.mouse_released[@intFromEnum(shared_types.input.MouseButton.left)] = true;
    frame = processDragFrame(&tabs, &batch, batch.mouse_pos, 0, 0, 300, true);
    try std.testing.expect(!frame.updated);
    try std.testing.expect(frame.release != null);
}
