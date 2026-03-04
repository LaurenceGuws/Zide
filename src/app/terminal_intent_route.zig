const app_modes = @import("modes/mod.zig");
const app_tab_action_route = @import("tab_action_route.zig");
const app_terminal_tab_intents = @import("terminal_tab_intents.zig");
const std = @import("std");

pub fn routeCloseByTabIdAndSync(
    tab_id: ?u64,
    ctx: *anyopaque,
    route_fn: *const fn (*anyopaque, app_modes.shared.actions.TabAction) anyerror!void,
) !bool {
    return app_tab_action_route.routeOptionalTabAction(
        app_terminal_tab_intents.closeIntentForTabId(tab_id),
        ctx,
        route_fn,
    );
}

pub fn routeActivateByTabIdAndSync(
    tab_id: ?u64,
    ctx: *anyopaque,
    route_fn: *const fn (*anyopaque, app_modes.shared.actions.TabAction) anyerror!void,
) !bool {
    return app_tab_action_route.routeOptionalTabAction(
        app_terminal_tab_intents.activateIntentForTabId(tab_id),
        ctx,
        route_fn,
    );
}

test "routeCloseByTabIdAndSync emits close action only when id exists" {
    const Ctx = struct {
        calls: usize = 0,
        last_close_id: ?u64 = null,
    };
    var ctx = Ctx{};

    try std.testing.expect(!try routeCloseByTabIdAndSync(
        null,
        @ptrCast(&ctx),
        struct {
            fn call(_: *anyopaque, _: app_modes.shared.actions.TabAction) !void {
                return error.TestUnexpectedResult;
            }
        }.call,
    ));

    try std.testing.expect(try routeCloseByTabIdAndSync(
        12,
        @ptrCast(&ctx),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                payload.calls += 1;
                switch (action) {
                    .close => |id| payload.last_close_id = id,
                    else => return error.TestUnexpectedResult,
                }
            }
        }.call,
    ));
    try std.testing.expectEqual(@as(usize, 1), ctx.calls);
    try std.testing.expectEqual(@as(?u64, 12), ctx.last_close_id);
}

test "routeActivateByTabIdAndSync emits activate action only when id exists" {
    const Ctx = struct {
        calls: usize = 0,
        last_activate_id: ?u64 = null,
    };
    var ctx = Ctx{};

    try std.testing.expect(!try routeActivateByTabIdAndSync(
        null,
        @ptrCast(&ctx),
        struct {
            fn call(_: *anyopaque, _: app_modes.shared.actions.TabAction) !void {
                return error.TestUnexpectedResult;
            }
        }.call,
    ));

    try std.testing.expect(try routeActivateByTabIdAndSync(
        34,
        @ptrCast(&ctx),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                payload.calls += 1;
                switch (action) {
                    .activate => |id| payload.last_activate_id = id,
                    else => return error.TestUnexpectedResult,
                }
            }
        }.call,
    ));
    try std.testing.expectEqual(@as(usize, 1), ctx.calls);
    try std.testing.expectEqual(@as(?u64, 34), ctx.last_activate_id);
}
