pub const FrameLatencyMetrics = struct {
    seq: u64 = 0,
    generation: u64 = 0,
    lock_ms: f64 = 0.0,
    lock_wait_ms: f64 = 0.0,
    lock_hold_ms: f64 = 0.0,
    view_cache_ms: f64 = 0.0,
    cache_copy_ms: f64 = 0.0,
    texture_update_ms: f64 = 0.0,
    texture_bg_ms: f64 = 0.0,
    texture_glyph_ms: f64 = 0.0,
    texture_kitty_ms: f64 = 0.0,
    overlay_ms: f64 = 0.0,
    render_ms: f64 = 0.0,
    draw_ms: f64 = 0.0,
};

var frame_latency_seq: u64 = 0;
var frame_latency_metrics: FrameLatencyMetrics = .{};

pub fn latestFrameLatencyMetrics() FrameLatencyMetrics {
    return frame_latency_metrics;
}

pub fn publishFrameLatencyMetrics(
    generation: u64,
    lock_ms: f64,
    lock_wait_ms: f64,
    lock_hold_ms: f64,
    view_cache_ms: f64,
    cache_copy_ms: f64,
    texture_update_ms: f64,
    texture_bg_ms: f64,
    texture_glyph_ms: f64,
    texture_kitty_ms: f64,
    overlay_ms: f64,
    render_ms: f64,
    draw_ms: f64,
) void {
    frame_latency_seq +%= 1;
    frame_latency_metrics = .{
        .seq = frame_latency_seq,
        .generation = generation,
        .lock_ms = lock_ms,
        .lock_wait_ms = lock_wait_ms,
        .lock_hold_ms = lock_hold_ms,
        .view_cache_ms = view_cache_ms,
        .cache_copy_ms = cache_copy_ms,
        .texture_update_ms = texture_update_ms,
        .texture_bg_ms = texture_bg_ms,
        .texture_glyph_ms = texture_glyph_ms,
        .texture_kitty_ms = texture_kitty_ms,
        .overlay_ms = overlay_ms,
        .render_ms = render_ms,
        .draw_ms = draw_ms,
    };
}
