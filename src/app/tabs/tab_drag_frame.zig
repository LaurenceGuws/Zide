const app_bootstrap = @import("../bootstrap.zig");
const app_modes = @import("../modes/mod.zig");
const shared_types = @import("../../types/mod.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;

pub const Hooks = struct {
    handle_terminal_tab_drag_input: *const fn (
        *anyopaque,
        *input_types.InputBatch,
        layout_types.WidgetLayout,
        input_types.MousePos,
        f64,
    ) anyerror!void,
    handle_ide_tab_drag_input: *const fn (
        *anyopaque,
        *input_types.InputBatch,
        layout_types.WidgetLayout,
        input_types.MousePos,
        f64,
    ) anyerror!void,
};

pub fn handle(
    app_mode: app_bootstrap.AppMode,
    input_batch: *input_types.InputBatch,
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    now: f64,
    ctx: *anyopaque,
    hooks: Hooks,
) !void {
    if (app_modes.ide.canDriveTerminalTabDrag(app_mode)) {
        try hooks.handle_terminal_tab_drag_input(ctx, input_batch, layout, mouse, now);
    }
    if (app_modes.ide.isIde(app_mode)) {
        try hooks.handle_ide_tab_drag_input(ctx, input_batch, layout, mouse, now);
    }
}
