const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const app_terminal_grid = @import("terminal_grid.zig");
const app_terminal_resize = @import("terminal_resize.zig");
const app_terminal_tabs_runtime = @import("terminal/terminal_tabs_runtime.zig");
const app_ui_layout_runtime = @import("ui_layout_runtime.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");

const AppMode = app_bootstrap.AppMode;
const TerminalSession = terminal_mod.TerminalSession;
const TerminalWorkspace = terminal_mod.TerminalWorkspace;

pub fn handle(
    state: anytype,
    app_mode: AppMode,
    terminal_workspace: *?TerminalWorkspace,
    terminals: []*TerminalSession,
    show_terminal: bool,
    terminal_height: f32,
    shell: anytype,
) !void {
    if (app_terminal_tabs_runtime.count(app_mode, terminal_workspace.*, terminals.len) == 0) return;
    const width = @as(f32, @floatFromInt(shell.width()));
    const height = @as(f32, @floatFromInt(shell.height()));
    const layout = app_ui_layout_runtime.computeLayout(state, width, height);
    const effective_height = app_modes.ide.terminalEffectiveHeightForSizing(
        app_mode,
        show_terminal,
        layout.terminal.height,
        terminal_height,
    );
    const grid = app_terminal_grid.compute(
        layout.terminal.width,
        effective_height,
        shell.terminalCellWidth(),
        shell.terminalCellHeight(),
        1,
        1,
    );
    const cols: u16 = grid.cols;
    const rows: u16 = grid.rows;
    if (app_modes.ide.shouldUseTerminalWorkspace(app_mode)) {
        if (terminal_workspace.*) |*workspace| {
            try app_terminal_resize.resizeWorkspaceWithShellCellSize(workspace, shell, rows, cols);
        }
    } else {
        try app_terminal_resize.resizeSessionsWithShellCellSize(terminals, shell, rows, cols);
    }
}
