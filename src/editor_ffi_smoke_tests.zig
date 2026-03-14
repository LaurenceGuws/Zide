const std = @import("std");
const c_api = @import("editor/ffi/c_api.zig");

test "editor ffi basic text, cursor, and undo/redo flow" {
    try std.testing.expectEqual(c_api.ZIDE_EDITOR_STRING_ABI_VERSION, c_api.zide_editor_string_abi_version());

    var handle: ?*c_api.ZideEditorHandle = null;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_create(&handle));
    defer c_api.zide_editor_destroy(handle);

    const initial = "alpha\nbeta\n";
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_set_text(handle, initial.ptr, initial.len));

    var len: usize = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_total_len(handle, &len));
    try std.testing.expectEqual(initial.len, len);

    var lines: usize = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_line_count(handle, &lines));
    try std.testing.expect(lines >= 2);

    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_set_cursor_offset(handle, 5));
    const insert = "_X_";
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_insert_text(handle, insert.ptr, insert.len));

    var text: c_api.ZideEditorStringBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_text_alloc(handle, &text));
    defer c_api.zide_editor_string_free(&text);
    try std.testing.expectEqual(c_api.ZIDE_EDITOR_STRING_ABI_VERSION, text.abi_version);
    try std.testing.expectEqual(@as(u32, @sizeOf(c_api.ZideEditorStringBuffer)), text.struct_size);
    const edited = ptrBytes(text.ptr, text.len);
    try std.testing.expect(std.mem.indexOf(u8, edited, "alpha_X_") != null);

    var changed: u8 = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_undo(handle, &changed));
    try std.testing.expectEqual(@as(u8, 1), changed);

    var undo_text: c_api.ZideEditorStringBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_text_alloc(handle, &undo_text));
    defer c_api.zide_editor_string_free(&undo_text);
    try std.testing.expectEqual(c_api.ZIDE_EDITOR_STRING_ABI_VERSION, undo_text.abi_version);
    try std.testing.expectEqual(@as(u32, @sizeOf(c_api.ZideEditorStringBuffer)), undo_text.struct_size);
    try std.testing.expectEqualStrings(initial, ptrBytes(undo_text.ptr, undo_text.len));

    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_redo(handle, &changed));
    try std.testing.expectEqual(@as(u8, 1), changed);
}

test "editor ffi replace/delete range and grouped undo" {
    var handle: ?*c_api.ZideEditorHandle = null;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_create(&handle));
    defer c_api.zide_editor_destroy(handle);

    const initial = "abcdef";
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_set_text(handle, initial.ptr, initial.len));
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_replace_range(handle, 1, 4, "XX".ptr, 2));
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_delete_range(handle, 3, 4));

    var text: c_api.ZideEditorStringBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_text_alloc(handle, &text));
    defer c_api.zide_editor_string_free(&text);
    try std.testing.expectEqual(c_api.ZIDE_EDITOR_STRING_ABI_VERSION, text.abi_version);
    try std.testing.expectEqual(@as(u32, @sizeOf(c_api.ZideEditorStringBuffer)), text.struct_size);
    try std.testing.expectEqualStrings("aXXf", ptrBytes(text.ptr, text.len));

    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_set_text(handle, initial.ptr, initial.len));
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_begin_undo_group(handle));
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_replace_range(handle, 1, 2, "Y".ptr, 1));
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_replace_range(handle, 4, 5, "Z".ptr, 1));
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_end_undo_group(handle));

    var changed: u8 = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_undo(handle, &changed));
    try std.testing.expectEqual(@as(u8, 1), changed);

    var undo_text: c_api.ZideEditorStringBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_text_alloc(handle, &undo_text));
    defer c_api.zide_editor_string_free(&undo_text);
    try std.testing.expectEqual(c_api.ZIDE_EDITOR_STRING_ABI_VERSION, undo_text.abi_version);
    try std.testing.expectEqual(@as(u32, @sizeOf(c_api.ZideEditorStringBuffer)), undo_text.struct_size);
    try std.testing.expectEqualStrings(initial, ptrBytes(undo_text.ptr, undo_text.len));
}

test "editor ffi string release zeroes exported struct" {
    var handle: ?*c_api.ZideEditorHandle = null;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_create(&handle));
    defer c_api.zide_editor_destroy(handle);

    const text_value = "abc";
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_set_text(handle, text_value.ptr, text_value.len));

    var text: c_api.ZideEditorStringBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_text_alloc(handle, &text));
    c_api.zide_editor_string_free(&text);
    try std.testing.expectEqual(@as(u32, 0), text.abi_version);
    try std.testing.expectEqual(@as(u32, 0), text.struct_size);
    try std.testing.expectEqual(@as(usize, 0), text.len);
    try std.testing.expectEqual(@as(?*anyopaque, null), text._ctx);
}

test "editor ffi validates pointer+len contracts" {
    var handle: ?*c_api.ZideEditorHandle = null;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_create(&handle));
    defer c_api.zide_editor_destroy(handle);

    try std.testing.expectEqual(@as(c_int, 1), c_api.zide_editor_set_text(handle, null, 1));
    try std.testing.expectEqual(@as(c_int, 1), c_api.zide_editor_insert_text(handle, null, 1));
}

test "editor ffi multicursor set/get offsets" {
    var handle: ?*c_api.ZideEditorHandle = null;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_create(&handle));
    defer c_api.zide_editor_destroy(handle);

    const text = "aa\nbb\ncc\n";
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_set_text(handle, text.ptr, text.len));

    const aux = [_]c_api.ZideEditorCaretOffset{
        .{ .offset = 4 },
        .{ .offset = 7 },
    };
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_set_carets(handle, 1, &aux, aux.len));

    var primary: usize = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_primary_caret_offset(handle, &primary));
    try std.testing.expectEqual(@as(usize, 1), primary);

    var aux_count: usize = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_aux_caret_count(handle, &aux_count));
    try std.testing.expectEqual(aux.len, aux_count);

    var aux0: usize = 0;
    var aux1: usize = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_aux_caret_get(handle, 0, &aux0));
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_aux_caret_get(handle, 1, &aux1));
    try std.testing.expectEqual(@as(usize, 4), aux0);
    try std.testing.expectEqual(@as(usize, 7), aux1);
}

test "editor ffi search and replace flow" {
    var handle: ?*c_api.ZideEditorHandle = null;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_create(&handle));
    defer c_api.zide_editor_destroy(handle);

    const text = "foo bar foo baz";
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_set_text(handle, text.ptr, text.len));
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_search_set_query(handle, "foo".ptr, 3, 0));

    var count: usize = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_search_match_count(handle, &count));
    try std.testing.expectEqual(@as(usize, 2), count);

    var m0: c_api.ZideEditorSearchMatch = .{ .start = 0, .end = 0 };
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_search_match_get(handle, 0, &m0));
    try std.testing.expectEqual(@as(usize, 0), m0.start);
    try std.testing.expectEqual(@as(usize, 3), m0.end);

    var activated: u8 = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_search_next(handle, &activated));
    try std.testing.expectEqual(@as(u8, 1), activated);

    var replaced: u8 = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_search_replace_active(handle, "qux".ptr, 3, &replaced));
    try std.testing.expectEqual(@as(u8, 1), replaced);

    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_search_set_query(handle, "ba.".ptr, 3, 1));
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_search_match_count(handle, &count));
    try std.testing.expectEqual(@as(usize, 2), count);

    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_search_set_query(handle, "foo".ptr, 3, 0));
    var replaced_all: usize = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_search_replace_all(handle, "x".ptr, 1, &replaced_all));
    try std.testing.expectEqual(@as(usize, 1), replaced_all);
}

fn ptrBytes(ptr: ?[*]const u8, len: usize) []const u8 {
    if (len == 0) return &[_]u8{};
    return (ptr orelse return &[_]u8{})[0..len];
}
