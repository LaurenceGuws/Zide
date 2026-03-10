const std = @import("std");
const app_reload_config_shortcut_runtime = @import("reload_config_shortcut_runtime.zig");
const app_terminal_close_confirm_input = @import("terminal/terminal_close_confirm_input.zig");
const app_terminal_shortcut_suppress = @import("terminal/terminal_shortcut_suppress.zig");
const app_terminal_surface_gate = @import("terminal/terminal_surface_gate.zig");
const app_terminal_clipboard_shortcuts_frame = @import("terminal/terminal_clipboard_shortcuts_frame.zig");
const app_update_prelude_frame_runtime = @import("update_prelude_frame_runtime.zig");
const app_shell = @import("../app_shell.zig");
const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const mode_build = @import("mode_build.zig");
const input_actions = @import("../input/input_actions.zig");
const shared_types = @import("../types/mod.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");

const Shell = app_shell.Shell;
const input_types = shared_types.input;
const layout_types = shared_types.layout;

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
    show_terminal: bool,
    terminal_workspace: *?terminal_mod.TerminalWorkspace,
    terminals: []*terminal_mod.TerminalSession,
    terminal_widgets: anytype,
    allocator: std.mem.Allocator,
    editors: anytype,
    active_tab: usize,
    editor_cluster_cache: anytype,
    editor_wrap: bool,
    editor_large_jump_rows: usize,
    search_panel_active: *bool,
    search_panel_query: *std.ArrayList(u8),
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
        if (focus == .editor and editors.len > 0) {
            const app_editor_shortcuts_frame = @import("editor/editor_shortcuts_frame.zig");
            const action_layout = hooks.compute_layout(ctx, @floatFromInt(r.width), @floatFromInt(r.height));
            const editor_idx = @min(active_tab, editors.len - 1);
            const editor = editors[editor_idx];
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
                search_panel_query,
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
