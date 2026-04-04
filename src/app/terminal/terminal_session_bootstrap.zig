const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const session_config = @import("../../terminal/core/session/config.zig");
const launch_shell_path_mod = @import("../../terminal/core/session/launch_shell_path.zig");
const session_runtime = @import("../../terminal/core/session/runtime.zig");
const terminal_runtime = @import("../../terminal/core/terminal_runtime.zig");
const widgets = @import("../../ui/widgets.zig");
const c = @cImport({
    @cInclude("stdlib.h");
});

const Shell = app_shell.Shell;
const TerminalRuntimeShell = terminal_runtime.TerminalRuntimeShell;
const TerminalWidget = widgets.TerminalWidget;

const win32 = if (@import("builtin").os.tag == .windows) struct {
    pub extern "kernel32" fn SetEnvironmentVariableA(lpName: [*:0]const u8, lpValue: ?[*:0]const u8) callconv(.winapi) i32;
} else struct {};

fn getEnvVarOwned(allocator: std.mem.Allocator, name: []const u8) !?[]u8 {
    return std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => return err,
    };
}

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

fn resolveLaunchShellPathOwned(
    allocator: std.mem.Allocator,
    configured_shell_path: ?[]const u8,
    env_shell_override: ?[]const u8,
) !?[]u8 {
    if (env_shell_override) |value| {
        if (value.len > 0) return try allocator.dupe(u8, value);
    }
    if (configured_shell_path) |value| {
        if (value.len > 0) return try allocator.dupe(u8, value);
    }
    if (@import("builtin").os.tag == .windows) {
        return try allocator.dupe(u8, "cmd.exe");
    }
    if (std.c.getenv("SHELL")) |value| {
        const shell = std.mem.sliceTo(value, 0);
        if (shell.len > 0) return try allocator.dupe(u8, shell);
    }
    return null;
}

pub fn startSessionWithShellCellSize(
    term: *TerminalRuntimeShell,
    shell: *Shell,
    launch_cwd: ?[]const u8,
    configured_shell_path: ?[]const u8,
) !void {
    const cell_geometry = shell.terminalCellGeometry();
    session_config.setCellSize(
        term,
        @intCast(@max(1, cell_geometry.cell_width_device_px)),
        @intCast(@max(1, cell_geometry.cell_height_device_px)),
    );
    const env_shell_override = try getEnvVarOwned(term.allocator, "ZIDE_TERMINAL_SHELL");
    defer if (env_shell_override) |value| term.allocator.free(value);
    const shell_override = env_shell_override orelse configured_shell_path;
    const shell_override_z = if (shell_override) |value|
        try term.allocator.dupeZ(u8, value)
    else
        null;
    defer if (shell_override_z) |value| term.allocator.free(value);
    const previous_launch_cwd = try getEnvVarOwned(term.allocator, "ZIDE_LAUNCH_CWD");
    defer if (previous_launch_cwd) |value| term.allocator.free(value);
    defer {
        if (previous_launch_cwd) |value| {
            if (term.allocator.dupeZ(u8, value)) |z_value| {
                defer term.allocator.free(z_value);
                setLaunchCwdEnv(z_value.ptr);
            } else |_| {
                setLaunchCwdEnv(null);
            }
        } else {
            setLaunchCwdEnv(null);
        }
    }

    const launch_shell_path = try resolveLaunchShellPathOwned(term.allocator, configured_shell_path, env_shell_override);
    defer if (launch_shell_path) |value| term.allocator.free(value);
    try launch_shell_path_mod.set(term, launch_shell_path);

    if (launch_cwd) |cwd| {
        const z_cwd = try term.allocator.dupeZ(u8, cwd);
        defer term.allocator.free(z_cwd);
        setLaunchCwdEnv(z_cwd.ptr);
    } else {
        setLaunchCwdEnv(null);
    }

    try session_runtime.start(term, if (shell_override_z) |value|
        value
    else
        null);
}

pub fn initWidget(
    term: *TerminalRuntimeShell,
    blink_style: TerminalWidget.BlinkStyle,
    focus_report_window_events: bool,
    focus_report_pane_events: bool,
) TerminalWidget {
    var widget = TerminalWidget.init(term, blink_style);
    widget.setFocusReportSources(focus_report_window_events, focus_report_pane_events);
    return widget;
}
