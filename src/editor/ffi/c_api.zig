const bridge = @import("bridge.zig");

pub const ZideEditorHandle = bridge.ZideEditorHandle;
pub const ZideEditorStringBuffer = bridge.StringBuffer;
pub const ZideEditorCaretOffset = bridge.CaretOffset;
pub const ZideEditorSearchMatch = bridge.SearchMatch;
pub const ZideEditorStatus = bridge.Status;
pub const ZIDE_EDITOR_STRING_ABI_VERSION = bridge.string_abi_version;

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

pub fn zide_editor_replace_range(handle: ?*ZideEditorHandle, start: usize, end: usize, bytes: ?[*]const u8, len: usize) c_int {
    return @intFromEnum(bridge.replaceRange(handle, start, end, bytes, len));
}

pub fn zide_editor_delete_range(handle: ?*ZideEditorHandle, start: usize, end: usize) c_int {
    return @intFromEnum(bridge.deleteRange(handle, start, end));
}

pub fn zide_editor_begin_undo_group(handle: ?*ZideEditorHandle) c_int {
    return @intFromEnum(bridge.beginUndoGroup(handle));
}

pub fn zide_editor_end_undo_group(handle: ?*ZideEditorHandle) c_int {
    return @intFromEnum(bridge.endUndoGroup(handle));
}

pub fn zide_editor_text_alloc(handle: ?*ZideEditorHandle, out_string: *ZideEditorStringBuffer) c_int {
    return @intFromEnum(bridge.textAlloc(handle, out_string));
}

pub fn zide_editor_string_free(string: *ZideEditorStringBuffer) void {
    bridge.stringFree(string);
}

pub fn zide_editor_string_abi_version() u32 {
    return bridge.stringAbiVersion();
}

pub fn zide_editor_set_cursor_offset(handle: ?*ZideEditorHandle, offset: usize) c_int {
    return @intFromEnum(bridge.setCursorOffset(handle, offset));
}

pub fn zide_editor_primary_caret_offset(handle: ?*ZideEditorHandle, out_offset: *usize) c_int {
    return @intFromEnum(bridge.primaryCaretOffset(handle, out_offset));
}

pub fn zide_editor_aux_caret_count(handle: ?*ZideEditorHandle, out_count: *usize) c_int {
    return @intFromEnum(bridge.auxiliaryCaretCount(handle, out_count));
}

pub fn zide_editor_aux_caret_get(handle: ?*ZideEditorHandle, index: usize, out_offset: *usize) c_int {
    return @intFromEnum(bridge.auxiliaryCaretGet(handle, index, out_offset));
}

pub fn zide_editor_clear_selections(handle: ?*ZideEditorHandle) c_int {
    return @intFromEnum(bridge.clearSelections(handle));
}

pub fn zide_editor_set_carets(
    handle: ?*ZideEditorHandle,
    primary_offset: usize,
    aux: ?[*]const ZideEditorCaretOffset,
    aux_count: usize,
) c_int {
    return @intFromEnum(bridge.setCarets(handle, primary_offset, aux, aux_count));
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

pub fn zide_editor_search_set_query(handle: ?*ZideEditorHandle, bytes: ?[*]const u8, len: usize, use_regex: u8) c_int {
    return @intFromEnum(bridge.searchSetQuery(handle, bytes, len, use_regex));
}

pub fn zide_editor_search_match_count(handle: ?*ZideEditorHandle, out_count: *usize) c_int {
    return @intFromEnum(bridge.searchMatchCount(handle, out_count));
}

pub fn zide_editor_search_match_get(handle: ?*ZideEditorHandle, index: usize, out_match: *ZideEditorSearchMatch) c_int {
    return @intFromEnum(bridge.searchMatchGet(handle, index, out_match));
}

pub fn zide_editor_search_active_index(handle: ?*ZideEditorHandle, out_index: *usize, out_has_active: *u8) c_int {
    return @intFromEnum(bridge.searchActiveIndex(handle, out_index, out_has_active));
}

pub fn zide_editor_search_next(handle: ?*ZideEditorHandle, out_activated: *u8) c_int {
    return @intFromEnum(bridge.searchNext(handle, out_activated));
}

pub fn zide_editor_search_prev(handle: ?*ZideEditorHandle, out_activated: *u8) c_int {
    return @intFromEnum(bridge.searchPrev(handle, out_activated));
}

pub fn zide_editor_search_replace_active(handle: ?*ZideEditorHandle, bytes: ?[*]const u8, len: usize, out_replaced: *u8) c_int {
    return @intFromEnum(bridge.searchReplaceActive(handle, bytes, len, out_replaced));
}

pub fn zide_editor_search_replace_all(handle: ?*ZideEditorHandle, bytes: ?[*]const u8, len: usize, out_count: *usize) c_int {
    return @intFromEnum(bridge.searchReplaceAll(handle, bytes, len, out_count));
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
