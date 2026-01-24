const std = @import("std");

pub const TabStops = struct {
    allocator: std.mem.Allocator,
    stops: std.ArrayList(bool),

    pub fn init(allocator: std.mem.Allocator, cols: u16) !TabStops {
        var stops = std.ArrayList(bool).empty;
        try stops.resize(allocator, cols);
        var tabstops = TabStops{
            .allocator = allocator,
            .stops = stops,
        };
        tabstops.reset();
        return tabstops;
    }

    pub fn deinit(self: *TabStops) void {
        self.stops.deinit(self.allocator);
    }

    pub fn resize(self: *TabStops, cols: u16) !void {
        const old_len = self.stops.items.len;
        try self.stops.resize(self.allocator, cols);
        if (cols > old_len) {
            var idx: usize = old_len;
            while (idx < cols) : (idx += 1) {
                self.stops.items[idx] = TabStops.defaultStop(idx);
            }
        }
    }

    pub fn reset(self: *TabStops) void {
        for (self.stops.items, 0..) |*stop, idx| {
            stop.* = TabStops.defaultStop(idx);
        }
    }

    pub fn next(self: *const TabStops, col: usize, max_col: usize) usize {
        if (self.stops.items.len == 0) return col;
        var idx = col + 1;
        const limit = @min(max_col, self.stops.items.len - 1);
        while (idx <= limit) : (idx += 1) {
            if (self.stops.items[idx]) return idx;
        }
        return max_col;
    }

    fn defaultStop(col: usize) bool {
        return (col % 8) == 0;
    }
};
