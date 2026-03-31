const std = @import("std");
const app_reload_config_shortcut_runtime = @import("reload_config_shortcut_runtime.zig");
const app_terminal_close_confirm_input = @import("terminal/terminal_close_confirm_input.zig");
const app_terminal_shortcut_suppress = @import("terminal/terminal_shortcut_suppress.zig");
const app_terminal_surface_gate = @import("terminal/terminal_surface_gate.zig");
const app_terminal_clipboard_shortcuts_frame = @import("terminal/terminal_clipboard_shortcuts_frame.zig");
const app_top_bar_window_chrome_runtime = @import("top_bar_window_chrome_runtime.zig");
const app_terminal_window_chrome_runtime = @import("terminal/window_chrome_runtime.zig");
const app_terminal_active_widget = @import("terminal/terminal_active_widget.zig");
const app_update_prelude_frame_runtime = @import("update_prelude_frame_runtime.zig");
const app_active_editor_runtime = @import("editor/active_editor_runtime.zig");
const app_logger = @import("../app_logger.zig");
const app_shell = @import("../app_shell.zig");
const app_bootstrap = @import("bootstrap.zig");
const capture_burst = @import("../debug/capture_burst.zig");
const app_modes = @import("modes/mod.zig");
const mode_build = @import("mode_build.zig");
const input_actions = @import("../input/input_actions.zig");
const sdl_api = @import("../platform/sdl_api.zig");
const shared_types = @import("../types/mod.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");

const Shell = app_shell.Shell;
const input_types = shared_types.input;
const layout_types = shared_types.layout;

fn maybeConsumeScrollLockCapture(
    frame_shell: *Shell,
    frame_input_batch: *input_types.InputBatch,
    at: f64,
    terminal_close_modal_active: bool,
    handled_shortcut: bool,
    app_mode: app_bootstrap.AppMode,
    show_terminal: bool,
    terminal_workspace: *?terminal_mod.TerminalWorkspace,
    terminals: []*terminal_mod.PtyTerminalSession,
    terminal_widgets: anytype,
    live_layout: layout_types.WidgetLayout,
) ?app_update_prelude_frame_runtime.PreInputResult {
    _ = show_terminal;
    for (frame_input_batch.events.items) |event| {
        switch (event) {
            .key => |key| {
                if (!key.pressed or key.repeated) continue;
                if (key.scancode == null or key.scancode.? != sdl_api.c.SDL_SCANCODE_SCROLLLOCK) continue;

                const renderer = frame_shell.rendererPtr();
                const burst_seq = capture_burst.arm(8);
                var rows: usize = 0;
                var cols: usize = 0;
                var visible_cols: i32 = 0;
                var visible_rows: i32 = 0;
                var viewport_w: f32 = 0;
                var viewport_h: f32 = 0;
                var texture_ready: bool = false;
                var render_generation: u64 = 0;
                if (app_terminal_active_widget.resolveActive(app_mode, terminal_workspace, terminals.len, terminal_widgets)) |term_widget| {
                    rows = term_widget.draw_cache.rows;
                    cols = term_widget.draw_cache.cols;
                    texture_ready = term_widget.terminal_texture_ready;
                    render_generation = term_widget.last_render_generation;
                    const strip = app_modes.ide.terminalStrip(app_mode, live_layout.terminal.height);
                    const geom = renderer.terminalCellGeometry();
                    viewport_w = @min(live_layout.terminal.width, geom.cell_width_logical_exact * @as(f32, @floatFromInt(cols)));
                    viewport_h = @min(strip.draw_height, geom.cell_height_logical_exact * @as(f32, @floatFromInt(rows)));
                    visible_cols = if (geom.cell_width_logical_exact > 0) @intFromFloat(std.math.floor(viewport_w / geom.cell_width_logical_exact)) else 0;
                    visible_rows = if (geom.cell_height_logical_exact > 0) @intFromFloat(std.math.floor(viewport_h / geom.cell_height_logical_exact)) else 0;
                }
                app_logger.logger("terminal.capture_trigger").logf(
                    .info,
                    "scroll_lock_capture seq={d} at={d:.3} render_scale={d:.3} window={d}x{d} drawable={d}x{d} target_logical={d}x{d} target_px={d}x{d} rows={d} cols={d} viewport={d:.1}x{d:.1} visible_cells={d}x{d} texture_ready={d} last_render_gen={d} mods=shift:{d} alt:{d} ctrl:{d} super:{d} altgr:{d}",
                    .{
                        burst_seq,
                        at,
                        renderer.render_scale,
                        renderer.width,
                        renderer.height,
                        renderer.render_width,
                        renderer.render_height,
                        renderer.target_width,
                        renderer.target_height,
                        renderer.target_pixel_width,
                        renderer.target_pixel_height,
                        rows,
                        cols,
                        viewport_w,
                        viewport_h,
                        visible_cols,
                        visible_rows,
                        @intFromBool(texture_ready),
                        render_generation,
                        @intFromBool(key.mods.shift),
                        @intFromBool(key.mods.alt),
                        @intFromBool(key.mods.ctrl),
                        @intFromBool(key.mods.super),
                        @intFromBool(key.mods.altgr),
                    },
                );
                return .{
                    .suppress_terminal_shortcuts = false,
                    .terminal_close_modal_active = terminal_close_modal_active,
                    .handled_shortcut = handled_shortcut,
                    .consumed = true,
                };
            },
            else => {},
        }
    }
    return null;
}

pub const Hooks = struct {
    reload_config: *const fn (*anyopaque) anyerror!void,
    show_reload_notice: *const fn (*anyopaque, bool) void,
    reconcile_terminal_close_modal_active: *const fn (*anyopaque) bool,
    apply_terminal_close_confirm_decision: *const fn (*anyopaque, app_modes.ide.TerminalCloseConfirmDecision, f64) anyerror!bool,
    compute_layout: *const fn (*anyopaque, f32, f32) layout_types.WidgetLayout,
    mark_redraw: *const fn (*anyopaque) void,
    note_input: *const fn (*anyopaque, f64) void,
};

pub fn handle(
    actions: []const input_actions.InputAction,
    frame_shell: *Shell,
    frame_input_batch: *input_types.InputBatch,
    focus: input_actions.FocusKind,
    at: f64,
    app_mode: app_bootstrap.AppMode,
    terminal_window_chrome_mode: anytype,
    show_terminal: bool,
    terminal_workspace: *?terminal_mod.TerminalWorkspace,
    terminals: []*terminal_mod.PtyTerminalSession,
    terminal_widgets: anytype,
    allocator: std.mem.Allocator,
    editors: anytype,
    active_tab: usize,
    top_bar: anytype,
    tab_bar: anytype,
    editor_cluster_cache: anytype,
    editor_wrap: bool,
    editor_large_jump_rows: usize,
    search_panel_active: *bool,
    search_panel_select_all: *bool,
    search_panel_query: *std.ArrayList(u8),
    path_prompt: anytype,
    ctx: *anyopaque,
    hooks: Hooks,
) !app_update_prelude_frame_runtime.PreInputResult {
    const r = frame_shell.rendererPtr();
    var handled_shortcut = app_reload_config_shortcut_runtime.handle(
        actions,
        ctx,
        .{
            .reload = hooks.reload_config,
            .show_notice = hooks.show_reload_notice,
        },
    );

    const live_layout = hooks.compute_layout(ctx, @floatFromInt(r.width), @floatFromInt(r.height));
    if ((app_terminal_window_chrome_runtime.isIntegratedActive(app_mode, terminal_window_chrome_mode) or
        app_top_bar_window_chrome_runtime.isIntegratedActive(app_mode)) and
        frame_input_batch.keyPressed(.space) and
        frame_input_batch.mods.alt and
        !frame_input_batch.mods.ctrl and
        !frame_input_batch.mods.super and
        !frame_input_batch.mods.altgr)
    {
        if (app_terminal_window_chrome_runtime.isIntegratedActive(app_mode, terminal_window_chrome_mode)) {
            const chrome = app_terminal_window_chrome_runtime.computeGeometry(
                frame_shell,
                tab_bar,
                live_layout.tab_bar,
                app_mode,
                terminal_window_chrome_mode,
            );
            if (chrome.enabled) {
                const scale = frame_shell.uiScaleFactor();
                _ = frame_shell.showWindowSystemMenu(
                    @intFromFloat(std.math.round(chrome.band.x + (8.0 * scale))),
                    @intFromFloat(std.math.round(chrome.band.y + chrome.band.height)),
                );
                hooks.note_input(ctx, at);
                return .{
                    .suppress_terminal_shortcuts = false,
                    .terminal_close_modal_active = hooks.reconcile_terminal_close_modal_active(ctx),
                    .handled_shortcut = true,
                    .consumed = true,
                };
            }
        } else {
            const chrome = app_top_bar_window_chrome_runtime.computeGeometry(
                frame_shell,
                top_bar,
                live_layout.top_bar,
                app_mode,
            );
            if (chrome.enabled) {
                const scale = frame_shell.uiScaleFactor();
                _ = frame_shell.showWindowSystemMenu(
                    @intFromFloat(std.math.round(chrome.band.x + (8.0 * scale))),
                    @intFromFloat(std.math.round(chrome.band.y + chrome.band.height)),
                );
                hooks.note_input(ctx, at);
                return .{
                    .suppress_terminal_shortcuts = false,
                    .terminal_close_modal_active = hooks.reconcile_terminal_close_modal_active(ctx),
                    .handled_shortcut = true,
                    .consumed = true,
                };
            }
        }
    }

    if (hooks.reconcile_terminal_close_modal_active(ctx)) {
        if (try app_terminal_close_confirm_input.handleInput(
            actions,
            frame_input_batch,
            live_layout,
            frame_shell.uiScaleFactor(),
            at,
            ctx,
            hooks.apply_terminal_close_confirm_decision,
        )) {
            return .{
                .suppress_terminal_shortcuts = false,
                .terminal_close_modal_active = hooks.reconcile_terminal_close_modal_active(ctx),
                .handled_shortcut = handled_shortcut,
                .consumed = true,
            };
        }
    }

    const terminal_close_modal_active = hooks.reconcile_terminal_close_modal_active(ctx);
    const suppress_terminal_shortcuts = app_terminal_shortcut_suppress.forFocus(focus, actions);

    if (maybeConsumeScrollLockCapture(frame_shell, frame_input_batch, at, terminal_close_modal_active, handled_shortcut, app_mode, show_terminal, terminal_workspace, terminals, terminal_widgets, live_layout)) |capture_result| {
        return capture_result;
    }

    if (!terminal_close_modal_active and focus == .terminal and app_terminal_surface_gate.hasTerminalInputScopeWithTabs(app_mode, show_terminal, terminal_workspace.*, terminals.len)) {
        const clipboard_result = try app_terminal_clipboard_shortcuts_frame.handle(
            actions,
            allocator,
            app_mode,
            terminal_workspace,
            terminals,
            terminal_widgets,
            frame_shell,
            frame_input_batch.events.items.len,
            at,
        );
        if (clipboard_result.needs_redraw) hooks.mark_redraw(ctx);
        if (clipboard_result.handled) handled_shortcut = true;
    }

    if (comptime mode_build.focused_mode != .terminal) {
        if (focus == .editor and editors.len > 0 and !search_panel_active.* and !path_prompt.active) {
            const app_editor_shortcuts_frame = @import("editor/editor_shortcuts_frame.zig");
            const action_layout = hooks.compute_layout(ctx, @floatFromInt(r.width), @floatFromInt(r.height));
            const editor = app_active_editor_runtime.fromVisualIndex(tab_bar, editors, active_tab) orelse return .{
                .suppress_terminal_shortcuts = suppress_terminal_shortcuts,
                .terminal_close_modal_active = terminal_close_modal_active,
                .handled_shortcut = handled_shortcut,
                .consumed = false,
            };
            const editor_shortcut_result = try app_editor_shortcuts_frame.handle(
                actions,
                allocator,
                frame_shell,
                action_layout,
                editor,
                editor_cluster_cache,
                editor_wrap,
                editor_large_jump_rows,
                search_panel_active,
                search_panel_select_all,
                search_panel_query,
                path_prompt,
            );
            if (editor_shortcut_result.needs_redraw) hooks.mark_redraw(ctx);
            if (editor_shortcut_result.handled) handled_shortcut = true;
        }
    }

    return .{
        .suppress_terminal_shortcuts = suppress_terminal_shortcuts,
        .terminal_close_modal_active = terminal_close_modal_active,
        .handled_shortcut = handled_shortcut,
        .consumed = false,
    };
}
