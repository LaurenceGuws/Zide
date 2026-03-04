const app_shell = @import("../app_shell.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");
const widgets = @import("../ui/widgets.zig");

const Shell = app_shell.Shell;
const TerminalSession = terminal_mod.TerminalSession;
const TerminalWidget = widgets.TerminalWidget;

pub fn startSessionWithShellCellSize(term: *TerminalSession, shell: *Shell) !void {
    term.setCellSize(
        @intFromFloat(shell.terminalCellWidth()),
        @intFromFloat(shell.terminalCellHeight()),
    );
    try term.start(null);
}

pub fn initWidget(
    term: *TerminalSession,
    blink_style: TerminalWidget.BlinkStyle,
    focus_report_window_events: bool,
    focus_report_pane_events: bool,
) TerminalWidget {
    var widget = TerminalWidget.init(term, blink_style);
    widget.setFocusReportSources(focus_report_window_events, focus_report_pane_events);
    return widget;
}
