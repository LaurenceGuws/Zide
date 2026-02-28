const std = @import("std");
const c_api = @import("editor/ffi/c_api.zig");

test "editor ffi basic text, cursor, and undo/redo flow" {
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
    const edited = ptrBytes(text.ptr, text.len);
    try std.testing.expect(std.mem.indexOf(u8, edited, "alpha_X_") != null);

    var changed: u8 = 0;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_undo(handle, &changed));
    try std.testing.expectEqual(@as(u8, 1), changed);

    var undo_text: c_api.ZideEditorStringBuffer = .{};
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_text_alloc(handle, &undo_text));
    defer c_api.zide_editor_string_free(&undo_text);
    try std.testing.expectEqualStrings(initial, ptrBytes(undo_text.ptr, undo_text.len));

    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_redo(handle, &changed));
    try std.testing.expectEqual(@as(u8, 1), changed);
}

test "editor ffi validates pointer+len contracts" {
    var handle: ?*c_api.ZideEditorHandle = null;
    try std.testing.expectEqual(@as(c_int, 0), c_api.zide_editor_create(&handle));
    defer c_api.zide_editor_destroy(handle);

    try std.testing.expectEqual(@as(c_int, 1), c_api.zide_editor_set_text(handle, null, 1));
    try std.testing.expectEqual(@as(c_int, 1), c_api.zide_editor_insert_text(handle, null, 1));
}

fn ptrBytes(ptr: ?[*]const u8, len: usize) []const u8 {
    if (len == 0) return &[_]u8{};
    return (ptr orelse return &[_]u8{})[0..len];
}
