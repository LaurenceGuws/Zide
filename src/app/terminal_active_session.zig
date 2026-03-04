const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const app_terminal_tabs = @import("terminal_tabs.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");

pub fn resolveActive(
    app_mode: app_bootstrap.AppMode,
    terminal_workspace: *?terminal_mod.TerminalWorkspace,
    terminals: []*terminal_mod.TerminalSession,
) ?*terminal_mod.TerminalSession {
    const active_idx = app_terminal_tabs.activeIndex(
        app_mode,
        terminal_workspace.*,
        app_terminal_tabs.count(app_mode, terminal_workspace.*, terminals.len),
    ) orelse return null;

    if (app_modes.ide.shouldUseTerminalWorkspace(app_mode)) {
        if (terminal_workspace.*) |*workspace| {
            return workspace.sessionAt(active_idx);
        }
        return null;
    }

    if (active_idx >= terminals.len) return null;
    return terminals[active_idx];
}

