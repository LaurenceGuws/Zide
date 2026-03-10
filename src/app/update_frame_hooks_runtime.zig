const app_config_reload_notice_state = @import("config_reload_notice_state.zig");
const app_input_actions_hooks_runtime = @import("input_actions_hooks_runtime.zig");
const app_mouse_pressed_hooks_runtime = @import("mouse_pressed_hooks_runtime.zig");
const app_modes = @import("modes/mod.zig");
const mode_build = @import("mode_build.zig");
const app_post_preinput_hooks_runtime = @import("post_preinput_hooks_runtime.zig");
const app_pre_input_shortcut_hooks_runtime = @import("pre_input_shortcut_hooks_runtime.zig");
const app_tab_action_apply_runtime = @import("tab_action_apply_runtime.zig");
const app_tab_drag_input_runtime = @import("tab_drag_input_runtime.zig");
const app_terminal_tab_bar_sync_runtime = @import("terminal/terminal_tab_bar_sync_runtime.zig");
const app_terminal_close_confirm_active_runtime = @import("terminal/terminal_close_confirm_active_runtime.zig");
const app_terminal_intent_route_runtime = @import("terminal/terminal_intent_route_runtime.zig");
const app_terminal_tab_navigation_runtime = @import("terminal/terminal_tab_navigation_runtime.zig");
const app_terminal_tabs_runtime = @import("terminal/terminal_tabs_runtime.zig");
const app_visible_terminal_frame_hooks_runtime = @import("terminal/visible_terminal_frame_hooks_runtime.zig");
const app_interactive_frame = @import("interactive_frame.zig");
const app_update_driver = @import("update_driver.zig");
const app_update_prelude_frame_runtime = @import("update_prelude_frame_runtime.zig");
const app_shell = @import("../app_shell.zig");
const input_actions = @import("../input/input_actions.zig");
const shared_types = @import("../types/mod.zig");

const Shell = app_shell.Shell;
const layout_types = shared_types.layout;

pub fn handle(state: anytype, input_batch: *shared_types.input.InputBatch) !void {
    const State = @TypeOf(state.*);
    try app_update_driver.handle(
        state.shell,
        input_batch,
        @ptrCast(state),
        .{
            .handle_update_prelude_frame = struct {
                fn cb(cb_raw: *anyopaque, shell: *Shell, batch: *shared_types.input.InputBatch) !?app_update_driver.Prelude {
                    const pre = (try app_update_prelude_frame_runtime.handle(
                        shell,
                        batch,
                        cb_raw,
                        .{
                            .handle_font_sample_frame = struct {
                                fn inner(inner_raw: *anyopaque, frame_shell: *Shell, frame_input_batch: *shared_types.input.InputBatch) bool {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    if (!app_modes.ide.isFontSample(inner_state.app_mode)) return false;
                                    if (inner_state.font_sample_auto_close_frames > 0 and inner_state.frame_id >= inner_state.font_sample_auto_close_frames) {
                                        inner_state.font_sample_close_pending = true;
                                        inner_state.needs_redraw = true;
                                        return true;
                                    }
                                    if (inner_state.font_sample_view) |*view| {
                                        if (view.update(frame_shell.rendererPtr(), frame_input_batch)) {
                                            inner_state.needs_redraw = true;
                                        }
                                    }
                                    return false;
                                }
                            }.inner,
                            .handle_widget_input_frame = struct {
                                fn inner(inner_raw: *anyopaque) !void {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    inner_state.options_bar.updateInput(inner_state.last_input);
                                    inner_state.tab_bar.updateInput(inner_state.last_input);
                                    inner_state.side_nav.updateInput(inner_state.last_input);
                                    inner_state.status_bar.updateInput(inner_state.last_input);
                                    try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(inner_state);
                                }
                            }.inner,
                            .tick_config_reload_notice_frame = struct {
                                fn inner(inner_raw: *anyopaque, at: f64) void {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    const still_visible = app_config_reload_notice_state.isVisible(inner_state.config_reload_notice_until, at);
                                    if (still_visible) {
                                        inner_state.needs_redraw = true;
                                    } else if (app_config_reload_notice_state.clearIfExpired(&inner_state.config_reload_notice_until, at)) {
                                        inner_state.needs_redraw = true;
                                    }
                                }
                            }.inner,
                            .route_input_for_current_focus = struct {
                                fn inner(inner_raw: *anyopaque, frame_input_batch: *shared_types.input.InputBatch) input_actions.FocusKind {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    _ = app_terminal_close_confirm_active_runtime.reconcile(inner_state);
                                    const routed_active = app_modes.ide.routedActiveMode(inner_state.app_mode, inner_state.active_kind);
                                    const focus = if (routed_active == .terminal) input_actions.FocusKind.terminal else input_actions.FocusKind.editor;
                                    inner_state.input_router.route(frame_input_batch, focus);
                                    return focus;
                                }
                            }.inner,
                            .handle_pre_input_shortcut_frame = struct {
                                fn inner(
                                    inner_raw: *anyopaque,
                                    frame_shell: *Shell,
                                    frame_input_batch: *shared_types.input.InputBatch,
                                    focus: input_actions.FocusKind,
                                    at: f64,
                                ) !app_update_prelude_frame_runtime.PreInputResult {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    return try app_pre_input_shortcut_hooks_runtime.handle(inner_state, frame_shell, frame_input_batch, focus, at);
                                }
                            }.inner,
                            .note_input = struct {
                                fn inner(inner_raw: *anyopaque, at: f64) void {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    inner_state.metrics.noteInput(at);
                                }
                            }.inner,
                            .set_last_input_snapshot = struct {
                                fn inner(inner_raw: *anyopaque, snapshot: shared_types.input.InputSnapshot) void {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    inner_state.last_input = snapshot;
                                }
                            }.inner,
                        },
                    )) orelse return null;
                    return .{
                        .now = pre.now,
                        .suppress_terminal_shortcuts = pre.suppress_terminal_shortcuts,
                        .terminal_close_modal_active = pre.terminal_close_modal_active,
                    };
                }
            }.cb,
            .handle_post_preinput_frame = struct {
                fn cb(cb_raw: *anyopaque, shell: *Shell, batch: *shared_types.input.InputBatch, now: f64) !app_update_driver.Frame {
                    const inner_state: *State = @ptrCast(@alignCast(cb_raw));
                    return try app_post_preinput_hooks_runtime.handle(inner_state, shell, batch, now);
                }
            }.cb,
            .handle_interactive_frame = struct {
                fn cb(
                    cb_raw: *anyopaque,
                    shell: *Shell,
                    frame: app_update_driver.Frame,
                    batch: *shared_types.input.InputBatch,
                    suppress_terminal_shortcuts: bool,
                    terminal_close_modal_active: bool,
                    now: f64,
                ) !void {
                    try app_interactive_frame.handle(
                        shell,
                        .{
                            .layout = frame.layout,
                            .mouse = frame.mouse,
                            .term_y = frame.term_y,
                        },
                        batch,
                        suppress_terminal_shortcuts,
                        terminal_close_modal_active,
                        now,
                        cb_raw,
                        .{
                            .handle_input_actions = struct {
                                fn inner(inner_raw: *anyopaque, frame_shell: *Shell, at: f64) !bool {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    return try app_input_actions_hooks_runtime.handle(inner_state, frame_shell, at);
                                }
                            }.inner,
                            .handle_mouse_pressed = struct {
                                fn inner(
                                    inner_raw: *anyopaque,
                                    frame_shell: *Shell,
                                    layout: layout_types.WidgetLayout,
                                    mouse: shared_types.input.MousePos,
                                    term_y: f32,
                                    frame_input_batch: *shared_types.input.InputBatch,
                                    at: f64,
                                ) !void {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    try app_mouse_pressed_hooks_runtime.handle(
                                        inner_state,
                                        frame_shell,
                                        layout,
                                        mouse,
                                        term_y,
                                        frame_input_batch,
                                        at,
                                    );
                                }
                            }.inner,
                            .handle_tab_drag = struct {
                                fn inner(
                                    inner_raw: *anyopaque,
                                    frame_input_batch: *shared_types.input.InputBatch,
                                    layout: layout_types.WidgetLayout,
                                    mouse: shared_types.input.MousePos,
                                    at: f64,
                                ) !void {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    try app_tab_drag_input_runtime.handle(
                                        inner_state.app_mode,
                                        &inner_state.tab_bar,
                                        app_terminal_tabs_runtime.barVisible(
                                            inner_state.app_mode,
                                            inner_state.terminal_tab_bar_show_single_tab,
                                            inner_state.terminal_workspace,
                                            inner_state.terminals.items.len,
                                        ),
                                        &inner_state.active_tab,
                                        frame_input_batch,
                                        layout,
                                        mouse,
                                        at,
                                        @ptrCast(inner_state),
                                        .{
                                            .apply_terminal_action = struct {
                                                fn call(hook_raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                                    try app_tab_action_apply_runtime.applyTerminalAndSync(hook_state, action);
                                                }
                                            }.call,
                                            .route_activate_by_tab_id = struct {
                                                fn call(hook_raw: *anyopaque, tab_id: ?u64) !void {
                                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                                    _ = try app_terminal_intent_route_runtime.routeByTabIdAndSync(
                                                        hook_state,
                                                        .activate,
                                                        tab_id,
                                                    );
                                                }
                                            }.call,
                                            .focus_terminal_tab_index = struct {
                                                fn call(hook_raw: *anyopaque, index: usize) bool {
                                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                                    return app_terminal_tab_navigation_runtime.focusByIndex(hook_state, index);
                                                }
                                            }.call,
                                            .apply_editor_action = struct {
                                                fn call(hook_raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                                    try app_tab_action_apply_runtime.applyEditorAndSync(hook_state, action);
                                                }
                                            }.call,
                                            .mark_redraw = struct {
                                                fn call(hook_raw: *anyopaque) void {
                                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                                    hook_state.needs_redraw = true;
                                                }
                                            }.call,
                                            .note_input = struct {
                                                fn call(hook_raw: *anyopaque, t: f64) void {
                                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                                    hook_state.metrics.noteInput(t);
                                                }
                                            }.call,
                                        },
                                    );
                                }
                            }.inner,
                            .handle_active_view = struct {
                                fn inner(
                                    inner_raw: *anyopaque,
                                    frame_shell: *Shell,
                                    layout: layout_types.WidgetLayout,
                                    mouse: shared_types.input.MousePos,
                                    frame_input_batch: *shared_types.input.InputBatch,
                                    frame_suppress_terminal_shortcuts: bool,
                                    frame_terminal_close_modal_active: bool,
                                    at: f64,
                                ) !void {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    if (comptime mode_build.focused_mode == .terminal) {
                                        try app_visible_terminal_frame_hooks_runtime.handle(
                                            inner_state.app_mode,
                                            inner_state.show_terminal,
                                            &inner_state.terminal_workspace,
                                            inner_state.terminals.items,
                                            inner_state.terminal_widgets.items,
                                            inner_state.tab_bar.isDragging(),
                                            inner_state.active_kind,
                                            frame_shell,
                                            layout,
                                            frame_input_batch,
                                            false,
                                            frame_suppress_terminal_shortcuts,
                                            frame_terminal_close_modal_active,
                                            at,
                                            inner_state.allocator,
                                            inner_raw,
                                            .{
                                                .open_file = struct {
                                                    fn call(raw: *anyopaque, path: []const u8) !void {
                                                        const s: *State = @ptrCast(@alignCast(raw));
                                                        try s.openFile(path);
                                                    }
                                                }.call,
                                                .open_file_at = struct {
                                                    fn call(raw: *anyopaque, path: []const u8, line_1: usize, col_1: ?usize) !void {
                                                        const s: *State = @ptrCast(@alignCast(raw));
                                                        try s.openFileAt(path, line_1, col_1);
                                                    }
                                                }.call,
                                                .mark_redraw = struct {
                                                    fn call(raw: *anyopaque) void {
                                                        const s: *State = @ptrCast(@alignCast(raw));
                                                        s.needs_redraw = true;
                                                    }
                                                }.call,
                                                .note_input = struct {
                                                    fn call(raw: *anyopaque, t: f64) void {
                                                        const s: *State = @ptrCast(@alignCast(raw));
                                                        s.metrics.noteInput(t);
                                                    }
                                                }.call,
                                                .sync_terminal_tab_bar = struct {
                                                    fn call(raw: *anyopaque) !void {
                                                        const s: *State = @ptrCast(@alignCast(raw));
                                                        try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(s);
                                                    }
                                                }.call,
                                            },
                                        );
                                    } else {
                                        const app_active_view_hooks_runtime = @import("active_view_hooks_runtime.zig");
                                        try app_active_view_hooks_runtime.handle(
                                            inner_state.allocator,
                                            &inner_state.search_panel.active,
                                            &inner_state.search_panel.query,
                                            inner_state.editors.items,
                                            inner_state.active_tab,
                                            inner_state.app_mode,
                                            inner_state.active_kind,
                                            &inner_state.editor_cluster_cache,
                                            inner_state.editor_wrap,
                                            frame_shell,
                                            layout,
                                            mouse,
                                            frame_input_batch,
                                            inner_state.perf_mode,
                                            &inner_state.perf_frames_done,
                                            inner_state.perf_frames_total,
                                            inner_state.perf_scroll_delta,
                                            &inner_state.editor_render_cache,
                                            inner_state.editor_highlight_budget,
                                            inner_state.editor_width_budget,
                                            .{
                                                .editor_hscroll_dragging = &inner_state.editor_hscroll_dragging,
                                                .editor_hscroll_grab_offset = &inner_state.editor_hscroll_grab_offset,
                                                .editor_vscroll_dragging = &inner_state.editor_vscroll_dragging,
                                                .editor_vscroll_grab_offset = &inner_state.editor_vscroll_grab_offset,
                                                .editor_dragging = &inner_state.editor_dragging,
                                                .editor_drag_start = &inner_state.editor_drag_start,
                                                .editor_drag_rect = &inner_state.editor_drag_rect,
                                            },
                                            inner_state.show_terminal,
                                            &inner_state.terminal_workspace,
                                            inner_state.terminals.items,
                                            inner_state.terminal_widgets.items,
                                            inner_state.tab_bar.isDragging(),
                                            frame_suppress_terminal_shortcuts,
                                            frame_terminal_close_modal_active,
                                            inner_state.allocator,
                                            at,
                                            &inner_state.needs_redraw,
                                            &inner_state.metrics,
                                            inner_state,
                                        );
                                    }
                                }
                            }.inner,
                        },
                    );
                }
            }.cb,
        },
    );
}

pub fn handleFocused(
    state: anytype,
    input_batch: *shared_types.input.InputBatch,
    comptime app_mode: @import("bootstrap.zig").AppMode,
) !void {
    switch (comptime app_mode) {
        .terminal, .editor, .ide, .font_sample => try handle(state, input_batch),
    }
}
