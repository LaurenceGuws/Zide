const input_actions = @import("../input/input_actions.zig");

pub const RuntimeHooks = struct {
    copy: *const fn (ctx: *anyopaque) anyerror!bool,
    paste: *const fn (ctx: *anyopaque) anyerror!bool,
    scrollback_pager: *const fn (ctx: *anyopaque) anyerror!bool,
};

pub const RuntimeResult = struct {
    handled: bool = false,
    needs_redraw: bool = false,
};

pub fn handle(
    actions: []const input_actions.InputAction,
    ctx: *anyopaque,
    hooks: RuntimeHooks,
) !RuntimeResult {
    var out: RuntimeResult = .{};
    for (actions) |action| {
        switch (action.kind) {
            .copy => {
                if (try hooks.copy(ctx)) out.handled = true;
            },
            .paste => {
                if (try hooks.paste(ctx)) {
                    out.handled = true;
                    out.needs_redraw = true;
                }
            },
            .terminal_scrollback_pager => {
                if (try hooks.scrollback_pager(ctx)) out.handled = true;
            },
            else => {},
        }
    }
    return out;
}

