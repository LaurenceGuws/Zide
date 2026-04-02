const app_shell = @import("../../app_shell.zig");
const session_config = @import("../../terminal/core/session/config.zig");
const session_runtime = @import("../../terminal/core/session/runtime.zig");
const terminal_runtime = @import("../../terminal/core/terminal_runtime.zig");
const workspace_mod = @import("../../terminal/core/workspace.zig");

const Shell = app_shell.Shell;
const TerminalWorkspace = workspace_mod.TerminalWorkspace;
const TerminalRuntimeShell = terminal_runtime.TerminalRuntimeShell;

pub fn resizeWorkspaceWithShellCellSize(
    workspace: *TerminalWorkspace,
    shell: *Shell,
    rows: u16,
    cols: u16,
) !void {
    workspace.setCellSizeAll(
        @intFromFloat(shell.terminalCellWidth()),
        @intFromFloat(shell.terminalCellHeight()),
    );
    try workspace.resizeAll(rows, cols);
}

pub fn resizeSessionWithShellCellSize(
    term: *TerminalRuntimeShell,
    shell: *Shell,
    rows: u16,
    cols: u16,
) !void {
    session_config.setCellSize(
        term,
        @intFromFloat(shell.terminalCellWidth()),
        @intFromFloat(shell.terminalCellHeight()),
    );
    try session_runtime.resize(term, rows, cols);
}

pub fn resizeSessionsWithShellCellSize(
    sessions: []*TerminalRuntimeShell,
    shell: *Shell,
    rows: u16,
    cols: u16,
) !void {
    for (sessions) |term| {
        try resizeSessionWithShellCellSize(term, shell, rows, cols);
    }
}
