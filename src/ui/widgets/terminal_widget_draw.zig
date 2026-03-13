const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const render_cache_mod = @import("../../terminal/core/render_cache.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const time_utils = @import("../renderer/time_utils.zig");
const common = @import("common.zig");
const terminal_font_mod = @import("../terminal_font.zig");
const draw_grid = @import("terminal_widget_draw_grid.zig");
const draw_overlay = @import("terminal_widget_draw_overlay.zig");
const draw_texture = @import("terminal_widget_draw_texture.zig");

const hover_mod = @import("terminal_widget_hover.zig");
const kitty_mod = @import("terminal_widget_kitty.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = terminal_mod.CursorPos;
const Cell = terminal_mod.Cell;
const Rgba = terminal_font_mod.Rgba;

const RenderCache = render_cache_mod.RenderCache;
const PresentationCapture = terminal_mod.PresentationCapture;
const PresentedRenderCache = terminal_mod.PresentedRenderCache;
const PresentationFeedback = terminal_mod.PresentationFeedback;
var jitter_debug_enabled_cache: ?bool = null;
var frame_latency_seq: u64 = 0;
var frame_latency_metrics: FrameLatencyMetrics = .{};

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

pub const DrawOutcome = PresentationFeedback;
const drawRowBackgrounds = draw_grid.drawRowBackgrounds;
const drawRowGlyphs = draw_grid.drawRowGlyphs;
const drawOverlays = draw_overlay.drawOverlays;
const GlyphDrawStats = draw_grid.GlyphDrawStats;

pub const DrawPreparation = struct {
    draw_start: f64,
    lock_ms: f64,
    lock_wait_ms: f64,
    lock_hold_ms: f64,
    view_cache_ms: f64,
    cache_copy_ms: f64,
    presented: PresentedRenderCache,

    pub fn fromCapture(draw_start: f64, capture: PresentationCapture) DrawPreparation {
        return .{
            .draw_start = draw_start,
            .lock_ms = capture.lock_ms,
            .lock_wait_ms = capture.lock_wait_ms,
            .lock_hold_ms = capture.lock_hold_ms,
            .view_cache_ms = capture.view_cache_ms,
            .cache_copy_ms = capture.cache_copy_ms,
            .presented = capture.presented,
        };
    }
};

const ViewportTextureShiftPlan = draw_texture.ViewportTextureShiftPlan;
const TextureUpdatePlan = draw_texture.TextureUpdatePlan;

pub fn latestFrameLatencyMetrics() FrameLatencyMetrics {
    return frame_latency_metrics;
}

fn publishFrameLatencyMetrics(
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

fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
}

fn spansOverlap(start_a: usize, end_a: usize, start_b: usize, end_b: usize) bool {
    return start_a <= end_b and start_b <= end_a;
}

fn rowSlice(cells: []const Cell, cols_count: usize, row: usize) []const Cell {
    const row_start = row * cols_count;
    if (row_start + cols_count > cells.len) return cells[0..0];
    return cells[row_start .. row_start + cols_count];
}

const max_target_sample_rows: usize = 8;
const cursor_probe_row_radius: usize = 5;
const cursor_probe_col_radius: usize = 5;

const TargetReadbackProbe = struct {
    row: usize = 0,
    col_start: usize = 0,
    col_end: usize = 0,
    column_present: bool = false,
    column_col: usize = 0,
    column_row_start: usize = 0,
    column_row_end: usize = 0,
    bg2_present: bool = false,
    bg2_col: usize = 0,
    bg2_codepoint: u32 = 0,
    bg2_expected: Color = Color.black,
    direct_samples: [draw_grid.max_direct_glyph_samples]draw_grid.DirectGlyphSample = [_]draw_grid.DirectGlyphSample{.{}} ** draw_grid.max_direct_glyph_samples,
    bg2_baseline: TargetGridSample = .{},
    bg2_glyph: TargetGridSample = .{},
    bg2_window: TargetGridSample = .{},
    bg2_final: TargetGridSample = .{},
    band_window: TargetBandSample = .{},
    band_final: TargetBandSample = .{},
    column_band_window: TargetBandSample = .{},
    column_band_final: TargetBandSample = .{},
    direct_baselines: [draw_grid.max_direct_glyph_samples]TargetGridSample = [_]TargetGridSample{.{}} ** draw_grid.max_direct_glyph_samples,
    direct_glyphs: [draw_grid.max_direct_glyph_samples]TargetGridSample = [_]TargetGridSample{.{}} ** draw_grid.max_direct_glyph_samples,
    direct_windows: [draw_grid.max_direct_glyph_samples]TargetGridSample = [_]TargetGridSample{.{}} ** draw_grid.max_direct_glyph_samples,
    direct_finals: [draw_grid.max_direct_glyph_samples]TargetGridSample = [_]TargetGridSample{.{}} ** draw_grid.max_direct_glyph_samples,
};

const TargetProbePhase = enum {
    bg,
    glyph,
    window,
    final,
};

const target_grid_side: usize = 3;
const target_grid_samples: usize = target_grid_side * target_grid_side;
const target_delta_threshold: u16 = 24;

const TargetGridSample = struct {
    pixels: [target_grid_samples]Rgba = undefined,
    valid: [target_grid_samples]bool = [_]bool{false} ** target_grid_samples,
};

const TargetGridDiff = struct {
    hits: usize = 0,
    samples: usize = 0,
    max_delta: u16 = 0,
};

const target_band_cols: usize = 8;
const target_band_rows: usize = 3;
const target_band_samples: usize = target_band_cols * target_band_rows;

const TargetBandSample = struct {
    pixels: [target_band_samples]Rgba = undefined,
    valid: [target_band_samples]bool = [_]bool{false} ** target_band_samples,
};

const TargetBandDiff = struct {
    hits: usize = 0,
    samples: usize = 0,
    max_delta: u16 = 0,
};

const SilentTargetProbeLogger = struct {
    fn logf(self: @This(), level: anytype, comptime fmt: []const u8, args: anytype) void {
        _ = self;
        _ = level;
        _ = fmt;
        _ = args;
    }
};

fn rgbaDelta(a: Rgba, b: Rgba) u16 {
    const dr: u16 = @intCast(@abs(@as(i16, @intCast(a.r)) - @as(i16, @intCast(b.r))));
    const dg: u16 = @intCast(@abs(@as(i16, @intCast(a.g)) - @as(i16, @intCast(b.g))));
    const db: u16 = @intCast(@abs(@as(i16, @intCast(a.b)) - @as(i16, @intCast(b.b))));
    return dr + dg + db;
}

fn captureTargetGrid(
    rr: anytype,
    logical_x: f32,
    logical_y: f32,
    cell_w_i: i32,
    cell_h_i: i32,
) TargetGridSample {
    const offsets = [_]f32{ -0.25, 0.0, 0.25 };
    var sample = TargetGridSample{};
    var idx: usize = 0;
    for (offsets) |y_off| {
        for (offsets) |x_off| {
            const sample_x = logical_x + x_off * @as(f32, @floatFromInt(cell_w_i));
            const sample_y = logical_y + y_off * @as(f32, @floatFromInt(cell_h_i));
            if (rr.sampleCurrentTargetPixel(sample_x, sample_y)) |rgba| {
                sample.valid[idx] = true;
                sample.pixels[idx] = rgba;
            }
            idx += 1;
        }
    }
    return sample;
}

fn diffTargetGrid(current: *const TargetGridSample, baseline: *const TargetGridSample) TargetGridDiff {
    var diff = TargetGridDiff{};
    var idx: usize = 0;
    while (idx < target_grid_samples) : (idx += 1) {
        if (!current.valid[idx] or !baseline.valid[idx]) continue;
        diff.samples += 1;
        const delta = rgbaDelta(current.pixels[idx], baseline.pixels[idx]);
        if (delta > diff.max_delta) diff.max_delta = delta;
        if (delta >= target_delta_threshold) diff.hits += 1;
    }
    return diff;
}

fn captureTargetBand(
    rr: anytype,
    logical_x: f32,
    logical_y: f32,
    logical_width: f32,
    logical_height: f32,
) TargetBandSample {
    var sample = TargetBandSample{};
    if (logical_width <= 0.0 or logical_height <= 0.0) return sample;

    const step_x = logical_width / @as(f32, @floatFromInt(target_band_cols));
    const step_y = logical_height / @as(f32, @floatFromInt(target_band_rows));
    var idx: usize = 0;
    var row_idx: usize = 0;
    while (row_idx < target_band_rows) : (row_idx += 1) {
        var col_idx: usize = 0;
        while (col_idx < target_band_cols) : (col_idx += 1) {
            const sample_x = logical_x + step_x * (@as(f32, @floatFromInt(col_idx)) + 0.5);
            const sample_y = logical_y + step_y * (@as(f32, @floatFromInt(row_idx)) + 0.5);
            if (rr.sampleCurrentTargetPixel(sample_x, sample_y)) |rgba| {
                sample.valid[idx] = true;
                sample.pixels[idx] = rgba;
            }
            idx += 1;
        }
    }
    return sample;
}

fn diffTargetBand(current: *const TargetBandSample, baseline: *const TargetBandSample) TargetBandDiff {
    var diff = TargetBandDiff{};
    var idx: usize = 0;
    while (idx < target_band_samples) : (idx += 1) {
        if (!current.valid[idx] or !baseline.valid[idx]) continue;
        diff.samples += 1;
        const delta = rgbaDelta(current.pixels[idx], baseline.pixels[idx]);
        if (delta > diff.max_delta) diff.max_delta = delta;
        if (delta >= target_delta_threshold) diff.hits += 1;
    }
    return diff;
}

fn hashTargetBand(sample: *const TargetBandSample) u64 {
    var hasher = std.hash.Fnv1a_64.init();
    var idx: usize = 0;
    while (idx < target_band_samples) : (idx += 1) {
        const valid: u8 = @intFromBool(sample.valid[idx]);
        hasher.update(&[_]u8{valid});
        if (sample.valid[idx]) {
            const rgba = sample.pixels[idx];
            hasher.update(&[_]u8{ rgba.r, rgba.g, rgba.b, rgba.a });
        }
    }
    return hasher.final();
}

fn logTargetSamplePixel(
    rr: anytype,
    log: anytype,
    phase: TargetProbePhase,
    kind: []const u8,
    row: usize,
    slot: isize,
    col: usize,
    codepoint: u32,
    logical_x: f32,
    logical_y: f32,
    fg: Color,
    bg: Color,
    baseline: ?*const TargetGridSample,
    baseline_store: ?*TargetGridSample,
    cell_w_i: i32,
    cell_h_i: i32,
) void {
    const rgba = rr.sampleCurrentTargetPixel(logical_x, logical_y) orelse return;
    const grid = captureTargetGrid(rr, logical_x, logical_y, cell_w_i, cell_h_i);
    if (baseline_store) |store| store.* = grid;
    if (baseline) |base| {
        const diff = diffTargetGrid(&grid, base);
        log.logf(
            .info,
            "event=target_sample phase={s} kind={s} row={d} slot={d} col={d} cp={d} rgba={d}:{d}:{d}:{d} fg={d}:{d}:{d} bg={d}:{d}:{d} diff_hits={d}/{d} diff_max={d}",
            .{
                @tagName(phase),
                kind,
                row,
                slot,
                col,
                codepoint,
                rgba.r,
                rgba.g,
                rgba.b,
                rgba.a,
                fg.r,
                fg.g,
                fg.b,
                bg.r,
                bg.g,
                bg.b,
                diff.hits,
                diff.samples,
                diff.max_delta,
            },
        );
        return;
    }
    log.logf(
        .info,
        "event=target_sample phase={s} kind={s} row={d} slot={d} col={d} cp={d} rgba={d}:{d}:{d}:{d} fg={d}:{d}:{d} bg={d}:{d}:{d}",
        .{
            @tagName(phase),
            kind,
            row,
            slot,
            col,
            codepoint,
            rgba.r,
            rgba.g,
            rgba.b,
            rgba.a,
            fg.r,
            fg.g,
            fg.b,
            bg.r,
            bg.g,
            bg.b,
        },
    );
}

fn logTargetProbePhase(
    rr: anytype,
    log: anytype,
    phase: TargetProbePhase,
    probe: *TargetReadbackProbe,
    origin_x: f32,
    origin_y: f32,
    cell_w_i: i32,
    cell_h_i: i32,
) void {
    const sample_y = origin_y + (@as(f32, @floatFromInt(@as(i32, @intCast(probe.row)) * cell_h_i)) + @as(f32, @floatFromInt(cell_h_i)) * 0.5);
    if (probe.bg2_present) {
        const sample_x = origin_x + (@as(f32, @floatFromInt(@as(i32, @intCast(probe.bg2_col)) * cell_w_i)) + @as(f32, @floatFromInt(cell_w_i)) * 0.5);
        logTargetSamplePixel(
            rr,
            log,
            phase,
            "bg2",
            probe.row,
            -1,
            probe.bg2_col,
            probe.bg2_codepoint,
            sample_x,
            sample_y,
            Color.black,
            probe.bg2_expected,
            switch (phase) {
                .glyph => &probe.bg2_baseline,
                .window => &probe.bg2_glyph,
                .final => &probe.bg2_window,
                .bg => null,
            },
            switch (phase) {
                .bg => &probe.bg2_baseline,
                .glyph => &probe.bg2_glyph,
                .window => &probe.bg2_window,
                .final => &probe.bg2_final,
            },
            cell_w_i,
            cell_h_i,
        );
    }
    var sample_idx: usize = 0;
    while (sample_idx < probe.direct_samples.len) : (sample_idx += 1) {
        const sample = probe.direct_samples[sample_idx];
        if (!sample.present) break;
        const sample_x = origin_x + (@as(f32, @floatFromInt(@as(i32, @intCast(sample.col)) * cell_w_i)) + @as(f32, @floatFromInt(cell_w_i)) * 0.5);
        logTargetSamplePixel(
            rr,
            log,
            phase,
            "direct",
            sample.row,
            @intCast(sample_idx),
            sample.col,
            sample.codepoint,
            sample_x,
            sample_y,
            sample.fg,
            sample.bg,
            switch (phase) {
                .glyph => &probe.direct_baselines[sample_idx],
                .window => &probe.direct_glyphs[sample_idx],
                .final => &probe.direct_windows[sample_idx],
                .bg => null,
            },
            switch (phase) {
                .bg => &probe.direct_baselines[sample_idx],
                .glyph => &probe.direct_glyphs[sample_idx],
                .window => &probe.direct_windows[sample_idx],
                .final => &probe.direct_finals[sample_idx],
            },
            cell_w_i,
            cell_h_i,
        );
    }
}

fn logTargetProbeBandPhase(
    rr: anytype,
    log: anytype,
    phase: TargetProbePhase,
    probe: *TargetReadbackProbe,
    origin_x: f32,
    origin_y: f32,
    cell_w_i: i32,
    cell_h_i: i32,
) void {
    if (probe.col_end < probe.col_start) return;
    const band_x = origin_x + @as(f32, @floatFromInt(@as(i32, @intCast(probe.col_start)) * cell_w_i));
    const band_y = origin_y + @as(f32, @floatFromInt(@as(i32, @intCast(probe.row)) * cell_h_i));
    const band_width = @as(f32, @floatFromInt(@as(i32, @intCast(probe.col_end - probe.col_start + 1)) * cell_w_i));
    const band_height = @as(f32, @floatFromInt(cell_h_i));
    const sample = captureTargetBand(rr, band_x, band_y, band_width, band_height);
    const signature = hashTargetBand(&sample);
    switch (phase) {
        .window => {
            probe.band_window = sample;
            log.logf(
                .info,
                "event=target_band phase=window row={d} cols={d}..{d} sig={x}",
                .{ probe.row, probe.col_start, probe.col_end, signature },
            );
        },
        .final => {
            const diff = diffTargetBand(&sample, &probe.band_window);
            probe.band_final = sample;
            log.logf(
                .info,
                "event=target_band phase=final row={d} cols={d}..{d} sig={x} diff_hits={d}/{d} diff_max={d}",
                .{ probe.row, probe.col_start, probe.col_end, signature, diff.hits, diff.samples, diff.max_delta },
            );
        },
        else => {},
    }
}

fn seedFallbackProbeSample(
    samples: *[draw_grid.max_direct_glyph_samples]draw_grid.DirectGlyphSample,
    view_cells: []const Cell,
    cols: usize,
    row: usize,
    col: usize,
    screen_reverse_mode: bool,
) void {
    if (samples[0].present or cols == 0 or col >= cols) return;
    const cell_idx = row * cols + col;
    if (cell_idx >= view_cells.len) return;
    const cell = view_cells[cell_idx];
    if (cell.codepoint == 0) return;
    const fg = Color{ .r = cell.attrs.fg.r, .g = cell.attrs.fg.g, .b = cell.attrs.fg.b, .a = cell.attrs.fg.a };
    const bg = Color{ .r = cell.attrs.bg.r, .g = cell.attrs.bg.g, .b = cell.attrs.bg.b, .a = cell.attrs.bg.a };
    const cell_reverse = cell.attrs.reverse != screen_reverse_mode;
    samples[0] = .{
        .present = true,
        .row = row,
        .col = col,
        .codepoint = cell.codepoint,
        .glyph_id = 0,
        .simple_ascii = cell.codepoint < 128,
        .want_color = false,
        .fg = if (cell_reverse) bg else fg,
        .bg = if (cell_reverse) fg else bg,
    };
}

fn appendFixedCursorNeighborhoodProbes(
    target_probes: *[max_target_sample_rows]TargetReadbackProbe,
    target_probe_count: *usize,
    view_cells: []const Cell,
    rows: usize,
    cols: usize,
    cursor: CursorPos,
    screen_reverse_mode: bool,
) void {
    if (rows == 0 or cols == 0 or cursor.row >= rows or target_probe_count.* >= target_probes.len) return;
    var idx: usize = 0;
    while (idx < target_probe_count.*) : (idx += 1) {
        if (target_probes[idx].row == cursor.row and target_probes[idx].column_present and target_probes[idx].column_col == cursor.col) {
            return;
        }
    }
    const row_start = cursor.row -| cursor_probe_row_radius;
    const row_end = @min(rows - 1, cursor.row + cursor_probe_row_radius);
    const col = std.math.clamp(cursor.col, @as(usize, 0), cols - 1);
    const col_start = col -| cursor_probe_col_radius;
    const col_end = @min(cols - 1, col + cursor_probe_col_radius);
    var direct_samples = [_]draw_grid.DirectGlyphSample{.{}} ** draw_grid.max_direct_glyph_samples;
    seedFallbackProbeSample(&direct_samples, view_cells, cols, cursor.row, col, screen_reverse_mode);
    if (!direct_samples[0].present) return;
    target_probes[target_probe_count.*] = .{
        .row = cursor.row,
        .col_start = col_start,
        .col_end = col_end,
        .column_present = true,
        .column_col = col,
        .column_row_start = row_start,
        .column_row_end = row_end,
        .direct_samples = direct_samples,
    };
    target_probe_count.* += 1;
}

fn logTargetProbeColumnBandPhase(
    rr: anytype,
    log: anytype,
    phase: TargetProbePhase,
    probe: *TargetReadbackProbe,
    origin_x: f32,
    origin_y: f32,
    cell_w_i: i32,
    cell_h_i: i32,
    rows: usize,
) void {
    if (!probe.column_present or rows == 0) return;
    const row_start = probe.column_row_start;
    const row_end = probe.column_row_end;
    if (row_end < row_start or row_end >= rows) return;
    const band_x = origin_x + @as(f32, @floatFromInt(@as(i32, @intCast(probe.column_col)) * cell_w_i));
    const band_y = origin_y + @as(f32, @floatFromInt(@as(i32, @intCast(row_start)) * cell_h_i));
    const band_width = @as(f32, @floatFromInt(cell_w_i));
    const band_height = @as(f32, @floatFromInt(@as(i32, @intCast(row_end - row_start + 1)) * cell_h_i));
    const sample = captureTargetBand(rr, band_x, band_y, band_width, band_height);
    const signature = hashTargetBand(&sample);
    switch (phase) {
        .window => {
            probe.column_band_window = sample;
            log.logf(
                .info,
                "event=target_band phase=window axis=column col={d} rows={d}..{d} sig={x}",
                .{ probe.column_col, row_start, row_end, signature },
            );
        },
        .final => {
            const diff = diffTargetBand(&sample, &probe.column_band_window);
            probe.column_band_final = sample;
            log.logf(
                .info,
                "event=target_band phase=final axis=column col={d} rows={d}..{d} sig={x} diff_hits={d}/{d} diff_max={d}",
                .{ probe.column_col, row_start, row_end, signature, diff.hits, diff.samples, diff.max_delta },
            );
        },
        else => {},
    }
}

fn registerPresentationProbes(
    rr: anytype,
    probe: *const TargetReadbackProbe,
    origin_x: f32,
    origin_y: f32,
    cell_w_i: i32,
    cell_h_i: i32,
    rows: usize,
) void {
    const sample_y = origin_y + (@as(f32, @floatFromInt(@as(i32, @intCast(probe.row)) * cell_h_i)) + @as(f32, @floatFromInt(cell_h_i)) * 0.5);
    if (probe.bg2_present) {
        const sample_x = origin_x + (@as(f32, @floatFromInt(@as(i32, @intCast(probe.bg2_col)) * cell_w_i)) + @as(f32, @floatFromInt(cell_w_i)) * 0.5);
        rr.registerPresentationProbe(
            .bg2,
            probe.row,
            -1,
            probe.bg2_col,
            probe.bg2_codepoint,
            sample_x,
            sample_y,
            Color.black,
            probe.bg2_expected,
            probe.bg2_final.valid,
            probe.bg2_final.pixels,
        );
    }
    var sample_idx: usize = 0;
    while (sample_idx < probe.direct_samples.len) : (sample_idx += 1) {
        const sample = probe.direct_samples[sample_idx];
        if (!sample.present) continue;
        const sample_x = origin_x + (@as(f32, @floatFromInt(@as(i32, @intCast(sample.col)) * cell_w_i)) + @as(f32, @floatFromInt(cell_w_i)) * 0.5);
        rr.registerPresentationProbe(
            .direct,
            sample.row,
            @intCast(sample_idx),
            sample.col,
            sample.codepoint,
            sample_x,
            sample_y,
            sample.fg,
            sample.bg,
            probe.direct_finals[sample_idx].valid,
            probe.direct_finals[sample_idx].pixels,
        );
    }
    if (probe.col_end >= probe.col_start) {
        const band_x = origin_x + @as(f32, @floatFromInt(@as(i32, @intCast(probe.col_start)) * cell_w_i));
        const band_y = origin_y + @as(f32, @floatFromInt(@as(i32, @intCast(probe.row)) * cell_h_i));
        const band_width = @as(f32, @floatFromInt(@as(i32, @intCast(probe.col_end - probe.col_start + 1)) * cell_w_i));
        const band_height = @as(f32, @floatFromInt(cell_h_i));
        rr.registerPresentationBandProbe(
            probe.row,
            probe.col_start,
            probe.col_end,
            band_x,
            band_y,
            band_width,
            band_height,
            probe.band_final.valid,
            probe.band_final.pixels,
        );
    }
    if (probe.column_present) {
        const row_start = probe.column_row_start;
        const row_end = probe.column_row_end;
        if (row_end >= rows or row_end < row_start) return;
        const band_x = origin_x + @as(f32, @floatFromInt(@as(i32, @intCast(probe.column_col)) * cell_w_i));
        const band_y = origin_y + @as(f32, @floatFromInt(@as(i32, @intCast(row_start)) * cell_h_i));
        const band_width = @as(f32, @floatFromInt(cell_w_i));
        const band_height = @as(f32, @floatFromInt(@as(i32, @intCast(row_end - row_start + 1)) * cell_h_i));
        rr.registerPresentationColumnBandProbe(
            probe.column_col,
            row_start,
            row_end,
            band_x,
            band_y,
            band_width,
            band_height,
            probe.column_band_final.valid,
            probe.column_band_final.pixels,
        );
    }
}

pub fn drawPrepared(
    self: anytype,
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    input: shared_types.input.InputSnapshot,
    preparation: DrawPreparation,
) DrawOutcome {
    const draw_start = preparation.draw_start;
    const lock_ms: f64 = preparation.lock_ms;
    const lock_wait_ms: f64 = preparation.lock_wait_ms;
    const lock_hold_ms: f64 = preparation.lock_hold_ms;
    const view_cache_ms: f64 = preparation.view_cache_ms;
    const cache_copy_ms: f64 = preparation.cache_copy_ms;
    var texture_update_ms: f64 = 0.0;
    var texture_bg_ms: f64 = 0.0;
    var texture_glyph_ms: f64 = 0.0;
    var texture_kitty_ms: f64 = 0.0;
    var glyph_draw_stats = GlyphDrawStats{};
    var overlay_ms: f64 = 0.0;
    var render_phase_start = draw_start;
    var outcome = DrawOutcome{ .presented = preparation.presented };
    defer {
        const draw_end = app_shell.getTime();
        const draw_ms_total = time_utils.secondsToMs(draw_end - draw_start);
        const render_ms = time_utils.secondsToMs(draw_end - render_phase_start);
        publishFrameLatencyMetrics(
            self.draw_cache.generation,
            lock_ms,
            lock_wait_ms,
            lock_hold_ms,
            view_cache_ms,
            cache_copy_ms,
            texture_update_ms,
            texture_bg_ms,
            texture_glyph_ms,
            texture_kitty_ms,
            overlay_ms,
            render_ms,
            draw_ms_total,
        );
    }

    const r = shell.rendererPtr();
    const cache = &self.draw_cache;
    var alt_exit = false;
    var alt_state_changed = false;
    alt_state_changed = self.last_alt_active != cache.alt_active;
    alt_exit = self.last_alt_active and !cache.alt_active;
    self.last_alt_active = cache.alt_active;
    render_phase_start = app_shell.getTime();

    const sync_updates = cache.sync_updates_active;
    const screen_reverse = cache.screen_reverse;
    const blink_style = self.blink_style;
    const blink_time = app_shell.getTime();
    if (sync_updates and cache.cells.items.len > 0) {
        const view_cells = cache.cells.items;
        const bg_color = if (view_cells.len > 0) blk: {
            const cell = view_cells[0];
            const reversed = cell.attrs.reverse != screen_reverse;
            const bg = if (reversed) cell.attrs.fg else cell.attrs.bg;
            break :blk Color{
                .r = bg.r,
                .g = bg.g,
                .b = bg.b,
            };
        } else r.theme.background;
        r.drawRect(
            @intFromFloat(x),
            @intFromFloat(y),
            @intFromFloat(width),
            @intFromFloat(height),
            bg_color,
        );
        r.drawTerminalTexture(x, y);
        return outcome;
    }
    const draw_start_time = if (alt_exit) app_shell.getTime() else 0;
    const rows = cache.rows;
    const cols = cache.cols;
    const history_len = cache.history_len;
    const total_lines = cache.total_lines;
    const scroll_offset = cache.scroll_offset;
    const viewport_shift_rows = cache.viewport_shift_rows;
    const max_scroll_offset = if (total_lines > rows) total_lines - rows else 0;
    const end_line = total_lines - scroll_offset;
    const start_line = if (end_line > rows) end_line - rows else 0;
    var draw_cursor = scroll_offset == 0 and cache.cursor_visible;
    const cursor = if (draw_cursor) cache.cursor else CursorPos{ .row = rows + 1, .col = cols + 1 };
    const probe_cursor = cache.cursor;
    const cursor_style = cache.cursor_style;
    if (draw_cursor and self.ui_focused and cursor_style.blink) {
        if (blink_time >= self.cursor_blink_pause_until) {
            const period: f64 = 0.5;
            const phase = @mod(blink_time, period * 2.0);
            draw_cursor = phase < period;
        }
    }
    const kitty_generation = cache.kitty_generation;
    const has_blink = blink_style != .off and cache.has_blink;
    const blink_phase_changed = self.blink_phase_changed_pending;
    self.blink_phase_changed_pending = false;
    const blink_requires_partial = has_blink and blink_phase_changed;

    self.kitty.updateViews(self.session.allocator, rows, cols, cache.kitty_images.items, cache.kitty_placements.items);

    var upload_stats: kitty_mod.KittyState.UploadStats = .{};
    if (self.kitty.images_view.items.len > 0) {
        self.kitty.primeUploads(self.session.allocator);
        upload_stats = self.kitty.processPendingUploads(shell);
    }

    const view_cells = cache.cells.items;
    const view_dirty_rows = cache.dirty_rows.items;
    const draw_log = app_logger.logger("terminal.ui.redraw");
    const texture_shift_log = app_logger.logger("terminal.ui.texture_shift");
    const target_sample_log = app_logger.logger("terminal.ui.target_sample");
    var dirty_rows_count: usize = 0;
    var damage_row_span: usize = 0;
    var damage_col_span: usize = 0;
    var partial_plan_rows_count: usize = 0;
    var partial_plan_row_span: usize = 0;
    var partial_plan_col_span: usize = 0;
    var partial_plan_cells: usize = 0;
    var partial_plan_union_cells: usize = 0;
    var partial_plan_summary: []const u8 = "";
    var partial_plan_summary_buf: [256]u8 = undefined;
    var glyph_stats_summary_buf: [220]u8 = undefined;
    var sprite_stats_summary_buf: [48]u8 = undefined;
    var lock_stats_summary_buf: [64]u8 = undefined;
    if (cache.dirty != .none) {
        for (view_dirty_rows) |row_dirty| {
            if (row_dirty) dirty_rows_count += 1;
        }
        if (cache.damage.end_row >= cache.damage.start_row) {
            damage_row_span = cache.damage.end_row - cache.damage.start_row + 1;
        }
        if (cache.damage.end_col >= cache.damage.start_col) {
            damage_col_span = cache.damage.end_col - cache.damage.start_col + 1;
        }
    }
    const has_kitty = self.kitty.hasKitty();
    const bg_color = if (view_cells.len > 0) Color{
        .r = view_cells[0].attrs.bg.r,
        .g = view_cells[0].attrs.bg.g,
        .b = view_cells[0].attrs.bg.b,
    } else r.theme.background;
    r.drawRect(
        @intFromFloat(x),
        @intFromFloat(y),
        @intFromFloat(width),
        @intFromFloat(height),
        bg_color,
    );

    // No clipping - let icons overflow freely
    // (sidebar draws last to cover any left overflow, right overflow goes into empty space)

    const base_x = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(x)))));
    const base_y = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(y)))));

    const scale = shell.uiScaleFactor();
    const scrollbar_hit_margin: f32 = common.scrollbarHitMargin(scale);
    const scrollbar_proximity: f32 = common.scrollbarProximityRange(scale);
    const mouse = input.mouse_pos;
    const in_scroll_y = mouse.y >= y and mouse.y <= y + height;
    const dist_from_right = (x + width) - mouse.x;
    const proximity_raw: f32 = if (in_scroll_y and dist_from_right <= scrollbar_proximity and dist_from_right >= -scrollbar_hit_margin)
        (1.0 - std.math.clamp(dist_from_right / scrollbar_proximity, 0.0, 1.0))
    else
        0.0;
    const show_scrollbar = !cache.alt_active and !cache.mouse_reporting_active and total_lines > rows;
    const proximity_t = common.smoothstep01(proximity_raw);
    const hover_target: f32 = if (show_scrollbar)
        (if (self.scrollbar_drag_active) 1.0 else proximity_t)
    else
        0.0;
    const anim_dt: f32 = blk: {
        if (self.scrollbar_anim_last_time <= 0) {
            self.scrollbar_anim_last_time = blink_time;
            break :blk 0;
        }
        const dt = std.math.clamp(blink_time - self.scrollbar_anim_last_time, 0.0, 0.1);
        self.scrollbar_anim_last_time = blink_time;
        break :blk @floatCast(dt);
    };
    self.scrollbar_hover_anim = common.expApproach(self.scrollbar_hover_anim, hover_target, anim_dt, 18.0);
    self.hover.dirty = false;
    const hover_link_id = hover_mod.hoverLinkId(&self.hover);

    var updated = false;
    var texture_full_update = false;
    var texture_partial_update = false;
    var active_viewport_shift_rows: i32 = 0;
    var active_shift_exposed_only = false;
    var cell_w_i: i32 = 0;
    var cell_h_i: i32 = 0;
    var target_probes = [_]TargetReadbackProbe{.{}} ** max_target_sample_rows;
    var target_probe_count: usize = 0;
    const row_render_log = app_logger.logger("terminal.ui.row_render_pass");
    const row_render_runs_log = app_logger.logger("terminal.ui.row_render_pass_runs");
    const texture_phase_start = app_shell.getTime();
    const texture_ready_before_draw = self.terminal_texture_ready;
    if (rows > 0 and cols > 0) {
        cell_w_i = @intFromFloat(std.math.round(r.terminal_cell_width));
        cell_h_i = @intFromFloat(std.math.round(r.terminal_cell_height));
        const cell_metrics_changed = cell_w_i != self.last_cell_w_i or cell_h_i != self.last_cell_h_i;
        const render_scale_changed = r.render_scale != self.last_render_scale;
        const padding_x_i: i32 = @max(2, @divTrunc(cell_w_i, 2));
        const texture_w = cell_w_i * @as(i32, @intCast(cols)) + padding_x_i;
        const texture_h = cell_h_i * @as(i32, @intCast(rows));
        const recreated = r.ensureTerminalTexture(texture_w, texture_h);
        const gen_changed = cache.generation != self.last_render_generation;
        var update_plan = chooseTextureUpdatePlan(
            cache.dirty,
            recreated,
            cell_metrics_changed,
            render_scale_changed,
            blink_requires_partial,
            self.terminal_texture_ready,
        );
        const force_full_recovery_window = r.forceFullTerminalTexturePublicationRecoveryWindow();
        const recovery_window_seconds = r.fullTerminalTexturePublicationRecoveryWindowSeconds();
        const force_full_recent_input_window = r.forceFullTerminalTexturePublicationRecentInputWindow();
        const recent_input_window_seconds = r.fullTerminalTexturePublicationRecentInputWindowSeconds();
        const modifier_pressure_active = input.mods.ctrl or input.mods.shift or input.mods.alt or input.mods.super;
        const plan_was_active = update_plan.needs_full or update_plan.needs_partial;
        const plan_time = app_shell.getTime();
        update_plan = forceFullTextureUpdatePlan(update_plan, r.forceFullTerminalTexturePublication());
        update_plan = forceFullTextureUpdatePlanEveryFrame(update_plan, r.forceFullTerminalTexturePublicationEveryFrame());
        if (force_full_recovery_window and plan_was_active) {
            self.force_full_texture_publish_until = @max(
                self.force_full_texture_publish_until,
                plan_time + recovery_window_seconds,
            );
        }
        const recovery_window_active = force_full_recovery_window and plan_time < self.force_full_texture_publish_until;
        const recent_input_age_s = if (self.last_terminal_input_time > 0 and plan_time >= self.last_terminal_input_time)
            plan_time - self.last_terminal_input_time
        else
            -1.0;
        const recent_input_window_active = force_full_recent_input_window and
            (modifier_pressure_active or
                (self.last_terminal_input_time > 0 and
                    recent_input_age_s >= 0 and
                    recent_input_age_s <= recent_input_window_seconds));
        update_plan = forceFullTextureUpdatePlanEveryFrame(
            update_plan,
            recovery_window_active,
        );
        update_plan = forceFullTextureUpdatePlanEveryFrame(
            update_plan,
            recent_input_window_active,
        );
        const pressure_log = app_logger.logger("terminal.ui.present_pressure");
        if ((pressure_log.enabled_file or pressure_log.enabled_console) and
            (plan_was_active or gen_changed or recovery_window_active or recent_input_window_active or modifier_pressure_active))
        {
            pressure_log.logf(
                .info,
                "gen_changed={d} pub_gen={d}->{d} texture_ready={d} recreated={d} plan_active={d} plan_full={d} plan_partial={d} recent_cfg={d} recent_active={d} recent_age_ms={d:.2} recent_window_ms={d:.2} modifier={d} recovery_cfg={d} recovery_active={d} recovery_until_ms={d:.2}",
                .{
                    @intFromBool(gen_changed),
                    self.last_render_generation,
                    cache.generation,
                    @intFromBool(texture_ready_before_draw),
                    @intFromBool(recreated),
                    @intFromBool(plan_was_active),
                    @intFromBool(update_plan.needs_full),
                    @intFromBool(update_plan.needs_partial),
                    @intFromBool(force_full_recent_input_window),
                    @intFromBool(recent_input_window_active),
                    if (recent_input_age_s >= 0) recent_input_age_s * 1000.0 else -1.0,
                    recent_input_window_seconds * 1000.0,
                    @intFromBool(modifier_pressure_active),
                    @intFromBool(force_full_recovery_window),
                    @intFromBool(recovery_window_active),
                    if (self.force_full_texture_publish_until > 0 and plan_time <= self.force_full_texture_publish_until)
                        (self.force_full_texture_publish_until - plan_time) * 1000.0
                    else
                        0.0,
                },
            );
        }
        const handoff_log = app_logger.logger("terminal.generation_handoff");
        if ((handoff_log.enabled_file or handoff_log.enabled_console) and
            (gen_changed or plan_was_active or update_plan.needs_full or update_plan.needs_partial))
        {
            handoff_log.logf(
                .info,
                "stage=widget_plan sid={x} last_render={d} cache_gen={d} cur={d} pub={d} presented={d} gen_changed={d} plan_full={d} plan_partial={d} texture_ready={d}",
                .{
                    @intFromPtr(self.session),
                    self.last_render_generation,
                    cache.generation,
                    self.session.currentGeneration(),
                    self.session.publishedGeneration(),
                    self.session.presentedGeneration(),
                    @intFromBool(gen_changed),
                    @intFromBool(update_plan.needs_full),
                    @intFromBool(update_plan.needs_partial),
                    @intFromBool(texture_ready_before_draw),
                },
            );
        }
        const needs_full = update_plan.needs_full;
        var needs_partial = update_plan.needs_partial;
        const use_viewport_shift = draw_texture.useViewportShiftForPartialPlan(cache.dirty, viewport_shift_rows);
        active_viewport_shift_rows = if (use_viewport_shift) viewport_shift_rows else 0;
        active_shift_exposed_only = use_viewport_shift and cache.viewport_shift_exposed_only;
        var shifted_rows: usize = 0;
        var shift_requires_fullwidth_partial = false;
        switch (planViewportTextureShift(
            r.terminalTextureShiftEnabled(),
            gen_changed,
            active_viewport_shift_rows,
            active_shift_exposed_only,
            scroll_offset,
            needs_full,
            self.terminal_texture_ready,
            rows,
        )) {
            .attempt => |shift_rows| {
                const dy_pixels: i32 = -active_viewport_shift_rows * cell_h_i;
                if (r.scrollTerminalTexture(0, dy_pixels)) {
                    needs_partial = true;
                    shifted_rows = shift_rows;
                    texture_shift_log.logf(
                        .info,
                        "result=scroll_copy_ok gen={d} dirty={s} shift_rows={d} exposed_only={d} scroll_offset={d} damage={d}..{d}/{d}..{d}",
                        .{
                            cache.generation,
                            @tagName(cache.dirty),
                            active_viewport_shift_rows,
                            @intFromBool(active_shift_exposed_only),
                            scroll_offset,
                            cache.damage.start_row,
                            cache.damage.end_row,
                            cache.damage.start_col,
                            cache.damage.end_col,
                        },
                    );
                } else {
                    shifted_rows = 0;
                    texture_shift_log.logf(
                        .info,
                        "result=scroll_copy_failed gen={d} dirty={s} shift_rows={d} exposed_only={d} scroll_offset={d}",
                        .{
                            cache.generation,
                            @tagName(cache.dirty),
                            active_viewport_shift_rows,
                            @intFromBool(active_shift_exposed_only),
                            scroll_offset,
                        },
                    );
                    if (active_shift_exposed_only) {
                        needs_partial = true;
                        shift_requires_fullwidth_partial = true;
                    }
                }
            },
            .none => {
                if (active_viewport_shift_rows != 0) {
                    texture_shift_log.logf(
                        .info,
                        "result=scroll_copy_skipped gen={d} dirty={s} shift_rows={d} exposed_only={d} scroll_offset={d} full={d}",
                        .{
                            cache.generation,
                            @tagName(cache.dirty),
                            active_viewport_shift_rows,
                            @intFromBool(active_shift_exposed_only),
                            scroll_offset,
                            @intFromBool(needs_full),
                        },
                    );
                }
                if (active_shift_exposed_only) {
                    needs_partial = true;
                    shift_requires_fullwidth_partial = true;
                }
            },
        }
        texture_full_update = needs_full;
        texture_partial_update = needs_partial;
        target_probe_count = 0;

        if ((needs_full or needs_partial) and r.beginTerminalTexture()) {
            // Disable scissor while updating the offscreen texture.
            // The main draw pass will restore the clip for on-screen drawing.
            r.endClip();
            const base_x_local: f32 = 0;
            const base_y_local: f32 = 0;

            if (needs_full) {
                const bg_phase_start = app_shell.getTime();
                const bg = if (view_cells.len > 0) blk: {
                    const cell = view_cells[0];
                    const reversed = cell.attrs.reverse != screen_reverse;
                    const base_bg = if (reversed) cell.attrs.fg else cell.attrs.bg;
                    break :blk Color{
                        .r = base_bg.r,
                        .g = base_bg.g,
                        .b = base_bg.b,
                    };
                } else r.theme.background;
                r.beginTerminalBatch();
                r.addTerminalRect(0, 0, texture_w, texture_h, bg);
                var row: usize = 0;
                while (row < rows) : (row += 1) {
                    drawRowBackgrounds(shell, view_cells, cols, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i, true, screen_reverse);
                }
                r.flushTerminalBatch();
                texture_bg_ms += time_utils.secondsToMs(app_shell.getTime() - bg_phase_start);
                if (has_kitty) {
                    const kitty_phase_start = app_shell.getTime();
                    self.kitty.cleanupTextures(self.session.allocator, self.kitty.images_view.items);
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, false, start_line, rows, cols);
                    texture_kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
                }
                const glyph_phase_start = app_shell.getTime();
                r.beginTerminalGlyphBatch();
                row = 0;
                while (row < rows) : (row += 1) {
                    drawRowGlyphs(shell, view_cells, cols, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time, draw_cursor, cursor, r.terminal_disable_ligatures, null, &glyph_draw_stats);
                }
                r.flushTerminalGlyphBatch();
                texture_glyph_ms += time_utils.secondsToMs(app_shell.getTime() - glyph_phase_start);
                if (has_kitty) {
                    const kitty_phase_start = app_shell.getTime();
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, true, start_line, rows, cols);
                    texture_kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
                }
            } else if (needs_partial) {
                self.partial_draw_rows.resize(self.session.allocator, rows) catch |err| {
                    const log = app_logger.logger("terminal.ui.redraw");
                    log.logf(.warning, "partial row plan resize failed field=rows rows={d} err={s}", .{ rows, @errorName(err) });
                    r.endTerminalTexture();
                    return outcome;
                };
                self.partial_draw_cols_start.resize(self.session.allocator, rows) catch |err| {
                    const log = app_logger.logger("terminal.ui.redraw");
                    log.logf(.warning, "partial row plan resize failed field=cols_start rows={d} err={s}", .{ rows, @errorName(err) });
                    r.endTerminalTexture();
                    return outcome;
                };
                self.partial_draw_cols_end.resize(self.session.allocator, rows) catch |err| {
                    const log = app_logger.logger("terminal.ui.redraw");
                    log.logf(.warning, "partial row plan resize failed field=cols_end rows={d} err={s}", .{ rows, @errorName(err) });
                    r.endTerminalTexture();
                    return outcome;
                };

                self.partial_draw_span_counts.resize(self.session.allocator, rows) catch |err| {
                    const log = app_logger.logger("terminal.ui.redraw");
                    log.logf(.warning, "partial row plan resize failed field=span_counts rows={d} err={s}", .{ rows, @errorName(err) });
                    r.endTerminalTexture();
                    return outcome;
                };
                self.partial_draw_spans.resize(self.session.allocator, rows) catch |err| {
                    const log = app_logger.logger("terminal.ui.redraw");
                    log.logf(.warning, "partial row plan resize failed field=spans rows={d} err={s}", .{ rows, @errorName(err) });
                    r.endTerminalTexture();
                    return outcome;
                };

                const partial_plan_bounds = buildPartialPlan(
                    cache,
                    self.partial_draw_rows.items,
                    self.partial_draw_span_counts.items,
                    self.partial_draw_spans.items,
                    self.partial_draw_cols_start.items,
                    self.partial_draw_cols_end.items,
                    shifted_rows,
                    active_viewport_shift_rows,
                    shift_requires_fullwidth_partial,
                    blink_requires_partial,
                );
                for (self.partial_draw_rows.items) |row_draw| {
                    if (row_draw) partial_plan_rows_count += 1;
                }
                for (self.partial_draw_rows.items, 0..) |row_draw, row| {
                    if (!row_draw) continue;
                    if (row < self.partial_draw_span_counts.items.len and row < self.partial_draw_spans.items.len and self.partial_draw_span_counts.items[row] > 0) {
                        var span_idx: usize = 0;
                        while (span_idx < self.partial_draw_span_counts.items[row]) : (span_idx += 1) {
                            const span = self.partial_draw_spans.items[row][span_idx];
                            const row_start = @as(usize, span.start);
                            const row_end = @as(usize, span.end);
                            if (row_end >= row_start) partial_plan_cells += row_end - row_start + 1;
                        }
                    } else {
                        const row_start = @as(usize, self.partial_draw_cols_start.items[row]);
                        const row_end = @as(usize, self.partial_draw_cols_end.items[row]);
                        if (row_end >= row_start) partial_plan_cells += row_end - row_start + 1;
                    }
                }
                if (partial_plan_bounds) |bounds| {
                    partial_plan_row_span = bounds.end_row - bounds.start_row + 1;
                    partial_plan_col_span = bounds.end_col - bounds.start_col + 1;
                    partial_plan_union_cells = partial_plan_row_span * partial_plan_col_span;
                }
                if ((draw_log.enabled_file or draw_log.enabled_console) and texture_partial_update) {
                    partial_plan_summary = draw_texture.formatPartialPlanRows(
                        &partial_plan_summary_buf,
                        self.partial_draw_rows.items,
                        self.partial_draw_span_counts.items,
                        self.partial_draw_spans.items,
                        self.partial_draw_cols_start.items,
                        self.partial_draw_cols_end.items,
                        12,
                    );
                }
                if (shifted_rows > 0 or shift_requires_fullwidth_partial) {
                    texture_shift_log.logf(
                        .info,
                        "result=partial_plan gen={d} shifted_rows={d} fullwidth_exposed={d} plan_rows={d} plan_row_span={d} plan_col_span={d} plan_cells={d} plan_union_cells={d} spans={s}",
                        .{
                            cache.generation,
                            shifted_rows,
                            @intFromBool(shift_requires_fullwidth_partial),
                            partial_plan_rows_count,
                            partial_plan_row_span,
                            partial_plan_col_span,
                            partial_plan_cells,
                            partial_plan_union_cells,
                            partial_plan_summary,
                        },
                    );
                }

                const bg_phase_start = app_shell.getTime();
                r.beginTerminalBatch();
                for (0..rows) |row| {
                    if (!self.partial_draw_rows.items[row]) continue;
                    if (row < self.partial_draw_span_counts.items.len and row < self.partial_draw_spans.items.len and self.partial_draw_span_counts.items[row] > 0) {
                        var span_idx: usize = 0;
                        while (span_idx < self.partial_draw_span_counts.items[row]) : (span_idx += 1) {
                            const span = self.partial_draw_spans.items[row][span_idx];
                            const col_start = @min(@as(usize, span.start), cols - 1);
                            const col_end = @min(@as(usize, span.end), cols - 1);
                            const draw_padding = col_end >= cols - 1;
                            drawRowBackgrounds(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, draw_padding, screen_reverse);
                        }
                        continue;
                    }
                    const col_start = @min(@as(usize, self.partial_draw_cols_start.items[row]), cols - 1);
                    const col_end = @min(@as(usize, self.partial_draw_cols_end.items[row]), cols - 1);
                    const draw_padding = col_end >= cols - 1;
                    drawRowBackgrounds(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, draw_padding, screen_reverse);
                }
                r.flushTerminalBatch();
                texture_bg_ms += time_utils.secondsToMs(app_shell.getTime() - bg_phase_start);
                if (has_kitty) {
                    const kitty_phase_start = app_shell.getTime();
                    self.kitty.cleanupTextures(self.session.allocator, self.kitty.images_view.items);
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, false, start_line, rows, cols);
                    texture_kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
                }
                const glyph_phase_start = app_shell.getTime();
                r.beginTerminalGlyphBatch();
                const target_probe_enabled =
                    target_sample_log.enabled_file or
                    target_sample_log.enabled_console or
                    row_render_log.enabled_file or
                    row_render_log.enabled_console;
                if (target_sample_log.enabled_file or target_sample_log.enabled_console) {
                    appendFixedCursorNeighborhoodProbes(&target_probes, &target_probe_count, view_cells, rows, cols, probe_cursor, screen_reverse);
                    if (target_probe_count > 0) {
                        var probe_idx: usize = 0;
                        while (probe_idx < target_probe_count) : (probe_idx += 1) {
                            logTargetProbePhase(r, SilentTargetProbeLogger{}, .bg, &target_probes[probe_idx], 0, 0, cell_w_i, cell_h_i);
                        }
                    }
                }
                for (0..rows) |row| {
                    if (!self.partial_draw_rows.items[row]) continue;
                    const before_stats = glyph_draw_stats;
                    var row_bg_runs: usize = 0;
                    var row_span_count: usize = 0;
                    var row_col_min: usize = cols;
                    var row_col_max: usize = 0;
                    var row_bg_summary = draw_grid.BackgroundRunSummary{};
                    var row_direct_samples = [_]draw_grid.DirectGlyphSample{.{}} ** draw_grid.max_direct_glyph_samples;
                    if (row < self.partial_draw_span_counts.items.len and row < self.partial_draw_spans.items.len and self.partial_draw_span_counts.items[row] > 0) {
                        var span_idx: usize = 0;
                        while (span_idx < self.partial_draw_span_counts.items[row]) : (span_idx += 1) {
                            const span = self.partial_draw_spans.items[row][span_idx];
                            const col_start = @min(@as(usize, span.start), cols - 1);
                            const col_end = @min(@as(usize, span.end), cols - 1);
                            const draw_padding = col_end >= cols - 1;
                            row_bg_runs += draw_grid.countRowBackgroundRuns(view_cells, cols, row, col_start, col_end, draw_padding, screen_reverse);
                            if (row_bg_summary.runs == 0) {
                                row_bg_summary = draw_grid.summarizeRowBackgroundRuns(view_cells, cols, row, col_start, col_end, draw_padding, screen_reverse);
                            }
                            row_span_count += 1;
                            row_col_min = @min(row_col_min, col_start);
                            row_col_max = @max(row_col_max, col_end);
                            drawRowGlyphs(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time, draw_cursor, cursor, r.terminal_disable_ligatures, &row_direct_samples, &glyph_draw_stats);
                        }
                    } else {
                        const col_start = @min(@as(usize, self.partial_draw_cols_start.items[row]), cols - 1);
                        const col_end = @min(@as(usize, self.partial_draw_cols_end.items[row]), cols - 1);
                        const draw_padding = col_end >= cols - 1;
                        row_bg_runs += draw_grid.countRowBackgroundRuns(view_cells, cols, row, col_start, col_end, draw_padding, screen_reverse);
                        row_bg_summary = draw_grid.summarizeRowBackgroundRuns(view_cells, cols, row, col_start, col_end, draw_padding, screen_reverse);
                        row_span_count = 1;
                        row_col_min = col_start;
                        row_col_max = col_end;
                        drawRowGlyphs(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time, draw_cursor, cursor, r.terminal_disable_ligatures, &row_direct_samples, &glyph_draw_stats);
                    }
                    const row_width = if (row_col_min < cols and row_col_max >= row_col_min) row_col_max - row_col_min + 1 else 0;
                    const row_shaped_total = glyph_draw_stats.shaped_glyphs - before_stats.shaped_glyphs;
                    const row_direct_text = glyph_draw_stats.direct_text_glyphs - before_stats.direct_text_glyphs;
                    const row_special = glyph_draw_stats.special_sprite_glyphs - before_stats.special_sprite_glyphs;
                    const row_box = glyph_draw_stats.box_glyphs - before_stats.box_glyphs;
                    const row_shaped_text = glyph_draw_stats.shaped_text_glyphs - before_stats.shaped_text_glyphs;
                    const row_fallback = glyph_draw_stats.fallback_cells - before_stats.fallback_cells;
                    const broad_probe_candidate = row_width >= cols / 2 and row_direct_samples[1].present;
                    const narrow_box_probe_candidate = row_width > 0 and row_width <= 2 and row_box > 0;
                    const cursor_probe_row_start = if (cursor.row > 0) cursor.row - 1 else cursor.row;
                    const cursor_probe_row_end = @min(rows - 1, cursor.row + 1);
                    const cursor_probe_candidate = row_width > 0 and cursor.row < rows and row >= cursor_probe_row_start and row <= cursor_probe_row_end;
                    const cursor_probe_col = if (row_width > 0)
                        std.math.clamp(cursor.col, row_col_min, row_col_max)
                    else
                        row_col_min;
                    if (narrow_box_probe_candidate) {
                        seedFallbackProbeSample(&row_direct_samples, view_cells, cols, row, row_col_min, screen_reverse);
                    }
                    if (cursor_probe_candidate) {
                        seedFallbackProbeSample(&row_direct_samples, view_cells, cols, row, cursor_probe_col, screen_reverse);
                    }
                    if (target_probe_enabled and
                        target_probe_count < target_probes.len and
                        row_span_count > 0 and
                        row_col_min < cols and
                        row_col_max >= row_col_min and
                        (broad_probe_candidate or
                            (narrow_box_probe_candidate and row_direct_samples[0].present) or
                            (cursor_probe_candidate and row_direct_samples[0].present)))
                    {
                        target_probes[target_probe_count] = .{
                            .row = row,
                            .col_start = row_col_min,
                            .col_end = row_col_max,
                            .column_present = true,
                            .column_col = if (cursor_probe_candidate)
                                cursor_probe_col
                            else if (row_bg_summary.second_sample.present)
                                row_bg_summary.second_sample.col
                            else if (row_direct_samples[1].present)
                                row_direct_samples[1].col
                            else
                                row_direct_samples[0].col,
                            .column_row_start = if (cursor_probe_candidate)
                                cursor_probe_row_start
                            else if (row > 0)
                                row - 1
                            else
                                row,
                            .column_row_end = if (cursor_probe_candidate)
                                cursor_probe_row_end
                            else
                                @min(rows - 1, row + 1),
                            .bg2_present = row_bg_summary.second_sample.present,
                            .bg2_col = row_bg_summary.second_sample.col,
                            .bg2_codepoint = row_bg_summary.second_sample.codepoint,
                            .bg2_expected = row_bg_summary.second_sample.resolved_bg,
                            .direct_samples = row_direct_samples,
                        };
                        if (row_render_log.enabled_file or row_render_log.enabled_console) {
                            logTargetProbePhase(r, row_render_log, .bg, &target_probes[target_probe_count], 0, 0, cell_w_i, cell_h_i);
                        }
                        if (target_sample_log.enabled_file or target_sample_log.enabled_console) {
                            logTargetProbePhase(r, SilentTargetProbeLogger{}, .bg, &target_probes[target_probe_count], 0, 0, cell_w_i, cell_h_i);
                        }
                        target_probe_count += 1;
                    }
                    if ((row_render_log.enabled_file or row_render_log.enabled_console) and row_span_count > 0) {
                        if (row_width >= cols / 2 or row == cursor.row) {
                            row_render_log.logf(
                                .info,
                                "row={d} cols={d}..{d} width={d} spans={d} bg_runs={d} bg1={d}..{d}@{d}:{d}:{d} bg2={d}..{d}@{d}:{d}:{d} bg3={d}..{d}@{d}:{d}:{d} glyph_total={d} direct_text={d} shaped_text={d} special={d} box={d} fallback={d} direct_draw_ms={d:.2} special_lookup_ms={d:.2} special_submit_ms={d:.2} box_submit_ms={d:.2}",
                                .{
                                    row,
                                    row_col_min,
                                    row_col_max,
                                    row_width,
                                    row_span_count,
                                    row_bg_runs,
                                    row_bg_summary.first_start,
                                    row_bg_summary.first_end,
                                    row_bg_summary.first_color.r,
                                    row_bg_summary.first_color.g,
                                    row_bg_summary.first_color.b,
                                    row_bg_summary.second_start,
                                    row_bg_summary.second_end,
                                    row_bg_summary.second_color.r,
                                    row_bg_summary.second_color.g,
                                    row_bg_summary.second_color.b,
                                    row_bg_summary.third_start,
                                    row_bg_summary.third_end,
                                    row_bg_summary.third_color.r,
                                    row_bg_summary.third_color.g,
                                    row_bg_summary.third_color.b,
                                    row_shaped_total,
                                    row_direct_text,
                                    row_shaped_text,
                                    row_special,
                                    row_box,
                                    row_fallback,
                                    glyph_draw_stats.direct_draw_ms - before_stats.direct_draw_ms,
                                    glyph_draw_stats.special_sprite_lookup_ms - before_stats.special_sprite_lookup_ms,
                                    glyph_draw_stats.shaped_special_submit_ms - before_stats.shaped_special_submit_ms,
                                    glyph_draw_stats.box_submit_ms - before_stats.box_submit_ms,
                                },
                            );
                            row_render_runs_log.logf(
                                .info,
                                "row={d} bg2s=p{d} col={d} cp={d} fg={d}:{d}:{d} bg={d}:{d}:{d} rev={d} res={d}:{d}:{d}",
                                .{
                                    row,
                                    @intFromBool(row_bg_summary.second_sample.present),
                                    row_bg_summary.second_sample.col,
                                    row_bg_summary.second_sample.codepoint,
                                    row_bg_summary.second_sample.fg.r,
                                    row_bg_summary.second_sample.fg.g,
                                    row_bg_summary.second_sample.fg.b,
                                    row_bg_summary.second_sample.bg.r,
                                    row_bg_summary.second_sample.bg.g,
                                    row_bg_summary.second_sample.bg.b,
                                    @intFromBool(row_bg_summary.second_sample.reverse),
                                    row_bg_summary.second_sample.resolved_bg.r,
                                    row_bg_summary.second_sample.resolved_bg.g,
                                    row_bg_summary.second_sample.resolved_bg.b,
                                },
                            );
                        }
                    }
                }
                if (target_sample_log.enabled_file or target_sample_log.enabled_console) {
                    appendFixedCursorNeighborhoodProbes(&target_probes, &target_probe_count, view_cells, rows, cols, probe_cursor, screen_reverse);
                }
                r.flushTerminalGlyphBatch();
                if (target_probe_count > 0) {
                    var probe_idx: usize = 0;
                    while (probe_idx < target_probe_count) : (probe_idx += 1) {
                        if (target_sample_log.enabled_file or target_sample_log.enabled_console) {
                            logTargetProbePhase(r, SilentTargetProbeLogger{}, .glyph, &target_probes[probe_idx], 0, 0, cell_w_i, cell_h_i);
                        }
                        if (row_render_log.enabled_file or row_render_log.enabled_console) {
                            logTargetProbePhase(r, row_render_log, .glyph, &target_probes[probe_idx], 0, 0, cell_w_i, cell_h_i);
                        }
                    }
                }
                texture_glyph_ms += time_utils.secondsToMs(app_shell.getTime() - glyph_phase_start);
                if (has_kitty) {
                    const kitty_phase_start = app_shell.getTime();
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, true, start_line, rows, cols);
                    texture_kitty_ms += time_utils.secondsToMs(app_shell.getTime() - kitty_phase_start);
                }
            }
            r.endTerminalTexture();
            if (kitty_generation != self.kitty.last_generation) {
                self.kitty.last_generation = kitty_generation;
            }
            self.terminal_texture_ready = true;
            if (handoff_log.enabled_file or handoff_log.enabled_console) {
                handoff_log.logf(
                    .info,
                    "stage=widget_commit sid={x} last_render={d}->{d} cur={d} pub={d} presented={d} full={d} partial={d}",
                    .{
                        @intFromPtr(self.session),
                        self.last_render_generation,
                        cache.generation,
                        self.session.currentGeneration(),
                        self.session.publishedGeneration(),
                        self.session.presentedGeneration(),
                        @intFromBool(texture_full_update),
                        @intFromBool(texture_partial_update),
                    },
                );
            }
            self.last_render_generation = cache.generation;
            self.last_cell_w_i = cell_w_i;
            self.last_cell_h_i = cell_h_i;
            self.last_render_scale = r.render_scale;
            const base_x_i: i32 = @intFromFloat(std.math.round(base_x));
            const base_y_i: i32 = @intFromFloat(std.math.round(base_y));
            const clip_w_i: i32 = @min(@as(i32, @intFromFloat(std.math.round(width))), cell_w_i * @as(i32, @intCast(cols)));
            const clip_h_i: i32 = @min(@as(i32, @intFromFloat(std.math.round(height))), @as(i32, @intFromFloat(std.math.round(r.terminal_cell_height))) * @as(i32, @intCast(rows)));
            r.beginClip(
                base_x_i,
                base_y_i,
                clip_w_i,
                clip_h_i,
            );
            updated = true;
        }
        if (rows > 0 and cols > 0) {
            const bg = if (view_cells.len > 0) blk: {
                const cell = view_cells[0];
                const reversed = cell.attrs.reverse != screen_reverse;
                const base_bg = if (reversed) cell.attrs.fg else cell.attrs.bg;
                break :blk Color{
                    .r = base_bg.r,
                    .g = base_bg.g,
                    .b = base_bg.b,
                    .a = base_bg.a,
                };
            } else r.theme.background;
            r.drawRect(
                @intFromFloat(base_x),
                @intFromFloat(base_y),
                @intFromFloat(width),
                @intFromFloat(height),
                bg,
            );
        }
        r.drawTerminalTexture(base_x, base_y);
        if (target_probe_count > 0) {
            var probe_idx: usize = 0;
            while (probe_idx < target_probe_count) : (probe_idx += 1) {
                if (target_sample_log.enabled_file or target_sample_log.enabled_console) {
                    logTargetProbePhase(r, SilentTargetProbeLogger{}, .window, &target_probes[probe_idx], base_x, base_y, cell_w_i, cell_h_i);
                    logTargetProbeBandPhase(r, SilentTargetProbeLogger{}, .window, &target_probes[probe_idx], base_x, base_y, cell_w_i, cell_h_i);
                    logTargetProbeColumnBandPhase(r, SilentTargetProbeLogger{}, .window, &target_probes[probe_idx], base_x, base_y, cell_w_i, cell_h_i, rows);
                }
                if (row_render_log.enabled_file or row_render_log.enabled_console) {
                    logTargetProbePhase(r, row_render_log, .window, &target_probes[probe_idx], base_x, base_y, cell_w_i, cell_h_i);
                    logTargetProbeBandPhase(r, row_render_log, .window, &target_probes[probe_idx], base_x, base_y, cell_w_i, cell_h_i);
                    logTargetProbeColumnBandPhase(r, row_render_log, .window, &target_probes[probe_idx], base_x, base_y, cell_w_i, cell_h_i, rows);
                }
            }
        }
    }
    texture_update_ms = time_utils.secondsToMs(app_shell.getTime() - texture_phase_start);
    const overlay_phase_start = app_shell.getTime();
    if (!has_kitty and self.kitty.textures.count() > 0) {
        self.kitty.cleanupTextures(self.session.allocator, self.kitty.images_view.items);
    }
    var overlay_probe_set = draw_overlay.OverlayProbeSet{};
    if (target_probe_count > 0) {
        var probe_idx: usize = 0;
        while (probe_idx < target_probe_count) : (probe_idx += 1) {
            const probe = &target_probes[probe_idx];
            if (probe.bg2_present) {
                overlay_probe_set.append(.{
                    .kind = .bg2,
                    .row = probe.row,
                    .slot = -1,
                    .col = probe.bg2_col,
                    .codepoint = probe.bg2_codepoint,
                });
            }
            var sample_idx: usize = 0;
            while (sample_idx < probe.direct_samples.len) : (sample_idx += 1) {
                const sample = probe.direct_samples[sample_idx];
                if (!sample.present) continue;
                overlay_probe_set.append(.{
                    .kind = .direct,
                    .row = probe.row,
                    .slot = @as(isize, @intCast(sample_idx)),
                    .col = sample.col,
                    .codepoint = sample.codepoint,
                });
            }
        }
    }

    drawOverlays(
        self,
        shell,
        base_x,
        base_y,
        width,
        height,
        input,
        cache,
        view_cells,
        rows,
        cols,
        scroll_offset,
        total_lines,
        max_scroll_offset,
        screen_reverse,
        hover_link_id,
        draw_cursor,
        cursor,
        cursor_style,
        if (overlay_probe_set.count > 0) &overlay_probe_set else null,
    );
    if (target_probe_count > 0) {
        var probe_idx: usize = 0;
        while (probe_idx < target_probe_count) : (probe_idx += 1) {
            if (target_sample_log.enabled_file or target_sample_log.enabled_console) {
                logTargetProbePhase(r, SilentTargetProbeLogger{}, .final, &target_probes[probe_idx], base_x, base_y, cell_w_i, cell_h_i);
                logTargetProbeBandPhase(r, SilentTargetProbeLogger{}, .final, &target_probes[probe_idx], base_x, base_y, cell_w_i, cell_h_i);
                logTargetProbeColumnBandPhase(r, SilentTargetProbeLogger{}, .final, &target_probes[probe_idx], base_x, base_y, cell_w_i, cell_h_i, rows);
            }
            if (row_render_log.enabled_file or row_render_log.enabled_console) {
                logTargetProbePhase(r, row_render_log, .final, &target_probes[probe_idx], base_x, base_y, cell_w_i, cell_h_i);
                logTargetProbeBandPhase(r, row_render_log, .final, &target_probes[probe_idx], base_x, base_y, cell_w_i, cell_h_i);
                logTargetProbeColumnBandPhase(r, row_render_log, .final, &target_probes[probe_idx], base_x, base_y, cell_w_i, cell_h_i, rows);
            }
            registerPresentationProbes(r, &target_probes[probe_idx], base_x, base_y, cell_w_i, cell_h_i, rows);
        }
    }

    if (updated or cache.dirty == .none) {
        outcome.texture_updated = updated;
    }
    overlay_ms = time_utils.secondsToMs(app_shell.getTime() - overlay_phase_start);

    if (alt_exit) {
        outcome.alt_exit_info = .{
            .draw_ms = (app_shell.getTime() - draw_start_time) * 1000.0,
            .rows = rows,
            .cols = cols,
            .history_len = history_len,
            .scroll_offset = scroll_offset,
        };
    }

    const perf_log = app_logger.logger("terminal.ui.perf");
    const lifecycle_log = app_logger.logger("terminal.ui.lifecycle");
    const now = app_shell.getTime();
    const elapsed_ms = time_utils.secondsToMs(now - draw_start);
    const has_kitty_images = self.kitty.images_view.items.len > 0;
    const lifecycle_reason = if (!texture_ready_before_draw)
        "init"
    else if (alt_state_changed)
        (if (cache.alt_active) "alt_enter" else "alt_exit")
    else
        null;
    const active_draw_log = if (lifecycle_reason != null) lifecycle_log else draw_log;
    const active_perf_log = if (lifecycle_reason != null) lifecycle_log else perf_log;
    const log_partial_update = texture_partial_update and updated and (active_draw_log.enabled_file or active_draw_log.enabled_console or active_perf_log.enabled_file or active_perf_log.enabled_console);
    const current_reason = switch (cache.dirty) {
        .full => @tagName(cache.full_dirty_reason),
        .partial => if (cache.viewport_shift_rows != 0)
            (if (cache.viewport_shift_exposed_only) "viewport_shift_exposed" else "viewport_shift")
        else
            "partial",
        .none => "clean",
    };
    if ((elapsed_ms >= 4.0 or has_kitty_images or log_partial_update) and (now - self.last_draw_log_time) >= 0.1) {
        self.last_draw_log_time = now;
        active_draw_log.logf(
            .info,
            "draw_ms={d:.2} rows={d} cols={d} history={d} cells={d} kitty_images={d} kitty_placements={d}",
            .{
                elapsed_ms,
                rows,
                cols,
                history_len,
                rows * cols,
                self.kitty.images_view.items.len,
                self.kitty.placements_view.items.len,
            },
        );
        active_perf_log.logf(
            .info,
            "draw_ms={d:.2} lock_stats={s} texture_update_ms={d:.2} texture_bg_ms={d:.2} texture_glyph_ms={d:.2} texture_kitty_ms={d:.2} overlay_ms={d:.2} full={d} partial={d} updated={d} sync={d} clear_ok={d} dirty={s} current_reason={s} dirty_rows={d} damage_rows={d} damage_cols={d} plan_rows={d} plan_row_span={d} plan_col_span={d} plan_cells={d} plan_union_cells={d} blink_cells={d} blink_phase_changed={d} shift_rows={d} shift_exposed_only={d} sprite_stats={s} glyph_stats={s} rows={d} cols={d}",
            .{
                elapsed_ms,
                std.fmt.bufPrint(&lock_stats_summary_buf, "{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}", .{
                    lock_ms,
                    lock_wait_ms,
                    lock_hold_ms,
                    view_cache_ms,
                    cache_copy_ms,
                }) catch "overflow",
                texture_update_ms,
                texture_bg_ms,
                texture_glyph_ms,
                texture_kitty_ms,
                overlay_ms,
                @intFromBool(texture_full_update),
                @intFromBool(texture_partial_update),
                @intFromBool(updated),
                @intFromBool(sync_updates),
                @intFromBool(outcome.presented != null and (outcome.texture_updated or cache.dirty == .none)),
                @tagName(cache.dirty),
                current_reason,
                dirty_rows_count,
                damage_row_span,
                damage_col_span,
                partial_plan_rows_count,
                partial_plan_row_span,
                partial_plan_col_span,
                partial_plan_cells,
                partial_plan_union_cells,
                @intFromBool(has_blink),
                @intFromBool(blink_phase_changed),
                active_viewport_shift_rows,
                @intFromBool(active_shift_exposed_only),
                std.fmt.bufPrint(&sprite_stats_summary_buf, "{d}/{d}/{d}/{d:.2}", .{
                    glyph_draw_stats.special_sprite_cache_hits,
                    glyph_draw_stats.special_sprite_cache_misses,
                    glyph_draw_stats.special_sprite_creates,
                    glyph_draw_stats.special_sprite_lookup_ms,
                }) catch "overflow",
                std.fmt.bufPrint(&glyph_stats_summary_buf, "{d}/{d}/{d}/{d}/{d}/{d}/{d}/{d}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}", .{
                    glyph_draw_stats.shaping_spans,
                    glyph_draw_stats.shaped_glyphs,
                    glyph_draw_stats.fallback_cells,
                    glyph_draw_stats.special_sprite_glyphs,
                    glyph_draw_stats.box_glyphs,
                    glyph_draw_stats.shaped_text_glyphs,
                    glyph_draw_stats.shaped_special_glyphs,
                    glyph_draw_stats.shaped_space_skips,
                    glyph_draw_stats.shape_ms,
                    glyph_draw_stats.submit_ms,
                    glyph_draw_stats.shaped_text_submit_ms,
                    glyph_draw_stats.shaped_special_submit_ms,
                    glyph_draw_stats.special_sprite_submit_ms,
                    glyph_draw_stats.box_submit_ms,
                    glyph_draw_stats.box_sprite_submit_ms,
                    glyph_draw_stats.box_rect_submit_ms,
                    glyph_draw_stats.special_sprite_lookup_ms,
                    glyph_draw_stats.direct_lookup_ms,
                    glyph_draw_stats.direct_draw_ms,
                }) catch "overflow",
                rows,
                cols,
            },
        );
        if (partial_plan_summary.len > 0) {
            active_draw_log.logf(
                .debug,
                "partial_plan rows={d} row_span={d} col_span={d} spans={s}",
                .{
                    partial_plan_rows_count,
                    partial_plan_row_span,
                    partial_plan_col_span,
                    partial_plan_summary,
                },
            );
        }
    }

    if (self.bench_enabled) {
        const bench_log = app_logger.logger("terminal.ui.bench");
        if ((now - self.last_bench_log_time) >= 0.1) {
            self.last_bench_log_time = now;
            bench_log.logf(
                .info,
                "draw_ms={d:.2} rows={d} cols={d} upload_images={d} upload_bytes={d}",
                .{ elapsed_ms, rows, cols, upload_stats.images, upload_stats.bytes },
            );
        }
    }
    return outcome;
}

fn jitterDebugEnabled() bool {
    if (jitter_debug_enabled_cache) |cached| return cached;
    const raw = std.c.getenv("ZIDE_TERMINAL_FONT_JITTER");
    if (raw == null) {
        jitter_debug_enabled_cache = false;
        return false;
    }
    const value = std.mem.sliceTo(raw.?, 0);
    if (value.len == 0) {
        jitter_debug_enabled_cache = true;
        return true;
    }
    if (std.ascii.eqlIgnoreCase(value, "0") or
        std.ascii.eqlIgnoreCase(value, "false") or
        std.ascii.eqlIgnoreCase(value, "off") or
        std.ascii.eqlIgnoreCase(value, "no"))
    {
        jitter_debug_enabled_cache = false;
        return false;
    }
    jitter_debug_enabled_cache = true;
    return true;
}

test "viewport texture shift attempts only when fast path is eligible" {
    switch (planViewportTextureShift(true, true, 2, false, 0, false, true, 24)) {
        .attempt => |rows| try std.testing.expectEqual(@as(usize, 2), rows),
        else => return error.ExpectedShiftAttempt,
    }
}

test "viewport texture shift disable falls back to standard damage path" {
    const plan = planViewportTextureShift(false, true, 2, false, 0, false, true, 24);
    try std.testing.expectEqual(ViewportTextureShiftPlan.none, plan);
}

test "viewport texture shift oversize scroll falls back to standard damage path" {
    const plan = planViewportTextureShift(true, true, 24, false, 0, false, true, 24);
    try std.testing.expectEqual(ViewportTextureShiftPlan.none, plan);
}

test "viewport texture shift does not attempt while already forced full" {
    const plan = planViewportTextureShift(true, true, 2, false, 0, true, true, 24);
    try std.testing.expectEqual(ViewportTextureShiftPlan.none, plan);
}

test "viewport texture shift ignores scrollback view movement" {
    const plan = planViewportTextureShift(true, true, 2, false, 3, false, true, 24);
    try std.testing.expectEqual(ViewportTextureShiftPlan.none, plan);
}

test "viewport texture shift allows explicit scrollback remap path" {
    switch (planViewportTextureShift(true, true, 2, true, 3, false, true, 24)) {
        .attempt => |rows| try std.testing.expectEqual(@as(usize, 2), rows),
        else => return error.ExpectedShiftAttempt,
    }
}

test "texture update plan keeps partial redraws eligible while scrolled" {
    const plan = chooseTextureUpdatePlan(
        .partial,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
    );
    try std.testing.expect(!plan.needs_full);
    try std.testing.expect(plan.needs_partial);
}

test "texture update plan forces full redraw when texture is not ready" {
    const plan = chooseTextureUpdatePlan(
        .partial,
        false,
        false,
        false,
        false,
        false,
    );
    try std.testing.expect(plan.needs_full);
    try std.testing.expect(!plan.needs_partial);
}

test "texture update plan stays idle when dirty state is clean" {
    const plan = chooseTextureUpdatePlan(
        .none,
        false,
        false,
        false,
        true,
    );
    try std.testing.expect(!plan.needs_full);
    try std.testing.expect(!plan.needs_partial);
}

test "texture update plan keeps partial redraw for normal partial damage" {
    const plan = chooseTextureUpdatePlan(
        .partial,
        false,
        false,
        false,
        true,
    );
    try std.testing.expect(!plan.needs_full);
    try std.testing.expect(plan.needs_partial);
}

test "texture update plan uses partial redraw for blink-only changes" {
    const plan = chooseTextureUpdatePlan(
        .none,
        false,
        false,
        false,
        true,
        true,
    );
    try std.testing.expect(!plan.needs_full);
    try std.testing.expect(plan.needs_partial);
}

test "full-width partial plan marks every row" {
    var rows = [_]bool{ false, false, false };
    var cols_start = [_]u16{ 9, 9, 9 };
    var cols_end = [_]u16{ 0, 0, 0 };

    markAllRowsFullWidthPartialPlan(&rows, &cols_start, &cols_end, 3, 5);

    for (rows) |row_marked| {
        try std.testing.expect(row_marked);
    }
    for (cols_start) |start| {
        try std.testing.expectEqual(@as(u16, 0), start);
    }
    for (cols_end) |end| {
        try std.testing.expectEqual(@as(u16, 4), end);
    }
}
const planViewportTextureShift = draw_texture.planViewportTextureShift;
const useViewportShiftForPartialPlan = draw_texture.useViewportShiftForPartialPlan;
const chooseTextureUpdatePlan = draw_texture.chooseTextureUpdatePlan;
const forceFullTextureUpdatePlan = draw_texture.forceFullTextureUpdatePlan;
const forceFullTextureUpdatePlanEveryFrame = draw_texture.forceFullTextureUpdatePlanEveryFrame;
const buildPartialPlan = draw_texture.buildPartialPlan;
const markAllRowsFullWidthPartialPlan = draw_texture.markAllRowsFullWidthPartialPlan;

test "useViewportShiftForPartialPlan ignores stale shift metadata on clean frames" {
    try std.testing.expect(!useViewportShiftForPartialPlan(.none, 1));
    try std.testing.expect(!useViewportShiftForPartialPlan(.full, 1));
    try std.testing.expect(useViewportShiftForPartialPlan(.partial, 1));
}
