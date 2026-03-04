const std = @import("std");
const tab_bar = @import("../../../ui/widgets/tab_bar.zig");
const tab_intents = @import("tab_intents.zig");
const shared = @import("../shared/mod.zig");

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

