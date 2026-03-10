const app_modes = @import("../modes/mod.zig");
const std = @import("std");

pub fn routeOptionalTabAction(
    tab_action: ?app_modes.shared.actions.TabAction,
    ctx: *anyopaque,
    route_fn: *const fn (*anyopaque, app_modes.shared.actions.TabAction) anyerror!void,
) !bool {
    if (tab_action) |action| {
        try route_fn(ctx, action);
        return true;
    }
    return false;
}

test "routeOptionalTabAction routes present action and skips null" {
    const Ctx = struct {
        calls: usize = 0,
        last_close_id: ?u64 = null,
    };

    var ctx = Ctx{};
    const routed = try routeOptionalTabAction(
        .{ .close = 77 },
        @ptrCast(&ctx),
        struct {
            fn route(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                payload.calls += 1;
                switch (action) {
                    .close => |id| payload.last_close_id = id,
                    else => return error.TestUnexpectedResult,
                }
            }
        }.route,
    );
    try std.testing.expect(routed);
    try std.testing.expectEqual(@as(usize, 1), ctx.calls);
    try std.testing.expectEqual(@as(?u64, 77), ctx.last_close_id);

    const skipped = try routeOptionalTabAction(
        null,
        @ptrCast(&ctx),
        struct {
            fn route(_: *anyopaque, _: app_modes.shared.actions.TabAction) !void {
                return error.TestUnexpectedResult;
            }
        }.route,
    );
    try std.testing.expect(!skipped);
    try std.testing.expectEqual(@as(usize, 1), ctx.calls);
}
