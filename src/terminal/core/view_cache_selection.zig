const types = @import("../model/types.zig");
const publication = @import("view_cache_publication.zig");

const Cell = types.Cell;

pub fn projectSelection(
    self: anytype,
    cache: anytype,
    total_lines: usize,
    start_line: usize,
    rows: usize,
    cols: usize,
    selection_active: bool,
) void {
    if (self.core.active == .alt) {
        for (cache.selection_rows.items) |*row_selected| {
            row_selected.* = false;
        }
        cache.selection_active = selection_active;
    } else if (self.core.history.selectionState()) |selection| {
        cache.selection_active = selection_active;
        var start_sel = selection.start;
        var end_sel = selection.end;
        if (start_sel.row > end_sel.row or (start_sel.row == end_sel.row and start_sel.col > end_sel.col)) {
            const tmp = start_sel;
            start_sel = end_sel;
            end_sel = tmp;
        }
        const total_lines_sel = total_lines;
        if (total_lines_sel > 0) {
            start_sel.row = @min(start_sel.row, total_lines_sel - 1);
            end_sel.row = @min(end_sel.row, total_lines_sel - 1);
            start_sel.col = @min(start_sel.col, cols - 1);
            end_sel.col = @min(end_sel.col, cols - 1);
        } else {
            start_sel.row = 0;
            end_sel.row = 0;
            start_sel.col = 0;
            end_sel.col = 0;
        }

        var row: usize = 0;
        while (row < rows) : (row += 1) {
            const global_row = start_line + row;
            const row_start = row * cols;
            const row_cells: []const Cell = cache.cells.items[row_start .. row_start + cols];
            const last_content_col = publication.rowLastContentCol(row_cells, cols);
            if (global_row < start_sel.row or global_row > end_sel.row) {
                cache.selection_rows.items[row] = false;
                continue;
            }
            const col_start = if (global_row == start_sel.row) start_sel.col else 0;
            const col_end = if (global_row == end_sel.row) end_sel.col else cols - 1;
            if (last_content_col == null) {
                cache.selection_rows.items[row] = false;
                continue;
            }
            const clamped_end = @min(col_end, last_content_col.?);
            if (clamped_end < col_start) {
                cache.selection_rows.items[row] = false;
                continue;
            }
            cache.selection_rows.items[row] = true;
            cache.selection_cols_start.items[row] = @intCast(col_start);
            cache.selection_cols_end.items[row] = @intCast(clamped_end);
        }
    } else {
        for (cache.selection_rows.items) |*row_selected| {
            row_selected.* = false;
        }
        cache.selection_active = selection_active;
    }
}
