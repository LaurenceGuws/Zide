const std = @import("std");
const editor_mod = @import("../editor.zig");
const grammar_manager_mod = @import("../grammar_manager.zig");

pub const Status = enum(c_int) {
    ok = 0,
    invalid_argument = 1,
    out_of_memory = 2,
    backend_error = 3,
};

pub const ZideEditorHandle = opaque {};

pub const StringBuffer = extern struct {
    ptr: ?[*]const u8 = null,
    len: usize = 0,
    _ctx: ?*anyopaque = null,
};

const Handle = struct {
    allocator: std.mem.Allocator,
    grammar_manager: grammar_manager_mod.GrammarManager,
    editor: *editor_mod.Editor,
};

const StringOwner = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
};

pub fn create(out_handle: *?*ZideEditorHandle) Status {
    out_handle.* = null;
    const allocator = std.heap.c_allocator;
    const handle = allocator.create(Handle) catch return .out_of_memory;
    errdefer allocator.destroy(handle);

    handle.* = .{
        .allocator = allocator,
        .grammar_manager = undefined,
        .editor = undefined,
    };
    handle.grammar_manager = grammar_manager_mod.GrammarManager.init(allocator) catch return .out_of_memory;
    errdefer handle.grammar_manager.deinit();
    handle.editor = editor_mod.Editor.init(allocator, &handle.grammar_manager) catch return .out_of_memory;
    errdefer handle.editor.deinit();

    out_handle.* = toOpaque(handle);
    return .ok;
}

pub fn destroy(handle: ?*ZideEditorHandle) void {
    const h = fromOpaque(handle) orelse return;
    h.editor.deinit();
    h.grammar_manager.deinit();
    h.allocator.destroy(h);
}

pub fn setText(handle: ?*ZideEditorHandle, bytes: ?[*]const u8, len: usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const slice = ptrLen(bytes, len) orelse return .invalid_argument;
    const editor = h.editor;

    const total = editor.totalLen();
    if (total > 0) {
        editor.buffer.deleteRange(0, total) catch |err| return mapError(err);
    }
    if (slice.len > 0) {
        editor.buffer.insertBytes(0, slice) catch |err| return mapError(err);
    }
    editor.setCursor(0, 0);
    editor.selection = null;
    editor.clearSelections();
    editor.scroll_line = 0;
    editor.scroll_col = 0;
    editor.scroll_row_offset = 0;
    editor.invalidateLineWidthCache();
    editor.modified = false;
    return .ok;
}

pub fn insertText(handle: ?*ZideEditorHandle, bytes: ?[*]const u8, len: usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const slice = ptrLen(bytes, len) orelse return .invalid_argument;
    h.editor.insertText(slice) catch |err| return mapError(err);
    return .ok;
}

pub fn replaceRange(
    handle: ?*ZideEditorHandle,
    start: usize,
    end: usize,
    bytes: ?[*]const u8,
    len: usize,
) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    if (end < start) return .invalid_argument;
    const replacement = ptrLen(bytes, len) orelse return .invalid_argument;
    const editor = h.editor;
    const total = editor.totalLen();
    if (end > total) return .invalid_argument;

    editor.buffer.beginUndoGroup();
    if (end > start) {
        editor.buffer.deleteRange(start, end - start) catch |err| return mapError(err);
    }
    if (replacement.len > 0) {
        editor.buffer.insertBytes(start, replacement) catch |err| return mapError(err);
    }
    editor.buffer.endUndoGroup() catch |err| return mapError(err);

    editor.setCursorOffsetNoClear(start + replacement.len);
    editor.selection = null;
    editor.clearSelections();
    editor.invalidateLineWidthCache();
    editor.modified = true;
    return .ok;
}

pub fn deleteRange(handle: ?*ZideEditorHandle, start: usize, end: usize) Status {
    return replaceRange(handle, start, end, null, 0);
}

pub fn beginUndoGroup(handle: ?*ZideEditorHandle) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    h.editor.buffer.beginUndoGroup();
    return .ok;
}

pub fn endUndoGroup(handle: ?*ZideEditorHandle) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    h.editor.buffer.endUndoGroup() catch |err| return mapError(err);
    return .ok;
}

pub fn textAlloc(handle: ?*ZideEditorHandle, out_string: *StringBuffer) Status {
    out_string.* = .{};
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const total = h.editor.totalLen();
    const bytes = h.editor.buffer.readRangeAlloc(0, total) catch |err| return mapError(err);
    const owner = h.allocator.create(StringOwner) catch {
        h.allocator.free(bytes);
        return .out_of_memory;
    };
    owner.* = .{
        .allocator = h.allocator,
        .bytes = bytes,
    };
    out_string.* = .{
        .ptr = if (bytes.len > 0) bytes.ptr else null,
        .len = bytes.len,
        ._ctx = owner,
    };
    return .ok;
}

pub fn stringFree(string: *StringBuffer) void {
    const owner = stringOwner(string._ctx) orelse {
        string.* = .{};
        return;
    };
    owner.allocator.free(owner.bytes);
    owner.allocator.destroy(owner);
    string.* = .{};
}

pub fn setCursorOffset(handle: ?*ZideEditorHandle, offset: usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const clamped = @min(offset, h.editor.totalLen());
    h.editor.setCursorOffsetNoClear(clamped);
    h.editor.selection = null;
    h.editor.clearSelections();
    return .ok;
}

pub fn cursorOffset(handle: ?*ZideEditorHandle, out_offset: *usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    out_offset.* = h.editor.cursor.offset;
    return .ok;
}

pub fn undo(handle: ?*ZideEditorHandle, out_changed: *u8) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const changed = h.editor.undo() catch |err| return mapError(err);
    out_changed.* = @intFromBool(changed);
    return .ok;
}

pub fn redo(handle: ?*ZideEditorHandle, out_changed: *u8) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const changed = h.editor.redo() catch |err| return mapError(err);
    out_changed.* = @intFromBool(changed);
    return .ok;
}

pub fn lineCount(handle: ?*ZideEditorHandle, out_lines: *usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    out_lines.* = h.editor.lineCount();
    return .ok;
}

pub fn totalLen(handle: ?*ZideEditorHandle, out_len: *usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    out_len.* = h.editor.totalLen();
    return .ok;
}

fn ptrLen(ptr: ?[*]const u8, len: usize) ?[]const u8 {
    if (len == 0) return &[_]u8{};
    const raw = ptr orelse return null;
    return raw[0..len];
}

fn toOpaque(handle: *Handle) *ZideEditorHandle {
    return @ptrCast(handle);
}

fn fromOpaque(handle: ?*ZideEditorHandle) ?*Handle {
    const raw = handle orelse return null;
    return @ptrCast(@alignCast(raw));
}

fn stringOwner(ctx: ?*anyopaque) ?*StringOwner {
    const raw = ctx orelse return null;
    return @ptrCast(@alignCast(raw));
}

fn mapError(err: anyerror) Status {
    return switch (err) {
        error.OutOfMemory => .out_of_memory,
        else => .backend_error,
    };
}
