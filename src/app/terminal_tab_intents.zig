const app_modes = @import("modes/mod.zig");
const std = @import("std");

pub fn closeIntentForTabId(tab_id: ?u64) ?app_modes.shared.actions.TabAction {
    return app_modes.ide.closeIntentForActiveTab(tab_id);
}

pub fn cycleIntentForDirection(
    dir: app_modes.ide.TerminalShortcutCycleDirection,
) app_modes.shared.actions.TabAction {
    return if (dir == .next) .next else .prev;
}

pub fn activateIntentForTabId(tab_id: ?u64) ?app_modes.shared.actions.TabAction {
    if (tab_id) |id| {
        return .{ .activate = id };
    }
    return null;
}

test "closeIntentForTabId emits only for present id" {
    try std.testing.expectEqual(@as(?app_modes.shared.actions.TabAction, null), closeIntentForTabId(null));
    const intent = closeIntentForTabId(7) orelse return error.TestUnexpectedResult;
    switch (intent) {
        .close => |id| try std.testing.expectEqual(@as(u64, 7), id),
        else => return error.TestUnexpectedResult,
    }
}

test "cycleIntentForDirection maps next and prev" {
    const next = cycleIntentForDirection(.next);
    const prev = cycleIntentForDirection(.prev);
    switch (next) {
        .next => {},
        else => return error.TestUnexpectedResult,
    }
    switch (prev) {
        .prev => {},
        else => return error.TestUnexpectedResult,
    }
}

test "activateIntentForTabId emits optional activate intent" {
    try std.testing.expectEqual(@as(?app_modes.shared.actions.TabAction, null), activateIntentForTabId(null));
    const intent = activateIntentForTabId(99) orelse return error.TestUnexpectedResult;
    switch (intent) {
        .activate => |id| try std.testing.expectEqual(@as(u64, 99), id),
        else => return error.TestUnexpectedResult,
    }
}
