const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const app_mouse_pressed_frame = @import("mouse_pressed_frame.zig");
const app_mouse_pressed_routing_runtime = @import("mouse_pressed_routing_runtime.zig");
const app_top_bar_frame_runtime = @import("top_bar_frame_runtime.zig");
const app_top_bar_window_chrome_runtime = @import("top_bar_window_chrome_runtime.zig");
const app_terminal_window_chrome_runtime = @import("terminal/window_chrome_runtime.zig");
const app_mode_adapter_sync_runtime = @import("mode_adapter_sync_runtime.zig");
const app_tab_action_apply_runtime = @import("tabs/tab_action_apply_runtime.zig");
const app_terminal_intent_route_runtime = @import("terminal/terminal_intent_route_runtime.zig");
const app_mouse_debug_log = @import("mouse_debug_log.zig");
const app_shell = @import("../app_shell.zig");
const shared_types = @import("../types/mod.zig");
const widgets = @import("../ui/widgets.zig");
const mode_build = @import("mode_build.zig");

const app_editor_intent_route = if (mode_build.focused_mode == .terminal) struct {
    pub fn routeActivateByIndexAndSync(_: usize, _: *anyopaque, _: anytype) !void {
        return error.UnsupportedMode;
    }
} else @import("editor/editor_intent_route.zig");

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
    const left_pressed = frame_input_batch.mousePressed(input_types.MouseButton.left);
    const left_released = frame_input_batch.mouseReleased(input_types.MouseButton.left);
    const right_pressed = frame_input_batch.mousePressed(input_types.MouseButton.right);

    if (left_pressed or left_released or right_pressed or state.pressed_window_caption_button != null) {
        if (app_terminal_window_chrome_runtime.isIntegratedActive(state.app_mode, state.terminal_window_chrome_mode)) {
            const chrome = app_terminal_window_chrome_runtime.computeGeometry(
                state.shell,
                &state.tab_bar,
                frame_layout.tab_bar,
                state.app_mode,
                state.terminal_window_chrome_mode,
            );
            if (try handleWindowChromeButtons(state, chrome, frame_mouse, frame_input_batch, now, app_terminal_window_chrome_runtime.buttonAt, app_terminal_window_chrome_runtime.captionDragAt)) return;
        } else if (app_top_bar_window_chrome_runtime.isIntegratedActive(state.app_mode)) {
            const chrome = app_top_bar_window_chrome_runtime.computeGeometry(
                state.shell,
                &state.top_bar,
                frame_layout.top_bar,
                state.app_mode,
            );
            if (try handleWindowChromeButtons(state, chrome, frame_mouse, frame_input_batch, now, app_top_bar_window_chrome_runtime.buttonAt, app_top_bar_window_chrome_runtime.captionDragAt)) return;
        } else {
            state.pressed_window_caption_button = null;
        }
    }
    if (comptime mode_build.focused_mode != .terminal) {
        if (frame_layout.top_bar.height > 0 and frame_input_batch.mousePressed(input_types.MouseButton.left)) {
            if (try app_top_bar_frame_runtime.handleLeftClick(state, frame_layout, frame_mouse, now)) return;
        }
    }
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
                        route_state.shell,
                        layout,
                        mouse,
                        app_terminal_window_chrome_runtime.barVisible(
                            route_state.app_mode,
                            route_state.terminal_window_chrome_mode,
                            route_state.terminal_tab_bar_show_single_tab,
                            route_state.terminal_workspace,
                            route_state.terminals.items.len,
                        ),
                        route_state.app_mode,
                        route_state.terminal_window_chrome_mode,
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

fn handleWindowChromeButtons(
    state: anytype,
    chrome: anytype,
    frame_mouse: input_types.MousePos,
    frame_input_batch: *input_types.InputBatch,
    now: f64,
    comptime buttonAtFn: anytype,
    comptime captionDragAtFn: anytype,
) !bool {
    if (!chrome.enabled or state.shell.integratedWindowChromeSinkOwnsChrome()) {
        state.pressed_window_caption_button = null;
        return false;
    }

    const left_pressed = frame_input_batch.mousePressed(input_types.MouseButton.left);
    const left_released = frame_input_batch.mouseReleased(input_types.MouseButton.left);
    const right_pressed = frame_input_batch.mousePressed(input_types.MouseButton.right);
    const hovered_button = buttonAtFn(chrome, frame_mouse.x, frame_mouse.y);
    if (right_pressed and hovered_button == null and captionDragAtFn(chrome, frame_mouse.x, frame_mouse.y)) {
        _ = state.shell.showWindowSystemMenu(
            @intFromFloat(std.math.round(frame_mouse.x)),
            @intFromFloat(std.math.round(frame_mouse.y)),
        );
        state.metrics.noteInput(now);
        return true;
    }
    if (left_pressed) {
        if (hovered_button == null and
            frame_input_batch.mouseClicks(input_types.MouseButton.left) >= 2 and
            captionDragAtFn(chrome, frame_mouse.x, frame_mouse.y))
        {
            _ = state.shell.toggleMaximizeWindow();
            state.pressed_window_caption_button = null;
            state.needs_redraw = true;
            state.metrics.noteInput(now);
            return true;
        }
        if (hovered_button) |button| {
            state.pressed_window_caption_button = button;
            state.needs_redraw = true;
            state.metrics.noteInput(now);
            return true;
        }
        state.pressed_window_caption_button = null;
    }
    if (left_released) {
        if (state.pressed_window_caption_button) |pressed_button| {
            if (hovered_button == pressed_button) {
                switch (pressed_button) {
                    .minimize => _ = state.shell.minimizeWindow(),
                    .maximize_restore => _ = state.shell.toggleMaximizeWindow(),
                    .close => state.shell.requestClose(),
                }
            }
            state.pressed_window_caption_button = null;
            state.needs_redraw = true;
            state.metrics.noteInput(now);
            return true;
        }
    }
    return false;
}
