const app_modes = @import("modes/mod.zig");
const std = @import("std");

pub fn createIntent() app_modes.shared.actions.TabAction {
    return .create;
}

pub fn activateByIndexIntent(index: usize) app_modes.shared.actions.TabAction {
    return .{ .activate_by_index = index };
}

test "createIntent emits create action" {
    const intent = createIntent();
    switch (intent) {
        .create => {},
        else => return error.TestUnexpectedResult,
    }
}

test "activateByIndexIntent emits activate_by_index action" {
    const intent = activateByIndexIntent(3);
    switch (intent) {
        .activate_by_index => |idx| try std.testing.expectEqual(@as(usize, 3), idx),
        else => return error.TestUnexpectedResult,
    }
}
