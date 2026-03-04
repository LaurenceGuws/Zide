const app_shell = @import("../app_shell.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");

const Shell = app_shell.Shell;
const TerminalWorkspace = terminal_mod.TerminalWorkspace;
const TerminalSession = terminal_mod.TerminalSession;

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
    term: *TerminalSession,
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
    sessions: []*TerminalSession,
    shell: *Shell,
    rows: u16,
    cols: u16,
) !void {
    for (sessions) |term| {
        try resizeSessionWithShellCellSize(term, shell, rows, cols);
    }
}
