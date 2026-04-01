const publication = @import("view_cache_publication.zig");

pub fn applySelectionDirtyExpansion(
    cache: anytype,
    active_cache: anytype,
    rows: usize,
    cols: usize,
    allow_selection_narrowing: bool,
) void {
    if (active_cache.selection_rows.items.len != rows) return;

    var row_idx: usize = 0;
    while (row_idx < rows) : (row_idx += 1) {
        const was_selected = active_cache.selection_rows.items[row_idx];
        const is_selected = cache.selection_rows.items[row_idx];
        var changed = if (allow_selection_narrowing)
            was_selected != is_selected
        else
            was_selected or is_selected;
        if (allow_selection_narrowing and !changed and is_selected and active_cache.selection_cols_start.items.len == rows and active_cache.selection_cols_end.items.len == rows) {
            changed = active_cache.selection_cols_start.items[row_idx] != cache.selection_cols_start.items[row_idx] or
                active_cache.selection_cols_end.items[row_idx] != cache.selection_cols_end.items[row_idx];
        }
        if (!changed) continue;

        publication.clearRowDirtySpans(cache, row_idx, cols);
        if (cols > 0) {
            publication.addRowDirtySpan(cache, row_idx, 0, cols - 1, cols);
        }
        publication.rebuildRowDirtyUnion(cache, row_idx, cols);
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
