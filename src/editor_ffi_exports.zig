const c_api = @import("editor/ffi/c_api.zig");

pub export fn zide_editor_create(out_handle: *?*c_api.ZideEditorHandle) c_int {
    return c_api.zide_editor_create(out_handle);
}

pub export fn zide_editor_destroy(handle: ?*c_api.ZideEditorHandle) void {
    c_api.zide_editor_destroy(handle);
}

pub export fn zide_editor_set_text(handle: ?*c_api.ZideEditorHandle, bytes: ?[*]const u8, len: usize) c_int {
    return c_api.zide_editor_set_text(handle, bytes, len);
}

pub export fn zide_editor_insert_text(handle: ?*c_api.ZideEditorHandle, bytes: ?[*]const u8, len: usize) c_int {
    return c_api.zide_editor_insert_text(handle, bytes, len);
}

pub export fn zide_editor_text_alloc(handle: ?*c_api.ZideEditorHandle, out_string: *c_api.ZideEditorStringBuffer) c_int {
    return c_api.zide_editor_text_alloc(handle, out_string);
}

pub export fn zide_editor_string_free(string: *c_api.ZideEditorStringBuffer) void {
    c_api.zide_editor_string_free(string);
}

pub export fn zide_editor_set_cursor_offset(handle: ?*c_api.ZideEditorHandle, offset: usize) c_int {
    return c_api.zide_editor_set_cursor_offset(handle, offset);
}

pub export fn zide_editor_cursor_offset(handle: ?*c_api.ZideEditorHandle, out_offset: *usize) c_int {
    return c_api.zide_editor_cursor_offset(handle, out_offset);
}

pub export fn zide_editor_undo(handle: ?*c_api.ZideEditorHandle, out_changed: *u8) c_int {
    return c_api.zide_editor_undo(handle, out_changed);
}

pub export fn zide_editor_redo(handle: ?*c_api.ZideEditorHandle, out_changed: *u8) c_int {
    return c_api.zide_editor_redo(handle, out_changed);
}

pub export fn zide_editor_line_count(handle: ?*c_api.ZideEditorHandle, out_lines: *usize) c_int {
    return c_api.zide_editor_line_count(handle, out_lines);
}

pub export fn zide_editor_total_len(handle: ?*c_api.ZideEditorHandle, out_len: *usize) c_int {
    return c_api.zide_editor_total_len(handle, out_len);
}

pub export fn zide_editor_status_string(status: c_int) [*:0]const u8 {
    return c_api.zide_editor_status_string(status);
}
