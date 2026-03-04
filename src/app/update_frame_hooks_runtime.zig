const app_config_reload_notice_state = @import("config_reload_notice_state.zig");
const app_modes = @import("modes/mod.zig");
const app_terminal_tab_bar_sync_runtime = @import("terminal_tab_bar_sync_runtime.zig");
const app_terminal_close_confirm_active_runtime = @import("terminal_close_confirm_active_runtime.zig");
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
                                    return try inner_state.handlePreInputShortcutFrame(
                                        frame_shell,
                                        frame_input_batch,
                                        focus,
                                        at,
                                    );
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
                    return try inner_state.handlePostPreinputFrame(shell, batch, now);
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
                                    return try inner_state.handleInputActionsFrame(frame_shell, at);
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
                                    try inner_state.handleMousePressedFrame(
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
                                    try inner_state.handleTabDragFrame(frame_input_batch, layout, mouse, at);
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
                                    try inner_state.handleActiveViewFrame(
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
