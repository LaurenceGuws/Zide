const std = @import("std");
const buffer_mod = @import("buffer.zig");
const rope_mod = @import("rope.zig");

pub const TextStoreKind = enum(u8) {
    piece_table,
    rope,
};

pub const default_kind: TextStoreKind = .rope;

pub const TextStore = struct {
    allocator: std.mem.Allocator,
    kind: TextStoreKind,
    buffer: ?*buffer_mod.TextBuffer,
    rope: ?*rope_mod.Rope,

    pub fn init(allocator: std.mem.Allocator, initial: []const u8) !*TextStore {
        return initWithKind(allocator, initial, default_kind);
    }

    pub fn initWithKind(allocator: std.mem.Allocator, initial: []const u8, kind: TextStoreKind) !*TextStore {
        var store = try allocator.create(TextStore);
        store.* = .{
            .allocator = allocator,
            .kind = kind,
            .buffer = null,
            .rope = null,
        };
        switch (kind) {
            .piece_table => store.buffer = try buffer_mod.createBuffer(allocator, initial),
            .rope => store.rope = try rope_mod.Rope.init(allocator, initial),
        }
        return store;
    }

    pub fn initFromFile(allocator: std.mem.Allocator, path: []const u8) !*TextStore {
        return initFromFileWithKind(allocator, path, default_kind);
    }

    pub fn initFromFileWithKind(allocator: std.mem.Allocator, path: []const u8, kind: TextStoreKind) !*TextStore {
        var store = try allocator.create(TextStore);
        store.* = .{
            .allocator = allocator,
            .kind = kind,
            .buffer = null,
            .rope = null,
        };
        switch (kind) {
            .piece_table => store.buffer = try buffer_mod.createBufferFromFile(allocator, path),
            .rope => {
                const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
                defer file.close();
                const stat = try file.stat();
                const data = try file.readToEndAlloc(allocator, @as(usize, @intCast(stat.size)));
                defer allocator.free(data);
                store.rope = try rope_mod.Rope.init(allocator, data);
            },
        }
        return store;
    }

    pub fn deinit(self: *TextStore) void {
        switch (self.kind) {
            .piece_table => if (self.buffer) |buf| buffer_mod.destroyBuffer(buf),
            .rope => if (self.rope) |rope| rope.deinit(),
        }
        self.allocator.destroy(self);
    }

    pub fn totalLen(self: *TextStore) usize {
        return switch (self.kind) {
            .piece_table => buffer_mod.totalLen(self.buffer.?),
            .rope => self.rope.?.totalLen(),
        };
    }

    pub fn insertBytes(self: *TextStore, pos: usize, data: []const u8) !void {
        switch (self.kind) {
            .piece_table => try buffer_mod.insertBytes(self.buffer.?, pos, data),
            .rope => try self.rope.?.insert(pos, data),
        }
    }

    pub fn deleteRange(self: *TextStore, start: usize, len: usize) !void {
        switch (self.kind) {
            .piece_table => try buffer_mod.deleteRange(self.buffer.?, start, len),
            .rope => try self.rope.?.deleteRange(start, len),
        }
    }

    pub fn readRange(self: *TextStore, start: usize, out: []u8) usize {
        return switch (self.kind) {
            .piece_table => buffer_mod.readRange(self.buffer.?, start, out),
            .rope => self.rope.?.readRange(start, out),
        };
    }

    pub fn readRangeAlloc(self: *TextStore, start: usize, len: usize) ![]u8 {
        return switch (self.kind) {
            .piece_table => buffer_mod.readRangeAlloc(self.buffer.?, start, len),
            .rope => {
                const total = self.totalLen();
                if (start >= total or len == 0) return self.allocator.alloc(u8, 0);
                const readable = if (start + len > total) total - start else len;
                var out = try self.allocator.alloc(u8, readable);
                const written = self.readRange(start, out);
                if (written < readable) {
                    out = try self.allocator.realloc(out, written);
                }
                return out;
            },
        };
    }

    pub fn lineCount(self: *TextStore) usize {
        return switch (self.kind) {
            .piece_table => buffer_mod.lineCount(self.buffer.?),
            .rope => self.rope.?.lineCount(),
        };
    }

    pub fn lineStart(self: *TextStore, line_index: usize) usize {
        return switch (self.kind) {
            .piece_table => buffer_mod.lineStart(self.buffer.?, line_index),
            .rope => self.rope.?.lineStart(line_index),
        };
    }

    pub fn lineLen(self: *TextStore, line_index: usize) usize {
        return switch (self.kind) {
            .piece_table => buffer_mod.lineLen(self.buffer.?, line_index),
            .rope => self.rope.?.lineLen(line_index),
        };
    }

    pub fn lineIndexForOffset(self: *TextStore, offset: usize) usize {
        return switch (self.kind) {
            .piece_table => buffer_mod.lineIndexForOffset(self.buffer.?, offset),
            .rope => self.rope.?.lineIndexForOffset(offset),
        };
    }

    pub fn readLine(self: *TextStore, line_index: usize, out: []u8) usize {
        return switch (self.kind) {
            .piece_table => buffer_mod.readLine(self.buffer.?, line_index, out),
            .rope => {
                const len = self.lineLen(line_index);
                if (len == 0) return 0;
                const cap = if (len < out.len) len else out.len;
                const start = self.lineStart(line_index);
                return self.readRange(start, out[0..cap]);
            },
        };
    }

    pub fn saveToFile(self: *TextStore, path: []const u8) !void {
        switch (self.kind) {
            .piece_table => try buffer_mod.saveToFile(self.buffer.?, path),
            .rope => {
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
            },
        }
    }

    pub fn canUndo(self: *TextStore) bool {
        return switch (self.kind) {
            .piece_table => buffer_mod.canUndo(self.buffer.?),
            .rope => false,
        };
    }

    pub fn canRedo(self: *TextStore) bool {
        return switch (self.kind) {
            .piece_table => buffer_mod.canRedo(self.buffer.?),
            .rope => false,
        };
    }

    pub fn undo(self: *TextStore) !bool {
        return switch (self.kind) {
            .piece_table => try buffer_mod.undo(self.buffer.?),
            .rope => false,
        };
    }

    pub fn redo(self: *TextStore) !bool {
        return switch (self.kind) {
            .piece_table => try buffer_mod.redo(self.buffer.?),
            .rope => false,
        };
    }
};
