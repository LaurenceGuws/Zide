const std = @import("std");
const shared = @import("../shared/mod.zig");

pub const ReorderDragMeta = struct {
    active: bool,
    moved: bool,
    from_index: usize,
    to_index: usize,
};

pub fn closeIntentForActiveTab(active_tab_id: ?u64) ?shared.actions.TabAction {
    if (active_tab_id) |id| {
        return .{ .close = id };
    }
    return null;
}

pub fn reorderIntentForDrag(meta: ReorderDragMeta) ?shared.actions.TabAction {
    if (meta.active and meta.moved and meta.from_index != meta.to_index) {
        return .{
            .move = .{
                .from_index = meta.from_index,
                .to_index = meta.to_index,
            },
        };
    }
    return null;
}

test "close intent helper maps optional active tab id" {
    try std.testing.expectEqual(@as(?shared.actions.TabAction, null), closeIntentForActiveTab(null));

    const intent = closeIntentForActiveTab(42) orelse return error.TestUnexpectedResult;
    switch (intent) {
        .close => |id| try std.testing.expectEqual(@as(u64, 42), id),
        else => return error.TestUnexpectedResult,
    }
}

test "reorder intent helper emits only for real drag moves" {
    const no_drag = ReorderDragMeta{
        .active = false,
        .moved = false,
        .from_index = 0,
        .to_index = 0,
    };
    try std.testing.expectEqual(@as(?shared.actions.TabAction, null), reorderIntentForDrag(no_drag));

    const click_only = ReorderDragMeta{
        .active = true,
        .moved = false,
        .from_index = 1,
        .to_index = 1,
    };
    try std.testing.expectEqual(@as(?shared.actions.TabAction, null), reorderIntentForDrag(click_only));

    const moved = ReorderDragMeta{
        .active = true,
        .moved = true,
        .from_index = 3,
        .to_index = 1,
    };
    const intent = reorderIntentForDrag(moved) orelse return error.TestUnexpectedResult;
    switch (intent) {
        .move => |mv| {
            try std.testing.expectEqual(@as(usize, 3), mv.from_index);
            try std.testing.expectEqual(@as(usize, 1), mv.to_index);
        },
        else => return error.TestUnexpectedResult,
    }
}
