const app_bootstrap = @import("../bootstrap.zig");
const app_modes = @import("../modes/mod.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");

const AppMode = app_bootstrap.AppMode;
const TerminalWorkspace = terminal_mod.TerminalWorkspace;

pub fn count(
    app_mode: AppMode,
    terminal_workspace: ?TerminalWorkspace,
    terminals_len: usize,
) usize {
    if (app_modes.ide.shouldUseTerminalWorkspace(app_mode)) {
        if (terminal_workspace) |workspace| return workspace.tabCount();
        return 0;
    }
    return terminals_len;
}

pub fn barVisible(app_mode: AppMode, show_single_tab: bool, tab_count: usize) bool {
    return app_modes.ide.terminalTabBarVisible(
        app_mode,
        show_single_tab,
        tab_count,
    );
}

pub fn activeIndex(
    app_mode: AppMode,
    terminal_workspace: ?TerminalWorkspace,
    tab_count: usize,
) ?usize {
    if (tab_count == 0) return null;
    if (app_modes.ide.shouldUseTerminalWorkspace(app_mode)) {
        if (terminal_workspace) |workspace| {
            return @min(workspace.activeIndex(), tab_count - 1);
        }
    }
    return 0;
}
