const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const app_bootstrap = @import("../bootstrap.zig");
const app_modes = @import("../modes/mod.zig");
const app_terminal_active_widget = @import("terminal_active_widget.zig");
const app_poll_visible_terminal_sessions_runtime = @import("poll_visible_terminal_sessions_runtime.zig");
const app_terminal_scrollbar_runtime = @import("terminal_scrollbar_runtime.zig");
const app_terminal_surface_gate = @import("terminal_surface_gate.zig");
const app_terminal_widget_input_hook_runtime = @import("terminal_widget_input_hook_runtime.zig");
const app_shell = @import("../../app_shell.zig");
const shared_types = @import("../../types/mod.zig");
const widgets = @import("../../ui/widgets.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;
const ActiveMode = app_modes.ide.ActiveMode;
const Shell = app_shell.Shell;
const TerminalWidget = widgets.TerminalWidget;

const Result = struct {
    needs_redraw: bool = false,
};

pub const Hooks = struct {
    open_file: *const fn (*anyopaque, []const u8) anyerror!void,
    open_file_at: *const fn (*anyopaque, []const u8, usize, ?usize) anyerror!void,
    mark_redraw: *const fn (*anyopaque) void,
    note_input: *const fn (*anyopaque, f64) void,
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

fn hasPassiveMouseMoveOnly(input_batch: *input_types.InputBatch, in_terminal_rect: bool) bool {
    if (!in_terminal_rect) return false;
    if (!input_batch.mouseMoved()) return false;
    if (input_batch.scroll.x != 0 or input_batch.scroll.y != 0) return false;
    if (input_batch.mouseDown(.left) or input_batch.mouseDown(.middle) or input_batch.mouseDown(.right) or input_batch.mouseDown(.back) or input_batch.mouseDown(.forward) or input_batch.mouseDown(.other)) return false;
    if (input_batch.mousePressed(.left) or input_batch.mousePressed(.middle) or input_batch.mousePressed(.right) or input_batch.mousePressed(.back) or input_batch.mousePressed(.forward) or input_batch.mousePressed(.other)) return false;
    if (input_batch.mouseReleased(.left) or input_batch.mouseReleased(.middle) or input_batch.mouseReleased(.right) or input_batch.mouseReleased(.back) or input_batch.mouseReleased(.forward) or input_batch.mouseReleased(.other)) return false;
    for (input_batch.events.items) |event| {
        switch (event) {
            .mouse => {},
            else => return false,
        }
    }
    return true;
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
    terminal_scrollbar_dragging: *bool,
    terminal_scrollbar_grab_offset: *f32,
    terminal_scrollbar_hovered: *bool,
    ctx: *anyopaque,
    hooks: Hooks,
) !void {
    const runtime_state = struct {
        app_mode: app_bootstrap.AppMode,
        show_terminal: bool,
        terminal_workspace: @TypeOf(terminal_workspace),
        terminals: @TypeOf(terminals),
        allocator: std.mem.Allocator,
        terminal_scrollbar_dragging: *bool,
        terminal_scrollbar_grab_offset: *f32,
        terminal_scrollbar_hovered: *bool,
        user_ctx: *anyopaque,
        hooks: Hooks,
    }{
        .app_mode = app_mode,
        .show_terminal = show_terminal,
        .terminal_workspace = terminal_workspace,
        .terminals = terminals,
        .allocator = allocator,
        .terminal_scrollbar_dragging = terminal_scrollbar_dragging,
        .terminal_scrollbar_grab_offset = terminal_scrollbar_grab_offset,
        .terminal_scrollbar_hovered = terminal_scrollbar_hovered,
        .user_ctx = ctx,
        .hooks = hooks,
    };

    var terminal_frame_result: Result = .{};
    if (app_terminal_surface_gate.hasVisibleTerminalTabs(app_mode, show_terminal, terminal_workspace.*, terminals.len)) {
        const wake_log = app_logger.logger("terminal.wake");
        const input_has_events = input_batch.events.items.len > 0;
        const terminal_input_activity = hasTerminalInputActivity(input_batch);
        const published_changed = try app_poll_visible_terminal_sessions_runtime.handle(
            app_mode,
            show_terminal,
            terminal_workspace,
            terminals,
            input_has_events,
            terminal_input_activity,
        );
        if (wake_log.enabled_file or wake_log.enabled_console) {
            wake_log.logFields(.info, "visible_poll", &.{
                .{ .key = "input_events", .value = .{ .boolean = input_has_events } },
                .{ .key = "terminal_input_activity", .value = .{ .boolean = terminal_input_activity } },
                .{ .key = "published_changed", .value = .{ .boolean = published_changed } },
            });
        }
        if (published_changed) hooks.mark_redraw(ctx);

        if (app_terminal_active_widget.resolveActive(
            app_mode,
            terminal_workspace,
            terminals.len,
            terminal_widgets,
        )) |term_widget| {
            const strip = app_modes.ide.terminalStrip(app_mode, layout.terminal.height);
            const term_y_draw = layout.terminal.y + strip.offset_y;
            const term_x = layout.terminal.x;
            const term_draw_height = strip.draw_height;

            if (term_widget.updateBlink(now)) {
                terminal_frame_result.needs_redraw = true;
            }

            const suppress_terminal_input_for_tab_drag = app_modes.ide.suppressTerminalInputForTabDrag(app_mode, tab_bar_dragging);
            const allow_terminal_input = active_kind == .terminal and !terminal_close_modal_active and !suppress_terminal_input_for_tab_drag;
            const mouse = input_batch.mouse_pos;
            const in_terminal_rect = mouse.x >= term_x and
                mouse.x <= term_x + layout.terminal.width and
                mouse.y >= term_y_draw and
                mouse.y <= term_y_draw + term_draw_height;
            const passive_move_only = hasPassiveMouseMoveOnly(input_batch, in_terminal_rect);
            _ = passive_move_only;
            const scrollbar_result = app_terminal_scrollbar_runtime.handleInput(
                term_widget,
                shell,
                term_x,
                term_y_draw,
                layout.terminal.width,
                term_draw_height,
                input_batch,
                runtime_state.terminal_scrollbar_dragging,
                runtime_state.terminal_scrollbar_grab_offset,
                runtime_state.terminal_scrollbar_hovered,
            );
            if (scrollbar_result.needs_redraw) hooks.mark_redraw(ctx);
            if (scrollbar_result.note_input) hooks.note_input(ctx, now);
            if (!scrollbar_result.blocking) {
                try app_terminal_widget_input_hook_runtime.handle(
                    term_widget,
                    shell,
                    term_x,
                    term_y_draw,
                    layout.terminal.width,
                    term_draw_height,
                    allow_terminal_input,
                    suppress_terminal_shortcuts,
                    input_batch,
                    search_panel_consumed_input,
                    allocator,
                    now,
                    ctx,
                    .{
                        .open_file = hooks.open_file,
                        .open_file_at = hooks.open_file_at,
                        .mark_redraw = hooks.mark_redraw,
                        .note_input = hooks.note_input,
                    },
                );
            }
        }
    }

    if (terminal_frame_result.needs_redraw) hooks.mark_redraw(ctx);
}
