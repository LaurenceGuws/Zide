const std = @import("std");
const publication = @import("view_cache_publication.zig");

fn restoredCarriedSpan(active_start: u16, active_end: u16, cols: usize) ?struct { start: u16, end: u16 } {
    if (active_start > active_end) return null;

    var start = active_start;
    var end = active_end;
    if (active_start > 0 and @as(usize, active_end) + 1 < cols and active_end > active_start + 1) {
        start = active_start + 1;
        end = active_end - 1;
    }
    return .{ .start = start, .end = end };
}

fn mergeActiveRowSpans(cache: anytype, active_cache: anytype, row_idx: usize, cols: usize) void {
    const count = active_cache.row_dirty_span_counts.items[row_idx];
    if (count > 0) {
        cache.row_dirty_span_overflow.items[row_idx] = cache.row_dirty_span_overflow.items[row_idx] or active_cache.row_dirty_span_overflow.items[row_idx];
        var span_idx: usize = 0;
        while (span_idx < count) : (span_idx += 1) {
            const span = active_cache.row_dirty_spans.items[row_idx][span_idx];
            publication.addRowDirtySpan(cache, row_idx, span.start, span.end, cols);
        }
        return;
    }
    const active_start = active_cache.dirty_cols_start.items[row_idx];
    const active_end = active_cache.dirty_cols_end.items[row_idx];
    const restored = restoredCarriedSpan(active_start, active_end, cols) orelse return;
    publication.addRowDirtySpan(cache, row_idx, restored.start, restored.end, cols);
}

pub fn refineRowHashDamage(
    cache: anytype,
    active_cache: anytype,
    rows: usize,
    cols: usize,
    fullwidth_origin_log: anytype,
    allow_row_hash_narrowing: bool,
    merge_active_partial: bool,
) void {
    var any_dirty = false;
    var row_idx: usize = 0;
    while (row_idx < rows) : (row_idx += 1) {
        if (!cache.dirty_rows.items[row_idx]) continue;
        const row_start = row_idx * cols;
        const row_cells = cache.cells.items[row_start .. row_start + cols];
        const old_row_cells = active_cache.cells.items[row_start .. row_start + cols];
        const hash_now = publication.hashRow(row_cells);
        cache.row_hashes.items[row_idx] = hash_now;
        if (!allow_row_hash_narrowing) {
            any_dirty = true;
            continue;
        }
        publication.clearRowDirtySpans(cache, row_idx, cols);
        const hash_changed = hash_now != active_cache.row_hashes.items[row_idx];
        cache.dirty_rows.items[row_idx] = hash_changed;
        if (hash_changed) {
            const spans = publication.rowDiffSpans(row_cells, old_row_cells, cols);
            if (spans.count == 0) {
                cache.dirty_rows.items[row_idx] = false;
                continue;
            }
            cache.row_dirty_span_overflow.items[row_idx] = spans.overflow;
            var span_idx: usize = 0;
            while (span_idx < spans.count) : (span_idx += 1) {
                const span = spans.spans[span_idx];
                publication.addRowDirtySpan(cache, row_idx, span.start, span.end, cols);
            }
            publication.rebuildRowDirtyUnion(cache, row_idx, cols);
            fullwidth_origin_log.logf(
                .info,
                "source=view_cache row={d} reason=row_hash_changed cols={d}..{d} rows={d} cols={d}",
                .{
                    row_idx,
                    cache.dirty_cols_start.items[row_idx],
                    cache.dirty_cols_end.items[row_idx],
                    rows,
                    cols,
                },
            );
            any_dirty = true;
        }
    }
    if (merge_active_partial and active_cache.dirty == .partial) {
        row_idx = 0;
        while (row_idx < rows) : (row_idx += 1) {
            if (!active_cache.dirty_rows.items[row_idx]) continue;
            mergeActiveRowSpans(cache, active_cache, row_idx, cols);
            any_dirty = true;
        }
    }
    if (!any_dirty) {
        cache.dirty = .none;
        cache.damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
        return;
    }
    publication.rebuildPartialDamageFromRowSpans(cache, rows, cols);
}

test "restoredCarriedSpan keeps narrow spans valid" {
    const one = restoredCarriedSpan(6, 6, 149).?;
    try std.testing.expectEqual(@as(u16, 6), one.start);
    try std.testing.expectEqual(@as(u16, 6), one.end);

    const two = restoredCarriedSpan(6, 7, 149).?;
    try std.testing.expectEqual(@as(u16, 6), two.start);
    try std.testing.expectEqual(@as(u16, 7), two.end);
}

test "restoredCarriedSpan shrinks only when interior remains" {
    const restored = restoredCarriedSpan(10, 14, 149).?;
    try std.testing.expectEqual(@as(u16, 11), restored.start);
    try std.testing.expectEqual(@as(u16, 13), restored.end);
}

test "restoredCarriedSpan rejects invalid source spans" {
    try std.testing.expect(restoredCarriedSpan(101, 87, 149) == null);
}

test "refineRowHashDamage preserves disjoint row spans after row-hash narrowing" {
    const allocator = std.testing.allocator;
    const render_cache = @import("render_cache.zig");
    const types = @import("../model/types.zig");
    const default_cell = types.default_cell;

    var cache = render_cache.RenderCache.init();
    defer cache.deinit(allocator);
    var active_cache = render_cache.RenderCache.init();
    defer active_cache.deinit(allocator);

    try cache.cells.resize(allocator, 20);
    try active_cache.cells.resize(allocator, 20);
    try cache.dirty_rows.resize(allocator, 1);
    try active_cache.dirty_rows.resize(allocator, 1);
    try cache.row_dirty_span_counts.resize(allocator, 1);
    try active_cache.row_dirty_span_counts.resize(allocator, 1);
    try cache.row_dirty_span_overflow.resize(allocator, 1);
    try active_cache.row_dirty_span_overflow.resize(allocator, 1);
    try cache.row_dirty_spans.resize(allocator, 1);
    try active_cache.row_dirty_spans.resize(allocator, 1);
    try cache.dirty_cols_start.resize(allocator, 1);
    try active_cache.dirty_cols_start.resize(allocator, 1);
    try cache.dirty_cols_end.resize(allocator, 1);
    try active_cache.dirty_cols_end.resize(allocator, 1);
    try cache.row_hashes.resize(allocator, 1);
    try active_cache.row_hashes.resize(allocator, 1);

    for (cache.cells.items, active_cache.cells.items) |*dst, *src| {
        dst.* = default_cell;
        src.* = default_cell;
    }
    cache.cells.items[2].codepoint = 'A';
    cache.cells.items[3].codepoint = 'B';
    cache.cells.items[10].codepoint = 'C';
    cache.cells.items[11].codepoint = 'D';
    cache.dirty = .partial;
    cache.dirty_rows.items[0] = true;
    cache.row_dirty_span_counts.items[0] = 1;
    cache.row_dirty_span_overflow.items[0] = false;
    cache.row_dirty_spans.items[0][0] = .{ .start = 0, .end = 19 };
    var span_idx: usize = 1;
    while (span_idx < publication.max_row_dirty_spans) : (span_idx += 1) {
        cache.row_dirty_spans.items[0][span_idx] = publication.invalidRowSpan(20);
    }
    cache.dirty_cols_start.items[0] = 0;
    cache.dirty_cols_end.items[0] = 19;
    active_cache.row_hashes.items[0] = publication.hashRow(active_cache.cells.items[0..20]);

    refineRowHashDamage(
        &cache,
        &active_cache,
        1,
        20,
        .{ .enabled_file = false, .enabled_console = false, .file_level = .info, .console_level = .info },
        true,
        false,
    );

    try std.testing.expectEqual(@as(u8, 2), cache.row_dirty_span_counts.items[0]);
    try std.testing.expectEqual(@as(u16, 2), cache.row_dirty_spans.items[0][0].start);
    try std.testing.expectEqual(@as(u16, 3), cache.row_dirty_spans.items[0][0].end);
    try std.testing.expectEqual(@as(u16, 10), cache.row_dirty_spans.items[0][1].start);
    try std.testing.expectEqual(@as(u16, 11), cache.row_dirty_spans.items[0][1].end);
    try std.testing.expectEqual(@as(u16, 2), cache.dirty_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 11), cache.dirty_cols_end.items[0]);
}
