const app_modes = @import("modes/mod.zig");
const app_bootstrap = @import("bootstrap.zig");
const app_run_loop_driver = @import("run_loop_driver.zig");
const app_shell = @import("../app_shell.zig");
const app_signals = @import("signals.zig");
const app_terminal_tab_navigation_runtime = @import("terminal/terminal_tab_navigation_runtime.zig");
const input_builder = @import("../input/input_builder.zig");

pub fn prepare(state: anytype) !?app_run_loop_driver.FrameSetup {
    return try prepareWithMode(state, null);
}

pub fn prepareFocused(state: anytype, comptime app_mode: app_bootstrap.AppMode) !?app_run_loop_driver.FrameSetup {
    return try prepareWithMode(state, app_mode);
}

fn prepareWithMode(
    state: anytype,
    comptime forced_mode: ?app_bootstrap.AppMode,
) !?app_run_loop_driver.FrameSetup {
    const app_mode = if (comptime forced_mode) |mode| mode else state.app_mode;

    const poll_start = app_shell.getTime();
    app_shell.pollInputEvents();
    const poll_end = app_shell.getTime();
    if (state.shell.shouldClose()) {
        state.terminal_window_close_pending = true;
        state.shell.clearCloseRequest();
    }

    if (state.terminal_window_close_pending) {
        const allow_close_now = handlePendingTerminalWindowClose(state, app_mode);
        if (allow_close_now) {
            state.shell.requestClose();
            return null;
        }
    }

    if (state.shell.shouldClose()) return null;
    if (app_signals.requested()) {
        state.shell.requestClose();
        return null;
    }

    const build_start = app_shell.getTime();
    const input_batch = input_builder.buildInputBatch(state.allocator, state.shell);
    const build_end = app_shell.getTime();

    state.frame_id +|= 1;
    if (!app_modes.ide.shouldUseTerminalWorkspace(app_mode)) {
        state.editor_cluster_cache.beginFrame(state.frame_id);
    }

    state.metrics.beginFrame(app_shell.getTime());

    return .{
        .input_batch = input_batch,
        .poll_ms = (poll_end - poll_start) * 1000.0,
        .build_ms = (build_end - build_start) * 1000.0,
    };
}

fn handlePendingTerminalWindowClose(state: anytype, app_mode: app_bootstrap.AppMode) bool {
    if (!app_modes.ide.shouldUseTerminalWorkspace(app_mode)) {
        state.terminal_window_close_pending = false;
        return true;
    }
    if (state.terminal_workspace == null) {
        state.terminal_window_close_pending = false;
        return true;
    }

    var workspace = &state.terminal_workspace.?;
    if (workspace.tabCount() == 0) {
        state.terminal_window_close_pending = false;
        return true;
    }

    if (state.terminal_close_confirm_tab != null) {
        // Modal is active and awaiting input.
        return false;
    }

    const active_idx = workspace.activeIndex();
    const next_confirm = workspace.firstConfirmCloseTab() orelse {
        state.terminal_window_close_pending = false;
        return true;
    };

    if (next_confirm.index != active_idx) {
        _ = app_terminal_tab_navigation_runtime.focusByIndex(state, next_confirm.index);
    }
    state.terminal_close_confirm_tab = next_confirm.id;
    state.needs_redraw = true;
    return false;
}
