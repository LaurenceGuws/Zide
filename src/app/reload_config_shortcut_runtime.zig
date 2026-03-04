const input_actions = @import("../input/input_actions.zig");

pub const Hooks = struct {
    reload: *const fn (ctx: *anyopaque) anyerror!void,
    show_notice: *const fn (ctx: *anyopaque, success: bool) void,
};

pub fn handle(
    actions: []const input_actions.InputAction,
    ctx: *anyopaque,
    hooks: Hooks,
) bool {
    var handled = false;
    for (actions) |action| {
        if (action.kind != .reload_config) continue;
        hooks.reload(ctx) catch {
            hooks.show_notice(ctx, false);
            handled = true;
            continue;
        };
        hooks.show_notice(ctx, true);
        handled = true;
    }
    return handled;
}

