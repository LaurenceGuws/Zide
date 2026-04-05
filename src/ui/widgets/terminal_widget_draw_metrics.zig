const app_shell = @import("../../app_shell.zig");
const terminal_debug_geometry = @import("terminal_widget_debug_geometry.zig");

pub const FrameLatencyMetrics = struct {
    terminal_presentation_mode: app_shell.TerminalPresentationMode = .retained_surface,
    terminal_presentation_sample_mode: terminal_debug_geometry.TerminalPresentationSampleMode = .retained_surface,
    seq: u64 = 0,
    generation: u64 = 0,
    lock_ms: f64 = 0.0,
    lock_wait_ms: f64 = 0.0,
    lock_hold_ms: f64 = 0.0,
    view_cache_ms: f64 = 0.0,
    cache_copy_ms: f64 = 0.0,
    presentation_update_ms: f64 = 0.0,
    presentation_bg_ms: f64 = 0.0,
    presentation_glyph_ms: f64 = 0.0,
    presentation_kitty_ms: f64 = 0.0,
    overlay_ms: f64 = 0.0,
    render_ms: f64 = 0.0,
    draw_ms: f64 = 0.0,
    metal_grid_row_runs: usize = 0,
    metal_grid_row_cells: usize = 0,
    metal_overlay_row_runs: usize = 0,
    metal_overlay_row_cells: usize = 0,
    special_sprite_glyphs: usize = 0,
    shaped_special_glyphs: usize = 0,
    powerline_special_glyphs: usize = 0,
    shade_special_glyphs: usize = 0,
    braille_special_glyphs: usize = 0,
    box_glyphs: usize = 0,
};

var frame_latency_seq: u64 = 0;
var frame_latency_metrics: FrameLatencyMetrics = .{};

pub fn latestFrameLatencyMetrics() FrameLatencyMetrics {
    return frame_latency_metrics;
}

pub fn publishFrameLatencyMetrics(
    terminal_presentation_mode: app_shell.TerminalPresentationMode,
    terminal_presentation_sample_mode: terminal_debug_geometry.TerminalPresentationSampleMode,
    generation: u64,
    lock_ms: f64,
    lock_wait_ms: f64,
    lock_hold_ms: f64,
    view_cache_ms: f64,
    cache_copy_ms: f64,
    presentation_update_ms: f64,
    presentation_bg_ms: f64,
    presentation_glyph_ms: f64,
    presentation_kitty_ms: f64,
    overlay_ms: f64,
    render_ms: f64,
    draw_ms: f64,
    metal_grid_row_runs: usize,
    metal_grid_row_cells: usize,
    metal_overlay_row_runs: usize,
    metal_overlay_row_cells: usize,
    special_sprite_glyphs: usize,
    shaped_special_glyphs: usize,
    powerline_special_glyphs: usize,
    shade_special_glyphs: usize,
    braille_special_glyphs: usize,
    box_glyphs: usize,
) void {
    frame_latency_seq +%= 1;
    frame_latency_metrics = .{
        .terminal_presentation_mode = terminal_presentation_mode,
        .terminal_presentation_sample_mode = terminal_presentation_sample_mode,
        .seq = frame_latency_seq,
        .generation = generation,
        .lock_ms = lock_ms,
        .lock_wait_ms = lock_wait_ms,
        .lock_hold_ms = lock_hold_ms,
        .view_cache_ms = view_cache_ms,
        .cache_copy_ms = cache_copy_ms,
        .presentation_update_ms = presentation_update_ms,
        .presentation_bg_ms = presentation_bg_ms,
        .presentation_glyph_ms = presentation_glyph_ms,
        .presentation_kitty_ms = presentation_kitty_ms,
        .overlay_ms = overlay_ms,
        .render_ms = render_ms,
        .draw_ms = draw_ms,
        .metal_grid_row_runs = metal_grid_row_runs,
        .metal_grid_row_cells = metal_grid_row_cells,
        .metal_overlay_row_runs = metal_overlay_row_runs,
        .metal_overlay_row_cells = metal_overlay_row_cells,
        .special_sprite_glyphs = special_sprite_glyphs,
        .shaped_special_glyphs = shaped_special_glyphs,
        .powerline_special_glyphs = powerline_special_glyphs,
        .shade_special_glyphs = shade_special_glyphs,
        .braille_special_glyphs = braille_special_glyphs,
        .box_glyphs = box_glyphs,
    };
}
