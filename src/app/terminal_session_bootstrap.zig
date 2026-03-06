const std = @import("std");
const app_shell = @import("../app_shell.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");
const widgets = @import("../ui/widgets.zig");
const c = @cImport({
    @cInclude("stdlib.h");
});

const Shell = app_shell.Shell;
const TerminalSession = terminal_mod.TerminalSession;
const TerminalWidget = widgets.TerminalWidget;

pub fn startSessionWithShellCellSize(term: *TerminalSession, shell: *Shell, launch_cwd: ?[]const u8) !void {
    term.setCellSize(
        @intFromFloat(shell.terminalCellWidth()),
        @intFromFloat(shell.terminalCellHeight()),
    );
    const previous_launch_cwd = if (std.c.getenv("ZIDE_LAUNCH_CWD")) |value|
        try term.allocator.dupeZ(u8, std.mem.sliceTo(value, 0))
    else
        null;
    defer if (previous_launch_cwd) |value| term.allocator.free(value);
    defer {
        if (previous_launch_cwd) |value| {
            _ = c.setenv("ZIDE_LAUNCH_CWD", value.ptr, 1);
        } else {
            _ = c.unsetenv("ZIDE_LAUNCH_CWD");
        }
    }

    if (launch_cwd) |cwd| {
        const z_cwd = try term.allocator.dupeZ(u8, cwd);
        defer term.allocator.free(z_cwd);
        _ = c.setenv("ZIDE_LAUNCH_CWD", z_cwd.ptr, 1);
    } else {
        _ = c.unsetenv("ZIDE_LAUNCH_CWD");
    }

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
