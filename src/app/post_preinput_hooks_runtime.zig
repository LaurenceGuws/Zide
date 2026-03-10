const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const app_update_driver = @import("update_driver.zig");
const app_post_preinput_frame = @import("post_preinput_frame.zig");
const app_ui_layout_runtime = @import("ui_layout_runtime.zig");
const app_tab_bar_width = @import("tab_bar_width.zig");
const app_terminal_refresh_sizing_runtime = @import("terminal/terminal_refresh_sizing_runtime.zig");
const app_window_resize_event_frame = @import("window_resize_event_frame.zig");
const app_cursor_blink_frame = @import("cursor_blink_frame.zig");
const app_terminal_active_widget = @import("terminal/terminal_active_widget.zig");
const app_logger = @import("../app_logger.zig");
const app_deferred_terminal_resize_frame = @import("terminal/deferred_terminal_resize_frame.zig");
const app_terminal_tabs_runtime = @import("terminal/terminal_tabs_runtime.zig");
const app_terminal_resize = @import("terminal/terminal_resize.zig");
const app_terminal_grid = @import("terminal/terminal_grid.zig");
const app_pointer_activity_frame = @import("pointer_activity_frame.zig");
const app_terminal_split_resize_frame = @import("terminal/terminal_split_resize_frame.zig");
const app_shell = @import("../app_shell.zig");
const shared_types = @import("../types/mod.zig");

const Shell = app_shell.Shell;
const input_types = shared_types.input;
const layout_types = shared_types.layout;

pub fn handle(state: anytype, shell: *Shell, batch: *input_types.InputBatch, now: f64) !app_update_driver.Frame {
    const State = @TypeOf(state.*);
    const frame = try app_post_preinput_frame.handle(
        shell,
        batch,
        now,
        @ptrCast(state),
        .{
            .apply_ui_scale = struct {
                fn inner(inner_raw: *anyopaque) void {
                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                    app_ui_layout_runtime.applyUiScale(
                        inner_state,
                        inner_state.shell.uiScaleFactor(),
                        @ptrCast(inner_state),
                        .{
                            .apply_current_tab_bar_width_mode = struct {
                                fn call(scale_raw: *anyopaque) void {
                                    const cb_state: *State = @ptrCast(@alignCast(scale_raw));
                                    app_tab_bar_width.applyForMode(
                                        &cb_state.tab_bar,
                                        cb_state.app_mode,
                                        cb_state.editor_tab_bar_width_mode,
                                        cb_state.terminal_tab_bar_width_mode,
                                    );
                                }
                            }.call,
                        },
                    );
                }
            }.inner,
            .refresh_terminal_sizing = struct {
                fn inner(inner_raw: *anyopaque) !void {
                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                    try app_terminal_refresh_sizing_runtime.handle(
                        inner_state,
                        inner_state.app_mode,
                        &inner_state.terminal_workspace,
                        inner_state.terminals.items,
                        inner_state.show_terminal,
                        inner_state.terminal_height,
                        inner_state.shell,
                    );
                }
            }.inner,
            .handle_window_resize_event = struct {
                fn inner(inner_raw: *anyopaque, frame_shell: *Shell, at: f64) !void {
                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                    _ = at;
                    const result = try app_window_resize_event_frame.handle(
                        frame_shell,
                        &inner_state.window_resize_pending,
                        &inner_state.window_resize_last_time,
                    );
                    if (result.ui_scale_changed) {
                        app_ui_layout_runtime.applyUiScale(
                            inner_state,
                            inner_state.shell.uiScaleFactor(),
                            @ptrCast(inner_state),
                            .{
                                .apply_current_tab_bar_width_mode = struct {
                                    fn call(scale_raw: *anyopaque) void {
                                        const cb_state: *State = @ptrCast(@alignCast(scale_raw));
                                        app_tab_bar_width.applyForMode(
                                            &cb_state.tab_bar,
                                            cb_state.app_mode,
                                            cb_state.editor_tab_bar_width_mode,
                                            cb_state.terminal_tab_bar_width_mode,
                                        );
                                    }
                                }.call,
                            },
                        );
                    }
                    if (result.needs_redraw) inner_state.needs_redraw = true;
                }
            }.inner,
            .compute_layout = struct {
                fn inner(inner_raw: *anyopaque, width: f32, height: f32) layout_types.WidgetLayout {
                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                    return app_ui_layout_runtime.computeLayout(inner_state, width, height);
                }
            }.inner,
            .handle_cursor_blink_arming = struct {
                fn inner(inner_raw: *anyopaque, at: f64) void {
                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                    var cache: ?app_cursor_blink_frame.Input = null;
                    if (app_terminal_active_widget.resolveActive(
                        inner_state.app_mode,
                        &inner_state.terminal_workspace,
                        inner_state.terminals.items.len,
                        inner_state.terminal_widgets.items,
                    )) |term_widget| {
                        const rc = &term_widget.draw_cache;
                        cache = app_cursor_blink_frame.Input{
                            .cursor_visible = rc.cursor_visible,
                            .cursor_blink = rc.cursor_style.blink,
                            .scroll_offset = rc.scroll_offset,
                        };
                    }

                    const result = app_cursor_blink_frame.handle(
                        cache,
                        at,
                        &inner_state.last_cursor_blink_armed,
                        &inner_state.last_cursor_blink_on,
                    );

                    if (result.blink_armed_changed) {
                        const cursor_log = app_logger.logger("terminal.cursor");
                        cursor_log.logf(
                            .info,
                            "cursor blink armed={any} visible={any} blink={any} scroll_offset={d}",
                            .{
                                result.blink_armed,
                                cache.?.cursor_visible,
                                cache.?.cursor_blink,
                                cache.?.scroll_offset,
                            },
                        );
                    }
                    if (result.needs_redraw) inner_state.needs_redraw = true;
                }
            }.inner,
            .handle_deferred_terminal_resize = struct {
                fn inner(inner_raw: *anyopaque, frame_shell: *Shell, layout: layout_types.WidgetLayout, at: f64) !void {
                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                    const result = app_deferred_terminal_resize_frame.handle(
                        &inner_state.window_resize_pending,
                        inner_state.window_resize_last_time,
                        at,
                        inner_state.app_mode,
                        inner_state.show_terminal,
                        layout,
                        inner_state.terminal_height,
                        app_terminal_tabs_runtime.count(inner_state.app_mode, inner_state.terminal_workspace, inner_state.terminals.items.len),
                        frame_shell.terminalCellWidth(),
                        frame_shell.terminalCellHeight(),
                    );
                    if (!result.triggered) return;

                    if (result.should_resize_terminals) {
                        if (app_modes.ide.shouldUseTerminalWorkspace(inner_state.app_mode)) {
                            if (inner_state.terminal_workspace) |*workspace| {
                                try app_terminal_resize.resizeWorkspaceWithShellCellSize(workspace, frame_shell, result.rows, result.cols);
                            }
                        } else {
                            const term = inner_state.terminals.items[0];
                            try app_terminal_resize.resizeSessionWithShellCellSize(term, frame_shell, result.rows, result.cols);
                        }
                    }
                    if (result.needs_redraw) inner_state.needs_redraw = true;
                }
            }.inner,
            .handle_pointer_activity = struct {
                fn inner(
                    inner_raw: *anyopaque,
                    frame_input_batch: *shared_types.input.InputBatch,
                    layout: layout_types.WidgetLayout,
                    mouse: shared_types.input.MousePos,
                    at: f64,
                ) void {
                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                    const result = app_pointer_activity_frame.handle(
                        inner_state.show_terminal,
                        frame_input_batch,
                        layout,
                        mouse,
                        at,
                        &inner_state.last_mouse_pos,
                        &inner_state.last_mouse_redraw_time,
                        &inner_state.last_ctrl_down,
                    );
                    if (result.needs_redraw) inner_state.needs_redraw = true;
                    if (result.note_input) inner_state.metrics.noteInput(at);
                }
            }.inner,
            .handle_terminal_split_resize = struct {
                fn inner(
                    inner_raw: *anyopaque,
                    frame_shell: *Shell,
                    frame_input_batch: *shared_types.input.InputBatch,
                    layout: layout_types.WidgetLayout,
                    width: f32,
                    height: f32,
                    at: f64,
                ) !void {
                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                    const result = app_terminal_split_resize_frame.handle(
                        inner_state.app_mode,
                        inner_state.show_terminal,
                        frame_input_batch,
                        layout,
                        height,
                        inner_state.options_bar.height,
                        inner_state.tab_bar.height,
                        inner_state.status_bar.height,
                        &inner_state.resizing_terminal,
                        &inner_state.resize_start_y,
                        &inner_state.resize_start_height,
                        inner_state.terminal_height,
                    );

                    if (result.new_terminal_height) |new_height| {
                        inner_state.terminal_height = new_height;
                        if (inner_state.terminals.items.len > 0) {
                            const term = inner_state.terminals.items[0];
                            const grid = app_terminal_grid.compute(
                                width,
                                inner_state.terminal_height,
                                inner_state.shell.terminalCellWidth(),
                                inner_state.shell.terminalCellHeight(),
                                1,
                                1,
                            );
                            const cols: u16 = grid.cols;
                            const rows: u16 = grid.rows;
                            term.setCellSize(
                                @intFromFloat(frame_shell.terminalCellWidth()),
                                @intFromFloat(frame_shell.terminalCellHeight()),
                            );
                            try term.resize(rows, cols);
                        }
                    }
                    if (result.needs_redraw) inner_state.needs_redraw = true;
                    if (result.note_input) inner_state.metrics.noteInput(at);
                }
            }.inner,
        },
    );
    if (frame.needs_redraw) state.needs_redraw = true;
    if (frame.note_input) state.metrics.noteInput(now);
    return .{
        .layout = frame.layout,
        .mouse = frame.mouse,
        .term_y = frame.term_y,
    };
}
