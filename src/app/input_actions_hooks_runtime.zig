const app_logger = @import("../app_logger.zig");
const app_modes = @import("modes/mod.zig");
const app_input_actions_frame_runtime = @import("input_actions_frame_runtime.zig");
const app_shortcut_action_runtime = @import("shortcut_action_runtime.zig");
const app_terminal_shortcut_policy = @import("terminal/terminal_shortcut_policy.zig");
const app_terminal_shortcut_runtime = @import("terminal/terminal_shortcut_runtime.zig");
const app_terminal_tab_intents = @import("terminal/terminal_tab_intents.zig");
const app_terminal_tab_navigation_runtime = @import("terminal/terminal_tab_navigation_runtime.zig");
const app_terminal_intent_route_runtime = @import("terminal/terminal_intent_route_runtime.zig");
const app_tab_action_apply_runtime = @import("tabs/tab_action_apply_runtime.zig");
const app_cycle_active_tab_runtime = @import("tabs/cycle_active_tab_runtime.zig");
const app_imported_theme_runtime = @import("editor/imported_theme_runtime.zig");
const app_close_active_editor_runtime = @import("editor/close_active_editor_runtime.zig");
const app_active_editor_runtime = @import("editor/active_editor_runtime.zig");
const app_terminal_close_active_runtime = @import("terminal/terminal_close_active_runtime.zig");
const app_terminal_close_confirm_active_runtime = @import("terminal/terminal_close_confirm_active_runtime.zig");
const app_terminal_tab_bar_sync_runtime = @import("terminal/terminal_tab_bar_sync_runtime.zig");
const app_path_prompt_state = @import("editor/path_prompt_state.zig");
const app_shell = @import("../app_shell.zig");
const input_actions = @import("../input/input_actions.zig");

const Shell = app_shell.Shell;

pub fn handle(state: anytype, frame_shell: *Shell, now: f64) !bool {
    _ = frame_shell;
    const State = @TypeOf(state.*);
    return try app_input_actions_frame_runtime.handle(
        state.input_router.actionsSlice(),
        now,
        @ptrCast(state),
        .{
            .handle_shortcut_action = struct {
                fn call(action_raw: *anyopaque, kind: input_actions.ActionKind, inner_at: f64, handled_zoom: *bool) !bool {
                    const action_state: *State = @ptrCast(@alignCast(action_raw));
                    const zoom_log = app_logger.logger("ui.zoom.shortcut");
                    const result = try app_shortcut_action_runtime.handle(
                        kind,
                        action_state.app_mode,
                        &action_state.show_terminal,
                        action_state.terminals.items.len,
                        action_state.shell,
                        inner_at,
                        zoom_log,
                        @ptrCast(action_state),
                        .{
                            .new_editor = struct {
                                fn call(hook_raw: *anyopaque) !void {
                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                    try hook_state.newEditor();
                                }
                            }.call,
                            .new_terminal = struct {
                                fn call(hook_raw: *anyopaque) !void {
                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                    try hook_state.newTerminal();
                                }
                            }.call,
                            .open_file_prompt = struct {
                                fn call(hook_raw: *anyopaque) !void {
                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                    const active_editor = app_active_editor_runtime.fromState(hook_state);
                                    hook_state.search_panel.active = false;
                                    try app_path_prompt_state.openForOpen(&hook_state.path_prompt, hook_state.allocator, active_editor);
                                }
                            }.call,
                            .close_active_editor = struct {
                                fn call(hook_raw: *anyopaque) !bool {
                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                    const active_editor = app_close_active_editor_runtime.activeEditor(hook_state) orelse return false;
                                    if (active_editor.modified) {
                                        hook_state.search_panel.active = false;
                                        try app_path_prompt_state.openForConfirmDirtyClose(&hook_state.path_prompt, hook_state.allocator);
                                        return true;
                                    }
                                    return try app_close_active_editor_runtime.closeActive(hook_state);
                                }
                            }.call,
                            .cycle_documents = struct {
                                fn call(hook_raw: *anyopaque, next: bool) !bool {
                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                    return try app_cycle_active_tab_runtime.cycle(hook_state, next);
                                }
                            }.call,
                            .quit_app = struct {
                                fn call(hook_raw: *anyopaque) void {
                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                    hook_state.shell.requestClose();
                                }
                            }.call,
                            .cycle_imported_theme_prev = struct {
                                fn call(hook_raw: *anyopaque) !void {
                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                    try app_imported_theme_runtime.cyclePrev(hook_state);
                                }
                            }.call,
                            .cycle_imported_theme_next = struct {
                                fn call(hook_raw: *anyopaque) !void {
                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                    try app_imported_theme_runtime.cycleNext(hook_state);
                                }
                            }.call,
                            .handle_terminal_shortcut_intent = struct {
                                fn call(route_raw: *anyopaque, intent: app_modes.ide.TerminalShortcutIntent, route_at: f64) !bool {
                                    const route_state: *State = @ptrCast(@alignCast(route_raw));
                                    if (!app_terminal_shortcut_policy.canHandleIntent(route_state.app_mode, intent)) return false;
                                    const hooks: app_terminal_shortcut_runtime.RuntimeHooks = .{
                                        .request_create = struct {
                                            fn call(hook_raw: *anyopaque, hook_at: f64) !bool {
                                                const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                                try app_tab_action_apply_runtime.applyTerminalAndSync(hook_state, .create);
                                                try hook_state.newTerminal();
                                                try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(hook_state);
                                                hook_state.needs_redraw = true;
                                                hook_state.metrics.noteInput(hook_at);
                                                return true;
                                            }
                                        }.call,
                                        .request_close = struct {
                                            fn call(hook_raw: *anyopaque, hook_at: f64) !bool {
                                                const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                                _ = try app_terminal_intent_route_runtime.routeActiveAndSync(hook_state, .close);
                                                if (try app_terminal_close_active_runtime.closeActive(
                                                    hook_state,
                                                    @ptrCast(hook_state),
                                                    .{
                                                        .sync_terminal_mode_tab_bar = struct {
                                                            fn call(sync_raw: *anyopaque) !void {
                                                                const sync_state: *State = @ptrCast(@alignCast(sync_raw));
                                                                try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(sync_state);
                                                            }
                                                        }.call,
                                                    },
                                                )) {
                                                    hook_state.needs_redraw = true;
                                                    hook_state.metrics.noteInput(hook_at);
                                                    return true;
                                                }
                                                if (app_terminal_close_confirm_active_runtime.reconcile(hook_state)) {
                                                    hook_state.needs_redraw = true;
                                                    hook_state.metrics.noteInput(hook_at);
                                                    return true;
                                                }
                                                return false;
                                            }
                                        }.call,
                                        .request_cycle = struct {
                                            fn call(hook_raw: *anyopaque, dir: app_modes.ide.TerminalShortcutCycleDirection, hook_at: f64) !bool {
                                                const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                                const moved = app_terminal_tab_navigation_runtime.cycle(hook_state, dir == .next);
                                                if (!moved) return false;
                                                try app_tab_action_apply_runtime.applyTerminalAndSync(hook_state, app_terminal_tab_intents.cycleIntentForDirection(dir));
                                                hook_state.needs_redraw = true;
                                                hook_state.metrics.noteInput(hook_at);
                                                return true;
                                            }
                                        }.call,
                                        .request_focus = struct {
                                            fn call(hook_raw: *anyopaque, route: app_modes.ide.TerminalFocusRoute, hook_at: f64) !bool {
                                                const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                                try app_tab_action_apply_runtime.applyTerminalAndSync(hook_state, route.intent);
                                                if (!app_terminal_tab_navigation_runtime.focusByIndex(hook_state, route.index)) return false;
                                                hook_state.needs_redraw = true;
                                                hook_state.metrics.noteInput(hook_at);
                                                return true;
                                            }
                                        }.call,
                                    };
                                    return app_terminal_shortcut_runtime.handleIntent(intent, route_at, @ptrCast(route_state), hooks);
                                }
                            }.call,
                        },
                    );
                    if (result.needs_redraw) action_state.needs_redraw = true;
                    if (result.note_input) action_state.metrics.noteInput(inner_at);
                    if (result.handled_zoom) handled_zoom.* = true;
                    return result.handled;
                }
            }.call,
        },
    );
}
