const std = @import("std");
const types = @import("types.zig");

pub const TextBuffer = types.TextBuffer;
const Piece = types.Piece;
const UndoOp = types.UndoOp;
const UndoKind = types.UndoKind;
const max_undo_bytes: usize = 8 * 1024 * 1024;

pub fn createBuffer(allocator: std.mem.Allocator, initial: []const u8) !*TextBuffer {
    var buffer = try allocator.create(TextBuffer);
    buffer.* = .{
        .allocator = allocator,
        .mutex = .{},
        .original = try allocator.dupe(u8, initial),
        .add = .{},
        .pieces = .{},
        .line_starts = .{},
        .line_index_dirty = true,
        .undo_stack = .{},
        .redo_stack = .{},
        .history_suspended = false,
        .original_in_file = false,
        .file = null,
        .file_len = 0,
        .index_thread = null,
        .index_building = std.atomic.Value(bool).init(false),
        .index_ready = std.atomic.Value(bool).init(false),
        .index_progress = std.atomic.Value(usize).init(0),
        .index_total = 0,
        .index_epoch = 0,
        .index_suspended = false,
        .last_piece_valid = false,
        .last_piece_index = 0,
        .last_piece_start = 0,
        .last_piece_end = 0,
    };
    if (buffer.original.len > 0) {
        try buffer.pieces.append(allocator, .{ .buffer = .original, .start = 0, .len = buffer.original.len });
    }
    return buffer;
}

pub fn createBufferFromFile(allocator: std.mem.Allocator, path: []const u8) !*TextBuffer {
    var file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    errdefer file.close();
    const stat = try file.stat();
    const len = @as(usize, @intCast(stat.size));
    var buffer = try allocator.create(TextBuffer);
    buffer.* = .{
        .allocator = allocator,
        .mutex = .{},
        .original = &[_]u8{},
        .add = .{},
        .pieces = .{},
        .line_starts = .{},
        .line_index_dirty = true,
        .undo_stack = .{},
        .redo_stack = .{},
        .history_suspended = false,
        .original_in_file = true,
        .file = file,
        .file_len = len,
        .index_thread = null,
        .index_building = std.atomic.Value(bool).init(false),
        .index_ready = std.atomic.Value(bool).init(false),
        .index_progress = std.atomic.Value(usize).init(0),
        .index_total = len,
        .index_epoch = 0,
        .index_suspended = false,
        .last_piece_valid = false,
        .last_piece_index = 0,
        .last_piece_start = 0,
        .last_piece_end = 0,
    };
    if (len > 0) {
        try buffer.pieces.append(allocator, .{ .buffer = .original, .start = 0, .len = len });
    }
    return buffer;
}

pub fn destroyBuffer(buffer: *TextBuffer) void {
    const allocator = buffer.allocator;
    if (!buffer.original_in_file) {
        allocator.free(buffer.original);
    }
    if (buffer.index_thread) |thread| {
        thread.join();
    }
    if (buffer.file) |*file| {
        file.close();
    }
    buffer.add.deinit(allocator);
    buffer.pieces.deinit(allocator);
    buffer.line_starts.deinit(allocator);
    freeUndoStack(buffer, &buffer.undo_stack);
    freeUndoStack(buffer, &buffer.redo_stack);
    allocator.destroy(buffer);
}

pub fn totalLen(buffer: *TextBuffer) usize {
    var total: usize = 0;
    for (buffer.pieces.items) |piece| {
        total += piece.len;
    }
    return total;
}

fn findPiece(buffer: *TextBuffer, pos: usize, piece_index: *usize, inner_offset: *usize) void {
    if (buffer.last_piece_valid and pos >= buffer.last_piece_start) {
        var offset = buffer.last_piece_start;
        var idx = buffer.last_piece_index;
        while (idx < buffer.pieces.items.len) : (idx += 1) {
            const piece = buffer.pieces.items[idx];
            if (pos <= offset + piece.len) {
                piece_index.* = idx;
                inner_offset.* = pos - offset;
                buffer.last_piece_index = idx;
                buffer.last_piece_start = offset;
                buffer.last_piece_end = offset + piece.len;
                buffer.last_piece_valid = true;
                return;
            }
            offset += piece.len;
        }
    }
    var offset: usize = 0;
    for (buffer.pieces.items, 0..) |piece, idx| {
        if (pos <= offset + piece.len) {
            piece_index.* = idx;
            inner_offset.* = pos - offset;
            buffer.last_piece_index = idx;
            buffer.last_piece_start = offset;
            buffer.last_piece_end = offset + piece.len;
            buffer.last_piece_valid = true;
            return;
        }
        offset += piece.len;
    }
    piece_index.* = buffer.pieces.items.len;
    inner_offset.* = 0;
    buffer.last_piece_valid = false;
}

fn insertBytesNoHistory(buffer: *TextBuffer, pos: usize, data: []const u8) !void {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    if (pos > totalLen(buffer)) return error.OutOfBounds;
    const add_start = buffer.add.items.len;
    try buffer.add.appendSlice(buffer.allocator, data);
    const new_piece = Piece{ .buffer = .add, .start = add_start, .len = data.len };
    buffer.index_epoch +%= 1;
    if (buffer.index_suspended) {
        buffer.line_index_dirty = true;
        _ = buffer.index_ready.store(false, .monotonic);
    } else if (!buffer.line_index_dirty and buffer.index_ready.load(.monotonic)) {
        try updateLineIndexForInsert(buffer, pos, data);
    } else {
        buffer.line_index_dirty = true;
        _ = buffer.index_ready.store(false, .monotonic);
    }

    var idx: usize = 0;
    var inner: usize = 0;
    findPiece(buffer, pos, &idx, &inner);

    if (idx == buffer.pieces.items.len) {
        try buffer.pieces.append(buffer.allocator, new_piece);
        buffer.last_piece_valid = false;
        return;
    }

    const piece = buffer.pieces.items[idx];
    if (inner == 0) {
        try buffer.pieces.insert(buffer.allocator, idx, new_piece);
        buffer.last_piece_valid = false;
        return;
    }
    if (inner == piece.len) {
        try buffer.pieces.insert(buffer.allocator, idx + 1, new_piece);
        buffer.last_piece_valid = false;
        return;
    }

    const left = Piece{ .buffer = piece.buffer, .start = piece.start, .len = inner };
    const right = Piece{
        .buffer = piece.buffer,
        .start = piece.start + inner,
        .len = piece.len - inner,
    };

    buffer.pieces.items[idx] = left;
    try buffer.pieces.insert(buffer.allocator, idx + 1, new_piece);
    try buffer.pieces.insert(buffer.allocator, idx + 2, right);
    buffer.last_piece_valid = false;
}

fn updateLineIndexForInsert(buffer: *TextBuffer, pos: usize, data: []const u8) !void {
    if (data.len == 0) return;
    if (buffer.line_starts.items.len == 0) {
        try buffer.line_starts.append(buffer.allocator, 0);
    }
    const insert_line = lineIndexForOffsetLocked(buffer, pos);
    const insert_index = insert_line + 1;

    var newline_count: usize = 0;
    for (data) |byte| {
        if (byte == '\n') newline_count += 1;
    }
    if (newline_count == 0) {
        for (buffer.line_starts.items[insert_index..]) |*start| {
            start.* += data.len;
        }
        return;
    }

    var new_starts = try buffer.allocator.alloc(usize, newline_count);
    defer buffer.allocator.free(new_starts);
    var idx: usize = 0;
    var offset: usize = 0;
    for (data) |byte| {
        if (byte == '\n') {
            new_starts[idx] = pos + offset + 1;
            idx += 1;
        }
        offset += 1;
    }

    if (insert_index == buffer.line_starts.items.len) {
        try buffer.line_starts.ensureTotalCapacity(buffer.allocator, buffer.line_starts.items.len + newline_count);
        buffer.line_starts.appendSliceAssumeCapacity(new_starts);
        return;
    }

    var updated = std.ArrayList(usize).empty;
    try updated.ensureTotalCapacity(buffer.allocator, buffer.line_starts.items.len + newline_count);
    updated.appendSliceAssumeCapacity(buffer.line_starts.items[0..insert_index]);
    updated.appendSliceAssumeCapacity(new_starts);
    for (buffer.line_starts.items[insert_index..]) |start| {
        updated.appendAssumeCapacity(start + data.len);
    }
    buffer.line_starts.deinit(buffer.allocator);
    buffer.line_starts = updated;
}

pub fn insertBytes(buffer: *TextBuffer, pos: usize, data: []const u8) !void {
    if (data.len == 0) return;
    if (data.len > max_undo_bytes) {
        clearHistory(buffer);
        buffer.history_suspended = true;
        defer buffer.history_suspended = false;
        try insertBytesNoHistory(buffer, pos, data);
        return;
    }
    if (buffer.history_suspended) {
        try insertBytesNoHistory(buffer, pos, data);
        return;
    }
    const op = try createUndoOp(buffer.allocator, .insert, pos, data);
    try insertBytesNoHistory(buffer, pos, data);
    try clearRedoStack(buffer);
    try buffer.undo_stack.append(buffer.allocator, op);
}

fn deleteRangeNoHistory(buffer: *TextBuffer, start: usize, len: usize) !void {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    if (len == 0) return;
    const total = totalLen(buffer);
    if (start > total or start + len > total) return error.OutOfBounds;
    buffer.line_index_dirty = true;
    _ = buffer.index_ready.store(false, .monotonic);
    buffer.index_epoch +%= 1;

    var remaining = len;
    var pos: usize = 0;
    var idx: usize = 0;
    var inner: usize = 0;
    findPiece(buffer, start, &idx, &inner);
    if (idx >= buffer.pieces.items.len) return;
    pos = start - inner;

    while (idx < buffer.pieces.items.len and remaining > 0) {
        const piece = buffer.pieces.items[idx];
        const piece_start = pos;
        const piece_end = pos + piece.len;

        if (piece_end <= start) {
            pos = piece_end;
            idx += 1;
            continue;
        }
        if (piece_start >= start + remaining) {
            break;
        }

        const overlap_start = if (start > piece_start) start else piece_start;
        const overlap_end = if (start + remaining < piece_end) start + remaining else piece_end;
        const overlap_len = overlap_end - overlap_start;

        if (overlap_len == piece.len) {
            _ = buffer.pieces.orderedRemove(idx);
        } else if (overlap_start == piece_start) {
            buffer.pieces.items[idx].start += overlap_len;
            buffer.pieces.items[idx].len -= overlap_len;
            pos = piece_end - overlap_len;
            idx += 1;
        } else if (overlap_end == piece_end) {
            buffer.pieces.items[idx].len -= overlap_len;
            pos = piece_end - overlap_len;
            idx += 1;
        } else {
            const left = Piece{ .buffer = piece.buffer, .start = piece.start, .len = overlap_start - piece_start };
            const right = Piece{
                .buffer = piece.buffer,
                .start = piece.start + (overlap_end - piece_start),
                .len = piece_end - overlap_end,
            };
            buffer.pieces.items[idx] = left;
            try buffer.pieces.insert(buffer.allocator, idx + 1, right);
            pos = piece_end - overlap_len;
            idx += 2;
        }

        remaining -= overlap_len;
    }
    buffer.last_piece_valid = false;
}

pub fn deleteRange(buffer: *TextBuffer, start: usize, len: usize) !void {
    if (len == 0) return;
    if (len > max_undo_bytes) {
        clearHistory(buffer);
        buffer.history_suspended = true;
        defer buffer.history_suspended = false;
        try deleteRangeNoHistory(buffer, start, len);
        return;
    }
    if (buffer.history_suspended) {
        try deleteRangeNoHistory(buffer, start, len);
        return;
    }
    const deleted = try readRangeAlloc(buffer, start, len);
    const op = UndoOp{ .kind = .delete, .pos = start, .text = deleted };
    try deleteRangeNoHistory(buffer, start, len);
    try clearRedoStack(buffer);
    try buffer.undo_stack.append(buffer.allocator, op);
}

pub fn readRange(buffer: *TextBuffer, start: usize, out: []u8) usize {
    if (out.len == 0) return 0;
    const total = totalLen(buffer);
    if (start >= total) return 0;

    var out_index: usize = 0;
    var pos: usize = 0;
    var idx: usize = 0;
    var inner: usize = 0;
    findPiece(buffer, start, &idx, &inner);
    if (idx >= buffer.pieces.items.len) return 0;
    pos = start - inner;

    var i: usize = idx;
    while (i < buffer.pieces.items.len) : (i += 1) {
        const piece = buffer.pieces.items[i];
        if (out_index == out.len) break;
        const piece_end = pos + piece.len;
        if (piece_end <= start) {
            pos = piece_end;
            continue;
        }

        const local_start = if (start > pos) start - pos else 0;
        const readable = @min(piece.len - local_start, out.len - out_index);
        if (piece.buffer == .original and buffer.original_in_file) {
            if (buffer.file) |*file| {
                const offset = piece.start + local_start;
                const read_slice = out[out_index .. out_index + readable];
                const amt = file.preadAll(read_slice, offset) catch 0;
                out_index += amt;
            }
        } else {
            const piece_data = switch (piece.buffer) {
                .original => buffer.original,
                .add => buffer.add.items,
            };
            const src_slice = piece_data[piece.start + local_start .. piece.start + local_start + readable];
            std.mem.copyForwards(u8, out[out_index .. out_index + readable], src_slice);
            out_index += readable;
        }
        pos = piece_end;
    }

    return out_index;
}

fn readRangeAlloc(buffer: *TextBuffer, start: usize, len: usize) ![]u8 {
    const total = totalLen(buffer);
    if (start >= total or len == 0) return try buffer.allocator.alloc(u8, 0);
    const readable = if (start + len > total) total - start else len;
    var out = try buffer.allocator.alloc(u8, readable);
    const written = readRange(buffer, start, out);
    if (written < readable) {
        out = try buffer.allocator.realloc(out, written);
    }
    return out;
}

fn createUndoOp(allocator: std.mem.Allocator, kind: UndoKind, pos: usize, data: []const u8) !UndoOp {
    const copy = try allocator.alloc(u8, data.len);
    if (data.len > 0) {
        std.mem.copyForwards(u8, copy, data);
    }
    return UndoOp{ .kind = kind, .pos = pos, .text = copy };
}

fn freeUndoOp(allocator: std.mem.Allocator, op: UndoOp) void {
    allocator.free(op.text);
}

fn freeUndoStack(buffer: *TextBuffer, stack: *std.ArrayList(UndoOp)) void {
    for (stack.items) |op| {
        freeUndoOp(buffer.allocator, op);
    }
    stack.clearAndFree(buffer.allocator);
}

fn clearRedoStack(buffer: *TextBuffer) !void {
    if (buffer.redo_stack.items.len == 0) return;
    freeUndoStack(buffer, &buffer.redo_stack);
}

fn clearHistory(buffer: *TextBuffer) void {
    if (buffer.undo_stack.items.len > 0) {
        freeUndoStack(buffer, &buffer.undo_stack);
    }
    if (buffer.redo_stack.items.len > 0) {
        freeUndoStack(buffer, &buffer.redo_stack);
    }
}

pub fn canUndo(buffer: *TextBuffer) bool {
    return buffer.undo_stack.items.len > 0;
}

pub fn canRedo(buffer: *TextBuffer) bool {
    return buffer.redo_stack.items.len > 0;
}

pub fn undo(buffer: *TextBuffer) !bool {
    var kind: u8 = 0;
    var pos: usize = 0;
    var len: usize = 0;
    return undoWithInfo(buffer, &kind, &pos, &len);
}

pub fn redo(buffer: *TextBuffer) !bool {
    var kind: u8 = 0;
    var pos: usize = 0;
    var len: usize = 0;
    return redoWithInfo(buffer, &kind, &pos, &len);
}

pub fn undoWithInfo(buffer: *TextBuffer, kind_out: *u8, pos_out: *usize, len_out: *usize) !bool {
    if (buffer.undo_stack.items.len == 0) return false;
    const op = buffer.undo_stack.pop() orelse return false;
    kind_out.* = @intFromEnum(op.kind);
    pos_out.* = op.pos;
    len_out.* = op.text.len;
    buffer.history_suspended = true;
    defer buffer.history_suspended = false;
    switch (op.kind) {
        .insert => try deleteRangeNoHistory(buffer, op.pos, op.text.len),
        .delete => try insertBytesNoHistory(buffer, op.pos, op.text),
    }
    try buffer.redo_stack.append(buffer.allocator, op);
    return true;
}

pub fn redoWithInfo(buffer: *TextBuffer, kind_out: *u8, pos_out: *usize, len_out: *usize) !bool {
    if (buffer.redo_stack.items.len == 0) return false;
    const op = buffer.redo_stack.pop() orelse return false;
    kind_out.* = @intFromEnum(op.kind);
    pos_out.* = op.pos;
    len_out.* = op.text.len;
    buffer.history_suspended = true;
    defer buffer.history_suspended = false;
    switch (op.kind) {
        .insert => try insertBytesNoHistory(buffer, op.pos, op.text),
        .delete => try deleteRangeNoHistory(buffer, op.pos, op.text.len),
    }
    try buffer.undo_stack.append(buffer.allocator, op);
    return true;
}

fn rebuildLineIndex(buffer: *TextBuffer) !void {
    buffer.line_starts.clearAndFree(buffer.allocator);
    try buffer.line_starts.append(buffer.allocator, 0);

    if (totalLen(buffer) == 0) {
        buffer.line_index_dirty = false;
        return;
    }

    var pos: usize = 0;
    var temp = try buffer.allocator.alloc(u8, 64 * 1024);
    defer buffer.allocator.free(temp);
    for (buffer.pieces.items) |piece| {
        if (piece.buffer == .original and buffer.original_in_file) {
            if (buffer.file) |*file| {
                var offset: usize = 0;
                while (offset < piece.len) {
                    const to_read = @min(temp.len, piece.len - offset);
                    const slice = temp[0..to_read];
                    const amt = file.preadAll(slice, piece.start + offset) catch 0;
                    if (amt == 0) break;
                    for (slice[0..amt]) |byte| {
                        if (byte == '\n') {
                            try buffer.line_starts.append(buffer.allocator, pos + 1);
                        }
                        pos += 1;
                    }
                    offset += amt;
                }
            }
            continue;
        }
        const data = switch (piece.buffer) {
            .original => buffer.original,
            .add => buffer.add.items,
        };
        const slice = data[piece.start .. piece.start + piece.len];
        for (slice) |byte| {
            if (byte == '\n') {
                try buffer.line_starts.append(buffer.allocator, pos + 1);
            }
            pos += 1;
        }
    }
    buffer.line_index_dirty = false;
    _ = buffer.index_ready.store(true, .monotonic);
}

fn ensureLineIndexLocked(buffer: *TextBuffer) !void {
    if (!buffer.line_index_dirty) return;
    if (buffer.index_building.load(.monotonic)) return;
    if (buffer.original_in_file) {
        _ = startLineIndexBuildLocked(buffer);
        return;
    }
    try rebuildLineIndex(buffer);
}

pub fn lineCount(buffer: *TextBuffer) usize {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    if (!buffer.index_ready.load(.monotonic)) {
        ensureLineIndexLocked(buffer) catch return 0;
    }
    return buffer.line_starts.items.len;
}

fn lineRangeLocked(buffer: *TextBuffer, line_index: usize, start_out: *usize, len_out: *usize) bool {
    ensureLineIndexLocked(buffer) catch return false;
    if (line_index >= buffer.line_starts.items.len) return false;
    const start = buffer.line_starts.items[line_index];
    const total = totalLen(buffer);
    if (line_index + 1 < buffer.line_starts.items.len) {
        const next_start = buffer.line_starts.items[line_index + 1];
        start_out.* = start;
        len_out.* = if (next_start > start) next_start - start - 1 else 0;
        return true;
    }
    start_out.* = start;
    len_out.* = if (total > start) total - start else 0;
    return true;
}

pub fn lineStart(buffer: *TextBuffer, line_index: usize) usize {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    ensureLineIndexLocked(buffer) catch return totalLen(buffer);
    if (line_index >= buffer.line_starts.items.len) return totalLen(buffer);
    return buffer.line_starts.items[line_index];
}

fn lineIndexForOffsetLocked(buffer: *TextBuffer, offset: usize) usize {
    ensureLineIndexLocked(buffer) catch return 0;
    const count = buffer.line_starts.items.len;
    if (count == 0) return 0;
    const total = totalLen(buffer);
    if (offset >= total) return count - 1;

    var low: usize = 0;
    var high: usize = count;
    while (low < high) {
        const mid = (low + high) / 2;
        if (buffer.line_starts.items[mid] <= offset) {
            low = mid + 1;
        } else {
            high = mid;
        }
    }
    return if (low == 0) 0 else low - 1;
}

pub fn lineIndexForOffset(buffer: *TextBuffer, offset: usize) usize {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    return lineIndexForOffsetLocked(buffer, offset);
}

fn startLineIndexBuildLocked(buffer: *TextBuffer) bool {
    if (buffer.index_building.load(.monotonic)) return false;
    _ = buffer.index_ready.store(false, .monotonic);
    _ = buffer.index_progress.store(0, .monotonic);
    buffer.index_total = totalLen(buffer);
    buffer.line_index_dirty = true;
    _ = buffer.index_building.store(true, .monotonic);
    buffer.index_thread = std.Thread.spawn(.{}, lineIndexThread, .{buffer}) catch {
        _ = buffer.index_building.store(false, .monotonic);
        return false;
    };
    return true;
}

pub fn startLineIndexBuild(buffer: *TextBuffer) bool {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    return startLineIndexBuildLocked(buffer);
}

fn lineIndexThread(buffer: *TextBuffer) void {
    buffer.mutex.lock();
    if (buffer.index_suspended) {
        _ = buffer.index_building.store(false, .monotonic);
        buffer.mutex.unlock();
        return;
    }
    const target_epoch = buffer.index_epoch;
    _ = buffer.index_progress.store(0, .monotonic);

    var temp = buffer.allocator.alloc(u8, 64 * 1024) catch {
        buffer.mutex.unlock();
        _ = buffer.index_building.store(false, .monotonic);
        return;
    };
    defer buffer.allocator.free(temp);
    var new_starts = std.ArrayList(usize).empty;
    _ = new_starts.append(buffer.allocator, 0) catch {};

    const yield_bytes: usize = 8 * 1024;
    var since_yield: usize = 0;
    var abort = false;

    var pos: usize = 0;
    outer: for (buffer.pieces.items) |piece| {
        if (piece.buffer == .original and buffer.original_in_file) {
            if (buffer.file) |*file| {
                var offset: usize = 0;
                while (offset < piece.len) {
                    if (buffer.index_suspended) {
                        abort = true;
                        break;
                    }
                    const to_read = @min(temp.len, piece.len - offset);
                    const slice = temp[0..to_read];
                    const amt = file.preadAll(slice, piece.start + offset) catch 0;
                    if (amt == 0) break;
                    for (slice[0..amt]) |byte| {
                        if (byte == '\n') {
                            _ = new_starts.append(buffer.allocator, pos + 1) catch {};
                        }
                        pos += 1;
                        since_yield += 1;
                        if (since_yield >= yield_bytes) {
                            since_yield = 0;
                            buffer.mutex.unlock();
                            buffer.mutex.lock();
                            if (buffer.index_epoch != target_epoch or buffer.index_suspended) {
                                abort = true;
                                break;
                            }
                        }
                    }
                    if (abort) break;
                    offset += amt;
                    _ = buffer.index_progress.store(pos, .monotonic);
                }
            }
            if (abort) break :outer;
            continue;
        }
        const data = switch (piece.buffer) {
            .original => buffer.original,
            .add => buffer.add.items,
        };
        const slice = data[piece.start .. piece.start + piece.len];
        for (slice) |byte| {
            if (byte == '\n') {
                _ = new_starts.append(buffer.allocator, pos + 1) catch {};
            }
            pos += 1;
            if (buffer.index_suspended) {
                abort = true;
                break;
            }
            since_yield += 1;
            if (since_yield >= yield_bytes) {
                since_yield = 0;
                buffer.mutex.unlock();
                buffer.mutex.lock();
                if (buffer.index_epoch != target_epoch or buffer.index_suspended) {
                    abort = true;
                    break;
                }
            }
        }
        if (abort) break;
        _ = buffer.index_progress.store(pos, .monotonic);
    }

    if (abort or buffer.index_epoch != target_epoch) {
        new_starts.deinit(buffer.allocator);
        _ = buffer.index_building.store(false, .monotonic);
        buffer.mutex.unlock();
        return;
    }
    buffer.line_starts.deinit(buffer.allocator);
    buffer.line_starts = new_starts;
    buffer.line_index_dirty = false;
    _ = buffer.index_ready.store(true, .monotonic);
    _ = buffer.index_building.store(false, .monotonic);
    buffer.mutex.unlock();
}

pub fn lineIndexProgress(buffer: *TextBuffer, progress_out: *usize, total_out: *usize, ready_out: *bool) bool {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    progress_out.* = buffer.index_progress.load(.monotonic);
    total_out.* = buffer.index_total;
    ready_out.* = buffer.index_ready.load(.monotonic);
    return true;
}

pub fn suspendLineIndex(buffer: *TextBuffer) void {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    buffer.index_suspended = true;
    buffer.line_index_dirty = true;
    _ = buffer.index_ready.store(false, .monotonic);
}

pub fn resumeLineIndex(buffer: *TextBuffer) void {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    buffer.index_suspended = false;
}

pub fn lineLen(buffer: *TextBuffer, line_index: usize) usize {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    var start: usize = 0;
    var len: usize = 0;
    if (lineRangeLocked(buffer, line_index, &start, &len)) {
        return len;
    }
    return 0;
}

pub fn readLine(buffer: *TextBuffer, line_index: usize, out: []u8) usize {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    var start: usize = 0;
    var len: usize = 0;
    if (lineRangeLocked(buffer, line_index, &start, &len)) {
        const cap = if (len < out.len) len else out.len;
        return readRange(buffer, start, out[0..cap]);
    }
    return 0;
}
