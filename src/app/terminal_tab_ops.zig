const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");
const widgets = @import("../ui/widgets.zig");

const AppMode = app_bootstrap.AppMode;
const TerminalWorkspace = terminal_mod.TerminalWorkspace;
const TabBar = widgets.TabBar;

pub fn focusByVisualIndex(
    app_mode: AppMode,
    terminal_workspace: *?TerminalWorkspace,
    tab_bar: *TabBar,
    index: usize,
) bool {
    if (!app_modes.ide.shouldUseTerminalWorkspace(app_mode)) return false;
    if (terminal_workspace.*) |*workspace| {
        const tab_id = tab_bar.terminalTabIdAtVisual(index) orelse return false;
        if (!workspace.activateTab(tab_id)) return false;
        tab_bar.active_index = tab_bar.indexOfTerminalTabId(tab_id) orelse tab_bar.active_index;
        return true;
    }
    return false;
}

pub fn cycle(
    app_mode: AppMode,
    terminal_workspace: *?TerminalWorkspace,
    tab_bar: *TabBar,
    next: bool,
) bool {
    if (!app_modes.ide.shouldUseTerminalWorkspace(app_mode)) return false;
    if (terminal_workspace.*) |*workspace| {
        const changed = if (next) workspace.activateNext() else workspace.activatePrev();
        if (!changed) return false;
        if (workspace.activeTabId()) |active_id| {
            tab_bar.active_index = tab_bar.indexOfTerminalTabId(active_id) orelse tab_bar.active_index;
        }
        return true;
    }
    return false;
}
