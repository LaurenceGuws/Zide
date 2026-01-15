const std = @import("std");

const buffer = @import("buffer.zig");
const TextBuffer = buffer.TextBuffer;
const syntax = @import("syntax.zig");

export fn zig_buffer_create() ?*TextBuffer {
    return buffer.createBuffer(std.heap.c_allocator, "") catch null;
}

export fn zig_buffer_create_with_utf8(data: [*]const u8, len: usize) ?*TextBuffer {
    return buffer.createBuffer(std.heap.c_allocator, data[0..len]) catch null;
}

export fn zig_buffer_create_from_file(path: [*]const u8, len: usize) ?*TextBuffer {
    return buffer.createBufferFromFile(std.heap.c_allocator, path[0..len]) catch null;
}

export fn zig_buffer_free(buf: ?*TextBuffer) void {
    if (buf) |real| {
        buffer.destroyBuffer(real);
    }
}

export fn zig_buffer_len(buf: ?*TextBuffer) usize {
    if (buf) |real| {
        return buffer.totalLen(real);
    }
    return 0;
}

export fn zig_buffer_insert_utf8(buf: ?*TextBuffer, pos: usize, data: [*]const u8, len: usize) bool {
    if (buf) |real| {
        buffer.insertBytes(real, pos, data[0..len]) catch return false;
        return true;
    }
    return false;
}

export fn zig_buffer_delete(buf: ?*TextBuffer, pos: usize, len: usize) bool {
    if (buf) |real| {
        buffer.deleteRange(real, pos, len) catch return false;
        return true;
    }
    return false;
}

export fn zig_buffer_read(buf: ?*TextBuffer, start: usize, out: [*]u8, out_len: usize) usize {
    if (buf) |real| {
        return buffer.readRange(real, start, out[0..out_len]);
    }
    return 0;
}

export fn zig_buffer_line_count(buf: ?*TextBuffer) usize {
    if (buf) |real| {
        return buffer.lineCount(real);
    }
    return 0;
}

export fn zig_buffer_line_len(buf: ?*TextBuffer, line_index: usize) usize {
    if (buf) |real| {
        return buffer.lineLen(real, line_index);
    }
    return 0;
}

export fn zig_buffer_read_line(buf: ?*TextBuffer, line_index: usize, out: [*]u8, out_len: usize) usize {
    if (buf) |real| {
        return buffer.readLine(real, line_index, out[0..out_len]);
    }
    return 0;
}

export fn zig_buffer_line_start(buf: ?*TextBuffer, line_index: usize) usize {
    if (buf) |real| {
        return buffer.lineStart(real, line_index);
    }
    return 0;
}

export fn zig_buffer_line_index_for_offset(buf: ?*TextBuffer, offset: usize) usize {
    if (buf) |real| {
        return buffer.lineIndexForOffset(real, offset);
    }
    return 0;
}

export fn zig_buffer_start_line_index_build(buf: ?*TextBuffer) bool {
    if (buf) |real| {
        return buffer.startLineIndexBuild(real);
    }
    return false;
}

export fn zig_buffer_line_index_progress(
    buf: ?*TextBuffer,
    progress_out: *usize,
    total_out: *usize,
    ready_out: *bool,
) bool {
    if (buf) |real| {
        return buffer.lineIndexProgress(real, progress_out, total_out, ready_out);
    }
    return false;
}

export fn zig_buffer_suspend_line_index(buf: ?*TextBuffer) void {
    if (buf) |real| {
        buffer.suspendLineIndex(real);
    }
}

export fn zig_buffer_resume_line_index(buf: ?*TextBuffer) void {
    if (buf) |real| {
        buffer.resumeLineIndex(real);
    }
}

export fn zig_buffer_can_undo(buf: ?*TextBuffer) bool {
    if (buf) |real| {
        return buffer.canUndo(real);
    }
    return false;
}

export fn zig_buffer_can_redo(buf: ?*TextBuffer) bool {
    if (buf) |real| {
        return buffer.canRedo(real);
    }
    return false;
}

export fn zig_buffer_undo(buf: ?*TextBuffer) bool {
    if (buf) |real| {
        return buffer.undo(real) catch false;
    }
    return false;
}

export fn zig_buffer_redo(buf: ?*TextBuffer) bool {
    if (buf) |real| {
        return buffer.redo(real) catch false;
    }
    return false;
}

export fn zig_buffer_undo_with_info(
    buf: ?*TextBuffer,
    kind_out: *u8,
    pos_out: *usize,
    len_out: *usize,
) bool {
    if (buf) |real| {
        return buffer.undoWithInfo(real, kind_out, pos_out, len_out) catch false;
    }
    return false;
}

export fn zig_buffer_redo_with_info(
    buf: ?*TextBuffer,
    kind_out: *u8,
    pos_out: *usize,
    len_out: *usize,
) bool {
    if (buf) |real| {
        return buffer.redoWithInfo(real, kind_out, pos_out, len_out) catch false;
    }
    return false;
}

export fn zig_syntax_create_with_query(
    buf: ?*TextBuffer,
    language: ?*anyopaque,
    query_ptr: [*]const u8,
    query_len: usize,
) ?*syntax.SyntaxHighlighter {
    if (buf == null or language == null) return null;
    const lang_ptr: *const syntax.TSLanguage = @ptrCast(@alignCast(language.?));
    const slice = query_ptr[0..query_len];
    return syntax.createHighlighterWithLanguage(buf.?, lang_ptr, slice) catch null;
}

export fn zig_syntax_destroy(highlighter: ?*syntax.SyntaxHighlighter) void {
    if (highlighter) |real| {
        real.destroy();
    }
}

export fn zig_syntax_reparse(highlighter: ?*syntax.SyntaxHighlighter) bool {
    if (highlighter) |real| {
        return syntax.reparse(real);
    }
    return false;
}

export fn zig_syntax_highlight_range(
    highlighter: ?*syntax.SyntaxHighlighter,
    start: usize,
    end: usize,
    out_ptr: **u64,
    out_len: *usize,
) bool {
    if (highlighter) |real| {
        return syntax.highlightRange(real, start, end, out_ptr, out_len);
    }
    const empty: [1]u64 = .{0};
    out_ptr.* = @constCast(&empty[0]);
    out_len.* = 0;
    return false;
}

export fn zig_syntax_free_highlights(ptr: [*]u64, len: usize) void {
    if (len == 0) return;
    syntax.freeHighlights(ptr, len);
}
