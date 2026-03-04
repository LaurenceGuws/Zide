const app_shell = @import("../app_shell.zig");
const input_actions = @import("../input/input_actions.zig");
const shared_types = @import("../types/mod.zig");

const input_types = shared_types.input;
const Shell = app_shell.Shell;

pub const PreInputResult = struct {
    suppress_terminal_shortcuts: bool,
    terminal_close_modal_active: bool,
    handled_shortcut: bool,
    consumed: bool,
};

pub const Result = struct {
    now: f64,
    suppress_terminal_shortcuts: bool,
    terminal_close_modal_active: bool,
};

pub const Hooks = struct {
    handle_font_sample_frame: *const fn (*anyopaque, *Shell, *input_types.InputBatch) bool,
    handle_widget_input_frame: *const fn (*anyopaque) anyerror!void,
    tick_config_reload_notice_frame: *const fn (*anyopaque, f64) void,
    route_input_for_current_focus: *const fn (*anyopaque, *input_types.InputBatch) input_actions.FocusKind,
    handle_pre_input_shortcut_frame: *const fn (*anyopaque, *Shell, *input_types.InputBatch, input_actions.FocusKind, f64) anyerror!PreInputResult,
    note_input: *const fn (*anyopaque, f64) void,
    set_last_input_snapshot: *const fn (*anyopaque, input_types.InputSnapshot) void,
};

pub fn handle(
    shell: *Shell,
    input_batch: *input_types.InputBatch,
    ctx: *anyopaque,
    hooks: Hooks,
) !?Result {
    hooks.set_last_input_snapshot(ctx, input_batch.snapshot());

    if (hooks.handle_font_sample_frame(ctx, shell, input_batch)) return null;
    try hooks.handle_widget_input_frame(ctx);
    const now = app_shell.getTime();
    hooks.tick_config_reload_notice_frame(ctx, now);
    const focus = hooks.route_input_for_current_focus(ctx, input_batch);
    const pre_input = try hooks.handle_pre_input_shortcut_frame(ctx, shell, input_batch, focus, now);
    if (pre_input.consumed) return null;
    if (pre_input.handled_shortcut) {
        hooks.note_input(ctx, now);
    }

    return .{
        .now = now,
        .suppress_terminal_shortcuts = pre_input.suppress_terminal_shortcuts,
        .terminal_close_modal_active = pre_input.terminal_close_modal_active,
    };
}
