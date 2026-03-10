const std = @import("std");
const types = @import("../types.zig");

pub fn eraseDisplay(self: anytype, mode: i32, blank_cell: types.Cell) void {
    const cols = @as(usize, self.grid.cols);
    const rows = @as(usize, self.grid.rows);
    if (rows == 0 or cols == 0) return;
    const row = self.cursor.row;
    const left = self.leftBoundary();
    const right = self.rightBoundary();
    const col = @min(@max(self.cursor.col, left), right);
    switch (mode) {
        0 => {
            const row_start = row * cols;
            if (col <= right) {
                self.logDirtyRangeSemanticGaps("erase_display_0_cursor_row", row, row, col, right);
                for (self.grid.cells.items[row_start + col .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                self.markDirtyRangeWithOrigin("erase_display_0_cursor_row", row, row, col, right);
            }
            var r_below = row + 1;
            while (r_below < rows) : (r_below += 1) {
                const start = r_below * cols;
                for (self.grid.cells.items[start + left .. start + right + 1]) |*cell| cell.* = blank_cell;
            }
            if (row + 1 < rows) {
                self.logDirtyRangeSemanticGaps("erase_display_0_below", row + 1, rows - 1, left, right);
                self.markDirtyRangeWithOrigin("erase_display_0_below", row + 1, rows - 1, left, right);
            }
            var r: usize = row;
            while (r < rows) : (r += 1) {
                self.grid.setRowWrapped(r, false);
            }
        },
        1 => {
            var r: usize = 0;
            while (r < row) : (r += 1) {
                const start = r * cols;
                for (self.grid.cells.items[start + left .. start + right + 1]) |*cell| cell.* = blank_cell;
            }
            if (row > 0) {
                self.logDirtyRangeSemanticGaps("erase_display_1_above", 0, row - 1, left, right);
                self.markDirtyRangeWithOrigin("erase_display_1_above", 0, row - 1, left, right);
            }
            const row_start = row * cols;
            const end_col = @min(col, right);
            if (left <= end_col) {
                self.logDirtyRangeSemanticGaps("erase_display_1_cursor_row", row, row, left, end_col);
                for (self.grid.cells.items[row_start + left .. row_start + end_col + 1]) |*cell| cell.* = blank_cell;
                self.markDirtyRangeWithOrigin("erase_display_1_cursor_row", row, row, left, end_col);
            }
            r = 0;
            while (r <= row) : (r += 1) {
                self.grid.setRowWrapped(r, false);
            }
        },
        2 => {
            self.logDirtyRangeSemanticGaps("erase_display_2", 0, rows - 1, left, right);
            if (left == 0 and right + 1 == cols) {
                for (self.grid.cells.items) |*cell| cell.* = blank_cell;
                self.grid.markDirtyRange(0, rows - 1, 0, cols - 1);
            } else {
                var r: usize = 0;
                while (r < rows) : (r += 1) {
                    const row_start = r * cols;
                    for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                }
                self.markDirtyRangeWithOrigin("erase_display_2_partial", 0, rows - 1, left, right);
            }
            for (self.grid.wrap_flags.items) |*flag| flag.* = false;
        },
        3 => {
            self.logDirtyRangeSemanticGaps("erase_display_3", 0, rows - 1, left, right);
            if (left == 0 and right + 1 == cols) {
                for (self.grid.cells.items) |*cell| cell.* = blank_cell;
                self.grid.markDirtyRange(0, rows - 1, 0, cols - 1);
            } else {
                var r: usize = 0;
                while (r < rows) : (r += 1) {
                    const row_start = r * cols;
                    for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                }
                self.markDirtyRangeWithOrigin("erase_display_3_partial", 0, rows - 1, left, right);
            }
            for (self.grid.wrap_flags.items) |*flag| flag.* = false;
        },
        else => {},
    }
}

pub fn eraseLine(self: anytype, mode: i32, blank_cell: types.Cell) void {
    const cols = @as(usize, self.grid.cols);
    if (cols == 0 or self.grid.rows == 0) return;
    if (self.cursor.row >= @as(usize, self.grid.rows)) return;
    const left = self.leftBoundary();
    const right = self.rightBoundary();
    const row_start = self.cursor.row * cols;
    const col = self.cursor.col;
    if (col < left or col > right or col >= cols) return;
    switch (mode) {
        0 => {
            self.logDirtyRangeSemanticGaps("erase_line_0", self.cursor.row, self.cursor.row, col, right);
            for (self.grid.cells.items[row_start + col .. row_start + right + 1]) |*cell| cell.* = blank_cell;
            self.markDirtyRangeWithOrigin("erase_line_0", self.cursor.row, self.cursor.row, col, right);
        },
        1 => {
            self.logDirtyRangeSemanticGaps("erase_line_1", self.cursor.row, self.cursor.row, left, col);
            for (self.grid.cells.items[row_start + left .. row_start + col + 1]) |*cell| cell.* = blank_cell;
            self.markDirtyRangeWithOrigin("erase_line_1", self.cursor.row, self.cursor.row, left, col);
        },
        2 => {
            self.logDirtyRangeSemanticGaps("erase_line_2", self.cursor.row, self.cursor.row, left, right);
            for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
            self.markDirtyRangeWithOrigin("erase_line_2", self.cursor.row, self.cursor.row, left, right);
        },
        else => {},
    }
    self.grid.setRowWrapped(self.cursor.row, false);
}

pub fn insertChars(self: anytype, count: usize, blank_cell: types.Cell) void {
    const cols = @as(usize, self.grid.cols);
    if (cols == 0) return;
    if (self.cursor.row >= @as(usize, self.grid.rows)) return;
    const left = self.leftBoundary();
    const right = self.rightBoundary();
    const col = self.cursor.col;
    if (col < left or col > right or col >= cols) return;
    const end_excl = right + 1;
    const n = @min(count, end_excl - col);
    if (n == 0) return;
    self.logDirtyRangeSemanticGaps("insert_chars", self.cursor.row, self.cursor.row, col, right);
    const row_start = self.cursor.row * cols;
    const line = self.grid.cells.items[row_start .. row_start + cols];
    if (end_excl - col > n) {
        std.mem.copyBackwards(types.Cell, line[col + n .. end_excl], line[col .. end_excl - n]);
    }
    for (line[col .. col + n]) |*cell| cell.* = blank_cell;
    self.markDirtyRangeWithOrigin("insert_chars", self.cursor.row, self.cursor.row, col, right);
}

pub fn deleteChars(self: anytype, count: usize, blank_cell: types.Cell) void {
    const cols = @as(usize, self.grid.cols);
    if (cols == 0) return;
    if (self.cursor.row >= @as(usize, self.grid.rows)) return;
    const left = self.leftBoundary();
    const right = self.rightBoundary();
    const col = self.cursor.col;
    if (col < left or col > right or col >= cols) return;
    const end_excl = right + 1;
    const n = @min(count, end_excl - col);
    if (n == 0) return;
    self.logDirtyRangeSemanticGaps("delete_chars", self.cursor.row, self.cursor.row, col, right);
    const row_start = self.cursor.row * cols;
    const line = self.grid.cells.items[row_start .. row_start + cols];
    if (end_excl - col > n) {
        std.mem.copyForwards(types.Cell, line[col .. end_excl - n], line[col + n .. end_excl]);
    }
    for (line[end_excl - n .. end_excl]) |*cell| cell.* = blank_cell;
    self.markDirtyRangeWithOrigin("delete_chars", self.cursor.row, self.cursor.row, col, right);
}

pub fn eraseChars(self: anytype, count: usize, blank_cell: types.Cell) void {
    const cols = @as(usize, self.grid.cols);
    if (cols == 0) return;
    if (self.cursor.row >= @as(usize, self.grid.rows)) return;
    const left = self.leftBoundary();
    const right = self.rightBoundary();
    const col = self.cursor.col;
    if (col < left or col > right or col >= cols) return;
    const end_excl = right + 1;
    const n = @min(count, end_excl - col);
    if (n == 0) return;
    self.logDirtyRangeSemanticGaps("erase_chars", self.cursor.row, self.cursor.row, col, col + n - 1);
    const row_start = self.cursor.row * cols;
    const line = self.grid.cells.items[row_start .. row_start + cols];
    for (line[col .. col + n]) |*cell| cell.* = blank_cell;
    self.markDirtyRangeWithOrigin("erase_chars", self.cursor.row, self.cursor.row, col, col + n - 1);
}

pub fn insertLines(self: anytype, count: usize, blank_cell: types.Cell) void {
    const cols = @as(usize, self.grid.cols);
    const rows = @as(usize, self.grid.rows);
    if (rows == 0 or cols == 0) return;
    if (self.cursor.row < self.scroll_top or self.cursor.row > self.scroll_bottom) return;
    if (self.left_right_margin_mode_69 and (self.cursor.col < self.leftBoundary() or self.cursor.col > self.rightBoundary())) return;
    const n = @min(count, self.scroll_bottom - self.cursor.row + 1);
    self.logDirtyRangeSemanticGaps("insert_lines", self.cursor.row, self.scroll_bottom, self.leftBoundary(), self.rightBoundary());
    if (self.left_right_margin_mode_69) {
        const left = self.leftBoundary();
        const right = self.rightBoundary();
        var row = self.scroll_bottom;
        while (true) {
            const row_start = row * cols;
            if (row >= self.cursor.row + n) {
                const src_row = row - n;
                const src_start = src_row * cols;
                std.mem.copyForwards(types.Cell, self.grid.cells.items[row_start + left .. row_start + right + 1], self.grid.cells.items[src_start + left .. src_start + right + 1]);
            } else {
                for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
            }
            self.grid.setRowWrapped(row, false);
            if (row == self.cursor.row) break;
            row -= 1;
        }
        self.markDirtyRangeWithOrigin("insert_lines_margin", self.cursor.row, self.scroll_bottom, left, right);
        return;
    }
    const region_end = (self.scroll_bottom + 1) * cols;
    const insert_at = self.cursor.row * cols;
    const move_len = region_end - insert_at - n * cols;
    if (move_len > 0) {
        std.mem.copyBackwards(types.Cell, self.grid.cells.items[insert_at + n * cols .. region_end], self.grid.cells.items[insert_at .. insert_at + move_len]);
    }
    for (self.grid.cells.items[insert_at .. insert_at + n * cols]) |*cell| cell.* = blank_cell;
    var row = self.scroll_bottom;
    while (row >= self.cursor.row + n) : (row -= 1) {
        self.grid.setRowWrapped(row, self.grid.rowWrapped(row - n));
        if (row == 0) break;
    }
    row = self.cursor.row;
    while (row < self.cursor.row + n and row <= self.scroll_bottom) : (row += 1) {
        self.grid.setRowWrapped(row, false);
    }
    self.markDirtyRangeWithOrigin("insert_lines_full", self.cursor.row, self.scroll_bottom, 0, cols - 1);
}

pub fn deleteLines(self: anytype, count: usize, blank_cell: types.Cell) void {
    const cols = @as(usize, self.grid.cols);
    const rows = @as(usize, self.grid.rows);
    if (rows == 0 or cols == 0) return;
    if (self.cursor.row < self.scroll_top or self.cursor.row > self.scroll_bottom) return;
    if (self.left_right_margin_mode_69 and (self.cursor.col < self.leftBoundary() or self.cursor.col > self.rightBoundary())) return;
    const n = @min(count, self.scroll_bottom - self.cursor.row + 1);
    self.logDirtyRangeSemanticGaps("delete_lines", self.cursor.row, self.scroll_bottom, self.leftBoundary(), self.rightBoundary());
    if (self.left_right_margin_mode_69) {
        const left = self.leftBoundary();
        const right = self.rightBoundary();
        var row = self.cursor.row;
        while (row <= self.scroll_bottom) : (row += 1) {
            const row_start = row * cols;
            if (row + n <= self.scroll_bottom) {
                const src_row = row + n;
                const src_start = src_row * cols;
                std.mem.copyForwards(types.Cell, self.grid.cells.items[row_start + left .. row_start + right + 1], self.grid.cells.items[src_start + left .. src_start + right + 1]);
            } else {
                for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
            }
            self.grid.setRowWrapped(row, false);
        }
        self.markDirtyRangeWithOrigin("delete_lines_margin", self.cursor.row, self.scroll_bottom, left, right);
        return;
    }
    const region_end = (self.scroll_bottom + 1) * cols;
    const delete_at = self.cursor.row * cols;
    const move_len = region_end - delete_at - n * cols;
    if (move_len > 0) {
        std.mem.copyForwards(types.Cell, self.grid.cells.items[delete_at .. delete_at + move_len], self.grid.cells.items[delete_at + n * cols .. region_end]);
    }
    for (self.grid.cells.items[region_end - n * cols .. region_end]) |*cell| cell.* = blank_cell;
    var row = self.cursor.row;
    while (row + n <= self.scroll_bottom) : (row += 1) {
        self.grid.setRowWrapped(row, self.grid.rowWrapped(row + n));
    }
    row = self.scroll_bottom + 1 - n;
    while (row <= self.scroll_bottom) : (row += 1) {
        self.grid.setRowWrapped(row, false);
    }
    self.markDirtyRangeWithOrigin("delete_lines_full", self.cursor.row, self.scroll_bottom, 0, cols - 1);
}

pub fn scrollRegionUpBy(self: anytype, n: usize, blank_cell: types.Cell) void {
    const cols = @as(usize, self.grid.cols);
    if (cols == 0 or self.grid.rows == 0) return;
    if (n == 0) return;
    self.logDirtyRangeSemanticGaps("scroll_region_up", self.scroll_top, self.scroll_bottom, self.leftBoundary(), self.rightBoundary());
    if (self.left_right_margin_mode_69) {
        const left = self.leftBoundary();
        const right = self.rightBoundary();
        var row = self.scroll_top;
        while (row <= self.scroll_bottom) : (row += 1) {
            const row_start = row * cols;
            if (row + n <= self.scroll_bottom) {
                const src_row = row + n;
                const src_start = src_row * cols;
                std.mem.copyForwards(types.Cell, self.grid.cells.items[row_start + left .. row_start + right + 1], self.grid.cells.items[src_start + left .. src_start + right + 1]);
            } else {
                for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
            }
            self.grid.setRowWrapped(row, false);
        }
        self.markDirtyRangeWithOrigin("scroll_region_up_margin", self.scroll_top, self.scroll_bottom, left, right);
        return;
    }
    const region_start = self.scroll_top * cols;
    const region_end = (self.scroll_bottom + 1) * cols;
    const move_len = region_end - region_start - n * cols;
    if (move_len > 0) {
        std.mem.copyForwards(types.Cell, self.grid.cells.items[region_start .. region_start + move_len], self.grid.cells.items[region_start + n * cols .. region_end]);
    }
    for (self.grid.cells.items[region_end - n * cols .. region_end]) |*cell| cell.* = blank_cell;
    const start_row = self.scroll_top;
    const end_row = self.scroll_bottom;
    if (start_row <= end_row and n > 0) {
        var row = start_row;
        while (row + n <= end_row) : (row += 1) {
            self.grid.setRowWrapped(row, self.grid.rowWrapped(row + n));
        }
        row = end_row + 1 - n;
        while (row <= end_row) : (row += 1) {
            self.grid.setRowWrapped(row, false);
        }
    }
    self.markDirtyRangeWithOrigin("scroll_region_up_full", self.scroll_top, self.scroll_bottom, 0, cols - 1);
}

pub fn scrollRegionUp(self: anytype, count: usize, blank_cell: types.Cell) usize {
    const cols = @as(usize, self.grid.cols);
    if (cols == 0 or self.grid.rows == 0) return 0;
    const n = @min(count, self.scroll_bottom - self.scroll_top + 1);
    if (n == 0) return 0;
    scrollRegionUpBy(self, n, blank_cell);
    return n;
}

pub fn scrollRegionDownBy(self: anytype, n: usize, blank_cell: types.Cell) void {
    const cols = @as(usize, self.grid.cols);
    if (cols == 0 or self.grid.rows == 0) return;
    if (n == 0) return;
    self.logDirtyRangeSemanticGaps("scroll_region_down", self.scroll_top, self.scroll_bottom, self.leftBoundary(), self.rightBoundary());
    if (self.left_right_margin_mode_69) {
        const left = self.leftBoundary();
        const right = self.rightBoundary();
        var row = self.scroll_bottom;
        while (true) {
            const row_start = row * cols;
            if (row >= self.scroll_top + n) {
                const src_row = row - n;
                const src_start = src_row * cols;
                std.mem.copyForwards(types.Cell, self.grid.cells.items[row_start + left .. row_start + right + 1], self.grid.cells.items[src_start + left .. src_start + right + 1]);
            } else {
                for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
            }
            self.grid.setRowWrapped(row, false);
            if (row == self.scroll_top) break;
            row -= 1;
        }
        self.markDirtyRangeWithOrigin("scroll_region_down_margin", self.scroll_top, self.scroll_bottom, left, right);
        return;
    }
    const region_start = self.scroll_top * cols;
    const region_end = (self.scroll_bottom + 1) * cols;
    const move_len = region_end - region_start - n * cols;
    if (move_len > 0) {
        std.mem.copyBackwards(types.Cell, self.grid.cells.items[region_start + n * cols .. region_end], self.grid.cells.items[region_start .. region_start + move_len]);
    }
    for (self.grid.cells.items[region_start .. region_start + n * cols]) |*cell| cell.* = blank_cell;
    const start_row = self.scroll_top;
    const end_row = self.scroll_bottom;
    if (start_row <= end_row and n > 0) {
        var row = end_row;
        while (row >= start_row + n) : (row -= 1) {
            self.grid.setRowWrapped(row, self.grid.rowWrapped(row - n));
            if (row == 0) break;
        }
        row = start_row;
        while (row < start_row + n and row <= end_row) : (row += 1) {
            self.grid.setRowWrapped(row, false);
        }
    }
    self.markDirtyRangeWithOrigin("scroll_region_down_full", self.scroll_top, self.scroll_bottom, 0, cols - 1);
}

pub fn scrollRegionDown(self: anytype, count: usize, blank_cell: types.Cell) usize {
    const cols = @as(usize, self.grid.cols);
    if (cols == 0 or self.grid.rows == 0) return 0;
    const n = @min(count, self.scroll_bottom - self.scroll_top + 1);
    if (n == 0) return 0;
    scrollRegionDownBy(self, n, blank_cell);
    return n;
}

pub fn scrollUp(self: anytype, blank_cell: types.Cell) void {
    const cols = @as(usize, self.grid.cols);
    const rows = @as(usize, self.grid.rows);
    if (rows == 0 or cols == 0) return;
    self.logDirtyRangeSemanticGaps("scroll_up", 0, rows - 1, 0, cols - 1);
    const total = rows * cols;
    const row_bytes = cols * @sizeOf(types.Cell);
    const src = @as([*]u8, @ptrCast(self.grid.cells.items.ptr));
    std.mem.copyForwards(u8, src[0 .. total * @sizeOf(types.Cell) - row_bytes], src[row_bytes .. total * @sizeOf(types.Cell)]);

    const row_start = (rows - 1) * cols;
    for (self.grid.cells.items[row_start .. row_start + cols]) |*cell| {
        cell.* = blank_cell;
    }
    if (rows > 1) {
        var row: usize = 0;
        while (row + 1 < rows) : (row += 1) {
            self.grid.setRowWrapped(row, self.grid.rowWrapped(row + 1));
        }
    }
    if (rows > 0) {
        self.grid.setRowWrapped(rows - 1, false);
    }
    self.cursor.row = rows - 1;
    self.cursor.col = 0;
    self.markDirtyRangeWithOrigin("scroll_up_full", 0, rows - 1, 0, cols - 1);
}
