const std = @import("std");

pub const BufferKind = enum(u8) {
    original,
    add,
};

pub const Leaf = struct {
    buffer: BufferKind,
    start: usize,
    len: usize,
};

pub const Node = struct {
    left: ?*Node,
    right: ?*Node,
    leaf: ?Leaf,
    byte_len: usize,
    line_breaks: usize,
    height: u8,
};

pub const Rope = struct {
    allocator: std.mem.Allocator,
    root: ?*Node,
    original: []const u8,
    add: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, initial: []const u8) !*Rope {
        var rope = try allocator.create(Rope);
        rope.* = .{
            .allocator = allocator,
            .root = null,
            .original = try allocator.dupe(u8, initial),
            .add = .{},
        };
        if (initial.len > 0) {
            // TODO: build initial leaf + root with aggregates.
        }
        return rope;
    }

    pub fn deinit(self: *Rope) void {
        if (self.original.len > 0) {
            self.allocator.free(self.original);
        }
        self.add.deinit(self.allocator);
        // TODO: free tree nodes.
        self.allocator.destroy(self);
    }

    pub fn totalLen(self: *Rope) usize {
        if (self.root) |root| return root.byte_len;
        return 0;
    }

    pub fn insert(self: *Rope, offset: usize, data: []const u8) !void {
        _ = self;
        _ = offset;
        _ = data;
        return error.Unimplemented;
    }

    pub fn deleteRange(self: *Rope, start: usize, len: usize) !void {
        _ = self;
        _ = start;
        _ = len;
        return error.Unimplemented;
    }

    pub fn readRange(self: *Rope, start: usize, out: []u8) usize {
        _ = self;
        _ = start;
        _ = out;
        return 0;
    }

    pub fn lineCount(self: *Rope) usize {
        if (self.root) |root| return root.line_breaks + 1;
        return 1;
    }

    pub fn lineStart(self: *Rope, line_index: usize) usize {
        _ = self;
        _ = line_index;
        return 0;
    }
};
