const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const app_mouse_pressed_frame = @import("mouse_pressed_frame.zig");
const app_mouse_pressed_routing_runtime = @import("mouse_pressed_routing_runtime.zig");
const app_terminal_tabs_runtime = @import("terminal/terminal_tabs_runtime.zig");
const app_mode_adapter_sync_runtime = @import("mode_adapter_sync_runtime.zig");
const app_tab_action_apply_runtime = @import("tab_action_apply_runtime.zig");
const app_editor_intent_route = @import("editor_intent_route.zig");
const app_terminal_intent_route_runtime = @import("terminal/terminal_intent_route_runtime.zig");
const app_mouse_debug_log = @import("mouse_debug_log.zig");
const app_shell = @import("../app_shell.zig");
const shared_types = @import("../types/mod.zig");
const widgets = @import("../ui/widgets.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;
const Shell = app_shell.Shell;
const TabBar = widgets.TabBar;

pub fn handle(
    state: anytype,
    frame_shell: *Shell,
    frame_layout: layout_types.WidgetLayout,
    frame_mouse: input_types.MousePos,
    term_y: f32,
    frame_input_batch: *input_types.InputBatch,
    now: f64,
) !void {
    _ = frame_shell;
    const State = @TypeOf(state.*);
    try app_mouse_pressed_frame.handle(
        state.app_mode,
        frame_input_batch,
        frame_layout,
        frame_mouse,
        term_y,
        now,
        @ptrCast(state),
        .{
            .handle_ide_mouse_pressed_routing = struct {
                fn call(
                    route_raw: *anyopaque,
                    layout: layout_types.WidgetLayout,
                    mouse: input_types.MousePos,
                    frame_term_y: f32,
                    frame_now: f64,
                ) !void {
                    const route_state: *State = @ptrCast(@alignCast(route_raw));
                    const result = try app_mouse_pressed_routing_runtime.handleIde(
                        &route_state.tab_bar,
                        route_state.options_bar.height,
                        layout,
                        mouse,
                        frame_term_y,
                        route_state.show_terminal,
                        &route_state.active_tab,
                        &route_state.active_kind,
                        @ptrCast(route_state),
                        .{
                            .route_editor_activate_by_index = struct {
                                fn call(hook_raw: *anyopaque, index: usize) !void {
                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                    _ = try app_editor_intent_route.routeActivateByIndexAndSync(
                                        index,
                                        @ptrCast(hook_state),
                                        struct {
                                            fn inner(activate_raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                                                const apply_state: *State = @ptrCast(@alignCast(activate_raw));
                                                try app_tab_action_apply_runtime.applyEditorAndSync(apply_state, action);
                                            }
                                        }.inner,
                                    );
                                }
                            }.call,
                            .sync_mode_adapters = struct {
                                fn call(hook_raw: *anyopaque) !void {
                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                    try app_mode_adapter_sync_runtime.sync(hook_state);
                                }
                            }.call,
                        },
                    );
                    if (result.needs_redraw) route_state.needs_redraw = true;
                    if (result.note_input) route_state.metrics.noteInput(frame_now);
                }
            }.call,
            .handle_terminal_mouse_pressed_routing = struct {
                fn call(route_raw: *anyopaque, layout: layout_types.WidgetLayout, mouse: input_types.MousePos) !void {
                    const route_state: *State = @ptrCast(@alignCast(route_raw));
                    _ = try app_mouse_pressed_routing_runtime.handleTerminal(
                        &route_state.tab_bar,
                        layout,
                        mouse,
                        app_terminal_tabs_runtime.barVisible(
                            route_state.app_mode,
                            route_state.terminal_tab_bar_show_single_tab,
                            route_state.terminal_workspace,
                            route_state.terminals.items.len,
                        ),
                        &route_state.active_kind,
                        @ptrCast(route_state),
                        .{
                            .sync_mode_adapters = struct {
                                fn call(hook_raw: *anyopaque) !void {
                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                    try app_mode_adapter_sync_runtime.sync(hook_state);
                                }
                            }.call,
                            .route_terminal_activate = struct {
                                fn call(hook_raw: *anyopaque) !void {
                                    const hook_state: *State = @ptrCast(@alignCast(hook_raw));
                                    _ = try app_terminal_intent_route_runtime.routeActiveAndSync(hook_state, .activate);
                                }
                            }.call,
                        },
                    );
                }
            }.call,
            .handle_editor_mouse_pressed_routing = struct {
                fn call(route_raw: *anyopaque) !void {
                    const route_state: *State = @ptrCast(@alignCast(route_raw));
                    if (route_state.active_kind != .editor) {
                        route_state.active_kind = .editor;
                        try app_mode_adapter_sync_runtime.sync(route_state);
                    }
                }
            }.call,
            .log_mouse_debug_click = struct {
                fn call(route_raw: *anyopaque) void {
                    const route_state: *State = @ptrCast(@alignCast(route_raw));
                    app_mouse_debug_log.log(route_state.shell, route_state.mouse_debug);
                }
            }.call,
        },
    );
    _ = app_bootstrap;
    _ = TabBar;
}
