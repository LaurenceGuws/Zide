const std = @import("std");
const app_terminal_widget_input_runtime = @import("terminal_widget_input_runtime.zig");
const app_shell = @import("../../app_shell.zig");
const shared_types = @import("../../types/mod.zig");
const widgets = @import("../../ui/widgets.zig");

const input_types = shared_types.input;
const Shell = app_shell.Shell;
const TerminalWidget = widgets.TerminalWidget;

pub const Hooks = struct {
    open_file: *const fn (*anyopaque, []const u8) anyerror!void,
    open_file_at: *const fn (*anyopaque, []const u8, usize, ?usize) anyerror!void,
    mark_redraw: *const fn (*anyopaque) void,
    note_input: *const fn (*anyopaque, f64) void,
};

pub fn handle(
    term_widget: *TerminalWidget,
    term_shell: *Shell,
    term_x: f32,
    term_y_draw: f32,
    term_width: f32,
    term_draw_height: f32,
    allow_terminal_input: bool,
    frame_suppress_shortcuts: bool,
    term_input_batch: *input_types.InputBatch,
    frame_search_consumed_input: bool,
    allocator: std.mem.Allocator,
    term_now: f64,
    ctx: *anyopaque,
    hooks: Hooks,
) !void {
    const result = try app_terminal_widget_input_runtime.handle(
        term_widget,
        term_shell,
        term_x,
        term_y_draw,
        term_width,
        term_draw_height,
        allow_terminal_input,
        frame_suppress_shortcuts,
        term_input_batch,
        frame_search_consumed_input,
        allocator,
        ctx,
        .{
            .open_file = hooks.open_file,
            .open_file_at = hooks.open_file_at,
        },
    );
    if (result.needs_redraw) hooks.mark_redraw(ctx);
    if (result.note_input) hooks.note_input(ctx, term_now);
}
