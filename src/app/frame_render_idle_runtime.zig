const app_shell = @import("../app_shell.zig");
const app_active_editor_runtime = @import("editor/active_editor_runtime.zig");
const app_terminal_frame_pacing_runtime = @import("terminal/terminal_frame_pacing_runtime.zig");
const app_modes = @import("modes/mod.zig");
const shared_types = @import("../types/mod.zig");
const mode_build = @import("mode_build.zig");

const input_types = shared_types.input;

pub const Hooks = struct {
    draw: *const fn (*anyopaque) void,
    maybe_log_metrics: *const fn (*anyopaque, f64) void,
};

fn maybeLogPerfDraw(state: anytype, draw_start: f64, draw_end: f64) void {
    if (!state.perf_mode or state.perf_frames_done == 0) return;

    const draw_ms_perf = (draw_end - draw_start) * 1000.0;
    if (comptime mode_build.focused_mode != .terminal) {
        if (app_active_editor_runtime.fromState(state)) |editor| {
            const view = editor.viewState();
            state.perf_logger.logf(
                .info,
                "frame={d} draw_ms={d:.2} scroll_line={d} scroll_row_offset={d} scroll_col={d}",
                .{ state.perf_frames_done, draw_ms_perf, view.scroll_line, view.scroll_row_offset, view.scroll_col },
            );
            return;
        }
    }
    state.perf_logger.logf(.info, "frame={d} draw_ms={d:.2}", .{ state.perf_frames_done, draw_ms_perf });
}

fn maybeLogInputLatency(
    state: anytype,
    input_batch: *input_types.InputBatch,
    poll_ms: f64,
    build_ms: f64,
    update_ms: f64,
    draw_ms: f64,
    draw_metrics: anytype,
) void {
    if (input_batch.events.items.len == 0) return;

    const total_ms = poll_ms + build_ms + update_ms + draw_ms;
    if (total_ms < 1.0) return;

    app_terminal_frame_pacing_runtime.logInputLatency(state, poll_ms, build_ms, update_ms, draw_ms, .{
        .poll = app_terminal_frame_pacing_runtime.consumePollMetrics(state),
        .poll_counters = app_terminal_frame_pacing_runtime.pollCounters(state),
        .draw = draw_metrics,
    });
}

fn handleRedraw(
    state: anytype,
    ctx: *anyopaque,
    input_batch: *input_types.InputBatch,
    poll_ms: f64,
    build_ms: f64,
    update_ms: f64,
    now: f64,
    terminal_snapshot: app_terminal_frame_pacing_runtime.Snapshot,
    generation_recently_advanced: bool,
    hooks: Hooks,
) void {
    const draw_start = app_shell.getTime();
    hooks.draw(ctx);
    const draw_end = app_shell.getTime();
    const draw_ms = (draw_end - draw_start) * 1000.0;
    const terminal_draw_metrics = app_terminal_frame_pacing_runtime.consumeDrawMetrics(state);

    state.metrics.recordDraw(draw_start, draw_end);
    maybeLogPerfDraw(state, draw_start, draw_end);
    hooks.maybe_log_metrics(ctx, draw_end);
    state.needs_redraw = false;

    if (!terminal_snapshot.redraw_pending and !terminal_snapshot.output_pressure and generation_recently_advanced) {
        state.terminal_frame_pacing.recent_generation_followthrough_draws +|= 1;
    } else {
        state.terminal_frame_pacing.recent_generation_followthrough_draws = 0;
    }

    app_terminal_frame_pacing_runtime.noteDraw(state);
    app_terminal_frame_pacing_runtime.logFramePacing(state, draw_end, terminal_snapshot, true, draw_ms, null);
    maybeLogInputLatency(state, input_batch, poll_ms, build_ms, update_ms, draw_ms, terminal_draw_metrics);
    _ = now;
}

fn handleIdle(
    state: anytype,
    ctx: *anyopaque,
    input_batch: *input_types.InputBatch,
    poll_ms: f64,
    build_ms: f64,
    update_ms: f64,
    now: f64,
    terminal_snapshot: app_terminal_frame_pacing_runtime.Snapshot,
    generation_recently_advanced: bool,
    hooks: Hooks,
) void {
    if (!generation_recently_advanced) {
        state.terminal_frame_pacing.recent_generation_followthrough_draws = 0;
    }
    app_terminal_frame_pacing_runtime.noteIdle(state);
    maybeLogInputLatency(state, input_batch, poll_ms, build_ms, update_ms, 0.0, null);

    var sleep_ms = app_terminal_frame_pacing_runtime.sleepDuration(state, now, terminal_snapshot);
    if (app_modes.ide.supportsEditorSurface(state.app_mode) and state.shell.integratedWindowChromeSinkActive()) {
        sleep_ms = @min(sleep_ms, 1.0 / 60.0);
    }
    app_terminal_frame_pacing_runtime.logFramePacing(state, now, terminal_snapshot, false, 0.0, sleep_ms);
    if (state.shell.windowFocused()) {
        app_shell.waitForWakeOrTimeout(sleep_ms);
    } else {
        app_shell.waitTime(sleep_ms);
    }
    hooks.maybe_log_metrics(ctx, app_shell.getTime());
}

pub fn handle(
    state: anytype,
    ctx: *anyopaque,
    input_batch: *input_types.InputBatch,
    poll_ms: f64,
    build_ms: f64,
    update_ms: f64,
    hooks: Hooks,
) void {
    const now = app_shell.getTime();
    const terminal_snapshot = app_terminal_frame_pacing_runtime.observe(state, now);
    const generation_recently_advanced = app_terminal_frame_pacing_runtime.generationRecentlyAdvanced(state, now);
    const can_followthrough_draw = generation_recently_advanced and
        state.terminal_frame_pacing.recent_generation_followthrough_draws < 2;
    if (terminal_snapshot.redraw_pending or terminal_snapshot.output_pressure or can_followthrough_draw) {
        state.needs_redraw = true;
    }

    if (state.needs_redraw) {
        handleRedraw(state, ctx, input_batch, poll_ms, build_ms, update_ms, now, terminal_snapshot, generation_recently_advanced, hooks);
        return;
    }

    handleIdle(state, ctx, input_batch, poll_ms, build_ms, update_ms, now, terminal_snapshot, generation_recently_advanced, hooks);
}
