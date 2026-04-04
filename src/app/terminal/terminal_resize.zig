const session_runtime = @import("../../terminal/core/session/runtime.zig");
const terminal_runtime = @import("../../terminal/core/terminal_runtime.zig");
const workspace_mod = @import("../../terminal/core/workspace.zig");

const TerminalWorkspace = workspace_mod.TerminalWorkspace;
const TerminalRuntimeShell = terminal_runtime.TerminalRuntimeShell;

pub fn resizeWorkspaceWithCellSize(
    workspace: *TerminalWorkspace,
    rows: u16,
    cols: u16,
    cell_width: u16,
    cell_height: u16,
) !void {
    try workspace.resizeAllWithCellSize(
        rows,
        cols,
        cell_width,
        cell_height,
    );
}

pub fn resizeSessionWithCellSize(
    term: *TerminalRuntimeShell,
    rows: u16,
    cols: u16,
    cell_width: u16,
    cell_height: u16,
) !void {
    try session_runtime.resizeWithCellSize(
        term,
        rows,
        cols,
        cell_width,
        cell_height,
    );
}

pub fn resizeSessionsWithCellSize(
    sessions: []*TerminalRuntimeShell,
    rows: u16,
    cols: u16,
    cell_width: u16,
    cell_height: u16,
) !void {
    for (sessions) |term| {
        try resizeSessionWithCellSize(term, rows, cols, cell_width, cell_height);
    }
}
