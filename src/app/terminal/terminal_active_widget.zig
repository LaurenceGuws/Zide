const app_bootstrap = @import("../bootstrap.zig");
const app_terminal_tabs = @import("terminal_tabs.zig");
const workspace_mod = @import("../../terminal/core/workspace.zig");
const widgets = @import("../../ui/widgets.zig");

pub fn resolveActive(
    app_mode: app_bootstrap.AppMode,
    terminal_workspace: *?workspace_mod.TerminalWorkspace,
    terminals_len: usize,
    terminal_widgets: []widgets.TerminalWidget,
) ?*widgets.TerminalWidget {
    const idx = app_terminal_tabs.activeIndex(
        app_mode,
        terminal_workspace.*,
        app_terminal_tabs.count(app_mode, terminal_workspace.*, terminals_len),
    ) orelse return null;
    if (idx >= terminal_widgets.len) return null;
    return &terminal_widgets[idx];
}
