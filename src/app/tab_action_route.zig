const app_modes = @import("modes/mod.zig");

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
