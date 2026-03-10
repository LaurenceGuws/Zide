const app_editor_tab_intents = @import("editor_tab_intents.zig");
const app_modes = @import("../modes/mod.zig");
const app_tab_action_route = @import("../tab_action_route.zig");
const std = @import("std");

pub fn routeCreateAndSync(
    ctx: *anyopaque,
    route_fn: *const fn (*anyopaque, app_modes.shared.actions.TabAction) anyerror!void,
) !bool {
    return app_tab_action_route.routeOptionalTabAction(
        app_editor_tab_intents.createIntent(),
        ctx,
        route_fn,
    );
}

pub fn routeActivateByIndexAndSync(
    index: usize,
    ctx: *anyopaque,
    route_fn: *const fn (*anyopaque, app_modes.shared.actions.TabAction) anyerror!void,
) !bool {
    return app_tab_action_route.routeOptionalTabAction(
        app_editor_tab_intents.activateByIndexIntent(index),
        ctx,
        route_fn,
    );
}

test "routeCreateAndSync emits create action" {
    const Ctx = struct {
        calls: usize = 0,
    };
    var ctx = Ctx{};
    const routed = try routeCreateAndSync(
        @ptrCast(&ctx),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                payload.calls += 1;
                switch (action) {
                    .create => {},
                    else => return error.TestUnexpectedResult,
                }
            }
        }.call,
    );
    try std.testing.expect(routed);
    try std.testing.expectEqual(@as(usize, 1), ctx.calls);
}

test "routeActivateByIndexAndSync emits activate_by_index action" {
    const Ctx = struct {
        calls: usize = 0,
        last_index: ?usize = null,
    };
    var ctx = Ctx{};
    const routed = try routeActivateByIndexAndSync(
        5,
        @ptrCast(&ctx),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                payload.calls += 1;
                switch (action) {
                    .activate_by_index => |idx| payload.last_index = idx,
                    else => return error.TestUnexpectedResult,
                }
            }
        }.call,
    );
    try std.testing.expect(routed);
    try std.testing.expectEqual(@as(usize, 1), ctx.calls);
    try std.testing.expectEqual(@as(?usize, 5), ctx.last_index);
}
