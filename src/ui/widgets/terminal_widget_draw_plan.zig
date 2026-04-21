//! Draw planning and execution selection: reuse/refresh/direct decision logic (before GPU work).
//!
//! This module owns the planning phase that decides whether to reuse a cached
//! presentable, refresh with a new render, or perform direct drawing. Planning happens
//! before GPU submission; execution is owned by `terminal_widget_presentation_runtime.zig`.
const std = @import("std");
const render_cache_mod = @import("../../terminal/core/publication/render_cache.zig");
const screen_mod = @import("../../terminal/model/screen.zig");

const RenderCache = render_cache_mod.RenderCache;
const max_row_dirty_spans = render_cache_mod.max_row_dirty_spans;

pub const ViewportPresentShiftPlan = union(enum) {
    none,
    attempt: usize,
};

pub const PresentationUpdatePlan = struct {
    needs_full: bool,
    needs_partial: bool,
};

pub const FullFrameFastPathDecision = struct {
    union_cells: usize = 0,
    total_cells: usize = 0,
    threshold_hit: bool = false,
};

pub const PartialPlanBounds = struct {
    start_row: usize,
    end_row: usize,
    start_col: usize,
    end_col: usize,
};

pub fn formatPartialPlanRows(
    buf: []u8,
    partial_rows: []const bool,
    partial_span_counts: []const u8,
    partial_spans: []const [screen_mod.max_row_dirty_spans]screen_mod.RowDirtySpan,
    partial_cols_start: []const u16,
    partial_cols_end: []const u16,
    max_rows: usize,
) []const u8 {
    if (buf.len == 0) return "";

    var stream = std.io.fixedBufferStream(buf);
    const writer = stream.writer();
    var emitted: usize = 0;
    var row_buf: [32]u8 = undefined;

    for (partial_rows, 0..) |dirty, row| {
        if (!dirty) continue;
        if (emitted == max_rows) {
            const ellipsis_needed: usize = if (emitted > 0) 4 else 3;
            if (stream.pos + ellipsis_needed <= buf.len) {
                if (emitted > 0) writer.writeAll(" ") catch {};
                writer.writeAll("...") catch {};
            }
            break;
        }
        const row_token = if (row < partial_span_counts.len and row < partial_spans.len and partial_span_counts[row] > 0) blk: {
            var row_stream = std.io.fixedBufferStream(&row_buf);
            const row_writer = row_stream.writer();
            row_writer.print("{d}:", .{row}) catch break :blk std.fmt.bufPrint(&row_buf, "{d}:{d}-{d}", .{ row, partial_cols_start[row], partial_cols_end[row] }) catch break;
            var span_idx: usize = 0;
            while (span_idx < partial_span_counts[row]) : (span_idx += 1) {
                if (span_idx > 0) row_writer.writeAll("|") catch break;
                const span = partial_spans[row][span_idx];
                row_writer.print("{d}-{d}", .{ span.start, span.end }) catch break;
            }
            break :blk row_stream.getWritten();
        } else std.fmt.bufPrint(
            &row_buf,
            "{d}:{d}-{d}",
            .{ row, partial_cols_start[row], partial_cols_end[row] },
        ) catch break;
        const needed = row_token.len + @as(usize, if (emitted > 0) 1 else 0);
        if (stream.pos + needed > buf.len) {
            const ellipsis_needed: usize = if (emitted > 0) 4 else 3;
            if (stream.pos + ellipsis_needed <= buf.len) {
                if (emitted > 0) writer.writeAll(" ") catch {};
                writer.writeAll("...") catch {};
            }
            break;
        }
        if (emitted > 0) {
            writer.writeAll(" ") catch break;
        }
        writer.writeAll(row_token) catch break;
        emitted += 1;
    }

    return stream.getWritten();
}

pub fn buildPartialPlan(
    cache: *const RenderCache,
    partial_rows: []bool,
    partial_span_counts: []u8,
    partial_spans: [][screen_mod.max_row_dirty_spans]screen_mod.RowDirtySpan,
    partial_cols_start: []u16,
    partial_cols_end: []u16,
    shifted_rows: usize,
    viewport_shift_rows: i32,
    shift_requires_fullwidth_partial: bool,
    blink_requires_partial: bool,
) ?PartialPlanBounds {
    buildBasePartialPlan(
        partial_rows,
        partial_span_counts,
        partial_spans,
        partial_cols_start,
        partial_cols_end,
        cache.dirty_rows.items,
        cache.row_dirty_span_counts.items,
        cache.row_dirty_spans.items,
        cache.dirty_cols_start.items,
        cache.dirty_cols_end.items,
        cache.rows,
        cache.cols,
        shifted_rows,
        viewport_shift_rows,
        shift_requires_fullwidth_partial,
    );
    if (blink_requires_partial) {
        addBlinkRowsToPartialPlan(
            cache,
            partial_rows,
            partial_span_counts,
            partial_spans,
            partial_cols_start,
            partial_cols_end,
        );
    }
    return summarizePartialPlan(partial_rows, partial_cols_start, partial_cols_end);
}

pub fn buildBasePartialPlan(
    partial_rows: []bool,
    partial_span_counts: []u8,
    partial_spans: [][screen_mod.max_row_dirty_spans]screen_mod.RowDirtySpan,
    partial_cols_start: []u16,
    partial_cols_end: []u16,
    view_dirty_rows: []const bool,
    row_dirty_span_counts: []const u8,
    row_dirty_spans: []const [screen_mod.max_row_dirty_spans]screen_mod.RowDirtySpan,
    dirty_cols_start: []const u16,
    dirty_cols_end: []const u16,
    rows: usize,
    cols: usize,
    shifted_rows: usize,
    viewport_shift_rows: i32,
    shift_requires_fullwidth_partial: bool,
) void {
    for (partial_rows) |*row_draw| {
        row_draw.* = false;
    }
    for (partial_span_counts) |*count| {
        count.* = 0;
    }
    for (partial_spans) |*row_spans| {
        for (row_spans) |*span| {
            span.* = .{ .start = @intCast(cols), .end = 0 };
        }
    }
    for (partial_cols_start, partial_cols_end) |*col_start, *col_end| {
        col_start.* = if (cols > 0) @intCast(cols) else 0;
        col_end.* = 0;
    }

    if (rows == 0 or cols == 0) return;

    if (shift_requires_fullwidth_partial) {
        markAllRowsFullWidthPartialPlan(
            partial_rows,
            partial_span_counts,
            partial_spans,
            partial_cols_start,
            partial_cols_end,
            rows,
            cols,
        );
        return;
    }

    const shift_up = viewport_shift_rows > 0;
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        const is_shift_row = shifted_rows > 0 and (if (shift_up) row >= rows - shifted_rows else row < shifted_rows);
        if (!((row < view_dirty_rows.len and view_dirty_rows[row]) or is_shift_row)) continue;

        if (!is_shift_row and row < row_dirty_span_counts.len and row < row_dirty_spans.len and row_dirty_span_counts[row] > 0) {
            var span_idx: usize = 0;
            while (span_idx < row_dirty_span_counts[row]) : (span_idx += 1) {
                const span = row_dirty_spans[row][span_idx];
                if (span.start > span.end) continue;
                markPartialPlanRow(
                    partial_rows,
                    partial_span_counts,
                    partial_spans,
                    partial_cols_start,
                    partial_cols_end,
                    row,
                    @min(@as(usize, span.start), cols - 1),
                    @min(@as(usize, span.end), cols - 1),
                );
            }
            continue;
        }
        var col_start: usize = 0;
        var col_end: usize = cols - 1;
        if (!is_shift_row and row < dirty_cols_start.len and row < dirty_cols_end.len) {
            col_start = @min(@as(usize, dirty_cols_start[row]), cols - 1);
            col_end = @min(@as(usize, dirty_cols_end[row]), cols - 1);
        }
        markPartialPlanRow(
            partial_rows,
            partial_span_counts,
            partial_spans,
            partial_cols_start,
            partial_cols_end,
            row,
            col_start,
            col_end,
        );
    }
}

/// Parameters `terminal_presentable_pipeline_ready` / plan inputs mirror `PresentationState` and
/// `presentationUpdateDelta` dominant names (`CZH-B25`).
pub fn planViewportPresentShift(
    texture_shift_enabled: bool,
    gen_changed: bool,
    viewport_shift_rows: i32,
    viewport_shift_exposed_only: bool,
    scroll_offset: usize,
    needs_full: bool,
    terminal_presentable_pipeline_ready: bool,
    rows: usize,
) ViewportPresentShiftPlan {
    const shift_abs_i: i32 = if (viewport_shift_rows < 0) -viewport_shift_rows else viewport_shift_rows;
    if (texture_shift_enabled and
        gen_changed and
        viewport_shift_rows != 0 and
        (scroll_offset == 0 or viewport_shift_exposed_only) and
        !needs_full and
        terminal_presentable_pipeline_ready and
        shift_abs_i > 0 and
        shift_abs_i < @as(i32, @intCast(rows)))
    {
        return .{ .attempt = @as(usize, @intCast(shift_abs_i)) };
    }
    return .none;
}

pub fn useViewportShiftForPartialPlan(
    cache_dirty: @TypeOf(RenderCache.init().dirty),
    viewport_shift_rows: i32,
) bool {
    return cache_dirty == .partial and viewport_shift_rows != 0;
}

pub fn choosePresentationUpdatePlan(
    cache_dirty: @TypeOf(RenderCache.init().dirty),
    recreated: bool,
    clear_generation_changed: bool,
    cell_metrics_changed: bool,
    render_scale_changed: bool,
    blink_requires_partial: bool,
    terminal_presentable_pipeline_ready: bool,
) PresentationUpdatePlan {
    var needs_full = recreated or
        clear_generation_changed or
        cell_metrics_changed or
        render_scale_changed or
        cache_dirty == .full;
    var needs_partial = (cache_dirty == .partial or blink_requires_partial) and !needs_full;
    if (!terminal_presentable_pipeline_ready) {
        needs_full = true;
        needs_partial = false;
    }
    return .{
        .needs_full = needs_full,
        .needs_partial = needs_partial,
    };
}

pub fn decideFullFrameFastPath(
    cache: *const RenderCache,
    shifted_rows: usize,
    viewport_shift_rows: i32,
    shift_requires_fullwidth_partial: bool,
    blink_requires_partial: bool,
    threshold: f64,
) FullFrameFastPathDecision {
    const rows = cache.rows;
    const cols = cache.cols;
    const total_cells = rows * cols;
    if (rows == 0 or cols == 0) return .{ .total_cells = total_cells };
    if (cache.dirty != .partial) return .{ .total_cells = total_cells };
    if (shift_requires_fullwidth_partial) {
        return .{
            .union_cells = total_cells,
            .total_cells = total_cells,
            .threshold_hit = true,
        };
    }

    // Row marks can be conservatively dense (for example visible-history republish paths)
    // while `cache.damage` stays tight. Using only the dirty-row union for the fast-path
    // threshold would promote almost every frame to a full redraw and defeat direct
    // snapshot partial updates on the Metal terminal lane.
    // Do not require `viewport_shift_rows == 0`: the cache can still carry a non-zero
    // line delta from the publication plan when texture scroll is disabled or failed,
    // while `shifted_rows` (actual shifted presentable rows) stays zero.
    if (shifted_rows == 0 and
        !shift_requires_fullwidth_partial and
        !blink_requires_partial and
        cache.damage.end_row >= cache.damage.start_row and
        cache.damage.end_col >= cache.damage.start_col)
    {
        const dr = cache.damage.end_row - cache.damage.start_row + 1;
        const dc = cache.damage.end_col - cache.damage.start_col + 1;
        const bbox_cells = dr * dc;
        const threshold_hit = if (total_cells > 0)
            @as(f64, @floatFromInt(bbox_cells)) / @as(f64, @floatFromInt(total_cells)) >= threshold
        else
            false;
        return .{
            .union_cells = bbox_cells,
            .total_cells = total_cells,
            .threshold_hit = threshold_hit,
        };
    }

    const shift_up = viewport_shift_rows > 0;
    var min_row: usize = rows;
    var max_row: usize = 0;
    var min_col: usize = cols;
    var max_col: usize = 0;
    var any = false;

    var row: usize = 0;
    while (row < rows) : (row += 1) {
        const is_shift_row = shifted_rows > 0 and (if (shift_up) row >= rows - shifted_rows else row < shifted_rows);
        const is_dirty_row = row < cache.dirty_rows.items.len and cache.dirty_rows.items[row];
        if (!(is_shift_row or is_dirty_row)) continue;

        var row_min: usize = if (is_shift_row or blink_requires_partial) 0 else cols;
        var row_max: usize = if (is_shift_row or blink_requires_partial) cols - 1 else 0;
        var row_any = is_shift_row or blink_requires_partial;

        if (!row_any and
            row < cache.row_dirty_span_counts.items.len and
            row < cache.row_dirty_spans.items.len and
            cache.row_dirty_span_counts.items[row] > 0)
        {
            var span_idx: usize = 0;
            while (span_idx < cache.row_dirty_span_counts.items[row]) : (span_idx += 1) {
                const span = cache.row_dirty_spans.items[row][span_idx];
                if (span.start > span.end) continue;
                row_min = @min(row_min, @min(@as(usize, span.start), cols - 1));
                row_max = @max(row_max, @min(@as(usize, span.end), cols - 1));
                row_any = true;
            }
        }

        if (!row_any and row < cache.dirty_cols_start.items.len and row < cache.dirty_cols_end.items.len) {
            row_min = @min(@as(usize, cache.dirty_cols_start.items[row]), cols - 1);
            row_max = @min(@as(usize, cache.dirty_cols_end.items[row]), cols - 1);
            row_any = row_max >= row_min;
        }

        if (!row_any) continue;
        any = true;
        min_row = @min(min_row, row);
        max_row = @max(max_row, row);
        min_col = @min(min_col, row_min);
        max_col = @max(max_col, row_max);
    }

    const union_cells: usize = if (any and max_row >= min_row and max_col >= min_col)
        (max_row - min_row + 1) * (max_col - min_col + 1)
    else
        0;
    const threshold_hit = if (total_cells > 0)
        @as(f64, @floatFromInt(union_cells)) / @as(f64, @floatFromInt(total_cells)) >= threshold
    else
        false;
    return .{
        .union_cells = union_cells,
        .total_cells = total_cells,
        .threshold_hit = threshold_hit,
    };
}

pub fn forceFullPresentationUpdatePlanEveryFrame(plan: PresentationUpdatePlan, enabled: bool) PresentationUpdatePlan {
    if (!enabled) return plan;
    return .{ .needs_full = true, .needs_partial = false };
}

pub fn forceFullPresentationUpdatePlan(plan: PresentationUpdatePlan, enabled: bool) PresentationUpdatePlan {
    if (!enabled or plan.needs_full or !plan.needs_partial) return plan;
    return .{
        .needs_full = true,
        .needs_partial = false,
    };
}

fn summarizePartialPlan(
    partial_rows: []const bool,
    partial_cols_start: []const u16,
    partial_cols_end: []const u16,
) ?PartialPlanBounds {
    var min_row: usize = partial_rows.len;
    var max_row: usize = 0;
    var min_col: usize = partial_cols_start.len;
    var max_col: usize = 0;
    var any = false;
    for (partial_rows, 0..) |dirty, row| {
        if (!dirty) continue;
        any = true;
        min_row = @min(min_row, row);
        max_row = @max(max_row, row);
        if (row < partial_cols_start.len and row < partial_cols_end.len) {
            min_col = @min(min_col, @as(usize, partial_cols_start[row]));
            max_col = @max(max_col, @as(usize, partial_cols_end[row]));
        }
    }
    if (!any) return null;
    return .{
        .start_row = min_row,
        .end_row = max_row,
        .start_col = min_col,
        .end_col = max_col,
    };
}

pub fn markAllRowsFullWidthPartialPlan(
    partial_rows: []bool,
    partial_span_counts: []u8,
    partial_spans: [][screen_mod.max_row_dirty_spans]screen_mod.RowDirtySpan,
    partial_cols_start: []u16,
    partial_cols_end: []u16,
    rows: usize,
    cols: usize,
) void {
    if (rows == 0 or cols == 0) return;
    for (0..rows) |row| {
        partial_rows[row] = true;
        partial_span_counts[row] = 1;
        partial_spans[row][0] = .{ .start = 0, .end = @intCast(cols - 1) };
        partial_cols_start[row] = 0;
        partial_cols_end[row] = @intCast(cols - 1);
    }
}

pub fn markPartialPlanRows(
    partial_rows: []bool,
    partial_span_counts: []u8,
    partial_spans: [][screen_mod.max_row_dirty_spans]screen_mod.RowDirtySpan,
    partial_cols_start: []u16,
    partial_cols_end: []u16,
    rows: usize,
    row: usize,
    col_start: usize,
    col_end: usize,
) void {
    const affect_start = row -| 1;
    const affect_end = @min(rows - 1, row + 1);
    const col_start_u16: u16 = @intCast(col_start);
    const col_end_u16: u16 = @intCast(col_end);
    var affect_row = affect_start;
    while (affect_row <= affect_end) : (affect_row += 1) {
        markPartialPlanRow(
            partial_rows,
            partial_span_counts,
            partial_spans,
            partial_cols_start,
            partial_cols_end,
            affect_row,
            col_start_u16,
            col_end_u16,
        );
    }
}

pub fn markPartialPlanRow(
    partial_rows: []bool,
    partial_span_counts: []u8,
    partial_spans: [][screen_mod.max_row_dirty_spans]screen_mod.RowDirtySpan,
    partial_cols_start: []u16,
    partial_cols_end: []u16,
    row: usize,
    col_start: usize,
    col_end: usize,
) void {
    if (row < partial_span_counts.len and row < partial_spans.len) {
        mergePartialPlanSpan(partial_span_counts, partial_spans, row, col_start, col_end);
    }
    const col_start_u16: u16 = @intCast(col_start);
    const col_end_u16: u16 = @intCast(col_end);
    partial_rows[row] = true;
    if (partial_cols_start[row] > col_start_u16) partial_cols_start[row] = col_start_u16;
    if (partial_cols_end[row] < col_end_u16) partial_cols_end[row] = col_end_u16;
}

fn mergePartialPlanSpan(
    partial_span_counts: []u8,
    partial_spans: [][screen_mod.max_row_dirty_spans]screen_mod.RowDirtySpan,
    row: usize,
    col_start: usize,
    col_end: usize,
) void {
    var merged_start: u16 = @intCast(col_start);
    var merged_end: u16 = @intCast(col_end);
    var count = @as(usize, partial_span_counts[row]);
    var row_spans = &partial_spans[row];

    var read_idx: usize = 0;
    var write_idx: usize = 0;
    while (read_idx < count) : (read_idx += 1) {
        const span = row_spans[read_idx];
        if (span.end + 1 < merged_start or merged_end + 1 < span.start) {
            row_spans[write_idx] = span;
            write_idx += 1;
            continue;
        }
        merged_start = @min(merged_start, span.start);
        merged_end = @max(merged_end, span.end);
    }
    count = write_idx;
    if (count >= screen_mod.max_row_dirty_spans) {
        var union_start = merged_start;
        var union_end = merged_end;
        var idx: usize = 0;
        while (idx < count) : (idx += 1) {
            union_start = @min(union_start, row_spans[idx].start);
            union_end = @max(union_end, row_spans[idx].end);
        }
        row_spans[0] = .{ .start = union_start, .end = union_end };
        partial_span_counts[row] = 1;
        var clear_idx: usize = 1;
        while (clear_idx < screen_mod.max_row_dirty_spans) : (clear_idx += 1) {
            row_spans[clear_idx] = .{ .start = union_end + 1, .end = union_end };
        }
        return;
    }
    row_spans[count] = .{ .start = merged_start, .end = merged_end };
    count += 1;

    var idx: usize = count;
    while (idx > 1) {
        const current_idx = idx - 1;
        const prev_idx = idx - 2;
        if (row_spans[prev_idx].start <= row_spans[current_idx].start) break;
        const tmp = row_spans[prev_idx];
        row_spans[prev_idx] = row_spans[current_idx];
        row_spans[current_idx] = tmp;
        idx -= 1;
    }

    partial_span_counts[row] = @intCast(count);
    var clear_idx: usize = count;
    while (clear_idx < screen_mod.max_row_dirty_spans) : (clear_idx += 1) {
        row_spans[clear_idx] = .{ .start = merged_end + 1, .end = merged_end };
    }
}

fn addBlinkRowsToPartialPlan(
    cache: *const RenderCache,
    partial_rows: []bool,
    partial_span_counts: []u8,
    partial_spans: [][screen_mod.max_row_dirty_spans]screen_mod.RowDirtySpan,
    partial_cols_start: []u16,
    partial_cols_end: []u16,
) void {
    const rows = cache.rows;
    const cols = cache.cols;
    if (rows == 0 or cols == 0) return;

    var row: usize = 0;
    while (row < rows) : (row += 1) {
        const row_start = row * cols;
        const row_cells = cache.cells.items[row_start .. row_start + cols];
        var first_col: ?usize = null;
        var last_col: usize = 0;
        var col: usize = 0;
        while (col < cols) : (col += 1) {
            const cell = row_cells[col];
            if (cell.x != 0 or cell.y != 0) continue;
            if (!cell.attrs.blink) continue;
            const width_units = @as(usize, @max(@as(u8, 1), cell.width));
            if (first_col == null) first_col = col;
            last_col = @max(last_col, @min(cols - 1, col + width_units - 1));
        }
        if (first_col) |start_col| {
            markPartialPlanRow(
                partial_rows,
                partial_span_counts,
                partial_spans,
                partial_cols_start,
                partial_cols_end,
                row,
                start_col,
                last_col,
            );
        }
    }
}

test "decideFullFrameFastPath uses damage bbox when dirty rows are conservative" {
    const allocator = std.testing.allocator;
    var cache = RenderCache.init();
    defer cache.deinit(allocator);

    const rows: usize = 8;
    const cols: usize = 28;
    try cache.cells.resize(allocator, rows * cols);
    try cache.dirty_rows.resize(allocator, rows);
    @memset(cache.dirty_rows.items, true);
    try cache.row_dirty_span_counts.resize(allocator, rows);
    @memset(cache.row_dirty_span_counts.items, 0);
    try cache.row_dirty_span_overflow.resize(allocator, rows);
    @memset(cache.row_dirty_span_overflow.items, false);
    try cache.row_dirty_spans.resize(allocator, rows);
    for (cache.row_dirty_spans.items) |*row_spans| {
        for (row_spans) |*span| {
            span.* = .{ .start = @intCast(cols), .end = 0 };
        }
    }
    try cache.dirty_cols_start.resize(allocator, rows);
    @memset(cache.dirty_cols_start.items, 0);
    try cache.dirty_cols_end.resize(allocator, rows);
    for (cache.dirty_cols_end.items) |*end| {
        end.* = if (cols > 0) @intCast(cols - 1) else 0;
    }

    cache.rows = rows;
    cache.cols = cols;
    cache.dirty = .partial;
    cache.damage = .{ .start_row = 7, .end_row = 7, .start_col = 27, .end_col = 27 };

    const d = decideFullFrameFastPath(&cache, 0, 0, false, false, 0.85);
    try std.testing.expect(!d.threshold_hit);
    try std.testing.expectEqual(@as(usize, 1), d.union_cells);
}

test "decideFullFrameFastPath uses row union when blink forces row-wide partial work" {
    const allocator = std.testing.allocator;
    var cache = RenderCache.init();
    defer cache.deinit(allocator);

    const rows: usize = 8;
    const cols: usize = 28;
    try cache.cells.resize(allocator, rows * cols);
    try cache.dirty_rows.resize(allocator, rows);
    @memset(cache.dirty_rows.items, true);
    try cache.row_dirty_span_counts.resize(allocator, rows);
    @memset(cache.row_dirty_span_counts.items, 0);
    try cache.row_dirty_span_overflow.resize(allocator, rows);
    @memset(cache.row_dirty_span_overflow.items, false);
    try cache.row_dirty_spans.resize(allocator, rows);
    for (cache.row_dirty_spans.items) |*row_spans| {
        for (row_spans) |*span| {
            span.* = .{ .start = @intCast(cols), .end = 0 };
        }
    }
    try cache.dirty_cols_start.resize(allocator, rows);
    @memset(cache.dirty_cols_start.items, 0);
    try cache.dirty_cols_end.resize(allocator, rows);
    for (cache.dirty_cols_end.items) |*end| {
        end.* = if (cols > 0) @intCast(cols - 1) else 0;
    }

    cache.rows = rows;
    cache.cols = cols;
    cache.dirty = .partial;
    cache.damage = .{ .start_row = 7, .end_row = 7, .start_col = 27, .end_col = 27 };

    const d = decideFullFrameFastPath(&cache, 0, 0, false, true, 0.85);
    try std.testing.expect(d.threshold_hit);
    try std.testing.expectEqual(@as(usize, rows * cols), d.union_cells);
}
