const std = @import("std");
const types = @import("../../model/types.zig");
const selection_mod = @import("../selection.zig");
const scrollback_view = @import("../scrollback_view.zig");

const Cell = types.Cell;

fn rowLastContentCol(row_cells: []const Cell, cols_count: usize) ?usize {
    if (cols_count == 0 or row_cells.len < cols_count) return null;
    var last: ?usize = null;
    var col_idx: usize = 0;
    while (col_idx < cols_count) : (col_idx += 1) {
        const cell = row_cells[col_idx];
        if (cell.x != 0 or cell.y != 0) continue;
        if (cell.codepoint == 0 and cell.combining_len == 0) continue;
        const width_units = @as(usize, @max(@as(u8, 1), cell.width));
        const end_col = @min(cols_count - 1, col_idx + width_units - 1);
        last = end_col;
    }
    return last;
}

fn appendCellText(out: *std.ArrayList(u8), allocator: std.mem.Allocator, cell: Cell) !void {
    if (cell.x != 0 or cell.y != 0) return;
    if (cell.codepoint == 0) {
        try out.append(allocator, ' ');
        return;
    }

    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(@intCast(cell.codepoint), &buf) catch 0;
    if (len > 0) try out.appendSlice(allocator, buf[0..len]);

    if (cell.combining_len > 0) {
        var ci: usize = 0;
        while (ci < @as(usize, @intCast(cell.combining_len)) and ci < cell.combining.len) : (ci += 1) {
            const cp = cell.combining[ci];
            const c_len = std.unicode.utf8Encode(@intCast(cp), &buf) catch 0;
            if (c_len > 0) try out.appendSlice(allocator, buf[0..c_len]);
        }
    }
}

fn appendSelectionRange(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    row_cells: []const Cell,
    cols: usize,
    col_start: usize,
    col_end: usize,
) !void {
    const last_content_col = rowLastContentCol(row_cells, cols) orelse return;
    const clamped_end = @min(col_end, last_content_col);
    if (clamped_end < col_start) return;

    var col_idx: usize = col_start;
    while (col_idx <= clamped_end and col_idx < cols) : (col_idx += 1) {
        try appendCellText(out, allocator, row_cells[col_idx]);
    }

    while (out.items.len > 0 and out.items[out.items.len - 1] == ' ') {
        _ = out.pop();
    }
}

fn visibleRow(self: anytype, cells: []const Cell, rows: usize, cols: usize, history: usize, line_idx: usize) ?[]const Cell {
    if (line_idx < history) return scrollback_view.scrollbackRow(self, line_idx);
    const grid_row = line_idx - history;
    if (grid_row >= rows or cols == 0) return null;
    const row_start = grid_row * cols;
    return cells[row_start .. row_start + cols];
}

pub fn selectionPlainTextAlloc(self: anytype, allocator: std.mem.Allocator) !?[]u8 {
    self.lock();
    defer self.unlock();

    const selection = selection_mod.selectionState(self) orelse return null;
    const screen = self.core.activeScreenConst();
    const view = screen.snapshotView();
    const rows = view.rows;
    const cols = view.cols;
    const history = scrollback_view.scrollbackCount(self);
    const total_lines = history + rows;
    if (rows == 0 or cols == 0 or total_lines == 0) return null;

    var start_sel = selection.start;
    var end_sel = selection.end;
    if (start_sel.row > end_sel.row or (start_sel.row == end_sel.row and start_sel.col > end_sel.col)) {
        const tmp = start_sel;
        start_sel = end_sel;
        end_sel = tmp;
    }
    start_sel.row = @min(start_sel.row, total_lines - 1);
    end_sel.row = @min(end_sel.row, total_lines - 1);
    start_sel.col = @min(start_sel.col, cols - 1);
    end_sel.col = @min(end_sel.col, cols - 1);

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var row_idx: usize = start_sel.row;
    while (row_idx <= end_sel.row and row_idx < total_lines) : (row_idx += 1) {
        const row_cells = visibleRow(self, view.cells, rows, cols, history, row_idx) orelse continue;
        const col_start = if (row_idx == start_sel.row) start_sel.col else 0;
        const col_end = if (row_idx == end_sel.row) end_sel.col else cols - 1;
        try appendSelectionRange(&out, allocator, row_cells, cols, col_start, col_end);
        if (row_idx != end_sel.row) try out.append(allocator, '\n');
    }

    const text = try out.toOwnedSlice(allocator);
    return text;
}
