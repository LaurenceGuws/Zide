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
    const idx = activeIndex(
        app_mode,
        terminal_workspace,
        terminals_len,
    ) orelse return null;
    if (idx >= terminal_widgets.len) return null;
    return &terminal_widgets[idx];
}

pub fn activeIndex(
    app_mode: app_bootstrap.AppMode,
    terminal_workspace: *?workspace_mod.TerminalWorkspace,
    terminals_len: usize,
) ?usize {
    return app_terminal_tabs.activeIndex(
        app_mode,
        terminal_workspace.*,
        app_terminal_tabs.count(app_mode, terminal_workspace.*, terminals_len),
    );
}

pub fn syncUiFocus(
    app_mode: app_bootstrap.AppMode,
    terminal_workspace: *?workspace_mod.TerminalWorkspace,
    terminals_len: usize,
    terminal_widgets: []widgets.TerminalWidget,
    focused: bool,
) void {
    const active_idx = activeIndex(app_mode, terminal_workspace, terminals_len);
    for (terminal_widgets, 0..) |*widget, idx| {
        widget.setUiFocused(focused and active_idx != null and idx == active_idx.?);
    }
}
