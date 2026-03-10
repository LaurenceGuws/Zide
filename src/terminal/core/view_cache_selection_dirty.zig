pub fn applySelectionDirtyExpansion(
    cache: anytype,
    active_cache: anytype,
    rows: usize,
    cols: usize,
    fullwidth_origin_log: anytype,
) void {
    if (active_cache.selection_rows.items.len != rows) return;

    var row_idx: usize = 0;
    while (row_idx < rows) : (row_idx += 1) {
        const was_selected = active_cache.selection_rows.items[row_idx];
        const is_selected = cache.selection_rows.items[row_idx];
        var changed = was_selected != is_selected;
        if (!changed and is_selected and active_cache.selection_cols_start.items.len == rows and active_cache.selection_cols_end.items.len == rows) {
            changed = active_cache.selection_cols_start.items[row_idx] != cache.selection_cols_start.items[row_idx] or
                active_cache.selection_cols_end.items[row_idx] != cache.selection_cols_end.items[row_idx];
        }
        if (!changed) continue;

        cache.dirty_rows.items[row_idx] = true;
        cache.dirty_cols_start.items[row_idx] = 0;
        cache.dirty_cols_end.items[row_idx] = if (cols > 0) @intCast(cols - 1) else 0;
        fullwidth_origin_log.logf(
            .info,
            "source=view_cache row={d} reason=selection_change cols=0..{d} was_selected={d} is_selected={d} rows={d} cols={d}",
            .{
                row_idx,
                if (cols > 0) cols - 1 else 0,
                @intFromBool(was_selected),
                @intFromBool(is_selected),
                rows,
                cols,
            },
        );
        if (cache.dirty == .none) {
            cache.dirty = .partial;
            cache.damage = .{
                .start_row = row_idx,
                .end_row = row_idx,
                .start_col = 0,
                .end_col = if (cols > 0) cols - 1 else 0,
            };
        } else if (cache.dirty != .full) {
            cache.damage.start_row = @min(cache.damage.start_row, row_idx);
            cache.damage.end_row = @max(cache.damage.end_row, row_idx);
            cache.damage.start_col = 0;
            cache.damage.end_col = if (cols > 0) cols - 1 else 0;
        }
    }
}
