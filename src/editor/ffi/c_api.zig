const bridge = @import("bridge.zig");

pub const ZideEditorHandle = bridge.ZideEditorHandle;
pub const ZideEditorStringBuffer = bridge.StringBuffer;
pub const ZideEditorStatus = bridge.Status;

pub fn zide_editor_create(out_handle: *?*ZideEditorHandle) c_int {
    return @intFromEnum(bridge.create(out_handle));
}

pub fn zide_editor_destroy(handle: ?*ZideEditorHandle) void {
    bridge.destroy(handle);
}

pub fn zide_editor_set_text(handle: ?*ZideEditorHandle, bytes: ?[*]const u8, len: usize) c_int {
    return @intFromEnum(bridge.setText(handle, bytes, len));
}

pub fn zide_editor_insert_text(handle: ?*ZideEditorHandle, bytes: ?[*]const u8, len: usize) c_int {
    return @intFromEnum(bridge.insertText(handle, bytes, len));
}

pub fn zide_editor_text_alloc(handle: ?*ZideEditorHandle, out_string: *ZideEditorStringBuffer) c_int {
    return @intFromEnum(bridge.textAlloc(handle, out_string));
}

pub fn zide_editor_string_free(string: *ZideEditorStringBuffer) void {
    bridge.stringFree(string);
}

pub fn zide_editor_set_cursor_offset(handle: ?*ZideEditorHandle, offset: usize) c_int {
    return @intFromEnum(bridge.setCursorOffset(handle, offset));
}

pub fn zide_editor_cursor_offset(handle: ?*ZideEditorHandle, out_offset: *usize) c_int {
    return @intFromEnum(bridge.cursorOffset(handle, out_offset));
}

pub fn zide_editor_undo(handle: ?*ZideEditorHandle, out_changed: *u8) c_int {
    return @intFromEnum(bridge.undo(handle, out_changed));
}

pub fn zide_editor_redo(handle: ?*ZideEditorHandle, out_changed: *u8) c_int {
    return @intFromEnum(bridge.redo(handle, out_changed));
}

pub fn zide_editor_line_count(handle: ?*ZideEditorHandle, out_lines: *usize) c_int {
    return @intFromEnum(bridge.lineCount(handle, out_lines));
}

pub fn zide_editor_total_len(handle: ?*ZideEditorHandle, out_len: *usize) c_int {
    return @intFromEnum(bridge.totalLen(handle, out_len));
}

pub fn zide_editor_status_string(status: c_int) [*:0]const u8 {
    return switch (status) {
        0 => "ok",
        1 => "invalid_argument",
        2 => "out_of_memory",
        3 => "backend_error",
        else => "unknown_status",
    };
}
