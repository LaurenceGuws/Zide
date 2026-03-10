const std = @import("std");
const app_terminal_clipboard_shortcuts_runtime = @import("terminal_clipboard_shortcuts_runtime.zig");
const terminal_scrollback_pager = @import("../terminal_scrollback_pager.zig");
const input_actions = @import("../../input/input_actions.zig");
const app_shell = @import("../../app_shell.zig");
const widgets = @import("../../ui/widgets.zig");

pub fn handle(
    actions: []const input_actions.InputAction,
    allocator: std.mem.Allocator,
    shell: *app_shell.Shell,
    widget: *widgets.TerminalWidget,
) !app_terminal_clipboard_shortcuts_runtime.RuntimeResult {
    const RuntimeCtx = struct {
        allocator: std.mem.Allocator,
        shell: *app_shell.Shell,
        widget: *widgets.TerminalWidget,
    };

    var runtime_ctx: RuntimeCtx = .{
        .allocator = allocator,
        .shell = shell,
        .widget = widget,
    };

    const hooks: app_terminal_clipboard_shortcuts_runtime.RuntimeHooks = .{
        .copy = struct {
            fn call(raw: *anyopaque) !bool {
                const ctx: *RuntimeCtx = @ptrCast(@alignCast(raw));
                const term = ctx.widget.session;
                const text = (try term.selectionPlainTextAlloc(ctx.allocator)) orelse return false;
                defer ctx.allocator.free(text);
                const cstr = try ctx.allocator.dupeZ(u8, text);
                defer ctx.allocator.free(cstr);
                ctx.shell.setClipboardText(cstr);
                return true;
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
                return terminal_scrollback_pager.openInPager(
                    ctx.allocator,
                    ctx.widget.session,
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
