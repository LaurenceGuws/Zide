const std = @import("std");
const types = @import("../model/types.zig");
const screen_mod = @import("../model/screen.zig");

const Cell = types.Cell;
const FullDirtyReason = screen_mod.FullDirtyReason;
pub const RowDirtySpan = screen_mod.RowDirtySpan;
pub const max_row_dirty_spans = screen_mod.max_row_dirty_spans;

pub fn pickForcedFullDirtyReason(
    rows: usize,
    active_rows: usize,
    cols: usize,
    active_cols: usize,
    requires_full_damage_for_scroll_offset_change: bool,
    active_is_alt: bool,
    cache_alt_active: bool,
    view_dirty: anytype,
    view_reason: FullDirtyReason,
) FullDirtyReason {
    if (rows != active_rows or cols != active_cols) return .view_cache_geometry_change;
    if (requires_full_damage_for_scroll_offset_change) return .view_cache_scroll_offset_change;
    if (active_is_alt != cache_alt_active) return .view_cache_alt_state_change;
    if (view_dirty == .full) {
        return if (view_reason == .unknown) .view_cache_view_dirty_full else view_reason;
    }
    return .unknown;
}

pub fn rowLastContentCol(row_cells: []const Cell, cols: usize) ?usize {
    if (cols == 0 or row_cells.len < cols) return null;
    var last: ?usize = null;
    var col: usize = 0;
    while (col < cols) : (col += 1) {
        const cell = row_cells[col];
        if (cell.x != 0 or cell.y != 0) continue;
        if (cell.codepoint == 0 and cell.combining_len == 0) continue;
        const width_units = @as(usize, @max(@as(u8, 1), cell.width));
        const end_col = @min(cols - 1, col + width_units - 1);
        last = end_col;
    }
    return last;
}

pub fn cellsEqual(a: Cell, b: Cell) bool {
    if (a.codepoint != b.codepoint) return false;
    if (a.combining_len != b.combining_len) return false;
    if (a.width != b.width or a.height != b.height or a.x != b.x or a.y != b.y) return false;
    if (!std.meta.eql(a.attrs, b.attrs)) return false;
    var i: usize = 0;
    while (i < a.combining.len) : (i += 1) {
        if (a.combining[i] != b.combining[i]) return false;
    }
    return true;
}

pub fn rowDiffSpan(new_row: []const Cell, old_row: []const Cell, cols: usize) ?struct { start: usize, end: usize } {
    if (cols == 0 or new_row.len < cols or old_row.len < cols) return null;

    var start_opt: ?usize = null;
    var col: usize = 0;
    while (col < cols) : (col += 1) {
        if (!cellsEqual(new_row[col], old_row[col])) {
            start_opt = col;
            break;
        }
    }
    const start = start_opt orelse return null;

    var end: usize = start;
    var rev: usize = cols;
    while (rev > start) {
        rev -= 1;
        if (!cellsEqual(new_row[rev], old_row[rev])) {
            end = rev;
            break;
        }
    }

    return .{ .start = start, .end = end };
}

pub const RowDiffSpans = struct {
    count: u8,
    overflow: bool,
    spans: [max_row_dirty_spans]RowDirtySpan,
};

pub fn invalidRowSpan(cols: usize) RowDirtySpan {
    return .{ .start = @intCast(cols), .end = 0 };
}

pub fn clearRowDirtySpans(cache: anytype, row_idx: usize, cols: usize) void {
    cache.row_dirty_span_counts.items[row_idx] = 0;
    cache.row_dirty_span_overflow.items[row_idx] = false;
    var span_idx: usize = 0;
    while (span_idx < max_row_dirty_spans) : (span_idx += 1) {
        cache.row_dirty_spans.items[row_idx][span_idx] = invalidRowSpan(cols);
    }
}

pub fn addRowDirtySpan(cache: anytype, row_idx: usize, start: usize, end: usize, cols: usize) void {
    if (cols == 0 or start > end or start >= cols) return;
    var merged_start: u16 = @intCast(start);
    var merged_end: u16 = @intCast(@min(end, cols - 1));
    var row_spans = &cache.row_dirty_spans.items[row_idx];
    var count = @as(usize, cache.row_dirty_span_counts.items[row_idx]);

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

    if (count >= max_row_dirty_spans) {
        cache.row_dirty_span_overflow.items[row_idx] = true;
        var union_start = merged_start;
        var union_end = merged_end;
        var idx: usize = 0;
        while (idx < count) : (idx += 1) {
            union_start = @min(union_start, row_spans[idx].start);
            union_end = @max(union_end, row_spans[idx].end);
        }
        row_spans[0] = .{ .start = union_start, .end = union_end };
        cache.row_dirty_span_counts.items[row_idx] = 1;
        var clear_idx: usize = 1;
        while (clear_idx < max_row_dirty_spans) : (clear_idx += 1) {
            row_spans[clear_idx] = invalidRowSpan(cols);
        }
        return;
    }

    row_spans[count] = .{ .start = merged_start, .end = merged_end };
    count += 1;
    if (count > 1) {
        std.sort.block(RowDirtySpan, row_spans[0..count], {}, struct {
            fn lessThan(_: void, a: RowDirtySpan, b: RowDirtySpan) bool {
                if (a.start == b.start) return a.end < b.end;
                return a.start < b.start;
            }
        }.lessThan);
    }
    cache.row_dirty_span_counts.items[row_idx] = @intCast(count);
    var clear_idx = count;
    while (clear_idx < max_row_dirty_spans) : (clear_idx += 1) {
        row_spans[clear_idx] = invalidRowSpan(cols);
    }
}

pub fn rebuildRowDirtyUnion(cache: anytype, row_idx: usize, cols: usize) void {
    const count = cache.row_dirty_span_counts.items[row_idx];
    if (count == 0 or cols == 0) {
        cache.dirty_rows.items[row_idx] = false;
        cache.dirty_cols_start.items[row_idx] = @intCast(cols);
        cache.dirty_cols_end.items[row_idx] = 0;
        return;
    }
    cache.dirty_rows.items[row_idx] = true;
    var start = cache.row_dirty_spans.items[row_idx][0].start;
    var end = cache.row_dirty_spans.items[row_idx][0].end;
    var span_idx: usize = 1;
    while (span_idx < count) : (span_idx += 1) {
        const span = cache.row_dirty_spans.items[row_idx][span_idx];
        start = @min(start, span.start);
        end = @max(end, span.end);
    }
    cache.dirty_cols_start.items[row_idx] = start;
    cache.dirty_cols_end.items[row_idx] = end;
}

pub fn rebuildPartialDamageFromRowSpans(cache: anytype, rows: usize, cols: usize) void {
    var first_dirty = true;
    var row_idx: usize = 0;
    while (row_idx < rows) : (row_idx += 1) {
        rebuildRowDirtyUnion(cache, row_idx, cols);
        if (!cache.dirty_rows.items[row_idx]) continue;
        const start_col = @as(usize, cache.dirty_cols_start.items[row_idx]);
        const end_col = @as(usize, cache.dirty_cols_end.items[row_idx]);
        if (first_dirty) {
            cache.damage = .{
                .start_row = row_idx,
                .end_row = row_idx,
                .start_col = start_col,
                .end_col = end_col,
            };
            first_dirty = false;
        } else {
            cache.damage.start_row = @min(cache.damage.start_row, row_idx);
            cache.damage.end_row = @max(cache.damage.end_row, row_idx);
            cache.damage.start_col = @min(cache.damage.start_col, start_col);
            cache.damage.end_col = @max(cache.damage.end_col, end_col);
        }
    }
    if (first_dirty) {
        cache.dirty = .none;
        cache.damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
    } else {
        cache.dirty = .partial;
    }
}

pub fn rowDiffSpans(new_row: []const Cell, old_row: []const Cell, cols: usize) RowDiffSpans {
    var out = RowDiffSpans{
        .count = 0,
        .overflow = false,
        .spans = undefined,
    };
    for (&out.spans) |*span| span.* = invalidRowSpan(cols);
    if (cols == 0 or new_row.len < cols or old_row.len < cols) return out;

    var run_start: ?usize = null;
    var union_start: usize = cols;
    var union_end: usize = 0;
    var col: usize = 0;
    while (col < cols) : (col += 1) {
        const differs = !cellsEqual(new_row[col], old_row[col]);
        if (differs) {
            if (run_start == null) run_start = col;
            union_start = @min(union_start, col);
            union_end = col;
            continue;
        }
        if (run_start) |start| {
            if (out.count < max_row_dirty_spans and !out.overflow) {
                out.spans[out.count] = .{ .start = @intCast(start), .end = @intCast(col - 1) };
                out.count += 1;
            } else {
                out.overflow = true;
            }
            run_start = null;
        }
    }
    if (run_start) |start| {
        if (out.count < max_row_dirty_spans and !out.overflow) {
            out.spans[out.count] = .{ .start = @intCast(start), .end = @intCast(cols - 1) };
            out.count += 1;
        } else {
            out.overflow = true;
        }
    }
    if (out.overflow and union_start < cols) {
        out.count = 1;
        out.spans[0] = .{ .start = @intCast(union_start), .end = @intCast(union_end) };
        var idx: usize = 1;
        while (idx < max_row_dirty_spans) : (idx += 1) {
            out.spans[idx] = invalidRowSpan(cols);
        }
    }
    return out;
}

pub fn assignProjectedDiffDamage(cache: anytype, active_cache: anytype, rows: usize, cols: usize) void {
    var row_idx: usize = 0;
    while (row_idx < rows) : (row_idx += 1) {
        clearRowDirtySpans(cache, row_idx, cols);
        const row_start = row_idx * cols;
        const row_cells = cache.cells.items[row_start .. row_start + cols];
        const old_row_cells = active_cache.cells.items[row_start .. row_start + cols];
        const spans = rowDiffSpans(row_cells, old_row_cells, cols);
        if (spans.count > 0) {
            cache.row_dirty_span_overflow.items[row_idx] = spans.overflow;
            var span_idx: usize = 0;
            while (span_idx < spans.count) : (span_idx += 1) {
                const span = spans.spans[span_idx];
                addRowDirtySpan(cache, row_idx, span.start, span.end, cols);
            }
        }
    }
    rebuildPartialDamageFromRowSpans(cache, rows, cols);
}

pub fn hashRow(cells: []const Cell) u64 {
    var h: u64 = 1469598103934665603;
    const prime: u64 = 1099511628211;
    for (cells) |cell| {
        h = (h ^ @as(u64, cell.codepoint)) *% prime;
        h = (h ^ @as(u64, cell.combining_len)) *% prime;
        if (cell.combining_len > 0) {
            var i: usize = 0;
            while (i < cell.combining_len and i < cell.combining.len) : (i += 1) {
                h = (h ^ @as(u64, cell.combining[i])) *% prime;
            }
        }
        h = (h ^ @as(u64, cell.width)) *% prime;
        const attrs = cell.attrs;
        h = (h ^ @as(u64, attrs.fg.r)) *% prime;
        h = (h ^ @as(u64, attrs.fg.g)) *% prime;
        h = (h ^ @as(u64, attrs.fg.b)) *% prime;
        h = (h ^ @as(u64, attrs.fg.a)) *% prime;
        h = (h ^ @as(u64, attrs.bg.r)) *% prime;
        h = (h ^ @as(u64, attrs.bg.g)) *% prime;
        h = (h ^ @as(u64, attrs.bg.b)) *% prime;
        h = (h ^ @as(u64, attrs.bg.a)) *% prime;
        h = (h ^ @as(u64, attrs.underline_color.r)) *% prime;
        h = (h ^ @as(u64, attrs.underline_color.g)) *% prime;
        h = (h ^ @as(u64, attrs.underline_color.b)) *% prime;
        h = (h ^ @as(u64, attrs.underline_color.a)) *% prime;
        h = (h ^ @as(u64, @intFromBool(attrs.bold))) *% prime;
        h = (h ^ @as(u64, @intFromBool(attrs.blink))) *% prime;
        h = (h ^ @as(u64, @intFromBool(attrs.blink_fast))) *% prime;
        h = (h ^ @as(u64, @intFromBool(attrs.reverse))) *% prime;
        h = (h ^ @as(u64, @intFromBool(attrs.underline))) *% prime;
        h = (h ^ @as(u64, attrs.link_id)) *% prime;
    }
    return h;
}

test "rowDiffSpans preserves disjoint row differences" {
    const default_cell = types.default_cell;
    var new_row = [_]Cell{default_cell} ** 20;
    var old_row = [_]Cell{default_cell} ** 20;

    new_row[2].codepoint = 'A';
    new_row[3].codepoint = 'B';
    new_row[10].codepoint = 'C';
    new_row[11].codepoint = 'D';

    const spans = rowDiffSpans(new_row[0..], old_row[0..], 20);
    try std.testing.expectEqual(@as(u8, 2), spans.count);
    try std.testing.expect(!spans.overflow);
    try std.testing.expectEqual(@as(u16, 2), spans.spans[0].start);
    try std.testing.expectEqual(@as(u16, 3), spans.spans[0].end);
    try std.testing.expectEqual(@as(u16, 10), spans.spans[1].start);
    try std.testing.expectEqual(@as(u16, 11), spans.spans[1].end);
}

test "assignProjectedDiffDamage preserves disjoint row spans" {
    const allocator = std.testing.allocator;
    const render_cache = @import("render_cache.zig");
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

    for (cache.cells.items, active_cache.cells.items) |*dst, *src| {
        dst.* = default_cell;
        src.* = default_cell;
    }
    cache.cells.items[2].codepoint = 'A';
    cache.cells.items[3].codepoint = 'B';
    cache.cells.items[10].codepoint = 'C';
    cache.cells.items[11].codepoint = 'D';

    assignProjectedDiffDamage(&cache, &active_cache, 1, 20);

    try std.testing.expectEqual(screen_mod.Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(u8, 2), cache.row_dirty_span_counts.items[0]);
    try std.testing.expectEqual(@as(u16, 2), cache.row_dirty_spans.items[0][0].start);
    try std.testing.expectEqual(@as(u16, 3), cache.row_dirty_spans.items[0][0].end);
    try std.testing.expectEqual(@as(u16, 10), cache.row_dirty_spans.items[0][1].start);
    try std.testing.expectEqual(@as(u16, 11), cache.row_dirty_spans.items[0][1].end);
    try std.testing.expectEqual(@as(u16, 2), cache.dirty_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 11), cache.dirty_cols_end.items[0]);
}
