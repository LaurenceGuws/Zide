const std = @import("std");
const terminal_transport = @import("terminal_transport.zig");
const scrollback_buffer = @import("../model/scrollback_buffer.zig");
const types = @import("../model/types.zig");
const app_logger = @import("../../app_logger.zig");

const PtySize = terminal_transport.PtySize;
const Cell = types.Cell;

const RowMapEntry = struct {
    line_index: usize,
    col_offset: usize,
};

pub fn resize(self: anytype, rows: u16, cols: u16) !void {
    self.state_mutex.lock();
    try resizeLocked(self, rows, cols);
    const log = app_logger.logger("terminal.core");
    log.logf(.info, "terminal resize rows={d} cols={d} scrollback_cols={d}", .{ rows, cols, self.core.primary.grid.cols });
    const cell_width = self.cell_width;
    const cell_height = self.cell_height;
    self.state_mutex.unlock();
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        const size = PtySize{
            .rows = rows,
            .cols = cols,
            .cell_width = cell_width,
            .cell_height = cell_height,
        };
        try transport.resize(size);
    }
}

fn resizeLocked(self: anytype, rows: u16, cols: u16) !void {
    const old_cols: u16 = self.core.primary.grid.cols;
    const old_rows: u16 = self.core.primary.grid.rows;
    self.core.history.ensureViewCache(old_cols, self.core.primary.defaultCell());
    const old_history_len: usize = self.core.history.scrollbackCount();
    const old_total_lines: usize = old_history_len + @as(usize, old_rows);
    const old_scroll_offset: usize = self.core.history.scrollOffset();
    const old_cursor = self.core.primary.cursorPos();
    const old_selection = self.core.history.selectionState();

    if (cols != old_cols and cols > 0 and old_cols > 0) {
        try reflowResizePrimary(self, rows, cols, old_rows, old_cols, old_total_lines, old_scroll_offset, old_cursor, old_selection);
    } else {
        try self.core.primary.resize(rows, cols);
        try self.core.alt.resize(rows, cols);
        if (cols != old_cols) {
            try self.core.history.resizePreserve(cols, self.core.primary.defaultCell());
        }
        if (self.core.active == .alt) {
            const max_offset = self.core.history.maxScrollOffset(self.core.primary.grid.rows);
            if (self.core.history.saved_scrollback_offset > max_offset) {
                self.core.history.saved_scrollback_offset = max_offset;
            }
            self.core.history.scrollback_offset = 0;
        } else {
            self.setScrollOffsetLocked(self.core.history.scrollback_offset);
        }
    }
}

fn mapLogicalToGlobal(line_index: usize, col: usize, line_lengths: []const usize, line_row_starts: []const usize, cols: usize) ?struct { row: usize, col: usize } {
    if (line_index >= line_lengths.len or line_index >= line_row_starts.len) return null;
    const line_len = line_lengths[line_index];
    const row_start = line_row_starts[line_index];
    if (line_len == 0) return .{ .row = row_start, .col = 0 };
    const col_index = if (col >= line_len) line_len - 1 else col;
    const row_offset = col_index / cols;
    const col_in_row = col_index % cols;
    return .{ .row = row_start + row_offset, .col = col_in_row };
}

fn reflowResizePrimary(
    self: anytype,
    rows: u16,
    cols: u16,
    old_rows: u16,
    old_cols: u16,
    old_total_lines: usize,
    old_scroll_offset: usize,
    old_cursor: types.CursorPos,
    old_selection: ?types.TerminalSelection,
) !void {
    const allocator = self.allocator;
    const default_cell = self.core.primary.defaultCell();
    const old_cols_usize = @as(usize, old_cols);
    const new_cols_usize = @as(usize, cols);
    const old_history_len = self.core.history.scrollbackCount();
    const old_saved_cursor = self.core.primary.saved_cursor;

    const isBlankCell = struct {
        fn check(cell: Cell) bool {
            return cell.codepoint == 0 and cell.width == 1 and cell.height == 1 and cell.x == 0 and cell.y == 0;
        }
    }.check;

    var row_map = std.ArrayList(RowMapEntry).empty;
    defer row_map.deinit(allocator);
    try row_map.resize(allocator, old_total_lines);

    var line_cells = std.ArrayList(Cell).empty;
    defer line_cells.deinit(allocator);
    var all_cells = std.ArrayList(Cell).empty;
    defer all_cells.deinit(allocator);
    var line_starts = std.ArrayList(usize).empty;
    defer line_starts.deinit(allocator);
    var line_lengths = std.ArrayList(usize).empty;
    defer line_lengths.deinit(allocator);
    var line_wrapped = std.ArrayList(bool).empty;
    defer line_wrapped.deinit(allocator);
    const cursor_global_row = old_history_len + old_cursor.row;
    var required_len: usize = 0;

    var fallback_row = std.ArrayList(Cell).empty;
    defer fallback_row.deinit(allocator);
    try fallback_row.resize(allocator, old_cols_usize);
    for (fallback_row.items) |*cell| cell.* = default_cell;

    var line_index: usize = 0;
    var last_row_wrapped = false;
    var global_row: usize = 0;
    while (global_row < old_total_lines) : (global_row += 1) {
        const row_cells = if (global_row < old_history_len)
            self.core.history.scrollbackRow(global_row) orelse fallback_row.items
        else blk: {
            const row = global_row - old_history_len;
            const row_start = row * old_cols_usize;
            break :blk self.core.primary.grid.cells.items[row_start .. row_start + old_cols_usize];
        };
        const wrapped = if (global_row < old_history_len)
            self.core.history.scrollbackRowWrapped(global_row)
        else
            self.core.primary.grid.rowWrapped(global_row - old_history_len);
        last_row_wrapped = wrapped;

        row_map.items[global_row] = .{ .line_index = line_index, .col_offset = line_cells.items.len };
        const row_offset = row_map.items[global_row].col_offset;
        if (global_row == cursor_global_row) {
            const cursor_offset = row_offset + old_cursor.col + 1;
            if (cursor_offset > required_len) required_len = cursor_offset;
        }
        if (old_selection) |selection| {
            if (global_row == selection.start.row) {
                const sel_offset = row_offset + selection.start.col + 1;
                if (sel_offset > required_len) required_len = sel_offset;
            }
            if (global_row == selection.end.row) {
                const sel_offset = row_offset + selection.end.col + 1;
                if (sel_offset > required_len) required_len = sel_offset;
            }
        }
        var row_len: usize = old_cols_usize;
        if (!wrapped) {
            row_len = 0;
            var col: usize = old_cols_usize;
            while (col > 0) {
                col -= 1;
                const cell = row_cells[col];
                if (!isBlankCell(cell)) {
                    row_len = col + 1;
                    break;
                }
            }
        }
        if (row_len > 0) {
            try line_cells.appendSlice(allocator, row_cells[0..row_len]);
        }

        if (!wrapped) {
            if (required_len > line_cells.items.len) {
                const prev_len = line_cells.items.len;
                try line_cells.resize(allocator, required_len);
                for (line_cells.items[prev_len..required_len]) |*cell| cell.* = default_cell;
            }
            try line_starts.append(allocator, all_cells.items.len);
            try line_lengths.append(allocator, line_cells.items.len);
            try line_wrapped.append(allocator, false);
            try all_cells.appendSlice(allocator, line_cells.items);
            line_cells.clearRetainingCapacity();
            required_len = 0;
            line_index += 1;
        }
    }

    if (line_cells.items.len > 0) {
        if (required_len > line_cells.items.len) {
            const prev_len = line_cells.items.len;
            try line_cells.resize(allocator, required_len);
            for (line_cells.items[prev_len..required_len]) |*cell| cell.* = default_cell;
        }
        try line_starts.append(allocator, all_cells.items.len);
        try line_lengths.append(allocator, line_cells.items.len);
        try line_wrapped.append(allocator, last_row_wrapped);
        try all_cells.appendSlice(allocator, line_cells.items);
        line_cells.clearRetainingCapacity();
    }

    var rows_cells = std.ArrayList(Cell).empty;
    defer rows_cells.deinit(allocator);
    var rows_wraps = std.ArrayList(bool).empty;
    defer rows_wraps.deinit(allocator);
    var line_row_starts = std.ArrayList(usize).empty;
    defer line_row_starts.deinit(allocator);

    var li: usize = 0;
    while (li < line_lengths.items.len) : (li += 1) {
        try line_row_starts.append(allocator, rows_wraps.items.len);
        const line_len = line_lengths.items[li];
        if (line_len == 0) {
            const row_start = rows_cells.items.len;
            try rows_cells.resize(allocator, row_start + new_cols_usize);
            for (rows_cells.items[row_start .. row_start + new_cols_usize]) |*cell| cell.* = default_cell;
            try rows_wraps.append(allocator, line_wrapped.items[li]);
            continue;
        }
        var idx: usize = 0;
        const line_start = line_starts.items[li];
        while (idx < line_len) {
            var chunk_len = @min(new_cols_usize, line_len - idx);
            if (chunk_len == new_cols_usize and idx + chunk_len < line_len) {
                while (chunk_len > 1) {
                    const last_cell = all_cells.items[line_start + idx + chunk_len - 1];
                    const next_cell = all_cells.items[line_start + idx + chunk_len];
                    if (last_cell.width == 2 or next_cell.width == 0) {
                        chunk_len -= 1;
                        continue;
                    }
                    break;
                }
            }
            const row_start = rows_cells.items.len;
            try rows_cells.resize(allocator, row_start + new_cols_usize);
            for (rows_cells.items[row_start .. row_start + new_cols_usize]) |*cell| cell.* = default_cell;
            std.mem.copyForwards(Cell, rows_cells.items[row_start .. row_start + chunk_len], all_cells.items[line_start + idx .. line_start + idx + chunk_len]);
            const remaining = line_len - idx;
            const is_last = remaining <= chunk_len;
            try rows_wraps.append(allocator, if (is_last) line_wrapped.items[li] else true);
            idx += chunk_len;
        }
    }

    if (rows_cells.items.len > 0) {
        const total_cell_rows = rows_cells.items.len / new_cols_usize;
        var cell_idx: usize = 0;
        while (cell_idx < rows_cells.items.len) : (cell_idx += 1) {
            const cell = rows_cells.items[cell_idx];
            if (cell.height <= 1 or cell.x != 0 or cell.y != 0) continue;
            const row_idx = cell_idx / new_cols_usize;
            const col_idx = cell_idx % new_cols_usize;
            var dy: usize = 1;
            while (dy < @as(usize, cell.height)) : (dy += 1) {
                const target_row = row_idx + dy;
                if (target_row >= total_cell_rows) break;
                var dx: usize = 0;
                while (dx < @as(usize, cell.width)) : (dx += 1) {
                    const target_col = col_idx + dx;
                    if (target_col >= new_cols_usize) break;
                    const target_idx = target_row * new_cols_usize + target_col;
                    rows_cells.items[target_idx] = .{
                        .codepoint = 0,
                        .width = cell.width,
                        .height = cell.height,
                        .x = @intCast(dx),
                        .y = @intCast(dy),
                        .attrs = cell.attrs,
                    };
                }
            }
        }
    }

    const total_rows = rows_wraps.items.len;
    var effective_total_rows = total_rows;
    if (total_rows > 0) {
        var idx: isize = @as(isize, @intCast(total_rows));
        while (idx > 0) {
            idx -= 1;
            const row_idx = @as(usize, @intCast(idx));
            const row_start = row_idx * new_cols_usize;
            const row_cells = rows_cells.items[row_start .. row_start + new_cols_usize];
            var non_blank = false;
            for (row_cells) |cell| {
                if (cell.y != 0) continue;
                if (!isBlankCell(cell)) {
                    non_blank = true;
                    break;
                }
            }
            if (non_blank) {
                effective_total_rows = row_idx + 1;
                break;
            }
            if (row_idx == 0) {
                effective_total_rows = 0;
            }
        }
    }
    const max_scrollback = self.core.history.scrollbackCapacity();
    const visible_rows = @as(usize, rows);
    const keep_rows = if (effective_total_rows > max_scrollback + visible_rows) max_scrollback + visible_rows else effective_total_rows;
    const drop_rows = effective_total_rows - keep_rows;
    const scrollback_rows = if (keep_rows > visible_rows) keep_rows - visible_rows else 0;

    var new_scrollback = try scrollback_buffer.ScrollbackBuffer.init(allocator, max_scrollback);
    var row_idx: usize = 0;
    while (row_idx < scrollback_rows) : (row_idx += 1) {
        const src_row = drop_rows + row_idx;
        const src_start = src_row * new_cols_usize;
        const slice = rows_cells.items[src_start .. src_start + new_cols_usize];
        _ = try new_scrollback.pushLine(slice, rows_wraps.items[src_row]);
    }

    self.core.history.scrollback.deinit();
    self.core.history.scrollback = new_scrollback;
    self.core.history.markScrollbackChanged();

    try self.core.primary.resize(rows, cols);
    try self.core.alt.resize(rows, cols);

    row_idx = 0;
    while (row_idx < visible_rows) : (row_idx += 1) {
        const src_row = drop_rows + scrollback_rows + row_idx;
        const dest_start = row_idx * new_cols_usize;
        if (src_row < keep_rows) {
            const src_start = src_row * new_cols_usize;
            std.mem.copyForwards(Cell, self.core.primary.grid.cells.items[dest_start .. dest_start + new_cols_usize], rows_cells.items[src_start .. src_start + new_cols_usize]);
            self.core.primary.grid.setRowWrapped(row_idx, rows_wraps.items[src_row]);
        } else {
            for (self.core.primary.grid.cells.items[dest_start .. dest_start + new_cols_usize]) |*cell| cell.* = default_cell;
            self.core.primary.grid.setRowWrapped(row_idx, false);
        }
    }
    self.core.primary.grid.markDirtyAllWithReason(.resize_reflow, @src());

    const old_start_line = if (old_total_lines > @as(usize, old_rows) + old_scroll_offset)
        old_total_lines - @as(usize, old_rows) - old_scroll_offset
    else
        0;
    var new_start_line = if (keep_rows > visible_rows) keep_rows - visible_rows else 0;
    if (old_scroll_offset > 0 and old_start_line < row_map.items.len) {
        const mapping = row_map.items[old_start_line];
        if (mapLogicalToGlobal(mapping.line_index, mapping.col_offset, line_lengths.items, line_row_starts.items, new_cols_usize)) |pos| {
            if (pos.row >= drop_rows) {
                const adjusted = pos.row - drop_rows;
                if (adjusted <= keep_rows - visible_rows) {
                    new_start_line = adjusted;
                }
            }
        } else if (keep_rows > visible_rows) {
            const max_start = keep_rows - visible_rows;
            new_start_line = @min(old_start_line, max_start);
        }
    }
    const new_total_lines = scrollback_rows + visible_rows;
    var new_scroll_offset = if (new_total_lines > visible_rows) new_total_lines - visible_rows - new_start_line else 0;
    if (old_scroll_offset == 0) {
        new_scroll_offset = 0;
    }

    if (self.core.active == .alt) {
        self.core.history.scrollback_offset = 0;
    } else {
        self.core.history.scrollback_offset = new_scroll_offset;
        self.view_cache_request_offset.store(@intCast(self.core.history.scrollback_offset), .release);
        self.view_cache_pending.store(true, .release);
        self.io_wait_cond.signal();
        self.updateViewCacheForScrollLocked();
    }
    const max_offset = self.core.history.maxScrollOffset(rows);
    if (self.core.history.saved_scrollback_offset > max_offset) {
        self.core.history.saved_scrollback_offset = max_offset;
    }

    if (old_selection) |selection| {
        const start_row = selection.start.row;
        const end_row = selection.end.row;
        const start_col = selection.start.col;
        const end_col = selection.end.col;
        if (start_row < row_map.items.len and end_row < row_map.items.len) {
            const start_map = row_map.items[start_row];
            const end_map = row_map.items[end_row];
            const start_pos = mapLogicalToGlobal(start_map.line_index, start_map.col_offset + start_col, line_lengths.items, line_row_starts.items, new_cols_usize);
            const end_pos = mapLogicalToGlobal(end_map.line_index, end_map.col_offset + end_col, line_lengths.items, line_row_starts.items, new_cols_usize);
            if (start_pos != null and end_pos != null) {
                const start_global = start_pos.?;
                const end_global = end_pos.?;
                if (start_global.row >= drop_rows and end_global.row >= drop_rows) {
                    const new_start_row = start_global.row - drop_rows;
                    const new_end_row = end_global.row - drop_rows;
                    self.core.history.selection.selection.active = selection.active;
                    self.core.history.selection.selection.selecting = selection.selecting;
                    self.core.history.selection.selection.start = .{ .row = new_start_row, .col = start_global.col };
                    self.core.history.selection.selection.end = .{ .row = new_end_row, .col = end_global.col };
                } else {
                    self.core.history.clearSelection();
                }
            } else {
                self.core.history.clearSelection();
            }
        } else {
            self.core.history.clearSelection();
        }
    } else {
        self.core.history.clearSelection();
    }

    if (cursor_global_row < row_map.items.len) {
        const cursor_map = row_map.items[cursor_global_row];
        const cursor_pos = mapLogicalToGlobal(cursor_map.line_index, cursor_map.col_offset + old_cursor.col, line_lengths.items, line_row_starts.items, new_cols_usize);
        if (cursor_pos) |pos| {
            const row_after_drop = if (pos.row >= drop_rows) pos.row - drop_rows else 0;
            const screen_row = if (row_after_drop >= scrollback_rows) row_after_drop - scrollback_rows else 0;
            const clamped_row = if (screen_row >= visible_rows) visible_rows - 1 else screen_row;
            const clamped_col = if (pos.col >= new_cols_usize) new_cols_usize - 1 else pos.col;
            self.core.primary.setCursor(clamped_row, clamped_col);
        }
    }

    if (old_saved_cursor.active) {
        const saved_global_row = old_history_len + old_saved_cursor.cursor.row;
        if (saved_global_row < row_map.items.len) {
            const saved_map = row_map.items[saved_global_row];
            const saved_pos = mapLogicalToGlobal(saved_map.line_index, saved_map.col_offset + old_saved_cursor.cursor.col, line_lengths.items, line_row_starts.items, new_cols_usize);
            if (saved_pos) |pos| {
                const row_after_drop = if (pos.row >= drop_rows) pos.row - drop_rows else 0;
                const screen_row = if (row_after_drop >= scrollback_rows) row_after_drop - scrollback_rows else 0;
                const clamped_row = if (screen_row >= visible_rows) visible_rows - 1 else screen_row;
                const clamped_col = if (pos.col >= new_cols_usize) new_cols_usize - 1 else pos.col;
                self.core.primary.saved_cursor.cursor = .{ .row = clamped_row, .col = clamped_col };
            } else if (rows > 0 and cols > 0) {
                self.core.primary.saved_cursor.cursor = .{
                    .row = @min(old_saved_cursor.cursor.row, @as(usize, rows - 1)),
                    .col = @min(old_saved_cursor.cursor.col, new_cols_usize - 1),
                };
            }
        } else if (rows > 0 and cols > 0) {
            self.core.primary.saved_cursor.cursor = .{
                .row = @min(old_saved_cursor.cursor.row, @as(usize, rows - 1)),
                .col = @min(old_saved_cursor.cursor.col, new_cols_usize - 1),
            };
        }
    }

    self.core.primary.wrap_next = false;
}
