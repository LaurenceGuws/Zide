const std = @import("std");
const app_modes = @import("modes/mod.zig");
const app_terminal_grid = @import("terminal/terminal_grid.zig");
const app_terminal_refresh_sizing_runtime = @import("terminal/terminal_refresh_sizing_runtime.zig");
const app_terminal_session_bootstrap = @import("terminal/terminal_session_bootstrap.zig");
const app_terminal_tab_bar_sync_runtime = @import("terminal/terminal_tab_bar_sync_runtime.zig");
const app_terminal_theme_apply = @import("terminal/terminal_theme_apply.zig");
const app_ui_layout_runtime = @import("ui_layout_runtime.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");

const TerminalSession = terminal_mod.TerminalSession;
const TerminalWorkspace = terminal_mod.TerminalWorkspace;

const LaunchCwd = struct {
    value: ?[]const u8 = null,
    owned: ?[]u8 = null,

    fn deinit(self: *LaunchCwd, allocator: anytype) void {
        if (self.owned) |path| allocator.free(path);
        self.* = .{};
    }
};

fn launchCwdFromEnvOverride(state: anytype) !LaunchCwd {
    const cwd_c = std.c.getenv("ZIDE_LAUNCH_CWD") orelse return .{};
    const cwd = std.mem.sliceTo(cwd_c, 0);
    if (cwd.len == 0) return .{};
    const owned = try state.allocator.dupe(u8, cwd);
    return .{
        .value = owned,
        .owned = owned,
    };
}

fn fallbackDefaultStartLocation(state: anytype) !LaunchCwd {
    const env_override = try launchCwdFromEnvOverride(state);
    if (env_override.value != null) return env_override;
    return .{
        .value = if (state.terminal_default_start_location) |path|
            if (path.len > 0) path else null
        else
            null,
    };
}

fn launchCwdForWorkspaceNewTab(state: anytype, workspace: *TerminalWorkspace) !LaunchCwd {
    const env_override = try launchCwdFromEnvOverride(state);
    if (env_override.value != null) return env_override;
    switch (state.terminal_new_tab_start_location) {
        .default => return fallbackDefaultStartLocation(state),
        .current => {
            var cwd_buf = std.ArrayList(u8).empty;
            defer cwd_buf.deinit(state.allocator);
            const cwd = try workspace.copyActiveSessionCwd(state.allocator, &cwd_buf);
            if (cwd.len > 0) {
                const owned = try state.allocator.dupe(u8, cwd);
                return .{
                    .value = owned,
                    .owned = owned,
                };
            }
            return fallbackDefaultStartLocation(state);
        },
    }
}

pub fn handle(state: anytype) !void {
    const shell = state.shell;
    const width = @as(f32, @floatFromInt(shell.width()));
    const height = @as(f32, @floatFromInt(shell.height()));
    const layout = app_ui_layout_runtime.computeLayout(state, width, height);
    if (app_modes.ide.shouldUseTerminalWorkspace(state.app_mode)) {
        state.active_kind = .terminal;
    } else if (app_modes.ide.isEditorOnly(state.app_mode)) {
        state.active_kind = .editor;
    }
    const initial_grid = app_terminal_grid.computeWithEnvOverride(
        layout.terminal.width,
        layout.terminal.height,
        shell.terminalCellWidth(),
        shell.terminalCellHeight(),
        80,
        24,
    );
    const cols: u16 = initial_grid.cols;
    const rows: u16 = initial_grid.rows;
    const theme = &state.terminal_theme;

    if (app_modes.ide.shouldUseTerminalWorkspace(state.app_mode)) {
        if (state.terminal_workspace) |*workspace| {
            var launch_cwd = try launchCwdForWorkspaceNewTab(state, workspace);
            defer launch_cwd.deinit(state.allocator);
            const created = try workspace.createTabWithSession(rows, cols);
            const term = created.session;
            app_terminal_theme_apply.setSessionPalette(term, theme);
            try app_terminal_session_bootstrap.startSessionWithShellCellSize(term, shell, launch_cwd.value);
            const widget = app_terminal_session_bootstrap.initWidget(
                term,
                state.terminal_blink_style,
                state.terminal_focus_report_window_events,
                state.terminal_focus_report_pane_events,
            );
            try state.terminal_widgets.append(state.allocator, widget);
            try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(state);
            try app_terminal_theme_apply.notifyColorSchemeChanged(&state.terminal_widgets, &state.terminal_theme);
            state.show_terminal = true;
            try app_terminal_refresh_sizing_runtime.handle(
                state,
                state.app_mode,
                &state.terminal_workspace,
                state.terminals.items,
                state.show_terminal,
                state.terminal_height,
                state.shell,
            );
            return;
        }
        return error.TerminalWorkspaceMissing;
    }

    const term = try TerminalSession.initWithOptions(state.allocator, rows, cols, .{
        .scrollback_rows = state.terminal_scrollback_rows,
        .cursor_style = state.terminal_cursor_style,
    });
    app_terminal_theme_apply.setSessionPalette(term, theme);
    var launch_cwd = try fallbackDefaultStartLocation(state);
    defer launch_cwd.deinit(state.allocator);
    try app_terminal_session_bootstrap.startSessionWithShellCellSize(term, shell, launch_cwd.value);
    try state.terminals.append(state.allocator, term);
    const widget = app_terminal_session_bootstrap.initWidget(
        term,
        state.terminal_blink_style,
        state.terminal_focus_report_window_events,
        state.terminal_focus_report_pane_events,
    );
    try state.terminal_widgets.append(state.allocator, widget);
    try app_terminal_theme_apply.notifyColorSchemeChanged(&state.terminal_widgets, &state.terminal_theme);

    state.show_terminal = true;
    try app_terminal_refresh_sizing_runtime.handle(
        state,
        state.app_mode,
        &state.terminal_workspace,
        state.terminals.items,
        state.show_terminal,
        state.terminal_height,
        state.shell,
    );
}
