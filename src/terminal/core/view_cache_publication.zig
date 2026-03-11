const std = @import("std");
const types = @import("../model/types.zig");
const screen_mod = @import("../model/screen.zig");

const Cell = types.Cell;
const FullDirtyReason = screen_mod.FullDirtyReason;

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

pub fn assignProjectedDiffDamage(cache: anytype, active_cache: anytype, rows: usize, cols: usize) void {
    var first_dirty = true;
    var row_idx: usize = 0;
    while (row_idx < rows) : (row_idx += 1) {
        const row_start = row_idx * cols;
        const row_cells = cache.cells.items[row_start .. row_start + cols];
        const old_row_cells = active_cache.cells.items[row_start .. row_start + cols];
        if (rowDiffSpan(row_cells, old_row_cells, cols)) |span| {
            cache.dirty_rows.items[row_idx] = true;
            cache.dirty_cols_start.items[row_idx] = @intCast(span.start);
            cache.dirty_cols_end.items[row_idx] = @intCast(span.end);
            if (first_dirty) {
                cache.damage = .{
                    .start_row = row_idx,
                    .end_row = row_idx,
                    .start_col = span.start,
                    .end_col = span.end,
                };
                first_dirty = false;
            } else {
                cache.damage.start_row = @min(cache.damage.start_row, row_idx);
                cache.damage.end_row = @max(cache.damage.end_row, row_idx);
                cache.damage.start_col = @min(cache.damage.start_col, span.start);
                cache.damage.end_col = @max(cache.damage.end_col, span.end);
            }
        } else {
            cache.dirty_rows.items[row_idx] = false;
        }
    }

    if (first_dirty) {
        cache.dirty = .none;
        cache.damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
    } else {
        cache.dirty = .partial;
    }
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
