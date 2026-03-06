const app_shell = @import("../app_shell.zig");
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

    if (state.needs_redraw) {
        const draw_start = app_shell.getTime();
        hooks.draw(ctx);
        const draw_end = app_shell.getTime();
        draw_ms = (draw_end - draw_start) * 1000.0;
        state.metrics.recordDraw(draw_start, draw_end);
        if (state.perf_mode and state.perf_frames_done > 0) {
            const draw_ms_perf = (draw_end - draw_start) * 1000.0;
            const editor_idx = if (state.editors.items.len > 0) @min(state.active_tab, state.editors.items.len - 1) else 0;
            if (state.editors.items.len > 0) {
                const editor = state.editors.items[editor_idx];
                state.perf_logger.logf(.info, 
                    "frame={d} draw_ms={d:.2} scroll_line={d} scroll_row_offset={d} scroll_col={d}",
                    .{ state.perf_frames_done, draw_ms_perf, editor.scroll_line, editor.scroll_row_offset, editor.scroll_col },
                );
            } else {
                state.perf_logger.logf(.info, "frame={d} draw_ms={d:.2}", .{ state.perf_frames_done, draw_ms_perf });
            }
        }
        hooks.maybe_log_metrics(ctx, draw_end);
        state.needs_redraw = false;
        state.idle_frames = 0;
        if (input_batch.events.items.len > 0) {
            const total_ms = poll_ms + build_ms + update_ms + draw_ms;
            if (total_ms >= 1.0) {
                state.input_latency_logger.logf(.info, 
                    "poll_ms={d:.2} build_ms={d:.2} update_ms={d:.2} draw_ms={d:.2}",
                    .{ poll_ms, build_ms, update_ms, draw_ms },
                );
            }
        }
        return;
    }

    state.idle_frames +|= 1;
    if (input_batch.events.items.len > 0) {
        const total_ms = poll_ms + build_ms + update_ms;
        if (total_ms >= 1.0) {
            state.input_latency_logger.logf(.info, 
                "poll_ms={d:.2} build_ms={d:.2} update_ms={d:.2} draw_ms=0.00",
                .{ poll_ms, build_ms, update_ms },
            );
        }
    }

    const uptime = app_shell.getTime();
    const sleep_ms: f64 = if (uptime < 3.0)
        0.016
    else if (state.idle_frames < 10)
        0.016
    else if (state.idle_frames < 60)
        0.033
    else
        0.100;

    app_shell.waitTime(sleep_ms);
    hooks.maybe_log_metrics(ctx, app_shell.getTime());
}
