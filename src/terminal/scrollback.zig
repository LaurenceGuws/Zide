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
