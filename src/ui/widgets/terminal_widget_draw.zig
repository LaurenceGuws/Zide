const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_publication = @import("../../terminal/core/terminal_publication.zig");
const render_cache_mod = @import("../../terminal/core/render_cache.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const time_utils = @import("../renderer/time_utils.zig");
const terminal_font_mod = @import("../terminal_font.zig");
const draw_grid = @import("terminal_widget_draw_grid.zig");
const draw_overlay = @import("terminal_widget_draw_overlay.zig");
const draw_texture = @import("terminal_widget_draw_texture.zig");

const hover_mod = @import("terminal_widget_hover.zig");
const kitty_mod = @import("terminal_widget_kitty.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = terminal_publication.CursorPos;
const Cell = terminal_publication.Cell;
const Rgba = terminal_font_mod.Rgba;

const RenderCache = render_cache_mod.RenderCache;
const PresentationCapture = terminal_publication.PresentationCapture;
const PresentedRenderCache = terminal_publication.PresentedRenderCache;
const PresentationFeedback = terminal_publication.PresentationFeedback;
var frame_latency_seq: u64 = 0;
var frame_latency_metrics: FrameLatencyMetrics = .{};
var capture_burst_seq: u64 = 0;
var capture_burst_frames_remaining: u32 = 0;

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
const FullFrameFastPathDecision = draw_texture.FullFrameFastPathDecision;
const PartialPlanBounds = draw_texture.PartialPlanBounds;
const max_frame_generation_buckets = 8;

const GenerationBucket = struct {
    generation: u64,
    count: usize,
};

const PresentedGenerationSummary = struct {
    min_generation: u64 = 0,
    max_generation: u64 = 0,
    modal_generation: u64 = 0,
    modal_count: usize = 0,
    non_modal_count: usize = 0,
    bbox_present: bool = false,
    row_min: usize = 0,
    row_max: usize = 0,
    col_min: usize = 0,
    col_max: usize = 0,
};

const RowContentSummary = struct {
    row: usize,
    occupied: usize,
    first_col: i32,
    last_col: i32,
    hash: u64,
};

const PartialPlanSummary = struct {
    rows_count: usize = 0,
    row_span: usize = 0,
    col_span: usize = 0,
    cells: usize = 0,
    union_cells: usize = 0,
    summary: []const u8 = "",
};

const DrawTelemetry = struct {
    texture_full_update: bool = false,
    texture_partial_update: bool = false,
    fastpath_threshold_hit: bool = false,
    fastpath_total_cells: usize = 0,
    fastpath_union_cells: usize = 0,
    capture_reason: []const u8 = "clean",
};

const ViewportShiftState = struct {
    rows: i32 = 0,
    exposed_only: bool = false,
};

const PresentPressureState = struct {
    force_recent_window: bool,
    recent_window_seconds: f64,
    modifier_pressure_active: bool,
    recent_input_age_s: f64,
    recent_input_window_active: bool,
    plan_was_active: bool,
};

const HandoffState = struct {
    last_render_generation: u64,
    pending_generation: u64,
    published_generation: u64,
    presented_generation: u64,
};

const DrawLogBuffers = struct {
    partial_plan_summary_buf: [256]u8 = undefined,
    glyph_stats_summary_buf: [220]u8 = undefined,
    glyph_batch_summary_buf: [96]u8 = undefined,
    glyph_atlas_summary_buf: [96]u8 = undefined,
    sprite_stats_summary_buf: [48]u8 = undefined,
    lock_stats_summary_buf: [64]u8 = undefined,
};

const DrawLoggers = struct {
    redraw: @TypeOf(app_logger.logger("terminal.ui.redraw")),
    texture_shift: @TypeOf(app_logger.logger("terminal.ui.texture_shift")),
    row_render: @TypeOf(app_logger.logger("terminal.ui.row_render_pass")),
    row_render_runs: @TypeOf(app_logger.logger("terminal.ui.row_render_pass_runs")),
    perf: @TypeOf(app_logger.logger("terminal.ui.perf")),
    lifecycle: @TypeOf(app_logger.logger("terminal.ui.lifecycle")),
    pressure: @TypeOf(app_logger.logger("terminal.ui.present_pressure")),
    handoff: @TypeOf(app_logger.logger("terminal.generation_handoff")),
};

pub fn latestFrameLatencyMetrics() FrameLatencyMetrics {
    return frame_latency_metrics;
}

pub fn armCaptureBurst(frames: u32) u64 {
    capture_burst_seq +%= 1;
    capture_burst_frames_remaining = frames;
    return capture_burst_seq;
}

fn maybeLogCaptureBurst(
    self: anytype,
    shell: *Shell,
    cache: *const RenderCache,
    width: f32,
    height: f32,
    viewport_w: f32,
    viewport_h: f32,
    visible_w: i32,
    visible_h: i32,
    rows: usize,
    cols: usize,
    full: bool,
    partial: bool,
    viewport_shift_rows: i32,
    threshold_hit: bool,
    fast_total_cells: usize,
    fast_union_cells: usize,
    partial_plan_cells: usize,
    partial_plan_union_cells: usize,
    current_reason: []const u8,
    glyph_draw_stats: GlyphDrawStats,
) void {
    if (capture_burst_frames_remaining == 0) return;
    const log = app_logger.logger("terminal.capture_trigger");
    const r = shell.rendererPtr();
    const geom = r.terminalCellGeometry();
    const glyph_frame = r.terminal_glyph_cache.frameMetrics();
    const atlas_frame = r.terminal_font.frameAtlasStats();
    const generation_summary = summarizePresentedGeneration(self, cache);
    var glyph_summary_buf: [96]u8 = undefined;
    var batch_summary_buf: [64]u8 = undefined;
    var atlas_summary_buf: [64]u8 = undefined;
    var provenance_summary_buf: [128]u8 = undefined;
    var row_summary_buf: [256]u8 = undefined;
    const glyph_summary = std.fmt.bufPrint(&glyph_summary_buf, "d:{d} s:{d} st:{d} sp:{d} b:{d} f:{d}", .{
        glyph_draw_stats.direct_text_glyphs,
        glyph_draw_stats.shaped_glyphs,
        glyph_draw_stats.shaped_text_glyphs,
        glyph_draw_stats.special_sprite_glyphs,
        glyph_draw_stats.box_glyphs,
        glyph_draw_stats.fallback_cells,
    }) catch "overflow";
    const batch_summary = std.fmt.bufPrint(&batch_summary_buf, "{d}/{d}/{d}/{d}", .{
        glyph_frame.quad_count,
        glyph_frame.flush_count,
        glyph_frame.draw_call_count,
        glyph_frame.vertex_count,
    }) catch "overflow";
    const atlas_summary = std.fmt.bufPrint(&atlas_summary_buf, "{d}/{d}/{d}", .{
        atlas_frame.glyph_cache_hits,
        atlas_frame.glyph_cache_misses,
        atlas_frame.rasterized_glyphs,
    }) catch "overflow";
    const provenance_summary = std.fmt.bufPrint(&provenance_summary_buf, "m:{d}:{d} min:{d} max:{d} non:{d} bbox:{d}:{d}..{d}/{d}..{d}", .{
        generation_summary.modal_generation,
        generation_summary.modal_count,
        generation_summary.min_generation,
        generation_summary.max_generation,
        generation_summary.non_modal_count,
        @intFromBool(generation_summary.bbox_present),
        generation_summary.row_min,
        generation_summary.row_max,
        generation_summary.col_min,
        generation_summary.col_max,
    }) catch "overflow";
    const row_summary = formatTopRowContentSummary(&row_summary_buf, cache, @min(rows, @as(usize, 6)));
    const visible_cols: i32 = if (geom.cell_width_logical_exact > 0) @intFromFloat(std.math.floor(@max(viewport_w, 0) / geom.cell_width_logical_exact)) else 0;
    const visible_rows: i32 = if (geom.cell_height_logical_exact > 0) @intFromFloat(std.math.floor(@max(viewport_h, 0) / geom.cell_height_logical_exact)) else 0;
    log.logf(
        .info,
        "capture_burst seq={d} frames_left={d} gen={d} rows={d} cols={d} widget={d:.1}x{d:.1} viewport={d:.1}x{d:.1} visible_px={d}x{d} visible_cells={d}x{d} cell_dev={d}x{d} full={d} partial={d} shift_rows={d} threshold_hit={d} fast_total_cells={d} fast_union_cells={d} plan_cells={d} plan_union_cells={d} reason={s} glyphs={s} batch={s} atlas={s} prov={s} rowsum={s} texture_ready={d} last_render_gen={d}",
        .{
            capture_burst_seq,
            capture_burst_frames_remaining,
            cache.generation,
            rows,
            cols,
            width,
            height,
            viewport_w,
            viewport_h,
            visible_w,
            visible_h,
            visible_cols,
            visible_rows,
            geom.cell_width_device_px,
            geom.cell_height_device_px,
            @intFromBool(full),
            @intFromBool(partial),
            viewport_shift_rows,
            @intFromBool(threshold_hit),
            fast_total_cells,
            fast_union_cells,
            partial_plan_cells,
            partial_plan_union_cells,
            current_reason,
            glyph_summary,
            batch_summary,
            atlas_summary,
            provenance_summary,
            row_summary,
            @intFromBool(self.terminal_texture_ready),
            self.last_render_generation,
        },
    );
    capture_burst_frames_remaining -= 1;
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

fn toShellColor(color: terminal_publication.Color) Color {
    return .{ .r = color.r, .g = color.g, .b = color.b, .a = color.a };
}

fn spansOverlap(start_a: usize, end_a: usize, start_b: usize, end_b: usize) bool {
    return start_a <= end_b and start_b <= end_a;
}

fn rowSlice(cells: []const Cell, cols_count: usize, row: usize) []const Cell {
    const row_start = row * cols_count;
    if (row_start + cols_count > cells.len) return cells[0..0];
    return cells[row_start .. row_start + cols_count];
}

const ColumnProbe = struct {
    col: usize,
    top_row: i32,
    bottom_row: i32,
    occupied: usize,
    hash: u64,
};

fn samplePresentedColumn(cells: []const Cell, rows: usize, cols: usize, col: usize) ColumnProbe {
    if (rows == 0 or cols == 0 or col >= cols or cells.len < rows * cols) {
        return .{ .col = col, .top_row = -1, .bottom_row = -1, .occupied = 0, .hash = 0 };
    }

    var top_row: i32 = -1;
    var bottom_row: i32 = -1;
    var occupied: usize = 0;
    var hash = std.hash.Wyhash.init(0);

    var row: usize = 0;
    while (row < rows) : (row += 1) {
        const cell = cells[row * cols + col];
        const cp: u32 = cell.codepoint;
        hash.update(std.mem.asBytes(&cp));
        if (cp != ' ') {
            occupied += 1;
            if (top_row < 0) top_row = @intCast(row);
            bottom_row = @intCast(row);
        }
    }

    return .{
        .col = col,
        .top_row = top_row,
        .bottom_row = bottom_row,
        .occupied = occupied,
        .hash = hash.final(),
    };
}

fn logPresentedColumnProbe(cache: *const RenderCache) void {
    const log = app_logger.logger("terminal.column_probe");
    if (!log.enabled_file and !log.enabled_console) return;
    if (cache.rows == 0 or cache.cols == 0) return;
    if (cache.cells.items.len < cache.rows * cache.cols) return;

    const sample_cols = [_]usize{ 58, 59, 60, 61, 62, 178, 179, 180, 181, 182 };
    var buf: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();
    var first = true;

    for (sample_cols) |raw_col| {
        const col = if (cache.cols == 0) 0 else @min(raw_col, cache.cols - 1);
        const probe = samplePresentedColumn(cache.cells.items, cache.rows, cache.cols, col);
        if (!first) writer.writeAll(" ") catch return;
        first = false;
        writer.print(
            "c{d}=t{d}:b{d}:o{d}:h{x}",
            .{ probe.col, probe.top_row, probe.bottom_row, probe.occupied, probe.hash },
        ) catch return;
    }

    log.logf(
        .info,
        "gen={d} rows={d} cols={d} {s}",
        .{ cache.generation, cache.rows, cache.cols, fbs.getWritten() },
    );
}

fn ensurePresentedGenerationCells(self: anytype, rows: usize, cols: usize) !void {
    const total = rows * cols;
    try self.presented_generation_cells.resize(self.session.allocator, total);
}

fn fillPresentedGenerationCells(self: anytype, rows: usize, cols: usize, generation: u64) void {
    const total = rows * cols;
    if (self.presented_generation_cells.items.len < total) return;
    @memset(self.presented_generation_cells.items[0..total], generation);
}

fn markPresentedGenerationRowRange(self: anytype, rows: usize, cols: usize, row: usize, col_start: usize, col_end: usize, generation: u64) void {
    if (row >= rows or cols == 0 or self.presented_generation_cells.items.len < rows * cols) return;
    const start = @min(col_start, cols - 1);
    const end = @min(col_end, cols - 1);
    if (end < start) return;
    const row_offset = row * cols;
    @memset(self.presented_generation_cells.items[row_offset + start .. row_offset + end + 1], generation);
}

fn shiftPresentedGenerationCells(self: anytype, rows: usize, cols: usize, viewport_shift_rows: i32) void {
    if (rows == 0 or cols == 0 or viewport_shift_rows == 0) return;
    const total = rows * cols;
    if (self.presented_generation_cells.items.len < total) return;
    const abs_shift: usize = @intCast(@abs(viewport_shift_rows));
    if (abs_shift == 0 or abs_shift >= rows) return;
    const row_width = cols;
    if (viewport_shift_rows > 0) {
        var row: usize = 0;
        while (row + abs_shift < rows) : (row += 1) {
            const dst = row * row_width;
            const src = (row + abs_shift) * row_width;
            std.mem.copyForwards(u64, self.presented_generation_cells.items[dst .. dst + row_width], self.presented_generation_cells.items[src .. src + row_width]);
        }
    } else {
        var row: usize = rows - abs_shift;
        while (true) {
            const dst = (row + abs_shift) * row_width;
            const src = row * row_width;
            std.mem.copyBackwards(u64, self.presented_generation_cells.items[dst .. dst + row_width], self.presented_generation_cells.items[src .. src + row_width]);
            if (row == 0) break;
            row -= 1;
        }
    }
}

fn insertGenerationBucket(buckets: *[max_frame_generation_buckets]GenerationBucket, bucket_count: *usize, generation: u64) void {
    var idx: usize = 0;
    while (idx < bucket_count.*) : (idx += 1) {
        if (buckets[idx].generation == generation) {
            buckets[idx].count += 1;
            return;
        }
    }
    if (bucket_count.* < buckets.len) {
        buckets[bucket_count.*] = .{ .generation = generation, .count = 1 };
        bucket_count.* += 1;
        return;
    }
    buckets[buckets.len - 1].count += 1;
}

fn logPresentedGenerationProvenance(self: anytype, cache: *const RenderCache) void {
    const log = app_logger.logger("terminal.frame_provenance");
    if (!log.enabled_file and !log.enabled_console) return;
    const summary = summarizePresentedGeneration(self, cache);
    log.logf(
        .info,
        "presented_gen={d} frame_mode={d} min={d} max={d} total_cells={d} modal_cells={d} non_modal_cells={d} per_gen={s} bbox_present={d} bbox={d}..{d}/{d}..{d} damage={d}..{d}/{d}..{d}",
        .{
            cache.generation,
            summary.modal_generation,
            summary.min_generation,
            summary.max_generation,
            cache.rows * cache.cols,
            summary.modal_count,
            summary.non_modal_count,
            blk: {
                const rows = cache.rows;
                const cols = cache.cols;
                const total = rows * cols;
                var buckets: [max_frame_generation_buckets]GenerationBucket = undefined;
                var bucket_count: usize = 0;
                var idx_fill: usize = 0;
                while (idx_fill < total) : (idx_fill += 1) {
                    insertGenerationBucket(&buckets, &bucket_count, self.presented_generation_cells.items[idx_fill]);
                }
                var bucket_buf: [192]u8 = undefined;
                var stream = std.io.fixedBufferStream(&bucket_buf);
                const writer = stream.writer();
                var idx: usize = 0;
                while (idx < bucket_count) : (idx += 1) {
                    if (idx > 0) writer.writeAll(" ") catch break;
                    writer.print("{d}:{d}", .{ buckets[idx].generation, buckets[idx].count }) catch break;
                }
                break :blk stream.getWritten();
            },
            @intFromBool(summary.bbox_present),
            if (summary.bbox_present) summary.row_min else 0,
            if (summary.bbox_present) summary.row_max else 0,
            if (summary.bbox_present) summary.col_min else 0,
            if (summary.bbox_present) summary.col_max else 0,
            cache.damage.start_row,
            cache.damage.end_row,
            cache.damage.start_col,
            cache.damage.end_col,
        },
    );
}

fn summarizePresentedGeneration(self: anytype, cache: *const RenderCache) PresentedGenerationSummary {
    const rows = cache.rows;
    const cols = cache.cols;
    const total = rows * cols;
    if (rows == 0 or cols == 0 or self.presented_generation_cells.items.len < total) return .{};

    var min_generation: u64 = std.math.maxInt(u64);
    var max_generation: u64 = 0;
    var buckets: [max_frame_generation_buckets]GenerationBucket = undefined;
    var bucket_count: usize = 0;
    var modal_generation: u64 = 0;
    var modal_count: usize = 0;

    var row_min: usize = rows;
    var row_max: usize = 0;
    var col_min: usize = cols;
    var col_max: usize = 0;
    var non_modal_count: usize = 0;

    for (self.presented_generation_cells.items[0..total]) |generation| {
        min_generation = @min(min_generation, generation);
        max_generation = @max(max_generation, generation);
        insertGenerationBucket(&buckets, &bucket_count, generation);
    }
    var idx: usize = 0;
    while (idx < bucket_count) : (idx += 1) {
        if (buckets[idx].count > modal_count) {
            modal_count = buckets[idx].count;
            modal_generation = buckets[idx].generation;
        }
    }

    var row: usize = 0;
    while (row < rows) : (row += 1) {
        var col: usize = 0;
        while (col < cols) : (col += 1) {
            const generation = self.presented_generation_cells.items[row * cols + col];
            if (generation == modal_generation) continue;
            non_modal_count += 1;
            row_min = @min(row_min, row);
            row_max = @max(row_max, row);
            col_min = @min(col_min, col);
            col_max = @max(col_max, col);
        }
    }

    const bbox_present = non_modal_count > 0 and row_min < rows and col_min < cols;
    return .{
        .min_generation = if (min_generation == std.math.maxInt(u64)) 0 else min_generation,
        .max_generation = max_generation,
        .modal_generation = modal_generation,
        .modal_count = modal_count,
        .non_modal_count = non_modal_count,
        .bbox_present = bbox_present,
        .row_min = if (bbox_present) row_min else 0,
        .row_max = if (bbox_present) row_max else 0,
        .col_min = if (bbox_present) col_min else 0,
        .col_max = if (bbox_present) col_max else 0,
    };
}

fn summarizeRowContent(cache: *const RenderCache, row: usize) RowContentSummary {
    if (row >= cache.rows or cache.cols == 0 or cache.cells.items.len < cache.rows * cache.cols) {
        return .{ .row = row, .occupied = 0, .first_col = -1, .last_col = -1, .hash = 0 };
    }
    const cells = rowSlice(cache.cells.items, cache.cols, row);
    var occupied: usize = 0;
    var first_col: i32 = -1;
    var last_col: i32 = -1;
    var hash = std.hash.Wyhash.init(0);
    for (cells, 0..) |cell, col| {
        const cp = cell.codepoint;
        hash.update(std.mem.asBytes(&cp));
        if (cp != ' ' and cp != 0) {
            occupied += 1;
            if (first_col < 0) first_col = @intCast(col);
            last_col = @intCast(col);
        }
    }
    return .{
        .row = row,
        .occupied = occupied,
        .first_col = first_col,
        .last_col = last_col,
        .hash = hash.final(),
    };
}

fn formatTopRowContentSummary(buf: []u8, cache: *const RenderCache, row_count: usize) []const u8 {
    if (row_count == 0) return "";
    var stream = std.io.fixedBufferStream(buf);
    const writer = stream.writer();
    var row: usize = 0;
    while (row < row_count and row < cache.rows) : (row += 1) {
        const summary = summarizeRowContent(cache, row);
        if (row > 0) writer.writeAll(" ") catch break;
        writer.print("r{d}={d}:{d}..{d}:h{x}", .{
            summary.row,
            summary.occupied,
            summary.first_col,
            summary.last_col,
            summary.hash,
        }) catch break;
    }
    return stream.getWritten();
}

fn partialPlanTouchesCell(self: anytype, row: usize, col: usize) bool {
    if (row >= self.partial_draw_rows.items.len or !self.partial_draw_rows.items[row]) return false;
    if (row < self.partial_draw_span_counts.items.len and row < self.partial_draw_spans.items.len and self.partial_draw_span_counts.items[row] > 0) {
        var span_idx: usize = 0;
        while (span_idx < self.partial_draw_span_counts.items[row]) : (span_idx += 1) {
            const span = self.partial_draw_spans.items[row][span_idx];
            if (col >= span.start and col <= span.end) return true;
        }
        return false;
    }
    if (row >= self.partial_draw_cols_start.items.len or row >= self.partial_draw_cols_end.items.len) return false;
    return col >= self.partial_draw_cols_start.items[row] and col <= self.partial_draw_cols_end.items[row];
}

fn partialWouldPreserveOlderGeneration(self: anytype, rows: usize, cols: usize, target_generation: u64) bool {
    const total = rows * cols;
    if (rows == 0 or cols == 0 or self.presented_generation_cells.items.len < total) return false;
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        var col: usize = 0;
        while (col < cols) : (col += 1) {
            if (partialPlanTouchesCell(self, row, col)) continue;
            if (self.presented_generation_cells.items[row * cols + col] != target_generation) return true;
        }
    }
    return false;
}

fn summarizePartialPlan(
    self: anytype,
    rows: usize,
    cols: usize,
    generation: u64,
    partial_plan_bounds: ?PartialPlanBounds,
    draw_log_enabled: bool,
    texture_partial_update: bool,
    summary_buf: []u8,
) PartialPlanSummary {
    var summary = PartialPlanSummary{};

    for (self.partial_draw_rows.items) |row_draw| {
        if (row_draw) summary.rows_count += 1;
    }
    for (self.partial_draw_rows.items, 0..) |row_draw, row| {
        if (!row_draw) continue;
        if (row < self.partial_draw_span_counts.items.len and row < self.partial_draw_spans.items.len and self.partial_draw_span_counts.items[row] > 0) {
            var span_idx: usize = 0;
            while (span_idx < self.partial_draw_span_counts.items[row]) : (span_idx += 1) {
                const span = self.partial_draw_spans.items[row][span_idx];
                const row_start = @as(usize, span.start);
                const row_end = @as(usize, span.end);
                if (row_end >= row_start) summary.cells += row_end - row_start + 1;
                markPresentedGenerationRowRange(self, rows, cols, row, row_start, row_end, generation);
            }
        } else {
            const row_start = @as(usize, self.partial_draw_cols_start.items[row]);
            const row_end = @as(usize, self.partial_draw_cols_end.items[row]);
            if (row_end >= row_start) summary.cells += row_end - row_start + 1;
            markPresentedGenerationRowRange(self, rows, cols, row, row_start, row_end, generation);
        }
    }
    if (partial_plan_bounds) |bounds| {
        summary.row_span = bounds.end_row - bounds.start_row + 1;
        summary.col_span = bounds.end_col - bounds.start_col + 1;
        summary.union_cells = summary.row_span * summary.col_span;
    }
    if (draw_log_enabled and texture_partial_update) {
        summary.summary = draw_texture.formatPartialPlanRows(
            summary_buf,
            self.partial_draw_rows.items,
            self.partial_draw_span_counts.items,
            self.partial_draw_spans.items,
            self.partial_draw_cols_start.items,
            self.partial_draw_cols_end.items,
            12,
        );
    }
    return summary;
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
            terminal_publication.drawStateInfo(&self.draw_cache).generation,
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
    const lifecycle_transition = terminal_publication.lifecycleTransitionInfo(self.last_alt_active, cache);
    const alt_exit = lifecycle_transition.exited;
    self.last_alt_active = lifecycle_transition.current_alt_active;
    render_phase_start = app_shell.getTime();

    const draw_state = terminal_publication.drawStateInfo(cache);
    const render_state = draw_state.render;
    const sync_updates = draw_state.sync_updates_active;
    const screen_reverse = render_state.screen_reverse;
    const blink_style = self.blink_style;
    const blink_time = app_shell.getTime();
    const rows = draw_state.rows;
    const cols = draw_state.cols;
    const view_cells = draw_state.cells;
    const base_colors = terminal_publication.baseColorInfo(cache);
    if (sync_updates and view_cells.len > 0) {
        const bg_color = if (view_cells.len > 0) toShellColor(base_colors.resolved_background) else r.theme.background;
        r.drawRect(
            @intFromFloat(x),
            @intFromFloat(y),
            @intFromFloat(width),
            @intFromFloat(height),
            bg_color,
        );
        r.drawTerminalTexture(x, y, width, height);
        return outcome;
    }
    const draw_start_time = if (alt_exit) app_shell.getTime() else 0;
    const viewport = draw_state.viewport;
    const history_len = viewport.history_len;
    const scroll_offset = viewport.scroll_offset;
    const start_line = viewport.start_line;
    var draw_cursor = render_state.draw_cursor_visible;
    const cursor = if (draw_cursor) draw_state.cursor else CursorPos{ .row = rows + 1, .col = cols + 1 };
    const cursor_style = render_state.cursor_style;
    if (draw_cursor and self.ui_focused and cursor_style.blink) {
        if (blink_time >= self.cursor_blink_pause_until) {
            const period: f64 = 0.5;
            const phase = @mod(blink_time, period * 2.0);
            draw_cursor = phase < period;
        }
    }
    const kitty_generation = draw_state.kitty_generation;
    const has_blink = blink_style != .off and render_state.has_blinking_cells;
    const blink_phase_changed = self.blink_phase_changed_pending;
    self.blink_phase_changed_pending = false;
    const blink_requires_partial = has_blink and blink_phase_changed;

    self.kitty.updateViews(self.session.allocator, rows, cols, draw_state.kitty_images, draw_state.kitty_placements);

    var upload_stats: kitty_mod.KittyState.UploadStats = .{};
    if (self.kitty.images_view.items.len > 0) {
        self.kitty.primeUploads(self.session.allocator);
        upload_stats = self.kitty.processPendingUploads(shell);
    }

    const logs = DrawLoggers{
        .redraw = app_logger.logger("terminal.ui.redraw"),
        .texture_shift = app_logger.logger("terminal.ui.texture_shift"),
        .row_render = app_logger.logger("terminal.ui.row_render_pass"),
        .row_render_runs = app_logger.logger("terminal.ui.row_render_pass_runs"),
        .perf = app_logger.logger("terminal.ui.perf"),
        .lifecycle = app_logger.logger("terminal.ui.lifecycle"),
        .pressure = app_logger.logger("terminal.ui.present_pressure"),
        .handoff = app_logger.logger("terminal.generation_handoff"),
    };
    const dirty_summary = terminal_publication.dirtySummary(cache);
    var partial_plan_rows_count: usize = 0;
    var partial_plan_row_span: usize = 0;
    var partial_plan_col_span: usize = 0;
    var partial_plan_cells: usize = 0;
    var partial_plan_union_cells: usize = 0;
    var partial_plan_summary: []const u8 = "";
    var log_buffers = DrawLogBuffers{};
    var fullframe_fastpath_decision: FullFrameFastPathDecision = .{};
    const has_kitty = self.kitty.hasKitty();
    const bg_color = if (view_cells.len > 0) toShellColor(base_colors.background) else r.theme.background;
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

    self.hover.dirty = false;
    const hover_link_id = hover_mod.hoverLinkId(&self.hover);

    var updated = false;
    var telemetry = DrawTelemetry{};
    var viewport_shift = ViewportShiftState{};
    var handoff_state = HandoffState{
        .last_render_generation = self.last_render_generation,
        .pending_generation = 0,
        .published_generation = 0,
        .presented_generation = 0,
    };
    var cell_w_i: i32 = 0;
    var cell_h_i: i32 = 0;
    var visible_w: i32 = 0;
    var visible_h: i32 = 0;
    var viewport_w: f32 = 0;
    var viewport_h: f32 = 0;
    const texture_phase_start = app_shell.getTime();
    const texture_ready_before_draw = self.terminal_texture_ready;
    if (rows > 0 and cols > 0) {
        ensurePresentedGenerationCells(self, rows, cols) catch |err| {
            const provenance_log = app_logger.logger("terminal.frame_provenance");
            provenance_log.logf(.warning, "presented_generation_cells resize failed rows={d} cols={d} err={s}", .{ rows, cols, @errorName(err) });
        };
        const geom = r.terminalCellGeometry();
        cell_w_i = geom.cell_width_device_px;
        cell_h_i = geom.cell_height_device_px;
        const cell_metrics_changed = cell_w_i != self.last_cell_w_i or cell_h_i != self.last_cell_h_i;
        const render_scale_changed = r.render_scale != self.last_render_scale;
        const padding_x_i: i32 = @max(2, @divTrunc(cell_w_i, 2));
        const scale = if (r.render_scale > 0.0) r.render_scale else 1.0;
        const texture_w = @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(cell_w_i * @as(i32, @intCast(cols)) + padding_x_i)) / scale)));
        const texture_h = @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(cell_h_i * @as(i32, @intCast(rows)))) / scale)));
        const clip_w = @min(width, geom.cell_width_logical_exact * @as(f32, @floatFromInt(cols)));
        const clip_h = @min(height, geom.cell_height_logical_exact * @as(f32, @floatFromInt(rows)));
        const visible_cols: i32 = if (geom.cell_width_logical_exact > 0) @intFromFloat(std.math.floor(clip_w / geom.cell_width_logical_exact)) else 0;
        const visible_rows: i32 = if (geom.cell_height_logical_exact > 0) @intFromFloat(std.math.floor(clip_h / geom.cell_height_logical_exact)) else 0;
        visible_w = @intFromFloat(std.math.round(@as(f32, @floatFromInt(visible_cols * geom.cell_width_device_px)) / scale));
        visible_h = @intFromFloat(std.math.round(@as(f32, @floatFromInt(visible_rows * geom.cell_height_device_px)) / scale));
        viewport_w = @as(f32, @floatFromInt(visible_w));
        viewport_h = @as(f32, @floatFromInt(visible_h));
        const recreated = r.ensureTerminalTexture(texture_w, texture_h);
        const gen_changed = draw_state.generation != self.last_render_generation;
        const clear_generation_changed = draw_state.clear_generation != self.last_render_clear_generation;
        var update_plan = chooseTextureUpdatePlan(
            cache.dirty,
            recreated,
            clear_generation_changed,
            cell_metrics_changed,
            render_scale_changed,
            blink_requires_partial,
            self.terminal_texture_ready,
        );
        var pressure_state = PresentPressureState{
            .force_recent_window = r.forceFullTerminalTexturePublicationRecentInputWindow(),
            .recent_window_seconds = r.fullTerminalTexturePublicationRecentInputWindowSeconds(),
            .modifier_pressure_active = input.mods.ctrl or input.mods.shift or input.mods.alt or input.mods.super,
            .recent_input_age_s = -1.0,
            .recent_input_window_active = false,
            .plan_was_active = false,
        };
        const plan_time = app_shell.getTime();
        pressure_state.recent_input_age_s = if (self.last_terminal_input_time > 0 and plan_time >= self.last_terminal_input_time)
            plan_time - self.last_terminal_input_time
        else
            -1.0;
        pressure_state.recent_input_window_active = pressure_state.force_recent_window and
            (pressure_state.modifier_pressure_active or
                (self.last_terminal_input_time > 0 and
                    pressure_state.recent_input_age_s >= 0 and
                    pressure_state.recent_input_age_s <= pressure_state.recent_window_seconds));
        update_plan = forceFullTextureUpdatePlanEveryFrame(
            update_plan,
            pressure_state.recent_input_window_active,
        );
        pressure_state.plan_was_active = update_plan.needs_full or update_plan.needs_partial;
        handoff_state.pending_generation = self.session.pendingGeneration();
        handoff_state.published_generation = self.session.publishedGeneration();
        handoff_state.presented_generation = self.session.presentedGeneration();
        if ((logs.pressure.enabled_file or logs.pressure.enabled_console) and
            (pressure_state.plan_was_active or gen_changed or pressure_state.recent_input_window_active or pressure_state.modifier_pressure_active))
        {
            logs.pressure.logf(
                .info,
                "gen_changed={d} pub_gen={d}->{d} texture_ready={d} recreated={d} plan_active={d} plan_full={d} plan_partial={d} recent_cfg={d} recent_active={d} recent_age_ms={d:.2} recent_window_ms={d:.2} modifier={d}",
                .{
                    @intFromBool(gen_changed),
                    self.last_render_generation,
                    draw_state.generation,
                    @intFromBool(texture_ready_before_draw),
                    @intFromBool(recreated),
                    @intFromBool(pressure_state.plan_was_active),
                    @intFromBool(update_plan.needs_full),
                    @intFromBool(update_plan.needs_partial),
                    @intFromBool(pressure_state.force_recent_window),
                    @intFromBool(pressure_state.recent_input_window_active),
                    if (pressure_state.recent_input_age_s >= 0) pressure_state.recent_input_age_s * 1000.0 else -1.0,
                    pressure_state.recent_window_seconds * 1000.0,
                    @intFromBool(pressure_state.modifier_pressure_active),
                },
            );
        }
        if ((logs.handoff.enabled_file or logs.handoff.enabled_console) and
            (gen_changed or pressure_state.plan_was_active or update_plan.needs_full or update_plan.needs_partial))
        {
            logs.handoff.logf(
                .info,
                "stage=widget_plan sid={x} last_render={d} cache_gen={d} cur={d} pub={d} presented={d} gen_changed={d} plan_full={d} plan_partial={d} texture_ready={d}",
                .{
                    @intFromPtr(self.session),
                    handoff_state.last_render_generation,
                    draw_state.generation,
                    handoff_state.pending_generation,
                    handoff_state.published_generation,
                    handoff_state.presented_generation,
                    @intFromBool(gen_changed),
                    @intFromBool(update_plan.needs_full),
                    @intFromBool(update_plan.needs_partial),
                    @intFromBool(texture_ready_before_draw),
                },
            );
        }
        var needs_full = update_plan.needs_full;
        var needs_partial = update_plan.needs_partial;
        const partial_capture = terminal_publication.partialCaptureInfo(cache);
        viewport_shift.rows = partial_capture.active_viewport_shift_rows;
        viewport_shift.exposed_only = partial_capture.shift_exposed_only;
        telemetry.capture_reason = partial_capture.reason;
        var shifted_rows: usize = 0;
        var shift_requires_fullwidth_partial = false;
        switch (planViewportTextureShift(
            r.terminalTextureShiftEnabled(),
            gen_changed,
            viewport_shift.rows,
            viewport_shift.exposed_only,
            scroll_offset,
            needs_full,
            self.terminal_texture_ready,
            rows,
        )) {
            .attempt => |shift_rows| {
                const dy_pixels: i32 = -viewport_shift.rows * cell_h_i;
                if (r.scrollTerminalTexture(0, dy_pixels)) {
                    needs_partial = true;
                    shifted_rows = shift_rows;
                    shiftPresentedGenerationCells(self, rows, cols, viewport_shift.rows);
                    logs.texture_shift.logf(
                        .info,
                        "result=scroll_copy_ok gen={d} dirty={s} shift_rows={d} exposed_only={d} scroll_offset={d} damage={d}..{d}/{d}..{d}",
                        .{
                            draw_state.generation,
                            dirty_summary.dirty_tag,
                            viewport_shift.rows,
                            @intFromBool(viewport_shift.exposed_only),
                            scroll_offset,
                            dirty_summary.damage_start_row,
                            dirty_summary.damage_end_row,
                            dirty_summary.damage_start_col,
                            dirty_summary.damage_end_col,
                        },
                    );
                } else {
                    shifted_rows = 0;
                    logs.texture_shift.logf(
                        .info,
                        "result=scroll_copy_failed gen={d} dirty={s} shift_rows={d} exposed_only={d} scroll_offset={d}",
                        .{
                            draw_state.generation,
                            dirty_summary.dirty_tag,
                            viewport_shift.rows,
                            @intFromBool(viewport_shift.exposed_only),
                            scroll_offset,
                        },
                    );
                    if (viewport_shift.exposed_only) {
                        needs_partial = true;
                        shift_requires_fullwidth_partial = true;
                    }
                }
            },
            .none => {
                if (viewport_shift.rows != 0) {
                    logs.texture_shift.logf(
                        .info,
                        "result=scroll_copy_skipped gen={d} dirty={s} shift_rows={d} exposed_only={d} scroll_offset={d} full={d}",
                        .{
                            draw_state.generation,
                            dirty_summary.dirty_tag,
                            viewport_shift.rows,
                            @intFromBool(viewport_shift.exposed_only),
                            scroll_offset,
                            @intFromBool(needs_full),
                        },
                    );
                }
                if (viewport_shift.exposed_only) {
                    needs_partial = true;
                    shift_requires_fullwidth_partial = true;
                }
            },
        }
        if (!needs_full and needs_partial) {
            fullframe_fastpath_decision = draw_texture.decideFullFrameFastPath(
                cache,
                shifted_rows,
                viewport_shift.rows,
                shift_requires_fullwidth_partial,
                blink_requires_partial,
                0.85,
            );
            const fullframe_fastpath_log = app_logger.logger("terminal.ui.fullframe_fastpath");
            if (fullframe_fastpath_log.enabled_file or fullframe_fastpath_log.enabled_console) {
                fullframe_fastpath_log.logf(
                    .info,
                    "threshold_hit={d} fast_path_taken={d} threshold={d:.2} total_cells={d} union_cells={d} dirty={s} rows={d} cols={d} shift_rows={d}",
                    .{
                        @intFromBool(fullframe_fastpath_decision.threshold_hit),
                        @intFromBool(fullframe_fastpath_decision.threshold_hit),
                        0.85,
                        fullframe_fastpath_decision.total_cells,
                        fullframe_fastpath_decision.union_cells,
                        dirty_summary.dirty_tag,
                        rows,
                        cols,
                        viewport_shift.rows,
                    },
                );
            }
            telemetry.fastpath_threshold_hit = fullframe_fastpath_decision.threshold_hit;
            telemetry.fastpath_total_cells = fullframe_fastpath_decision.total_cells;
            telemetry.fastpath_union_cells = fullframe_fastpath_decision.union_cells;
            if (fullframe_fastpath_decision.threshold_hit) {
                needs_full = true;
                needs_partial = false;
            }
        }
        if (!needs_full and needs_partial) {
            self.partial_draw_rows.resize(self.session.allocator, rows) catch |err| {
                const log = app_logger.logger("terminal.ui.redraw");
                log.logf(.warning, "partial row plan resize failed field=rows rows={d} err={s}", .{ rows, @errorName(err) });
                needs_full = true;
                needs_partial = false;
            };
            self.partial_draw_cols_start.resize(self.session.allocator, rows) catch |err| {
                const log = app_logger.logger("terminal.ui.redraw");
                log.logf(.warning, "partial row plan resize failed field=cols_start rows={d} err={s}", .{ rows, @errorName(err) });
                needs_full = true;
                needs_partial = false;
            };
            self.partial_draw_cols_end.resize(self.session.allocator, rows) catch |err| {
                const log = app_logger.logger("terminal.ui.redraw");
                log.logf(.warning, "partial row plan resize failed field=cols_end rows={d} err={s}", .{ rows, @errorName(err) });
                needs_full = true;
                needs_partial = false;
            };
            self.partial_draw_span_counts.resize(self.session.allocator, rows) catch |err| {
                const log = app_logger.logger("terminal.ui.redraw");
                log.logf(.warning, "partial row plan resize failed field=span_counts rows={d} err={s}", .{ rows, @errorName(err) });
                needs_full = true;
                needs_partial = false;
            };
            self.partial_draw_spans.resize(self.session.allocator, rows) catch |err| {
                const log = app_logger.logger("terminal.ui.redraw");
                log.logf(.warning, "partial row plan resize failed field=spans rows={d} err={s}", .{ rows, @errorName(err) });
                needs_full = true;
                needs_partial = false;
            };
            if (!needs_full and needs_partial) {
                _ = buildPartialPlan(
                    cache,
                    self.partial_draw_rows.items,
                    self.partial_draw_span_counts.items,
                    self.partial_draw_spans.items,
                    self.partial_draw_cols_start.items,
                    self.partial_draw_cols_end.items,
                    shifted_rows,
                    viewport_shift.rows,
                    shift_requires_fullwidth_partial,
                    blink_requires_partial,
                );
                if (partialWouldPreserveOlderGeneration(self, rows, cols, draw_state.generation)) {
                    const provenance_log = app_logger.logger("terminal.frame_provenance");
                    if (provenance_log.enabled_file or provenance_log.enabled_console) {
                        provenance_log.logf(
                            .info,
                            "stage=escalate_full_for_generation_coherence gen={d} rows={d} cols={d}",
                            .{ draw_state.generation, rows, cols },
                        );
                    }
                    needs_full = true;
                    needs_partial = false;
                }
            }
        }
        telemetry.texture_full_update = needs_full;
        telemetry.texture_partial_update = needs_partial;

        if ((needs_full or needs_partial) and r.beginTerminalTexture()) {
            // Disable scissor while updating the offscreen texture.
            // The main draw pass will restore the clip for on-screen drawing.
            r.endClip();
            const base_x_local: f32 = 0;
            const base_y_local: f32 = 0;

            if (needs_full) {
                fillPresentedGenerationCells(self, rows, cols, draw_state.generation);
                const bg_phase_start = app_shell.getTime();
                const bg = if (view_cells.len > 0) toShellColor(base_colors.resolved_background) else r.theme.background;
                r.beginTerminalBatch();
                r.addTerminalRect(0, 0, texture_w, texture_h, bg);
                var row: usize = 0;
                while (row < rows) : (row += 1) {
                    drawRowBackgrounds(shell, view_cells, cols, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i, true, screen_reverse, draw_cursor, cursor, cursor_style);
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
                r.terminal_font.beginFrameAtlasStats();
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
                    viewport_shift.rows,
                    shift_requires_fullwidth_partial,
                    blink_requires_partial,
                );
                const partial_plan = summarizePartialPlan(
                    self,
                    rows,
                    cols,
                    draw_state.generation,
                    partial_plan_bounds,
                    logs.redraw.enabled_file or logs.redraw.enabled_console,
                    telemetry.texture_partial_update,
                    &log_buffers.partial_plan_summary_buf,
                );
                partial_plan_rows_count = partial_plan.rows_count;
                partial_plan_row_span = partial_plan.row_span;
                partial_plan_col_span = partial_plan.col_span;
                partial_plan_cells = partial_plan.cells;
                partial_plan_union_cells = partial_plan.union_cells;
                partial_plan_summary = partial_plan.summary;
                if (shifted_rows > 0 or shift_requires_fullwidth_partial) {
                    logs.texture_shift.logf(
                        .info,
                        "result=partial_plan gen={d} shifted_rows={d} fullwidth_exposed={d} plan_rows={d} plan_row_span={d} plan_col_span={d} plan_cells={d} plan_union_cells={d} spans={s}",
                        .{
                            draw_state.generation,
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
                            drawRowBackgrounds(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, draw_padding, screen_reverse, draw_cursor, cursor, cursor_style);
                        }
                        continue;
                    }
                    const col_start = @min(@as(usize, self.partial_draw_cols_start.items[row]), cols - 1);
                    const col_end = @min(@as(usize, self.partial_draw_cols_end.items[row]), cols - 1);
                    const draw_padding = col_end >= cols - 1;
                    drawRowBackgrounds(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, draw_padding, screen_reverse, draw_cursor, cursor, cursor_style);
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
                r.terminal_font.beginFrameAtlasStats();
                r.beginTerminalGlyphBatch();
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
                    if ((logs.row_render.enabled_file or logs.row_render.enabled_console) and row_span_count > 0) {
                        if (row_width >= cols / 2 or row == cursor.row) {
                            logs.row_render.logf(
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
                            logs.row_render_runs.logf(
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
                r.flushTerminalGlyphBatch();
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
            if (logs.handoff.enabled_file or logs.handoff.enabled_console) {
                logs.handoff.logf(
                    .info,
                    "stage=widget_commit sid={x} last_render={d}->{d} cur={d} pub={d} presented={d} full={d} partial={d}",
                    .{
                        @intFromPtr(self.session),
                        handoff_state.last_render_generation,
                        draw_state.generation,
                        handoff_state.pending_generation,
                        handoff_state.published_generation,
                        handoff_state.presented_generation,
                        @intFromBool(telemetry.texture_full_update),
                        @intFromBool(telemetry.texture_partial_update),
                    },
                );
            }
            logPresentedColumnProbe(cache);
            logPresentedGenerationProvenance(self, cache);
            self.last_render_generation = draw_state.generation;
            self.last_render_clear_generation = draw_state.clear_generation;
            self.last_cell_w_i = cell_w_i;
            self.last_cell_h_i = cell_h_i;
            self.last_render_scale = r.render_scale;
            if (visible_w > 0 and visible_h > 0) {
                r.beginClip(
                    @intFromFloat(std.math.round(base_x)),
                    @intFromFloat(std.math.round(base_y)),
                    visible_w,
                    visible_h,
                );
            }
            updated = true;
        }
        if (!updated and self.terminal_texture_ready and visible_w > 0 and visible_h > 0) {
            r.beginClip(
                @intFromFloat(std.math.round(base_x)),
                @intFromFloat(std.math.round(base_y)),
                visible_w,
                visible_h,
            );
        }
        if (rows > 0 and cols > 0) {
            const bg = if (view_cells.len > 0) toShellColor(base_colors.resolved_background) else r.theme.background;
            if (visible_w > 0 and visible_h > 0) {
                r.drawRectF(base_x, base_y, viewport_w, viewport_h, bg);
            }
        }
        if (self.terminal_texture_ready and visible_w > 0 and visible_h > 0) {
            r.drawTerminalTexture(base_x, base_y, viewport_w, viewport_h);
        }
        maybeLogCaptureBurst(
            self,
            shell,
            cache,
            width,
            height,
            viewport_w,
            viewport_h,
            visible_w,
            visible_h,
            rows,
            cols,
            telemetry.texture_full_update,
            telemetry.texture_partial_update,
            viewport_shift.rows,
            telemetry.fastpath_threshold_hit,
            telemetry.fastpath_total_cells,
            telemetry.fastpath_union_cells,
            partial_plan_cells,
            partial_plan_union_cells,
            telemetry.capture_reason,
            glyph_draw_stats,
        );
    }
    texture_update_ms = time_utils.secondsToMs(app_shell.getTime() - texture_phase_start);
    const overlay_phase_start = app_shell.getTime();
    if (!has_kitty and self.kitty.textures.count() > 0) {
        self.kitty.cleanupTextures(self.session.allocator, self.kitty.images_view.items);
    }
    drawOverlays(
        self,
        shell,
        base_x,
        base_y,
        viewport_w,
        viewport_h,
        input,
        cache,
        view_cells,
        rows,
        cols,
        screen_reverse,
        hover_link_id,
        draw_cursor,
        cursor,
        cursor_style,
    );

    if (updated or dirty_summary.is_clean) {
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

    const now = app_shell.getTime();
    const elapsed_ms = time_utils.secondsToMs(now - draw_start);
    const has_kitty_images = self.kitty.images_view.items.len > 0;
    const lifecycle_reason = if (!texture_ready_before_draw)
        "init"
    else if (lifecycle_transition.reason()) |reason|
        reason
    else
        null;
    const active_draw_log = if (lifecycle_reason != null) logs.lifecycle else logs.redraw;
    const active_perf_log = if (lifecycle_reason != null) logs.lifecycle else logs.perf;
    const log_partial_update = telemetry.texture_partial_update and updated and (active_draw_log.enabled_file or active_draw_log.enabled_console or active_perf_log.enabled_file or active_perf_log.enabled_console);
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
            "draw_ms={d:.2} lock_stats={s} texture_update_ms={d:.2} texture_bg_ms={d:.2} texture_glyph_ms={d:.2} texture_kitty_ms={d:.2} overlay_ms={d:.2} full={d} partial={d} updated={d} sync={d} clear_ok={d} dirty={s} current_reason={s} dirty_rows={d} damage_rows={d} damage_cols={d} plan_rows={d} plan_row_span={d} plan_col_span={d} plan_cells={d} plan_union_cells={d} blink_cells={d} blink_phase_changed={d} shift_rows={d} shift_exposed_only={d} sprite_stats={s} glyph_batch_stats={s} glyph_atlas_stats={s} glyph_stats={s} rows={d} cols={d}",
            .{
                elapsed_ms,
                std.fmt.bufPrint(&log_buffers.lock_stats_summary_buf, "{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}", .{
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
                @intFromBool(telemetry.texture_full_update),
                @intFromBool(telemetry.texture_partial_update),
                @intFromBool(updated),
                @intFromBool(sync_updates),
                @intFromBool(outcome.presented != null and (outcome.texture_updated or dirty_summary.is_clean)),
                dirty_summary.dirty_tag,
                dirty_summary.current_reason,
                dirty_summary.dirty_rows_count,
                dirty_summary.damage_row_span,
                dirty_summary.damage_col_span,
                partial_plan_rows_count,
                partial_plan_row_span,
                partial_plan_col_span,
                partial_plan_cells,
                partial_plan_union_cells,
                @intFromBool(has_blink),
                @intFromBool(blink_phase_changed),
                viewport_shift.rows,
                @intFromBool(viewport_shift.exposed_only),
                std.fmt.bufPrint(&log_buffers.sprite_stats_summary_buf, "{d}/{d}/{d}/{d:.2}", .{
                    glyph_draw_stats.special_sprite_cache_hits,
                    glyph_draw_stats.special_sprite_cache_misses,
                    glyph_draw_stats.special_sprite_creates,
                    glyph_draw_stats.special_sprite_lookup_ms,
                }) catch "overflow",
                std.fmt.bufPrint(&log_buffers.glyph_batch_summary_buf, "{d}/{d}/{d}/{d}", .{
                    r.terminal_glyph_cache.frameMetrics().quad_count,
                    r.terminal_glyph_cache.frameMetrics().flush_count,
                    r.terminal_glyph_cache.frameMetrics().draw_call_count,
                    r.terminal_glyph_cache.frameMetrics().vertex_count,
                }) catch "overflow",
                std.fmt.bufPrint(&log_buffers.glyph_atlas_summary_buf, "{d}/{d}/{d}/{d}/{d}/{d}/{d}", .{
                    r.terminal_font.frameAtlasStats().glyph_cache_hits,
                    r.terminal_font.frameAtlasStats().glyph_cache_misses,
                    r.terminal_font.frameAtlasStats().rasterized_glyphs,
                    r.terminal_font.frameAtlasStats().atlas_compactions,
                    r.terminal_font.frameAtlasStats().uploaded_coverage_glyphs,
                    r.terminal_font.frameAtlasStats().uploaded_color_glyphs,
                    r.terminal_font.frameAtlasStats().uploaded_pixels,
                }) catch "overflow",
                std.fmt.bufPrint(&log_buffers.glyph_stats_summary_buf, "{d}/{d}/{d}/{d}/{d}/{d}/{d}/{d}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}/{d:.2}", .{
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

    return outcome;
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
