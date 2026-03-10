const app_bootstrap = @import("../bootstrap.zig");
const app_terminal_tabs = @import("terminal_tabs.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");

pub fn count(
    app_mode: app_bootstrap.AppMode,
    terminal_workspace: ?terminal_mod.TerminalWorkspace,
    terminals_len: usize,
) usize {
    return app_terminal_tabs.count(app_mode, terminal_workspace, terminals_len);
}

pub fn barVisible(
    app_mode: app_bootstrap.AppMode,
    show_single_tab: bool,
    terminal_workspace: ?terminal_mod.TerminalWorkspace,
    terminals_len: usize,
) bool {
    return app_terminal_tabs.barVisible(
        app_mode,
        show_single_tab,
        count(app_mode, terminal_workspace, terminals_len),
    );
}

pub fn activeIndex(
    app_mode: app_bootstrap.AppMode,
    terminal_workspace: ?terminal_mod.TerminalWorkspace,
    terminals_len: usize,
) ?usize {
    return app_terminal_tabs.activeIndex(
        app_mode,
        terminal_workspace,
        count(app_mode, terminal_workspace, terminals_len),
    );
}
