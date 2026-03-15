pub fn maybeLog(state: anytype, now: f64) void {
    if (now - state.last_metrics_log_time < 1.0) return;
    state.last_metrics_log_time = now;
    state.metrics_logger.logf(
        .info,
        "frame_avg_ms={d:.2} draw_avg_ms={d:.2} input_avg_ms={d:.2} input_max_ms={d:.2} frames={d} redraws={d}",
        .{
            state.metrics.frame_ms_avg,
            state.metrics.draw_ms_avg,
            state.metrics.input_latency_ms_avg,
            state.metrics.input_latency_ms_max,
            state.metrics.frames,
            state.metrics.redraws,
        },
    );
}
