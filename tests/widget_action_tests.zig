const std = @import("std");
const types = @import("../src/types/mod.zig");

test "widget action unions compile" {
    const alloc = std.testing.allocator;
    _ = alloc;

    const action = types.actions.WidgetAction{
        .editor = .{ .request_save = {} },
    };
    _ = action;

    const action2 = types.actions.WidgetAction{
        .terminal = .{ .copy_selection = {} },
    };
    _ = action2;
}
