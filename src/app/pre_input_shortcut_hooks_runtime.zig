const app_config_reload_notice_state = @import("config_reload_notice_state.zig");
const app_modes = @import("modes/mod.zig");
const app_pre_input_shortcut_frame_runtime = @import("pre_input_shortcut_frame_runtime.zig");
const app_reload_config_runtime = @import("reload_config_runtime.zig");
const app_shell = @import("../app_shell.zig");
const app_tab_bar_width = @import("tabs/tab_bar_width.zig");
const app_terminal_close_active_runtime = @import("terminal/terminal_close_active_runtime.zig");
const app_terminal_close_confirm_active_runtime = @import("terminal/terminal_close_confirm_active_runtime.zig");
const app_terminal_close_confirm_decision_runtime = @import("terminal/terminal_close_confirm_decision_runtime.zig");
const app_terminal_intent_route_runtime = @import("terminal/terminal_intent_route_runtime.zig");
const app_terminal_refresh_sizing_runtime = @import("terminal/terminal_refresh_sizing_runtime.zig");
const app_terminal_tab_bar_sync_runtime = @import("terminal/terminal_tab_bar_sync_runtime.zig");
const app_ui_layout_runtime = @import("ui_layout_runtime.zig");
const input_actions = @import("../input/input_actions.zig");
const shared_types = @import("../types/mod.zig");
const app_update_prelude_frame_runtime = @import("update_prelude_frame_runtime.zig");

const Shell = app_shell.Shell;
const layout_types = shared_types.layout;

pub fn handle(
    state: anytype,
    frame_shell: *Shell,
    frame_input_batch: *shared_types.input.InputBatch,
    focus: input_actions.FocusKind,
    at: f64,
) !app_update_prelude_frame_runtime.PreInputResult {
    const State = @TypeOf(state.*);
    return try app_pre_input_shortcut_frame_runtime.handle(
        state.input_router.actionsSlice(),
        frame_shell,
        frame_input_batch,
        focus,
        at,
        state.app_mode,
        state.show_terminal,
        &state.terminal_workspace,
        state.terminals.items,
        state.terminal_widgets.items,
        state.allocator,
        state.editors.items,
        state.active_tab,
        &state.editor_cluster_cache,
        state.editor_wrap,
        state.editor_large_jump_rows,
        &state.search_panel.active,
        &state.search_panel.query,
        @ptrCast(state),
        .{
            .reload_config = struct {
                fn call(raw: *anyopaque) !void {
                    const s: *State = @ptrCast(@alignCast(raw));
                    try app_reload_config_runtime.handle(
                        s,
                        raw,
                        .{
                            .refresh_terminal_sizing = struct {
                                fn call(inner_raw: *anyopaque) !void {
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
                            }.call,
                            .apply_current_tab_bar_width_mode = struct {
                                fn call(inner_raw: *anyopaque) void {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    app_tab_bar_width.applyForMode(
                                        &inner_state.tab_bar,
                                        inner_state.app_mode,
                                        inner_state.editor_tab_bar_width_mode,
                                        inner_state.terminal_tab_bar_width_mode,
                                    );
                                }
                            }.call,
                        },
                    );
                }
            }.call,
            .show_reload_notice = struct {
                fn call(raw: *anyopaque, success: bool) void {
                    const s: *State = @ptrCast(@alignCast(raw));
                    const notice = app_config_reload_notice_state.arm(app_shell.getTime(), success);
                    s.config_reload_notice_success = notice.success;
                    s.config_reload_notice_until = notice.until;
                    s.needs_redraw = true;
                }
            }.call,
            .reconcile_terminal_close_modal_active = struct {
                fn call(raw: *anyopaque) bool {
                    const s: *State = @ptrCast(@alignCast(raw));
                    return app_terminal_close_confirm_active_runtime.reconcile(s);
                }
            }.call,
            .apply_terminal_close_confirm_decision = struct {
                fn call(raw: *anyopaque, decision: app_modes.ide.TerminalCloseConfirmDecision, now: f64) !bool {
                    const s: *State = @ptrCast(@alignCast(raw));
                    return try app_terminal_close_confirm_decision_runtime.applyDecision(
                        s,
                        decision,
                        now,
                        raw,
                        .{
                            .route_close_intent_and_sync = struct {
                                fn call(inner_raw: *anyopaque) !void {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    _ = try app_terminal_intent_route_runtime.routeActiveAndSync(inner_state, .close);
                                }
                            }.call,
                            .close_active_terminal_tab = struct {
                                fn call(inner_raw: *anyopaque) !bool {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    return try app_terminal_close_active_runtime.closeActive(
                                        inner_state,
                                        inner_raw,
                                        .{
                                            .sync_terminal_mode_tab_bar = struct {
                                                fn call(sync_raw: *anyopaque) !void {
                                                    const sync_state: *State = @ptrCast(@alignCast(sync_raw));
                                                    try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(sync_state);
                                                }
                                            }.call,
                                        },
                                    );
                                }
                            }.call,
                            .note_input = struct {
                                fn call(inner_raw: *anyopaque, t: f64) void {
                                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                                    inner_state.metrics.noteInput(t);
                                }
                            }.call,
                        },
                    );
                }
            }.call,
            .compute_layout = struct {
                fn call(raw: *anyopaque, w: f32, h: f32) layout_types.WidgetLayout {
                    const s: *State = @ptrCast(@alignCast(raw));
                    return app_ui_layout_runtime.computeLayout(s, w, h);
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
        },
    );
}
