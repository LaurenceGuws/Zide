const app_config_reload_notice_state = @import("config_reload_notice_state.zig");
const app_input_actions_hooks_runtime = @import("input_actions_hooks_runtime.zig");
const app_mouse_pressed_hooks_runtime = @import("mouse_pressed_hooks_runtime.zig");
const app_modes = @import("modes/mod.zig");
const mode_build = @import("mode_build.zig");
const app_post_preinput_hooks_runtime = @import("post_preinput_hooks_runtime.zig");
const app_pre_input_shortcut_hooks_runtime = @import("pre_input_shortcut_hooks_runtime.zig");
const app_tab_action_apply_runtime = @import("tabs/tab_action_apply_runtime.zig");
const app_tab_drag_input_runtime = @import("tabs/tab_drag_input_runtime.zig");
const app_terminal_tab_bar_sync_runtime = @import("terminal/terminal_tab_bar_sync_runtime.zig");
const app_terminal_close_confirm_active_runtime = @import("terminal/terminal_close_confirm_active_runtime.zig");
const app_terminal_intent_route_runtime = @import("terminal/terminal_intent_route_runtime.zig");
const app_terminal_tab_navigation_runtime = @import("terminal/terminal_tab_navigation_runtime.zig");
const app_terminal_tabs_runtime = @import("terminal/terminal_tabs_runtime.zig");
const app_terminal_window_chrome_runtime = @import("terminal/window_chrome_runtime.zig");
const app_visible_terminal_frame_hooks_runtime = @import("terminal/visible_terminal_frame_hooks_runtime.zig");
const app_interactive_frame = @import("interactive_frame.zig");
const app_update_driver = @import("update_driver.zig");
const app_update_prelude_frame_runtime = @import("update_prelude_frame_runtime.zig");
const app_shell = @import("../app_shell.zig");
const input_actions = @import("../input/input_actions.zig");
const shared_types = @import("../types/mod.zig");

const app_editor_tab_bar_sync_runtime = if (mode_build.focused_mode == .terminal) struct {
    pub fn sync(_: anytype, _: anytype) !void {}
} else @import("editor/editor_tab_bar_sync_runtime.zig");

const Shell = app_shell.Shell;
const layout_types = shared_types.layout;

fn handleFontSampleFrame(state: anytype, frame_shell: *Shell, frame_input_batch: *shared_types.input.InputBatch) bool {
    if (!app_modes.ide.isFontSample(state.app_mode)) return false;
    if (state.font_sample_auto_close_frames > 0 and state.frame_id >= state.font_sample_auto_close_frames) {
        state.font_sample_close_pending = true;
        state.needs_redraw = true;
        return true;
    }
    if (state.font_sample_view) |*view| {
        if (view.update(frame_shell.rendererPtr(), frame_input_batch)) {
            state.needs_redraw = true;
        }
    }
    return false;
}

fn handleWidgetInputFrame(state: anytype) !void {
    state.top_bar.updateInput(state.last_input);
    state.tab_bar.updateInput(state.last_input);
    state.side_nav.updateInput(state.last_input);
    state.status_bar.updateInput(state.last_input);
    try app_editor_tab_bar_sync_runtime.sync(&state.tab_bar, state.editors.items);
    try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(state);
}

fn tickConfigReloadNoticeFrame(state: anytype, at: f64) void {
    const still_visible = app_config_reload_notice_state.isVisible(state.config_reload_notice_until, at);
    if (still_visible) {
        state.needs_redraw = true;
    } else if (app_config_reload_notice_state.clearIfExpired(&state.config_reload_notice_until, at)) {
        state.needs_redraw = true;
    }
}

fn routeInputForCurrentFocus(state: anytype, frame_input_batch: *shared_types.input.InputBatch) input_actions.FocusKind {
    _ = app_terminal_close_confirm_active_runtime.reconcile(state);
    const routed_active = app_modes.ide.routedActiveMode(state.app_mode, state.active_kind);
    const focus = if (routed_active == .terminal) input_actions.FocusKind.terminal else input_actions.FocusKind.editor;
    state.input_router.route(frame_input_batch, focus);
    return focus;
}

fn noteInput(state: anytype, at: f64) void {
    state.metrics.noteInput(at);
}

fn setLastInputSnapshot(state: anytype, snapshot: shared_types.input.InputSnapshot) void {
    state.last_input = snapshot;
}

fn handleTabDrag(state: anytype, frame_input_batch: *shared_types.input.InputBatch, layout: layout_types.WidgetLayout, mouse: shared_types.input.MousePos, at: f64) !void {
    const State = @TypeOf(state.*);
    try app_tab_drag_input_runtime.handle(
        state.app_mode,
        &state.tab_bar,
        app_terminal_window_chrome_runtime.barVisible(
            state.app_mode,
            state.terminal_window_chrome_mode,
            state.terminal_tab_bar_show_single_tab,
            state.terminal_workspace,
            state.terminals.items.len,
        ),
        state.terminal_window_chrome_mode,
        &state.active_tab,
        state.shell,
        frame_input_batch,
        layout,
        mouse,
        at,
        @ptrCast(state),
        .{
            .apply_terminal_action = struct {
                fn call(hook_raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                    switch (action) {
                        .move => |mv| {
                            if (app_terminal_tab_navigation_runtime.moveByVisualIndex(
                                hook_state.app_mode,
                                &hook_state.terminal_workspace,
                                &hook_state.tab_bar,
                                mv.to_index,
                            )) {
                                _ = app_terminal_tab_navigation_runtime.moveWidgetByIndex(
                                    hook_state,
                                    mv.from_index,
                                    mv.to_index,
                                );
                                try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(hook_state);
                                return;
                            }
                        },
                        else => {},
                    }
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

fn handleActiveView(
    state: anytype,
    frame_shell: *Shell,
    layout: layout_types.WidgetLayout,
    mouse: shared_types.input.MousePos,
    frame_input_batch: *shared_types.input.InputBatch,
    frame_suppress_terminal_shortcuts: bool,
    frame_terminal_close_modal_active: bool,
    at: f64,
) !void {
    if (comptime mode_build.focused_mode == .terminal) {
        try app_visible_terminal_frame_hooks_runtime.handle(
            state.app_mode,
            state.show_terminal,
            &state.terminal_workspace,
            state.terminals.items,
            state.terminal_widgets.items,
            state.tab_bar.isDragging(),
            state.active_kind,
            frame_shell,
            layout,
            frame_input_batch,
            false,
            frame_suppress_terminal_shortcuts,
            frame_terminal_close_modal_active,
            at,
            state.allocator,
            &state.terminal_scrollbar_dragging,
            &state.terminal_scrollbar_grab_offset,
            &state.terminal_scrollbar_hovered,
            @ptrCast(state),
            .{
                .open_file = struct {
                    fn call(raw: *anyopaque, path: []const u8) !void {
                        const s: *@TypeOf(state.*) = @ptrCast(@alignCast(raw));
                        try s.openFile(path);
                    }
                }.call,
                .open_file_at = struct {
                    fn call(raw: *anyopaque, path: []const u8, line_1: usize, col_1: ?usize) !void {
                        const s: *@TypeOf(state.*) = @ptrCast(@alignCast(raw));
                        try s.openFileAt(path, line_1, col_1);
                    }
                }.call,
                .mark_redraw = struct {
                    fn call(raw: *anyopaque) void {
                        const s: *@TypeOf(state.*) = @ptrCast(@alignCast(raw));
                        s.needs_redraw = true;
                    }
                }.call,
                .note_input = struct {
                    fn call(raw: *anyopaque, t: f64) void {
                        const s: *@TypeOf(state.*) = @ptrCast(@alignCast(raw));
                        s.metrics.noteInput(t);
                    }
                }.call,
                .sync_terminal_tab_bar = struct {
                    fn call(raw: *anyopaque) !void {
                        const s: *@TypeOf(state.*) = @ptrCast(@alignCast(raw));
                        try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(s);
                    }
                }.call,
            },
        );
        return;
    }

    const app_active_view_hooks_runtime = @import("active_view_hooks_runtime.zig");
    try app_active_view_hooks_runtime.handle(
        state.allocator,
        &state.path_prompt,
        &state.search_panel.active,
        &state.search_panel.select_all,
        &state.search_panel.query,
        state.editors.items,
        state.active_tab,
        &state.tab_bar,
        state.app_mode,
        state.active_kind,
        &state.editor_cluster_cache,
        state.editor_wrap,
        frame_shell,
        layout,
        mouse,
        frame_input_batch,
        state.perf_mode,
        &state.perf_frames_done,
        state.perf_frames_total,
        state.perf_scroll_delta,
        state.frame_id,
        &state.editor_render_cache,
        state.editor_highlight_budget,
        state.editor_width_budget,
        .{
            .editor_hscroll_dragging = &state.editor_hscroll_dragging,
            .editor_hscroll_grab_offset = &state.editor_hscroll_grab_offset,
            .editor_vscroll_dragging = &state.editor_vscroll_dragging,
            .editor_vscroll_grab_offset = &state.editor_vscroll_grab_offset,
            .editor_dragging = &state.editor_dragging,
            .editor_drag_start = &state.editor_drag_start,
            .editor_drag_rect = &state.editor_drag_rect,
        },
        &state.terminal_scrollbar_dragging,
        &state.terminal_scrollbar_grab_offset,
        &state.terminal_scrollbar_hovered,
        state.show_terminal,
        &state.terminal_workspace,
        state.terminals.items,
        state.terminal_widgets.items,
        state.tab_bar.isDragging(),
        frame_suppress_terminal_shortcuts,
        frame_terminal_close_modal_active,
        state.allocator,
        at,
        &state.needs_redraw,
        &state.metrics,
        state,
    );
}

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
                                    return handleFontSampleFrame(inner_state, frame_shell, frame_input_batch);
                                }
                            }.inner,
                            .handle_widget_input_frame = struct {
                                fn inner(inner_raw: *anyopaque) !void {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    try handleWidgetInputFrame(inner_state);
                                }
                            }.inner,
                            .tick_config_reload_notice_frame = struct {
                                fn inner(inner_raw: *anyopaque, at: f64) void {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    tickConfigReloadNoticeFrame(inner_state, at);
                                }
                            }.inner,
                            .route_input_for_current_focus = struct {
                                fn inner(inner_raw: *anyopaque, frame_input_batch: *shared_types.input.InputBatch) input_actions.FocusKind {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    return routeInputForCurrentFocus(inner_state, frame_input_batch);
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
                                    noteInput(inner_state, at);
                                }
                            }.inner,
                            .set_last_input_snapshot = struct {
                                fn inner(inner_raw: *anyopaque, snapshot: shared_types.input.InputSnapshot) void {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    setLastInputSnapshot(inner_state, snapshot);
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
                                    try handleTabDrag(inner_state, frame_input_batch, layout, mouse, at);
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
                                    try handleActiveView(
                                        inner_state,
                                        frame_shell,
                                        layout,
                                        mouse,
                                        frame_input_batch,
                                        frame_suppress_terminal_shortcuts,
                                        frame_terminal_close_modal_active,
                                        at,
                                    );
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
