const publication = @import("view_cache_publication.zig");

pub fn refineRowHashDamage(
    cache: anytype,
    active_cache: anytype,
    rows: usize,
    cols: usize,
    fullwidth_origin_log: anytype,
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
        const hash_changed = hash_now != active_cache.row_hashes.items[row_idx];
        cache.dirty_rows.items[row_idx] = hash_changed;
        if (hash_changed) {
            if (publication.rowDiffSpan(row_cells, old_row_cells, cols)) |span| {
                cache.dirty_cols_start.items[row_idx] = @intCast(span.start);
                cache.dirty_cols_end.items[row_idx] = @intCast(span.end);
            } else {
                cache.dirty_rows.items[row_idx] = false;
                continue;
            }
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
            cache.dirty_rows.items[row_idx] = true;
            any_dirty = true;
        }
    }
    if (!any_dirty) {
        cache.dirty = .none;
        return;
    }

    var first_dirty = true;
    row_idx = 0;
    while (row_idx < rows) : (row_idx += 1) {
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
}
