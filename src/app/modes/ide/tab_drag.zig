const std = @import("std");
const tab_bar = @import("../../../ui/widgets/tab_bar.zig");
const tab_intents = @import("tab_intents.zig");
const shared = @import("../shared/mod.zig");

pub const ReleasePlan = struct {
    intent: ?shared.actions.TabAction,
    handle_click: bool,
    mark_redraw: bool,
    sync_active_tab: bool,
};

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
