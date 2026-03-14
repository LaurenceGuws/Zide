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

pub export fn zide_editor_replace_range(
    handle: ?*c_api.ZideEditorHandle,
    start: usize,
    end: usize,
    bytes: ?[*]const u8,
    len: usize,
) c_int {
    return c_api.zide_editor_replace_range(handle, start, end, bytes, len);
}

pub export fn zide_editor_delete_range(handle: ?*c_api.ZideEditorHandle, start: usize, end: usize) c_int {
    return c_api.zide_editor_delete_range(handle, start, end);
}

pub export fn zide_editor_begin_undo_group(handle: ?*c_api.ZideEditorHandle) c_int {
    return c_api.zide_editor_begin_undo_group(handle);
}

pub export fn zide_editor_end_undo_group(handle: ?*c_api.ZideEditorHandle) c_int {
    return c_api.zide_editor_end_undo_group(handle);
}

pub export fn zide_editor_text_alloc(handle: ?*c_api.ZideEditorHandle, out_string: *c_api.ZideEditorStringBuffer) c_int {
    return c_api.zide_editor_text_alloc(handle, out_string);
}

pub export fn zide_editor_string_free(string: *c_api.ZideEditorStringBuffer) void {
    c_api.zide_editor_string_free(string);
}

pub export fn zide_editor_string_abi_version() u32 {
    return c_api.zide_editor_string_abi_version();
}

pub export fn zide_editor_set_cursor_offset(handle: ?*c_api.ZideEditorHandle, offset: usize) c_int {
    return c_api.zide_editor_set_cursor_offset(handle, offset);
}

pub export fn zide_editor_primary_caret_offset(handle: ?*c_api.ZideEditorHandle, out_offset: *usize) c_int {
    return c_api.zide_editor_primary_caret_offset(handle, out_offset);
}

pub export fn zide_editor_aux_caret_count(handle: ?*c_api.ZideEditorHandle, out_count: *usize) c_int {
    return c_api.zide_editor_aux_caret_count(handle, out_count);
}

pub export fn zide_editor_aux_caret_get(handle: ?*c_api.ZideEditorHandle, index: usize, out_offset: *usize) c_int {
    return c_api.zide_editor_aux_caret_get(handle, index, out_offset);
}

pub export fn zide_editor_clear_selections(handle: ?*c_api.ZideEditorHandle) c_int {
    return c_api.zide_editor_clear_selections(handle);
}

pub export fn zide_editor_set_carets(
    handle: ?*c_api.ZideEditorHandle,
    primary_offset: usize,
    aux: ?[*]const c_api.ZideEditorCaretOffset,
    aux_count: usize,
) c_int {
    return c_api.zide_editor_set_carets(handle, primary_offset, aux, aux_count);
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

pub export fn zide_editor_search_set_query(handle: ?*c_api.ZideEditorHandle, bytes: ?[*]const u8, len: usize, use_regex: u8) c_int {
    return c_api.zide_editor_search_set_query(handle, bytes, len, use_regex);
}

pub export fn zide_editor_search_match_count(handle: ?*c_api.ZideEditorHandle, out_count: *usize) c_int {
    return c_api.zide_editor_search_match_count(handle, out_count);
}

pub export fn zide_editor_search_match_get(
    handle: ?*c_api.ZideEditorHandle,
    index: usize,
    out_match: *c_api.ZideEditorSearchMatch,
) c_int {
    return c_api.zide_editor_search_match_get(handle, index, out_match);
}

pub export fn zide_editor_search_active_index(
    handle: ?*c_api.ZideEditorHandle,
    out_index: *usize,
    out_has_active: *u8,
) c_int {
    return c_api.zide_editor_search_active_index(handle, out_index, out_has_active);
}

pub export fn zide_editor_search_next(handle: ?*c_api.ZideEditorHandle, out_activated: *u8) c_int {
    return c_api.zide_editor_search_next(handle, out_activated);
}

pub export fn zide_editor_search_prev(handle: ?*c_api.ZideEditorHandle, out_activated: *u8) c_int {
    return c_api.zide_editor_search_prev(handle, out_activated);
}

pub export fn zide_editor_search_replace_active(
    handle: ?*c_api.ZideEditorHandle,
    bytes: ?[*]const u8,
    len: usize,
    out_replaced: *u8,
) c_int {
    return c_api.zide_editor_search_replace_active(handle, bytes, len, out_replaced);
}

pub export fn zide_editor_search_replace_all(
    handle: ?*c_api.ZideEditorHandle,
    bytes: ?[*]const u8,
    len: usize,
    out_count: *usize,
) c_int {
    return c_api.zide_editor_search_replace_all(handle, bytes, len, out_count);
}

pub export fn zide_editor_status_string(status: c_int) [*:0]const u8 {
    return c_api.zide_editor_status_string(status);
}
