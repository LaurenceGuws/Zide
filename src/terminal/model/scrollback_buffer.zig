const std = @import("std");
const types = @import("types.zig");

pub const LogicalLine = struct {
    id: u64,
    wrapped: bool,
    cells: []types.Cell,
};

pub const ScrollbackBuffer = struct {
    allocator: std.mem.Allocator,
    lines: []LogicalLine,
    capacity: usize,
    head: usize,
    len: usize,
    next_id: u64,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !ScrollbackBuffer {
        const lines: []LogicalLine = if (capacity > 0)
            try allocator.alloc(LogicalLine, capacity)
        else
            @constCast(&[_]LogicalLine{});
        return .{
            .allocator = allocator,
            .lines = lines,
            .capacity = capacity,
            .head = 0,
            .len = 0,
            .next_id = 1,
        };
    }

    pub fn deinit(self: *ScrollbackBuffer) void {
        self.clear();
        if (self.lines.len > 0) {
            self.allocator.free(self.lines);
            self.lines = &.{};
        }
        self.capacity = 0;
        self.head = 0;
        self.len = 0;
    }

    pub fn clear(self: *ScrollbackBuffer) void {
        var idx: usize = 0;
        while (idx < self.len) : (idx += 1) {
            const slot = (self.head + idx) % self.capacity;
            self.freeLine(&self.lines[slot]);
        }
        self.head = 0;
        self.len = 0;
    }

    pub fn count(self: *const ScrollbackBuffer) usize {
        return self.len;
    }

    pub fn capacityLines(self: *const ScrollbackBuffer) usize {
        return self.capacity;
    }

    pub fn pushLine(self: *ScrollbackBuffer, cells: []const types.Cell, wrapped: bool) !u64 {
        if (self.capacity == 0) return 0;
        const id = self.next_id;
        self.next_id +|= 1;

        if (self.len == self.capacity) {
            const slot = self.head;
            self.freeLine(&self.lines[slot]);
            self.lines[slot] = .{
                .id = id,
                .wrapped = wrapped,
                .cells = try self.allocator.dupe(types.Cell, cells),
            };
            self.head = (self.head + 1) % self.capacity;
            return id;
        }

        const slot = (self.head + self.len) % self.capacity;
        self.lines[slot] = .{
            .id = id,
            .wrapped = wrapped,
            .cells = try self.allocator.dupe(types.Cell, cells),
        };
        self.len += 1;
        return id;
    }

    pub fn lineByIndex(self: *const ScrollbackBuffer, index: usize) ?*const LogicalLine {
        if (index >= self.len or self.capacity == 0) return null;
        const slot = (self.head + index) % self.capacity;
        return &self.lines[slot];
    }

    pub fn lineByIndexMut(self: *ScrollbackBuffer, index: usize) ?*LogicalLine {
        if (index >= self.len or self.capacity == 0) return null;
        const slot = (self.head + index) % self.capacity;
        return &self.lines[slot];
    }

    pub fn lineById(self: *const ScrollbackBuffer, id: u64) ?*const LogicalLine {
        var idx: usize = 0;
        while (idx < self.len) : (idx += 1) {
            const slot = (self.head + idx) % self.capacity;
            if (self.lines[slot].id == id) return &self.lines[slot];
        }
        return null;
    }

    fn freeLine(self: *ScrollbackBuffer, line: *LogicalLine) void {
        if (line.cells.len > 0) {
            self.allocator.free(line.cells);
            line.cells = &.{};
        }
        line.id = 0;
        line.wrapped = false;
    }
};
