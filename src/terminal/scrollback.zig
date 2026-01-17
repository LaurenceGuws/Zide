const std = @import("std");

pub fn Scrollback(comptime CellType: type) type {
    return struct {
        allocator: std.mem.Allocator,
        cols: u16,
        max_rows: usize,
        start: usize,
        len: usize,
        rows: std.ArrayList(CellType),

        pub fn init(allocator: std.mem.Allocator, max_rows: usize, cols: u16) !@This() {
            var rows = std.ArrayList(CellType).empty;
            if (max_rows > 0 and cols > 0) {
                const cell_count = max_rows * @as(usize, cols);
                try rows.resize(allocator, cell_count);
            }
            return .{
                .allocator = allocator,
                .cols = cols,
                .max_rows = max_rows,
                .start = 0,
                .len = 0,
                .rows = rows,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.rows.deinit(self.allocator);
        }

        pub fn reset(self: *@This()) void {
            self.start = 0;
            self.len = 0;
        }

        pub fn resize(self: *@This(), cols: u16) !void {
            if (self.cols == cols) return;
            self.cols = cols;
            self.reset();
            if (self.max_rows == 0 or cols == 0) {
                self.rows.deinit(self.allocator);
                self.rows = std.ArrayList(CellType).empty;
                return;
            }
            const cell_count = self.max_rows * @as(usize, cols);
            try self.rows.resize(self.allocator, cell_count);
        }

        pub fn resizePreserve(self: *@This(), cols: u16, default_cell: CellType) !void {
            if (self.cols == cols) return;

            if (self.max_rows == 0 or cols == 0) {
                self.cols = cols;
                self.reset();
                self.rows.deinit(self.allocator);
                self.rows = std.ArrayList(CellType).empty;
                return;
            }

            const old_cols = self.cols;
            const old_len = self.len;

            var new_rows = std.ArrayList(CellType).empty;
            const cell_count = self.max_rows * @as(usize, cols);
            try new_rows.resize(self.allocator, cell_count);

            // Preserve row order (oldest -> newest) starting at index 0.
            if (old_len > 0 and old_cols > 0 and self.rows.items.len > 0) {
                const copy_cols = @min(@as(usize, old_cols), @as(usize, cols));
                var row_idx: usize = 0;
                while (row_idx < old_len and row_idx < self.max_rows) : (row_idx += 1) {
                    const old_row = self.rowSlice(row_idx) orelse break;
                    const new_offset = row_idx * @as(usize, cols);
                    std.mem.copyForwards(CellType, new_rows.items[new_offset .. new_offset + copy_cols], old_row[0..copy_cols]);
                    if (cols > copy_cols) {
                        for (new_rows.items[new_offset + copy_cols .. new_offset + @as(usize, cols)]) |*cell| {
                            cell.* = default_cell;
                        }
                    }
                }
                // Initialize any remaining rows with default cells.
                if (old_len < self.max_rows) {
                    var fill_row: usize = old_len;
                    while (fill_row < self.max_rows) : (fill_row += 1) {
                        const offset = fill_row * @as(usize, cols);
                        for (new_rows.items[offset .. offset + @as(usize, cols)]) |*cell| {
                            cell.* = default_cell;
                        }
                    }
                }
            } else {
                for (new_rows.items) |*cell| {
                    cell.* = default_cell;
                }
            }

            self.rows.deinit(self.allocator);
            self.rows = new_rows;
            self.cols = cols;
            self.start = 0;
            self.len = old_len;
        }

        pub fn pushRow(self: *@This(), row: []const CellType) void {
            if (self.max_rows == 0 or self.cols == 0) return;
            if (row.len != @as(usize, self.cols)) return;
            if (self.rows.items.len == 0) return;

            const idx = if (self.len < self.max_rows)
                (self.start + self.len) % self.max_rows
            else blk: {
                const drop_idx = self.start;
                self.start = (self.start + 1) % self.max_rows;
                break :blk drop_idx;
            };

            const offset = idx * @as(usize, self.cols);
            std.mem.copyForwards(CellType, self.rows.items[offset .. offset + @as(usize, self.cols)], row);
            if (self.len < self.max_rows) self.len += 1;
        }

        pub fn rowSlice(self: *@This(), index: usize) ?[]const CellType {
            if (index >= self.len) return null;
            const idx = (self.start + index) % self.max_rows;
            const offset = idx * @as(usize, self.cols);
            return self.rows.items[offset .. offset + @as(usize, self.cols)];
        }

        pub fn count(self: *@This()) usize {
            return self.len;
        }
    };
}
