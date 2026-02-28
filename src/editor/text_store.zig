const std = @import("std");
const builtin = @import("builtin");
const rope_mod = @import("rope.zig");
const app_logger = @import("../app_logger.zig");

pub const TextStore = struct {
    const mmap_threshold_bytes: usize = 16 * 1024 * 1024;

    allocator: std.mem.Allocator,
    rope: *rope_mod.Rope,
    mapped_original: ?[]align(std.heap.page_size_min) const u8,

    pub fn init(allocator: std.mem.Allocator, initial: []const u8) !*TextStore {
        const store = try allocator.create(TextStore);
        errdefer allocator.destroy(store);
        store.* = .{
            .allocator = allocator,
            .rope = try rope_mod.Rope.init(allocator, initial),
            .mapped_original = null,
        };
        return store;
    }

    pub fn initFromFile(allocator: std.mem.Allocator, path: []const u8) !*TextStore {
        const log = app_logger.logger("editor.perf");
        const t_open = std.time.nanoTimestamp();
        const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
        defer file.close();
        const stat = try file.stat();
        if (stat.size > std.math.maxInt(usize)) return error.FileTooBig;
        const size: usize = @intCast(stat.size);

        if (builtin.os.tag != .windows and size >= mmap_threshold_bytes and size > 0) {
            const t_map_start = std.time.nanoTimestamp();
            const mapped = std.posix.mmap(
                null,
                size,
                std.posix.PROT.READ,
                .{ .TYPE = .PRIVATE },
                file.handle,
                0,
            ) catch |err| blk: {
                log.logf("initFromFile mmap fallback err={s} size={d}", .{ @errorName(err), stat.size });
                break :blk null;
            };
            if (mapped) |mapped_bytes| {
                const t_map_end = std.time.nanoTimestamp();
                const t_rope_start = std.time.nanoTimestamp();
                errdefer std.posix.munmap(mapped_bytes);
                const store = try allocator.create(TextStore);
                errdefer allocator.destroy(store);
                store.* = .{
                    .allocator = allocator,
                    .rope = try rope_mod.Rope.initBorrowedOriginal(allocator, mapped_bytes),
                    .mapped_original = mapped_bytes,
                };
                const t_rope_end = std.time.nanoTimestamp();
                log.logf(
                    "initFromFile size={d} mmap_ms={d} rope_ms={d} total_ms={d} source=mmap",
                    .{
                        stat.size,
                        @as(i64, @intCast(@divTrunc(t_map_end - t_map_start, 1_000_000))),
                        @as(i64, @intCast(@divTrunc(t_rope_end - t_rope_start, 1_000_000))),
                        @as(i64, @intCast(@divTrunc(t_rope_end - t_open, 1_000_000))),
                    },
                );
                return store;
            }
        }

        const t_read_start = std.time.nanoTimestamp();
        const data = try file.readToEndAlloc(allocator, size);
        const t_read_end = std.time.nanoTimestamp();

        const t_rope_start = std.time.nanoTimestamp();
        const store = try allocator.create(TextStore);
        errdefer allocator.destroy(store);
        store.* = .{
            .allocator = allocator,
            .rope = try rope_mod.Rope.initOwnedOriginal(allocator, data),
            .mapped_original = null,
        };
        const t_rope_end = std.time.nanoTimestamp();

        log.logf(
            "initFromFile size={d} read_ms={d} rope_ms={d} total_ms={d}",
            .{
                stat.size,
                @as(i64, @intCast(@divTrunc(t_read_end - t_read_start, 1_000_000))),
                @as(i64, @intCast(@divTrunc(t_rope_end - t_rope_start, 1_000_000))),
                @as(i64, @intCast(@divTrunc(t_rope_end - t_open, 1_000_000))),
            },
        );

        return store;
    }

    pub fn deinit(self: *TextStore) void {
        self.rope.deinit();
        if (self.mapped_original) |mapped| {
            std.posix.munmap(mapped);
        }
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
        const result = try self.rope.undo();
        return result.changed;
    }

    pub fn redo(self: *TextStore) !bool {
        const result = try self.rope.redo();
        return result.changed;
    }

    pub fn undoWithCursor(self: *TextStore) !rope_mod.Rope.UndoResult {
        return self.rope.undo();
    }

    pub fn redoWithCursor(self: *TextStore) !rope_mod.Rope.UndoResult {
        return self.rope.redo();
    }

    pub fn beginUndoGroup(self: *TextStore) void {
        self.rope.beginUndoGroup();
    }

    pub fn endUndoGroup(self: *TextStore) !void {
        try self.rope.endUndoGroup();
    }

    pub fn annotateLastUndoState(self: *TextStore, before_state: ?u64, after_state: ?u64) void {
        self.rope.annotateLastUndoState(before_state, after_state);
    }

    pub fn annotateCurrentUndoGroupBefore(self: *TextStore, before_state: u64) void {
        self.rope.annotateCurrentUndoGroupBefore(before_state);
    }

    pub fn annotateClosedUndoGroupAfter(self: *TextStore, after_state: u64) void {
        self.rope.annotateClosedUndoGroupAfter(after_state);
    }
};
