const std = @import("std");
const editor_mod = @import("../editor.zig");
const grammar_manager_mod = @import("../grammar_manager.zig");
const editor_types = @import("../types.zig");
const app_logger = @import("../../app_logger.zig");

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

pub const CaretOffset = extern struct {
    offset: usize,
};

pub const SearchMatch = extern struct {
    start: usize,
    end: usize,
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
    const log = app_logger.logger("editor.ffi");
    out_handle.* = null;
    const allocator = std.heap.c_allocator;
    const handle = allocator.create(Handle) catch |err| {
        log.logf(.warning, "create handle alloc failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer allocator.destroy(handle);

    handle.* = .{
        .allocator = allocator,
        .grammar_manager = undefined,
        .editor = undefined,
    };
    handle.grammar_manager = grammar_manager_mod.GrammarManager.init(allocator) catch |err| {
        log.logf(.warning, "create grammar manager init failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
    errdefer handle.grammar_manager.deinit();
    handle.editor = editor_mod.Editor.init(allocator, &handle.grammar_manager) catch |err| {
        log.logf(.warning, "create editor init failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
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
    const log = app_logger.logger("editor.ffi");
    out_string.* = .{};
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const total = h.editor.totalLen();
    const bytes = h.editor.buffer.readRangeAlloc(0, total) catch |err| return mapError(err);
    const owner = h.allocator.create(StringOwner) catch |err| {
        log.logf(.warning, "textAlloc owner alloc failed bytes={d} err={s}", .{ bytes.len, @errorName(err) });
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

pub fn primaryCaretOffset(handle: ?*ZideEditorHandle, out_offset: *usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    out_offset.* = h.editor.primaryCaret().offset;
    return .ok;
}

pub fn auxiliaryCaretCount(handle: ?*ZideEditorHandle, out_count: *usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    out_count.* = h.editor.auxiliaryCaretCount();
    return .ok;
}

pub fn auxiliaryCaretGet(handle: ?*ZideEditorHandle, index: usize, out_offset: *usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const caret = h.editor.auxiliaryCaretAt(index) orelse return .invalid_argument;
    out_offset.* = caret.offset;
    return .ok;
}

pub fn clearSelections(handle: ?*ZideEditorHandle) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    h.editor.selection = null;
    h.editor.clearSelections();
    return .ok;
}

pub fn setCarets(
    handle: ?*ZideEditorHandle,
    primary_offset: usize,
    aux: ?[*]const CaretOffset,
    aux_count: usize,
) Status {
    const log = app_logger.logger("editor.ffi");
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const aux_slice = ptrLenTyped(CaretOffset, aux, aux_count) orelse return .invalid_argument;
    const editor = h.editor;
    const total = editor.totalLen();
    const primary = @min(primary_offset, total);

    editor.setCursorOffsetNoClear(primary);
    editor.selection = null;
    editor.clearSelections();
    for (aux_slice) |entry| {
        const aux_offset = @min(entry.offset, total);
        if (aux_offset == primary) continue;
        const pos = cursorPosForOffset(editor, aux_offset);
        editor.addSelection(.{
            .start = pos,
            .end = pos,
            .is_rectangular = false,
        }) catch |err| {
            log.logf(.warning, "setCarets addSelection failed err={s}", .{@errorName(err)});
            return .out_of_memory;
        };
    }
    editor.normalizeSelections() catch |err| {
        log.logf(.warning, "setCarets normalizeSelections failed err={s}", .{@errorName(err)});
        return .out_of_memory;
    };
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

pub fn searchSetQuery(handle: ?*ZideEditorHandle, bytes: ?[*]const u8, len: usize, use_regex: u8) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const editor = h.editor;
    if (len == 0) {
        if (use_regex != 0) {
            editor.setSearchQueryRegex(null) catch |err| return mapError(err);
        } else {
            editor.setSearchQuery(null) catch |err| return mapError(err);
        }
        return .ok;
    }
    const query = ptrLen(bytes, len) orelse return .invalid_argument;
    if (use_regex != 0) {
        editor.setSearchQueryRegex(query) catch |err| return mapError(err);
    } else {
        editor.setSearchQuery(query) catch |err| return mapError(err);
    }
    return .ok;
}

pub fn searchMatchCount(handle: ?*ZideEditorHandle, out_count: *usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    out_count.* = h.editor.searchMatches().len;
    return .ok;
}

pub fn searchMatchGet(handle: ?*ZideEditorHandle, index: usize, out_match: *SearchMatch) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const matches = h.editor.searchMatches();
    if (index >= matches.len) return .invalid_argument;
    out_match.* = .{
        .start = matches[index].start,
        .end = matches[index].end,
    };
    return .ok;
}

pub fn searchActiveIndex(handle: ?*ZideEditorHandle, out_index: *usize, out_has_active: *u8) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    if (h.editor.searchActiveIndex()) |idx| {
        out_index.* = idx;
        out_has_active.* = 1;
    } else {
        out_index.* = 0;
        out_has_active.* = 0;
    }
    return .ok;
}

pub fn searchNext(handle: ?*ZideEditorHandle, out_activated: *u8) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    out_activated.* = @intFromBool(h.editor.activateNextSearchMatch());
    return .ok;
}

pub fn searchPrev(handle: ?*ZideEditorHandle, out_activated: *u8) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    out_activated.* = @intFromBool(h.editor.activatePrevSearchMatch());
    return .ok;
}

pub fn searchReplaceActive(handle: ?*ZideEditorHandle, bytes: ?[*]const u8, len: usize, out_replaced: *u8) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const replacement = ptrLen(bytes, len) orelse return .invalid_argument;
    const replaced = h.editor.replaceActiveSearchMatch(replacement) catch |err| return mapError(err);
    out_replaced.* = @intFromBool(replaced);
    return .ok;
}

pub fn searchReplaceAll(handle: ?*ZideEditorHandle, bytes: ?[*]const u8, len: usize, out_count: *usize) Status {
    const h = fromOpaque(handle) orelse return .invalid_argument;
    const replacement = ptrLen(bytes, len) orelse return .invalid_argument;
    out_count.* = h.editor.replaceAllSearchMatches(replacement) catch |err| return mapError(err);
    return .ok;
}

fn ptrLen(ptr: ?[*]const u8, len: usize) ?[]const u8 {
    if (len == 0) return &[_]u8{};
    const raw = ptr orelse return null;
    return raw[0..len];
}

fn ptrLenTyped(comptime T: type, ptr: ?[*]const T, len: usize) ?[]const T {
    if (len == 0) return &[_]T{};
    const raw = ptr orelse return null;
    return raw[0..len];
}

fn cursorPosForOffset(editor: *editor_mod.Editor, offset: usize) editor_types.CursorPos {
    const total = editor.totalLen();
    const clamped = @min(offset, total);
    const line = editor.buffer.lineIndexForOffset(clamped);
    const line_start = editor.buffer.lineStart(line);
    return .{
        .line = line,
        .col = clamped - line_start,
        .offset = clamped,
    };
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
    const log = app_logger.logger("editor.ffi");
    return switch (err) {
        error.OutOfMemory => .out_of_memory,
        else => blk: {
            log.logf(.warning, "backend error mapped status=backend_error err={s}", .{@errorName(err)});
            break :blk .backend_error;
        },
    };
}
