const input_actions = @import("../input/input_actions.zig");
const app_logger = @import("../app_logger.zig");

pub const Hooks = struct {
    reload: *const fn (ctx: *anyopaque) anyerror!void,
    show_notice: *const fn (ctx: *anyopaque, success: bool) void,
};

pub fn handle(
    actions: []const input_actions.InputAction,
    ctx: *anyopaque,
    hooks: Hooks,
) bool {
    const log = app_logger.logger("app.reload_config");
    var handled = false;
    for (actions) |action| {
        if (action.kind != .reload_config) continue;
        hooks.reload(ctx) catch |err| {
            log.logf(.warning, "reload config failed err={s}", .{@errorName(err)});
            hooks.show_notice(ctx, false);
            handled = true;
            continue;
        };
        hooks.show_notice(ctx, true);
        handled = true;
    }
    return handled;
}
