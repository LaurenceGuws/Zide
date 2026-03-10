const app_bootstrap = @import("../bootstrap.zig");
const app_modes = @import("../modes/mod.zig");
const app_terminal_tabs_runtime = @import("terminal_tabs_runtime.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");

pub fn hasVisibleTerminalTabs(
    app_mode: app_bootstrap.AppMode,
    show_terminal: bool,
    terminal_workspace: ?terminal_mod.TerminalWorkspace,
    terminals_len: usize,
) bool {
    return app_modes.ide.supportsTerminalSurface(app_mode) and
        show_terminal and
        app_terminal_tabs_runtime.count(app_mode, terminal_workspace, terminals_len) > 0;
}

pub fn hasTerminalInputScopeWithTabs(
    app_mode: app_bootstrap.AppMode,
    show_terminal: bool,
    terminal_workspace: ?terminal_mod.TerminalWorkspace,
    terminals_len: usize,
) bool {
    return app_modes.ide.hasTerminalInputScope(app_mode, show_terminal) and
        app_terminal_tabs_runtime.count(app_mode, terminal_workspace, terminals_len) > 0;
}
