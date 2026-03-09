const std = @import("std");
const app_file_detect = @import("file_detect.zig");
const app_logger = @import("../app_logger.zig");
const app_shell = @import("../app_shell.zig");
const shared_types = @import("../types/mod.zig");
const widgets = @import("../ui/widgets.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;
const TerminalWidget = widgets.TerminalWidget;

pub const Result = struct {
    needs_redraw: bool = false,
    note_input: bool = false,
};

pub const Hooks = struct {
    open_file: *const fn (ctx: *anyopaque, path: []const u8) anyerror!void,
    open_file_at: *const fn (ctx: *anyopaque, path: []const u8, line_1: usize, col_1: ?usize) anyerror!void,
};

pub fn handle(
    term_widget: *TerminalWidget,
    shell: *app_shell.Shell,
    term_x: f32,
    term_y: f32,
    term_width: f32,
    term_height: f32,
    allow_terminal_input: bool,
    suppress_terminal_shortcuts: bool,
    input_batch: *input_types.InputBatch,
    search_panel_consumed_input: bool,
    allocator: std.mem.Allocator,
    ctx: *anyopaque,
    hooks: Hooks,
) !Result {
    const log = app_logger.logger("app.terminal_input");
    var out: Result = .{};
    if (!search_panel_consumed_input and try term_widget.handleInput(
        shell,
        term_x,
        term_y,
        term_width,
        term_height,
        allow_terminal_input,
        suppress_terminal_shortcuts,
        input_batch,
    )) {
        out.needs_redraw = true;
        out.note_input = true;
    }

    if (term_widget.takePendingOpenRequest()) |req| {
        defer allocator.free(req.path);
        if (app_file_detect.isProbablyTextFile(req.path)) {
            if (req.line != null) {
                hooks.open_file_at(ctx, req.path, req.line.?, req.col) catch |err| {
                    log.logf(.debug, "ctrl+click open_file_at failed path={s}: {s}", .{ req.path, @errorName(err) });
                    return out;
                };
            } else {
                hooks.open_file(ctx, req.path) catch |err| {
                    log.logf(.debug, "ctrl+click open_file failed path={s}: {s}", .{ req.path, @errorName(err) });
                    return out;
                };
            }
            out.needs_redraw = true;
            out.note_input = true;
        }
    }

    return out;
}
