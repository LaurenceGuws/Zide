const app_shell = @import("../../app_shell.zig");
const terminal_runtime = @import("../../terminal/core/terminal_runtime.zig");

const Shell = app_shell.Shell;
const TerminalWorkspace = terminal_runtime.TerminalWorkspace;
const PtyTerminalRuntime = terminal_runtime.PtyTerminalRuntime;

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
    term: *PtyTerminalRuntime,
    shell: *Shell,
    rows: u16,
    cols: u16,
) !void {
    term.setCellSize(
        @intFromFloat(shell.terminalCellWidth()),
        @intFromFloat(shell.terminalCellHeight()),
    );
    try term.resize(rows, cols);
}

pub fn resizeSessionsWithShellCellSize(
    sessions: []*PtyTerminalRuntime,
    shell: *Shell,
    rows: u16,
    cols: u16,
) !void {
    for (sessions) |term| {
        try resizeSessionWithShellCellSize(term, shell, rows, cols);
    }
}
