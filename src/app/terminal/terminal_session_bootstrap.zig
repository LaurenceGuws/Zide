const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const widgets = @import("../../ui/widgets.zig");
const c = @cImport({
    @cInclude("stdlib.h");
});

const Shell = app_shell.Shell;
const TerminalSession = terminal_mod.TerminalSession;
const TerminalWidget = widgets.TerminalWidget;

const win32 = if (@import("builtin").os.tag == .windows) struct {
    pub extern "kernel32" fn SetEnvironmentVariableA(lpName: [*:0]const u8, lpValue: ?[*:0]const u8) callconv(.winapi) i32;
} else struct {};

fn setLaunchCwdEnv(value: ?[*:0]const u8) void {
    if (@import("builtin").os.tag == .windows) {
        _ = win32.SetEnvironmentVariableA("ZIDE_LAUNCH_CWD", value);
    } else {
        if (value) |v| {
            _ = c.setenv("ZIDE_LAUNCH_CWD", v, 1);
        } else {
            _ = c.unsetenv("ZIDE_LAUNCH_CWD");
        }
    }
}

pub fn startSessionWithShellCellSize(term: *TerminalSession, shell: *Shell, launch_cwd: ?[]const u8) !void {
    term.setCellSize(
        @intFromFloat(shell.terminalCellWidth()),
        @intFromFloat(shell.terminalCellHeight()),
    );
    const shell_override = if (std.c.getenv("ZIDE_TERMINAL_SHELL")) |value|
        std.mem.sliceTo(value, 0)
    else
        null;
    const previous_launch_cwd = if (std.c.getenv("ZIDE_LAUNCH_CWD")) |value|
        try term.allocator.dupeZ(u8, std.mem.sliceTo(value, 0))
    else
        null;
    defer if (previous_launch_cwd) |value| term.allocator.free(value);
    defer {
        if (previous_launch_cwd) |value| {
            setLaunchCwdEnv(value.ptr);
        } else {
            setLaunchCwdEnv(null);
        }
    }

    if (launch_cwd) |cwd| {
        const z_cwd = try term.allocator.dupeZ(u8, cwd);
        defer term.allocator.free(z_cwd);
        setLaunchCwdEnv(z_cwd.ptr);
    } else {
        setLaunchCwdEnv(null);
    }

    try term.start(if (shell_override) |value| value else null);
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
