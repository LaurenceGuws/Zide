const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
pub const Hooks = struct {
    terminal_tab_count: *const fn (*anyopaque) usize,
    new_terminal: *const fn (*anyopaque) anyerror!void,
    sync_terminal_mode_tab_bar: *const fn (*anyopaque) anyerror!void,
    open_file: *const fn (*anyopaque, []const u8) anyerror!void,
    new_editor: *const fn (*anyopaque) anyerror!void,
    seed_default_welcome_buffer: *const fn (*anyopaque) anyerror!void,
};

fn shouldRunSingleSessionStartupSmoke(app_mode: app_bootstrap.AppMode) bool {
    if (app_modes.ide.shouldUseTerminalWorkspace(app_mode)) return false;
    if (app_modes.ide.isFontSample(app_mode)) return false;
    const scenario = app_bootstrap.envSlice("ZIDE_TERMINAL_STARTUP_SMOKE_SCENARIO") orelse return false;
    return std.mem.eql(u8, scenario, "single_session");
}

pub fn initialize(
    app_mode: app_bootstrap.AppMode,
    perf_mode: bool,
    perf_file_path: ?[]u8,
    startup_file_paths: ?[][]u8,
    ctx: *anyopaque,
    hooks: Hooks,
) !void {
    if (app_modes.ide.shouldUseTerminalWorkspace(app_mode)) {
        if (hooks.terminal_tab_count(ctx) == 0) {
            try hooks.new_terminal(ctx);
        }
        try hooks.sync_terminal_mode_tab_bar(ctx);
        return;
    }

    if (app_modes.ide.isFontSample(app_mode)) {
        return;
    }

    if (shouldRunSingleSessionStartupSmoke(app_mode)) {
        try hooks.new_terminal(ctx);
        return;
    }

    if (perf_mode and perf_file_path != null) {
        try hooks.open_file(ctx, perf_file_path.?);
        return;
    }

    if (startup_file_paths) |paths| {
        for (paths) |path| {
            try hooks.open_file(ctx, path);
        }
        return;
    }

    try hooks.new_editor(ctx);
    try hooks.seed_default_welcome_buffer(ctx);
}
