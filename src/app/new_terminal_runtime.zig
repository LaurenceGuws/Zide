const std = @import("std");
const app_modes = @import("modes/mod.zig");
const app_terminal_grid = @import("terminal/terminal_grid.zig");
const app_terminal_refresh_sizing_runtime = @import("terminal/terminal_refresh_sizing_runtime.zig");
const app_terminal_session_bootstrap = @import("terminal/terminal_session_bootstrap.zig");
const app_terminal_tab_bar_sync_runtime = @import("terminal/terminal_tab_bar_sync_runtime.zig");
const app_terminal_theme_apply = @import("terminal/terminal_theme_apply.zig");
const app_ui_layout_runtime = @import("ui_layout_runtime.zig");
const terminal_cli = @import("terminal_cli.zig");
const terminal_runtime = @import("../terminal/core/terminal_runtime.zig");
const workspace_mod = @import("../terminal/core/workspace.zig");
const workspace_host = @import("../terminal/core/workspace_host.zig");
const app_logger = @import("../app_logger.zig");

const TerminalRuntimeShell = terminal_runtime.TerminalRuntimeShell;
const TerminalWorkspace = workspace_mod.TerminalWorkspace;

const StartupFailPoint = enum {
    workspace_after_start,
    single_after_start,
};

const LaunchCwd = struct {
    value: ?[]const u8 = null,
    owned: ?[]u8 = null,

    fn deinit(self: *LaunchCwd, allocator: anytype) void {
        if (self.owned) |path| allocator.free(path);
        self.* = .{};
    }
};

fn getEnvVarOwned(allocator: std.mem.Allocator, name: []const u8) !?[]u8 {
    return std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => return err,
    };
}

fn launchCwdFromEnvOverride(state: anytype) !LaunchCwd {
    const owned = (try getEnvVarOwned(state.allocator, "ZIDE_LAUNCH_CWD")) orelse return .{};
    if (owned.len == 0) {
        state.allocator.free(owned);
        return .{};
    }
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
            const cwd = try workspace_host.copyActiveSessionCwd(workspace, state.allocator, &cwd_buf);
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

fn shouldInjectStartupFailure(point: StartupFailPoint) bool {
    const raw = std.c.getenv("ZIDE_TERMINAL_STARTUP_FAIL_POINT") orelse return false;
    const value = std.mem.sliceTo(raw, 0);
    return std.mem.eql(u8, value, switch (point) {
        .workspace_after_start => "workspace_after_start",
        .single_after_start => "single_after_start",
    });
}

fn injectStartupFailureIfRequested(point: StartupFailPoint, term: *TerminalRuntimeShell) !void {
    if (!shouldInjectStartupFailure(point)) return;
    std.debug.print("terminal_startup_failure_injected point={s} session_ptr={x}\n", .{
        switch (point) {
            .workspace_after_start => "workspace_after_start",
            .single_after_start => "single_after_start",
        },
        @intFromPtr(term),
    });
    app_logger.logger("terminal.lifecycle").logFields(.warning, "terminal_startup_failure_injected", &.{
        .{ .key = "point", .value = .{ .string = switch (point) {
            .workspace_after_start => "workspace_after_start",
            .single_after_start => "single_after_start",
        } } },
        .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(term) } },
    });
    return error.TerminalStartupInjectedFailure;
}

fn rollbackAddedWidgets(state: anytype, initial_widget_count: usize) void {
    while (state.terminal_widgets.items.len > initial_widget_count) {
        const idx = state.terminal_widgets.items.len - 1;
        state.terminal_widgets.items[idx].deinit();
        _ = state.terminal_widgets.orderedRemove(idx);
    }
}

fn rollbackWorkspaceStartup(state: anytype, workspace: *TerminalWorkspace, initial_tab_count: usize, initial_widget_count: usize) void {
    std.debug.print("terminal_startup_workspace_rollback_begin tabs_before={d} tabs_target={d} widgets_before={d} widgets_target={d}\n", .{
        workspace.tabCount(),
        initial_tab_count,
        state.terminal_widgets.items.len,
        initial_widget_count,
    });
    app_logger.logger("terminal.lifecycle").logFields(.warning, "terminal_startup_workspace_rollback_begin", &.{
        .{ .key = "tabs_before", .value = .{ .unsigned = workspace.tabCount() } },
        .{ .key = "tabs_target", .value = .{ .unsigned = initial_tab_count } },
        .{ .key = "widgets_before", .value = .{ .unsigned = state.terminal_widgets.items.len } },
        .{ .key = "widgets_target", .value = .{ .unsigned = initial_widget_count } },
    });
    rollbackAddedWidgets(state, initial_widget_count);
    while (workspace.tabCount() > initial_tab_count) {
        const idx = workspace.tabCount() - 1;
        const tab_id = workspace.tabIdAt(idx) orelse break;
        _ = workspace.closeTab(tab_id);
    }
    std.debug.print("terminal_startup_workspace_rollback_end tabs_after={d} widgets_after={d}\n", .{
        workspace.tabCount(),
        state.terminal_widgets.items.len,
    });
    app_logger.logger("terminal.lifecycle").logFields(.warning, "terminal_startup_workspace_rollback_end", &.{
        .{ .key = "tabs_after", .value = .{ .unsigned = workspace.tabCount() } },
        .{ .key = "widgets_after", .value = .{ .unsigned = state.terminal_widgets.items.len } },
    });
}

fn rollbackSingleSessionStartup(
    state: anytype,
    initial_terminal_count: usize,
    initial_widget_count: usize,
    unowned_term: *?*TerminalRuntimeShell,
) void {
    std.debug.print("terminal_startup_single_rollback_begin terminals_before={d} terminals_target={d} widgets_before={d} widgets_target={d} has_unowned_term={any}\n", .{
        state.terminals.items.len,
        initial_terminal_count,
        state.terminal_widgets.items.len,
        initial_widget_count,
        unowned_term.* != null,
    });
    app_logger.logger("terminal.lifecycle").logFields(.warning, "terminal_startup_single_rollback_begin", &.{
        .{ .key = "terminals_before", .value = .{ .unsigned = state.terminals.items.len } },
        .{ .key = "terminals_target", .value = .{ .unsigned = initial_terminal_count } },
        .{ .key = "widgets_before", .value = .{ .unsigned = state.terminal_widgets.items.len } },
        .{ .key = "widgets_target", .value = .{ .unsigned = initial_widget_count } },
        .{ .key = "has_unowned_term", .value = .{ .boolean = unowned_term.* != null } },
    });
    rollbackAddedWidgets(state, initial_widget_count);
    while (state.terminals.items.len > initial_terminal_count) {
        const idx = state.terminals.items.len - 1;
        const term = state.terminals.items[idx];
        _ = state.terminals.orderedRemove(idx);
        term.deinit();
    }
    if (state.terminals.items.len == initial_terminal_count) {
        if (unowned_term.*) |term| {
            term.deinit();
            unowned_term.* = null;
        }
    }
    std.debug.print("terminal_startup_single_rollback_end terminals_after={d} widgets_after={d}\n", .{
        state.terminals.items.len,
        state.terminal_widgets.items.len,
    });
    app_logger.logger("terminal.lifecycle").logFields(.warning, "terminal_startup_single_rollback_end", &.{
        .{ .key = "terminals_after", .value = .{ .unsigned = state.terminals.items.len } },
        .{ .key = "widgets_after", .value = .{ .unsigned = state.terminal_widgets.items.len } },
    });
}

fn createWorkspaceTerminalTab(state: anytype, workspace: *TerminalWorkspace, rows: u16, cols: u16, launch_cwd: ?[]const u8) !void {
    const shell = state.shell;
    const theme = &state.terminal_theme;
    const created = try workspace.createTabWithSession(rows, cols);
    const term = created.session;
    app_terminal_theme_apply.setSessionPalette(term, theme);
    try app_terminal_session_bootstrap.startSessionWithShellCellSize(term, shell, launch_cwd, state.terminal_shell_path);
    try injectStartupFailureIfRequested(.workspace_after_start, term);
    const widget = app_terminal_session_bootstrap.initWidget(
        term,
        state.terminal_blink_style,
        state.terminal_focus_report_window_events,
        state.terminal_focus_report_pane_events,
    );
    try state.terminal_widgets.append(state.allocator, widget);
}

fn launchWorkspaceStartupTabsFromArgs(state: anytype, workspace: *TerminalWorkspace, rows: u16, cols: u16) !bool {
    if (workspace.tabCount() != 0) return false;

    const launch_cwds = try terminal_cli.parseLaunchCwdsFromProcessArgs(state.allocator);
    defer if (launch_cwds) |paths| {
        for (paths) |path| state.allocator.free(path);
        state.allocator.free(paths);
    };

    if (launch_cwds == null) return false;

    for (launch_cwds.?) |path| {
        try createWorkspaceTerminalTab(state, workspace, rows, cols, path);
    }
    return true;
}

fn computeInitialGrid(state: anytype) struct { rows: u16, cols: u16 } {
    const shell = state.shell;
    const width = @as(f32, @floatFromInt(shell.width()));
    const height = @as(f32, @floatFromInt(shell.height()));
    const layout = app_ui_layout_runtime.computeLayout(state, width, height);
    const initial_grid = app_terminal_grid.computeWithEnvOverride(
        layout.terminal.width,
        layout.terminal.height,
        shell.terminalCellWidth(),
        shell.terminalCellHeight(),
        80,
        24,
    );
    return .{
        .rows = initial_grid.rows,
        .cols = initial_grid.cols,
    };
}

fn syncTerminalStartupState(state: anytype) !void {
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

fn handleWorkspaceLaunch(state: anytype, rows: u16, cols: u16) !void {
    if (state.terminal_workspace) |*workspace| {
        const initial_tab_count = workspace.tabCount();
        const initial_widget_count = state.terminal_widgets.items.len;
        errdefer rollbackWorkspaceStartup(state, workspace, initial_tab_count, initial_widget_count);
        const launched_many = try launchWorkspaceStartupTabsFromArgs(state, workspace, rows, cols);
        if (!launched_many) {
            var launch_cwd = try launchCwdForWorkspaceNewTab(state, workspace);
            defer launch_cwd.deinit(state.allocator);
            try createWorkspaceTerminalTab(state, workspace, rows, cols, launch_cwd.value);
        }
        try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(state);
        try syncTerminalStartupState(state);
        return;
    }
    return error.TerminalWorkspaceMissing;
}

fn handleSingleLaunch(state: anytype, rows: u16, cols: u16) !void {
    const theme = &state.terminal_theme;
    const initial_terminal_count = state.terminals.items.len;
    const initial_widget_count = state.terminal_widgets.items.len;
    const term = try terminal_runtime.initWithOptions(state.allocator, rows, cols, .{
        .scrollback_rows = state.terminal_scrollback_rows,
        .cursor_style = state.terminal_cursor_style,
    });
    var unowned_term: ?*TerminalRuntimeShell = term;
    errdefer rollbackSingleSessionStartup(state, initial_terminal_count, initial_widget_count, &unowned_term);
    app_terminal_theme_apply.setSessionPalette(term, theme);
    var launch_cwd = try fallbackDefaultStartLocation(state);
    defer launch_cwd.deinit(state.allocator);
    try app_terminal_session_bootstrap.startSessionWithShellCellSize(term, state.shell, launch_cwd.value, state.terminal_shell_path);
    try injectStartupFailureIfRequested(.single_after_start, term);
    try state.terminals.append(state.allocator, term);
    unowned_term = null;
    const widget = app_terminal_session_bootstrap.initWidget(
        term,
        state.terminal_blink_style,
        state.terminal_focus_report_window_events,
        state.terminal_focus_report_pane_events,
    );
    try state.terminal_widgets.append(state.allocator, widget);
    try syncTerminalStartupState(state);
}

pub fn handle(state: anytype) !void {
    if (app_modes.ide.shouldUseTerminalWorkspace(state.app_mode)) {
        state.active_kind = .terminal;
    } else if (app_modes.ide.isEditorOnly(state.app_mode)) {
        state.active_kind = .editor;
    }

    const initial_grid = computeInitialGrid(state);

    if (app_modes.ide.shouldUseTerminalWorkspace(state.app_mode)) {
        try handleWorkspaceLaunch(state, initial_grid.rows, initial_grid.cols);
        return;
    }

    try handleSingleLaunch(state, initial_grid.rows, initial_grid.cols);
}
