const std = @import("std");

pub const EditorDrawList = struct {
    allocator: std.mem.Allocator,
    ops: std.ArrayList(DrawOp),

    pub fn init(allocator: std.mem.Allocator) EditorDrawList {
        return .{
            .allocator = allocator,
            .ops = std.ArrayList(DrawOp).empty,
        };
    }

    pub fn deinit(self: *EditorDrawList) void {
        self.ops.deinit(self.allocator);
    }

    pub fn clear(self: *EditorDrawList) void {
        self.ops.clearRetainingCapacity();
    }

    pub fn add(self: *EditorDrawList, op: DrawOp) !void {
        try self.ops.append(self.allocator, op);
    }
};

pub const DrawOp = union(enum) {
    text: TextOp,
    rect: RectOp,
    cursor: CursorOp,
};

pub const TextOp = struct {
    x: f32,
    y: f32,
    text: []const u8,
    color: u32,
    bg_color: u32,
    disable_programming_ligatures: bool,
};

pub const RectOp = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    color: u32,
};

pub const CursorOp = struct {
    x: f32,
    y: f32,
    h: f32,
    color: u32,
};
