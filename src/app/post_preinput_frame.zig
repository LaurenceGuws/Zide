const shared_types = @import("../types/mod.zig");
const app_shell = @import("../app_shell.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;
const Shell = app_shell.Shell;

pub const Result = struct {
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    term_y: f32,
    needs_redraw: bool = false,
    note_input: bool = false,
};

pub const Hooks = struct {
    apply_ui_scale: *const fn (*anyopaque) void,
    refresh_terminal_sizing: *const fn (*anyopaque) anyerror!void,
    handle_window_resize_event: *const fn (*anyopaque, *Shell, f64) anyerror!void,
    compute_layout: *const fn (*anyopaque, f32, f32) layout_types.WidgetLayout,
    handle_cursor_blink_arming: *const fn (*anyopaque, f64) void,
    handle_deferred_terminal_resize: *const fn (*anyopaque, *Shell, layout_types.WidgetLayout, f64) anyerror!void,
    handle_pointer_activity: *const fn (
        *anyopaque,
        *input_types.InputBatch,
        layout_types.WidgetLayout,
        input_types.MousePos,
        f64,
    ) void,
    handle_terminal_split_resize: *const fn (
        *anyopaque,
        *Shell,
        *input_types.InputBatch,
        layout_types.WidgetLayout,
        f32,
        f32,
        f64,
    ) anyerror!void,
};

pub fn handle(
    shell: *Shell,
    input_batch: *input_types.InputBatch,
    now: f64,
    ctx: *anyopaque,
    hooks: Hooks,
) !Result {
    var out_needs_redraw = false;
    var out_note_input = false;

    if (try shell.applyPendingZoom(now)) {
        hooks.apply_ui_scale(ctx);
        try hooks.refresh_terminal_sizing(ctx);
        out_needs_redraw = true;
        out_note_input = true;
    }
    try hooks.handle_window_resize_event(ctx, shell, now);

    const width = @as(f32, @floatFromInt(shell.width()));
    const height = @as(f32, @floatFromInt(shell.height()));
    const layout = hooks.compute_layout(ctx, width, height);

    hooks.handle_cursor_blink_arming(ctx, now);
    try hooks.handle_deferred_terminal_resize(ctx, shell, layout, now);

    const mouse = input_batch.mouse_pos;
    const term_y = layout.terminal.y;
    hooks.handle_pointer_activity(ctx, input_batch, layout, mouse, now);
    try hooks.handle_terminal_split_resize(ctx, shell, input_batch, layout, layout.terminal.width, height, now);

    return .{
        .layout = layout,
        .mouse = mouse,
        .term_y = term_y,
        .needs_redraw = out_needs_redraw,
        .note_input = out_note_input,
    };
}
