const std = @import("std");
const shared = @import("../shared/mod.zig");
const input_actions = @import("../../../input/input_actions.zig");

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

pub fn terminalFocusIndexForAction(kind: input_actions.ActionKind) ?usize {
    return switch (kind) {
        .terminal_focus_tab_1 => 0,
        .terminal_focus_tab_2 => 1,
        .terminal_focus_tab_3 => 2,
        .terminal_focus_tab_4 => 3,
        .terminal_focus_tab_5 => 4,
        .terminal_focus_tab_6 => 5,
        .terminal_focus_tab_7 => 6,
        .terminal_focus_tab_8 => 7,
        .terminal_focus_tab_9 => 8,
        else => null,
    };
}

pub fn terminalFocusIntentForAction(kind: input_actions.ActionKind) ?shared.actions.TabAction {
    if (terminalFocusIndexForAction(kind)) |idx| {
        return .{ .activate_by_index = idx };
    }
    return null;
}

pub const TerminalFocusRoute = struct {
    index: usize,
    intent: shared.actions.TabAction,
};

pub fn terminalFocusRouteForAction(kind: input_actions.ActionKind) ?TerminalFocusRoute {
    if (terminalFocusIndexForAction(kind)) |idx| {
        return .{
            .index = idx,
            .intent = .{ .activate_by_index = idx },
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

test "terminal focus index helper maps focus actions only" {
    try std.testing.expectEqual(@as(?usize, 0), terminalFocusIndexForAction(.terminal_focus_tab_1));
    try std.testing.expectEqual(@as(?usize, 8), terminalFocusIndexForAction(.terminal_focus_tab_9));
    try std.testing.expectEqual(@as(?usize, null), terminalFocusIndexForAction(.terminal_new_tab));
}

test "terminal focus intent helper maps focus actions to activate_by_index" {
    const intent = terminalFocusIntentForAction(.terminal_focus_tab_3) orelse return error.TestUnexpectedResult;
    switch (intent) {
        .activate_by_index => |idx| try std.testing.expectEqual(@as(usize, 2), idx),
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expectEqual(@as(?shared.actions.TabAction, null), terminalFocusIntentForAction(.terminal_new_tab));
}

test "terminal focus route helper returns both index and intent" {
    const route = terminalFocusRouteForAction(.terminal_focus_tab_2) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 1), route.index);
    switch (route.intent) {
        .activate_by_index => |idx| try std.testing.expectEqual(@as(usize, 1), idx),
        else => return error.TestUnexpectedResult,
    }
}
