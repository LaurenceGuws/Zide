const app_modes = @import("modes/mod.zig");
const app_terminal_intent_route = @import("terminal_intent_route.zig");
const app_terminal_workspace_route = @import("terminal_workspace_route.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");
const std = @import("std");

pub const Intent = enum {
    close,
    activate,
};

pub const TabActionRouteFn = *const fn (*anyopaque, app_modes.shared.actions.TabAction) anyerror!void;

pub fn routeByTabIdAndSync(
    intent: Intent,
    tab_id: ?u64,
    route_ctx: *anyopaque,
    route_fn: TabActionRouteFn,
) !bool {
    return switch (intent) {
        .close => app_terminal_intent_route.routeCloseByTabIdAndSync(tab_id, route_ctx, route_fn),
        .activate => app_terminal_intent_route.routeActivateByTabIdAndSync(tab_id, route_ctx, route_fn),
    };
}

const ActiveRouteCtx = struct {
    intent: Intent,
    route_ctx: *anyopaque,
    route_fn: TabActionRouteFn,
};

fn routeFromWorkspaceCtx(raw: *anyopaque, tab_id: ?u64) !bool {
    const ctx: *ActiveRouteCtx = @ptrCast(@alignCast(raw));
    return routeByTabIdAndSync(ctx.intent, tab_id, ctx.route_ctx, ctx.route_fn);
}

pub fn routeForActiveWorkspaceTabAndSync(
    intent: Intent,
    terminal_workspace: *?terminal_mod.TerminalWorkspace,
    route_ctx: *anyopaque,
    route_fn: TabActionRouteFn,
) !bool {
    var ctx = ActiveRouteCtx{
        .intent = intent,
        .route_ctx = route_ctx,
        .route_fn = route_fn,
    };
    return app_terminal_workspace_route.routeActiveTabId(
        terminal_workspace,
        @ptrCast(&ctx),
        routeFromWorkspaceCtx,
    );
}

test "routeByTabIdAndSync emits close and activate only when id exists" {
    const Ctx = struct {
        close_calls: usize = 0,
        activate_calls: usize = 0,
    };
    var ctx = Ctx{};

    try std.testing.expect(!try routeByTabIdAndSync(
        .close,
        null,
        @ptrCast(&ctx),
        struct {
            fn call(_: *anyopaque, _: app_modes.shared.actions.TabAction) !void {
                return error.TestUnexpectedResult;
            }
        }.call,
    ));

    try std.testing.expect(try routeByTabIdAndSync(
        .close,
        12,
        @ptrCast(&ctx),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                switch (action) {
                    .close => payload.close_calls += 1,
                    else => return error.TestUnexpectedResult,
                }
            }
        }.call,
    ));

    try std.testing.expect(!try routeByTabIdAndSync(
        .activate,
        null,
        @ptrCast(&ctx),
        struct {
            fn call(_: *anyopaque, _: app_modes.shared.actions.TabAction) !void {
                return error.TestUnexpectedResult;
            }
        }.call,
    ));

    try std.testing.expect(try routeByTabIdAndSync(
        .activate,
        34,
        @ptrCast(&ctx),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                switch (action) {
                    .activate => payload.activate_calls += 1,
                    else => return error.TestUnexpectedResult,
                }
            }
        }.call,
    ));

    try std.testing.expectEqual(@as(usize, 1), ctx.close_calls);
    try std.testing.expectEqual(@as(usize, 1), ctx.activate_calls);
}

