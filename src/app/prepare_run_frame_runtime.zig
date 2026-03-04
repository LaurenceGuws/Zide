const app_modes = @import("modes/mod.zig");
const app_bootstrap = @import("bootstrap.zig");
const app_run_loop_driver = @import("run_loop_driver.zig");
const app_shell = @import("../app_shell.zig");
const app_signals = @import("signals.zig");
const input_builder = @import("../input/input_builder.zig");

pub fn prepare(state: anytype) !?app_run_loop_driver.FrameSetup {
    return try prepareWithMode(state, null, .ide);
}

pub fn prepareFocused(state: anytype, comptime app_mode: app_bootstrap.AppMode) !?app_run_loop_driver.FrameSetup {
    return try prepareWithMode(state, app_mode, .ide);
}

fn prepareWithMode(
    state: anytype,
    comptime forced_mode: ?app_bootstrap.AppMode,
    runtime_mode_fallback: app_bootstrap.AppMode,
) !?app_run_loop_driver.FrameSetup {
    const app_mode = if (comptime forced_mode) |mode| mode else state.app_mode;
    _ = runtime_mode_fallback;

    const poll_start = app_shell.getTime();
    app_shell.pollInputEvents();
    const poll_end = app_shell.getTime();
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
