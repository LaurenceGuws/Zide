const std = @import("std");
const app_bootstrap = @import("../bootstrap.zig");
const app_terminal_active_widget = @import("terminal_active_widget.zig");
const app_terminal_clipboard_shortcuts = @import("terminal_clipboard_shortcuts.zig");
const app_terminal_clipboard_shortcuts_runtime = @import("terminal_clipboard_shortcuts_runtime.zig");
const input_actions = @import("../../input/input_actions.zig");
const app_shell = @import("../../app_shell.zig");
const widgets = @import("../../ui/widgets.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");

pub fn handle(
    actions: []const input_actions.InputAction,
    allocator: std.mem.Allocator,
    app_mode: app_bootstrap.AppMode,
    terminal_workspace: *?terminal_mod.TerminalWorkspace,
    terminals: []*terminal_mod.TerminalSession,
    terminal_widgets: []widgets.TerminalWidget,
    shell: *app_shell.Shell,
    input_event_count: usize,
    now: f64,
) !app_terminal_clipboard_shortcuts_runtime.RuntimeResult {
    const term_widget = app_terminal_active_widget.resolveActive(
        app_mode,
        terminal_workspace,
        terminals.len,
        terminal_widgets,
    ) orelse return .{};

    if (input_event_count > 0) {
        term_widget.noteInput(now);
    }

    return app_terminal_clipboard_shortcuts.handle(
        actions,
        allocator,
        shell,
        term_widget,
    );
}
