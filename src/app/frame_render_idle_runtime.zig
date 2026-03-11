const app_shell = @import("../app_shell.zig");
const app_terminal_frame_pacing_runtime = @import("terminal/terminal_frame_pacing_runtime.zig");
const shared_types = @import("../types/mod.zig");

const input_types = shared_types.input;

pub const Hooks = struct {
    draw: *const fn (*anyopaque) void,
    maybe_log_metrics: *const fn (*anyopaque, f64) void,
};

pub fn handle(
    state: anytype,
    ctx: *anyopaque,
    input_batch: *input_types.InputBatch,
    poll_ms: f64,
    build_ms: f64,
    update_ms: f64,
    hooks: Hooks,
) void {
    var draw_ms: f64 = 0.0;
    const now = app_shell.getTime();
    const terminal_snapshot = app_terminal_frame_pacing_runtime.observe(state, now);
    if (terminal_snapshot.redraw_pending) {
        state.needs_redraw = true;
    }

    if (state.needs_redraw) {
        const draw_start = app_shell.getTime();
        hooks.draw(ctx);
        const draw_end = app_shell.getTime();
        draw_ms = (draw_end - draw_start) * 1000.0;
        const terminal_draw_metrics = app_terminal_frame_pacing_runtime.consumeDrawMetrics(state);
        state.terminal_frame_pacing.last_drawn_generation = terminal_snapshot.published_generation;
        state.metrics.recordDraw(draw_start, draw_end);
        if (state.perf_mode and state.perf_frames_done > 0) {
            const draw_ms_perf = (draw_end - draw_start) * 1000.0;
            const editor_idx = if (state.editors.items.len > 0) @min(state.active_tab, state.editors.items.len - 1) else 0;
            if (state.editors.items.len > 0) {
                const editor = state.editors.items[editor_idx];
                state.perf_logger.logf(
                    .info,
                    "frame={d} draw_ms={d:.2} scroll_line={d} scroll_row_offset={d} scroll_col={d}",
                    .{ state.perf_frames_done, draw_ms_perf, editor.scroll_line, editor.scroll_row_offset, editor.scroll_col },
                );
            } else {
                state.perf_logger.logf(.info, "frame={d} draw_ms={d:.2}", .{ state.perf_frames_done, draw_ms_perf });
            }
        }
        hooks.maybe_log_metrics(ctx, draw_end);
        state.needs_redraw = false;
        app_terminal_frame_pacing_runtime.noteDraw(state);
        app_terminal_frame_pacing_runtime.logFramePacing(state, draw_end, terminal_snapshot, true, draw_ms, null);
        if (input_batch.events.items.len > 0) {
            const total_ms = poll_ms + build_ms + update_ms + draw_ms;
            if (total_ms >= 1.0) {
                app_terminal_frame_pacing_runtime.logInputLatency(state, poll_ms, build_ms, update_ms, draw_ms, .{
                    .poll = app_terminal_frame_pacing_runtime.consumePollMetrics(state),
                    .draw = terminal_draw_metrics,
                });
            }
        }
        return;
    }

    app_terminal_frame_pacing_runtime.noteIdle(state);

    if (input_batch.events.items.len > 0) {
        const total_ms = poll_ms + build_ms + update_ms;
        if (total_ms >= 1.0) {
            app_terminal_frame_pacing_runtime.logInputLatency(state, poll_ms, build_ms, update_ms, 0.0, .{
                .poll = app_terminal_frame_pacing_runtime.consumePollMetrics(state),
                .draw = null,
            });
        }
    }

    const sleep_ms = app_terminal_frame_pacing_runtime.sleepDuration(state, now, terminal_snapshot);
    app_terminal_frame_pacing_runtime.logFramePacing(state, now, terminal_snapshot, false, 0.0, sleep_ms);
    app_shell.waitTime(sleep_ms);
    hooks.maybe_log_metrics(ctx, app_shell.getTime());
}
