const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const app_terminal_active_session = @import("terminal_active_session.zig");
const app_terminal_clipboard_shortcuts_runtime = @import("terminal_clipboard_shortcuts_runtime.zig");
const terminal_scrollback_pager = @import("terminal_scrollback_pager.zig");
const input_actions = @import("../input/input_actions.zig");
const app_shell = @import("../app_shell.zig");
const widgets = @import("../ui/widgets.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");

pub fn handle(
    actions: []const input_actions.InputAction,
    allocator: std.mem.Allocator,
    app_mode: app_bootstrap.AppMode,
    terminal_workspace: *?terminal_mod.TerminalWorkspace,
    terminals: []*terminal_mod.TerminalSession,
    shell: *app_shell.Shell,
    widget: *widgets.TerminalWidget,
) !app_terminal_clipboard_shortcuts_runtime.RuntimeResult {
    const RuntimeCtx = struct {
        allocator: std.mem.Allocator,
        app_mode: app_bootstrap.AppMode,
        terminal_workspace: *?terminal_mod.TerminalWorkspace,
        terminals: []*terminal_mod.TerminalSession,
        shell: *app_shell.Shell,
        widget: *widgets.TerminalWidget,
    };

    var runtime_ctx: RuntimeCtx = .{
        .allocator = allocator,
        .app_mode = app_mode,
        .terminal_workspace = terminal_workspace,
        .terminals = terminals,
        .shell = shell,
        .widget = widget,
    };

    const hooks: app_terminal_clipboard_shortcuts_runtime.RuntimeHooks = .{
        .copy = struct {
            fn call(raw: *anyopaque) !bool {
                const ctx: *RuntimeCtx = @ptrCast(@alignCast(raw));
                return ctx.widget.copySelectionToClipboard(ctx.shell);
            }
        }.call,
        .paste = struct {
            fn call(raw: *anyopaque) !bool {
                const ctx: *RuntimeCtx = @ptrCast(@alignCast(raw));
                return ctx.widget.pasteClipboardFromSystem(ctx.shell);
            }
        }.call,
        .scrollback_pager = struct {
            fn call(raw: *anyopaque) !bool {
                const ctx: *RuntimeCtx = @ptrCast(@alignCast(raw));
                const term = app_terminal_active_session.resolveActive(
                    ctx.app_mode,
                    ctx.terminal_workspace,
                    ctx.terminals,
                ) orelse return false;
                return terminal_scrollback_pager.openInPager(
                    ctx.allocator,
                    ctx.widget,
                    term,
                );
            }
        }.call,
    };

    return app_terminal_clipboard_shortcuts_runtime.handle(
        actions,
        @ptrCast(&runtime_ctx),
        hooks,
    );
}

