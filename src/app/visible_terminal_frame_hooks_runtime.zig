const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const app_poll_visible_terminal_sessions_runtime = @import("poll_visible_terminal_sessions_runtime.zig");
const app_terminal_widget_input_hook_runtime = @import("terminal_widget_input_hook_runtime.zig");
const app_visible_terminal_frame = @import("visible_terminal_frame.zig");
const app_shell = @import("../app_shell.zig");
const shared_types = @import("../types/mod.zig");
const widgets = @import("../ui/widgets.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;
const ActiveMode = app_modes.ide.ActiveMode;
const Shell = app_shell.Shell;
const TerminalWidget = widgets.TerminalWidget;

pub const Hooks = struct {
    open_file: *const fn (*anyopaque, []const u8) anyerror!void,
    open_file_at: *const fn (*anyopaque, []const u8, usize, ?usize) anyerror!void,
    mark_redraw: *const fn (*anyopaque) void,
    note_input: *const fn (*anyopaque, f64) void,
    sync_terminal_tab_bar: *const fn (*anyopaque) anyerror!void,
};

fn hasTerminalInputActivity(batch: *const input_types.InputBatch) bool {
    for (batch.events.items) |event| {
        switch (event) {
            .key, .text, .focus => return true,
            else => {},
        }
    }
    if (batch.mousePressed(.left) or batch.mousePressed(.middle) or batch.mousePressed(.right)) return true;
    if (batch.mouseReleased(.left) or batch.mouseReleased(.middle) or batch.mouseReleased(.right)) return true;
    if (batch.mouseDown(.left) or batch.mouseDown(.middle) or batch.mouseDown(.right)) return true;
    return batch.scroll.x != 0 or batch.scroll.y != 0;
}

pub fn handle(
    app_mode: app_bootstrap.AppMode,
    show_terminal: bool,
    terminal_workspace: anytype,
    terminals: anytype,
    terminal_widgets: []TerminalWidget,
    tab_bar_dragging: bool,
    active_kind: ActiveMode,
    shell: *Shell,
    layout: layout_types.WidgetLayout,
    input_batch: *input_types.InputBatch,
    search_panel_consumed_input: bool,
    suppress_terminal_shortcuts: bool,
    terminal_close_modal_active: bool,
    now: f64,
    allocator: std.mem.Allocator,
    terminal_scroll_dragging: *bool,
    terminal_scroll_grab_offset: *f32,
    ctx: *anyopaque,
    hooks: Hooks,
) !void {
    var runtime_state = struct {
        app_mode: app_bootstrap.AppMode,
        show_terminal: bool,
        terminal_workspace: @TypeOf(terminal_workspace),
        terminals: @TypeOf(terminals),
        allocator: std.mem.Allocator,
        terminal_scroll_dragging: *bool,
        terminal_scroll_grab_offset: *f32,
        user_ctx: *anyopaque,
        hooks: Hooks,
    }{
        .app_mode = app_mode,
        .show_terminal = show_terminal,
        .terminal_workspace = terminal_workspace,
        .terminals = terminals,
        .allocator = allocator,
        .terminal_scroll_dragging = terminal_scroll_dragging,
        .terminal_scroll_grab_offset = terminal_scroll_grab_offset,
        .user_ctx = ctx,
        .hooks = hooks,
    };

    const terminal_frame_result = try app_visible_terminal_frame.handle(
        app_mode,
        show_terminal,
        terminal_workspace,
        terminals.len,
        terminal_widgets,
        tab_bar_dragging,
        active_kind,
        shell,
        layout,
        input_batch,
        search_panel_consumed_input,
        suppress_terminal_shortcuts,
        terminal_close_modal_active,
        now,
        @ptrCast(&runtime_state),
        .{
            .poll_visible_sessions = struct {
                fn call(route_raw: *anyopaque, poll_batch: *input_types.InputBatch) !void {
                    const route = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(route_raw)));
                    app_poll_visible_terminal_sessions_runtime.setTerminalInputActivityHint(hasTerminalInputActivity(poll_batch));
                    if (try app_poll_visible_terminal_sessions_runtime.handle(
                        route.app_mode,
                        route.show_terminal,
                        route.terminal_workspace,
                        route.terminals,
                        poll_batch.events.items.len > 0,
                    )) route.hooks.mark_redraw(route.user_ctx);
                }
            }.call,
            .handle_terminal_widget_input = struct {
                fn call(
                    route_raw: *anyopaque,
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
                    term_now: f64,
                ) !void {
                    const route = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(route_raw)));
                    try app_terminal_widget_input_hook_runtime.handle(
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
                        route.allocator,
                        route.terminal_scroll_dragging,
                        route.terminal_scroll_grab_offset,
                        term_now,
                        route.user_ctx,
                        .{
                            .open_file = route.hooks.open_file,
                            .open_file_at = route.hooks.open_file_at,
                            .mark_redraw = route.hooks.mark_redraw,
                            .note_input = route.hooks.note_input,
                        },
                    );
                }
            }.call,
        },
    );

    if (terminal_frame_result.needs_redraw) hooks.mark_redraw(ctx);
    try hooks.sync_terminal_tab_bar(ctx);
}
