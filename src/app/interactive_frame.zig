const shared_types = @import("../types/mod.zig");
const app_shell = @import("../app_shell.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;
const Shell = app_shell.Shell;

pub const Frame = struct {
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    term_y: f32,
};

pub const Hooks = struct {
    handle_input_actions: *const fn (*anyopaque, *Shell, f64) anyerror!bool,
    handle_mouse_pressed: *const fn (*anyopaque, *Shell, layout_types.WidgetLayout, input_types.MousePos, f32, *input_types.InputBatch, f64) anyerror!void,
    handle_tab_drag: *const fn (*anyopaque, *input_types.InputBatch, layout_types.WidgetLayout, input_types.MousePos, f64) anyerror!void,
    handle_active_view: *const fn (
        *anyopaque,
        *Shell,
        layout_types.WidgetLayout,
        input_types.MousePos,
        *input_types.InputBatch,
        bool,
        bool,
        f64,
    ) anyerror!void,
};

pub fn handle(
    shell: *Shell,
    frame: Frame,
    input_batch: *input_types.InputBatch,
    suppress_terminal_shortcuts: bool,
    terminal_close_modal_active: bool,
    now: f64,
    ctx: *anyopaque,
    hooks: Hooks,
) !void {
    if (try hooks.handle_input_actions(ctx, shell, now)) {
        return;
    }

    try hooks.handle_mouse_pressed(ctx, shell, frame.layout, frame.mouse, frame.term_y, input_batch, now);
    try hooks.handle_tab_drag(ctx, input_batch, frame.layout, frame.mouse, now);

    try hooks.handle_active_view(
        ctx,
        shell,
        frame.layout,
        frame.mouse,
        input_batch,
        suppress_terminal_shortcuts,
        terminal_close_modal_active,
        now,
    );
}
