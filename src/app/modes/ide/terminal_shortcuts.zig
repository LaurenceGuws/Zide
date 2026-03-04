const std = @import("std");
const input_actions = @import("../../../input/input_actions.zig");
const tab_intents = @import("tab_intents.zig");

pub const CycleDirection = enum {
    next,
    prev,
};

pub const ShortcutIntent = union(enum) {
    create,
    close,
    cycle: CycleDirection,
    focus: tab_intents.TerminalFocusRoute,
};

pub fn terminalShortcutIntentForAction(kind: input_actions.ActionKind) ?ShortcutIntent {
    return switch (kind) {
        .terminal_new_tab => .create,
        .terminal_close_tab => .close,
        .terminal_next_tab => .{ .cycle = .next },
        .terminal_prev_tab => .{ .cycle = .prev },
        else => if (tab_intents.terminalFocusRouteForAction(kind)) |route| .{ .focus = route } else null,
    };
}

test "terminal shortcut intent maps tab lifecycle actions" {
    try std.testing.expectEqual(ShortcutIntent.create, terminalShortcutIntentForAction(.terminal_new_tab).?);
    try std.testing.expectEqual(ShortcutIntent.close, terminalShortcutIntentForAction(.terminal_close_tab).?);
    try std.testing.expectEqual(@as(CycleDirection, .next), terminalShortcutIntentForAction(.terminal_next_tab).?.cycle);
    try std.testing.expectEqual(@as(CycleDirection, .prev), terminalShortcutIntentForAction(.terminal_prev_tab).?.cycle);
    try std.testing.expectEqual(@as(?ShortcutIntent, null), terminalShortcutIntentForAction(.new_editor));
}

test "terminal shortcut intent maps focus actions through typed routes" {
    const intent = terminalShortcutIntentForAction(.terminal_focus_tab_4) orelse return error.TestUnexpectedResult;
    switch (intent) {
        .focus => |route| {
            try std.testing.expectEqual(@as(usize, 3), route.index);
            switch (route.intent) {
                .activate_by_index => |idx| try std.testing.expectEqual(@as(usize, 3), idx),
                else => return error.TestUnexpectedResult,
            }
        },
        else => return error.TestUnexpectedResult,
    }
}

