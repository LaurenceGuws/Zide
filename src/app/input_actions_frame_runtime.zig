const input_actions = @import("../input/input_actions.zig");

pub const Hooks = struct {
    handle_shortcut_action: *const fn (*anyopaque, input_actions.ActionKind, f64, *bool) anyerror!bool,
};

pub fn handle(
    actions: []const input_actions.InputAction,
    now: f64,
    ctx: *anyopaque,
    hooks: Hooks,
) !bool {
    var handled_zoom = false;
    for (actions) |action| {
        if (try hooks.handle_shortcut_action(ctx, action.kind, now, &handled_zoom)) {
            return true;
        }
    }
    if (handled_zoom) return true;
    return false;
}
