const input_actions = @import("../../input/input_actions.zig");

pub fn forFocus(
    focus: input_actions.FocusKind,
    actions: []const input_actions.InputAction,
) bool {
    if (focus != .terminal) return false;
    for (actions) |action| {
        switch (action.kind) {
            .copy, .paste => return true,
            else => {},
        }
    }
    return false;
}
