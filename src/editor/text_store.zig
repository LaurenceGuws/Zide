const std = @import("std");
const rope_mod = @import("rope.zig");

pub const TextStore = struct {
    allocator: std.mem.Allocator,
    rope: *rope_mod.Rope,

    pub fn init(allocator: std.mem.Allocator, initial: []const u8) !*TextStore {
        const store = try allocator.create(TextStore);
        store.* = .{
            .allocator = allocator,
            .rope = try rope_mod.Rope.init(allocator, initial),
        };
        return store;
    }

    pub fn initFromFile(allocator: std.mem.Allocator, path: []const u8) !*TextStore {
        const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
        defer file.close();
        const stat = try file.stat();
        const data = try file.readToEndAlloc(allocator, @as(usize, @intCast(stat.size)));
        defer allocator.free(data);
        return init(allocator, data);
    }

    pub fn deinit(self: *TextStore) void {
        self.rope.deinit();
        self.allocator.destroy(self);
    }

    pub fn totalLen(self: *TextStore) usize {
        return self.rope.totalLen();
    }

    pub fn insertBytes(self: *TextStore, pos: usize, data: []const u8) !void {
        try self.rope.insert(pos, data);
    }

    pub fn deleteRange(self: *TextStore, start: usize, len: usize) !void {
        try self.rope.deleteRange(start, len);
    }

    pub fn readRange(self: *TextStore, start: usize, out: []u8) usize {
        return self.rope.readRange(start, out);
    }

    pub fn readRangeAlloc(self: *TextStore, start: usize, len: usize) ![]u8 {
        return self.rope.readRangeAlloc(start, len);
    }

    pub fn lineCount(self: *TextStore) usize {
        return self.rope.lineCount();
    }

    pub fn lineStart(self: *TextStore, line_index: usize) usize {
        return self.rope.lineStart(line_index);
    }

    pub fn lineLen(self: *TextStore, line_index: usize) usize {
        return self.rope.lineLen(line_index);
    }

    pub fn lineIndexForOffset(self: *TextStore, offset: usize) usize {
        return self.rope.lineIndexForOffset(offset);
    }

    pub fn readLine(self: *TextStore, line_index: usize, out: []u8) usize {
        const len = self.lineLen(line_index);
        if (len == 0) return 0;
        const cap = if (len < out.len) len else out.len;
        const start = self.lineStart(line_index);
        return self.readRange(start, out[0..cap]);
    }

    pub fn saveToFile(self: *TextStore, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        var temp: [64 * 1024]u8 = undefined;
        var offset: usize = 0;
        const total = self.totalLen();
        while (offset < total) {
            const to_read = @min(temp.len, total - offset);
            const read_count = self.readRange(offset, temp[0..to_read]);
            if (read_count == 0) break;
            try file.writeAll(temp[0..read_count]);
            offset += read_count;
        }
    }

    pub fn canUndo(self: *TextStore) bool {
        return self.rope.canUndo();
    }

    pub fn canRedo(self: *TextStore) bool {
        return self.rope.canRedo();
    }

    pub fn undo(self: *TextStore) !bool {
        return self.rope.undo();
    }

    pub fn redo(self: *TextStore) !bool {
        return self.rope.redo();
    }
};
