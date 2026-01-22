const std = @import("std");
const Editor = @import("editor/editor.zig").Editor;

test "editor selection replace uses single undo" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("hello world");
    editor.selection = .{
        .start = .{ .line = 0, .col = 6, .offset = 6 },
        .end = .{ .line = 0, .col = 11, .offset = 11 },
    };

    try editor.insertText("zide");
    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("hello zide", after);

    try std.testing.expect(try editor.undo());
    const undone = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(undone);
    try std.testing.expectEqualStrings("hello world", undone);
}

test "editor grouped undo with mixed insert/delete" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("abcdef");
    editor.selection = .{
        .start = .{ .line = 0, .col = 2, .offset = 2 },
        .end = .{ .line = 0, .col = 4, .offset = 4 },
    };
    try editor.insertText("XY");
    try editor.insertText("!");

    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("abXY!ef", after);

    try std.testing.expect(try editor.undo());
    const undone = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(undone);
    try std.testing.expectEqualStrings("abXYef", undone);
}

test "editor explicit undo group wraps multiple ops" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    editor.beginUndoGroup();
    try editor.insertText("foo");
    try editor.insertText("bar");
    try editor.endUndoGroup();

    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("foobar", after);

    try std.testing.expect(try editor.undo());
    const undone = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(undone);
    try std.testing.expectEqualStrings("", undone);
}

test "editor undo redo updates cursor offset" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("word1 word2");
    editor.selection = .{
        .start = .{ .line = 0, .col = 5, .offset = 5 },
        .end = .{ .line = 0, .col = 11, .offset = 11 },
    };
    try editor.deleteSelection();

    const after_delete = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after_delete);
    try std.testing.expectEqualStrings("word1", after_delete);
    try std.testing.expectEqual(@as(usize, 5), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 5), editor.cursor.col);

    try std.testing.expect(try editor.undo());
    const after_undo = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after_undo);
    try std.testing.expectEqualStrings("word1 word2", after_undo);
    try std.testing.expectEqual(@as(usize, 11), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 11), editor.cursor.col);

    try std.testing.expect(try editor.redo());
    const after_redo = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after_redo);
    try std.testing.expectEqualStrings("word1", after_redo);
    try std.testing.expectEqual(@as(usize, 5), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 5), editor.cursor.col);
}

test "editor line width cache counts utf8 codepoints" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("aé文𐍈");
    const line = try editor.getLineAlloc(0);
    defer allocator.free(line);
    try std.testing.expectEqual(@as(usize, 4), editor.lineWidthCached(0, line, null));
}

test "editor selection normalization merges overlaps" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("abcdef");
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 1, .offset = 1 },
        .end = .{ .line = 0, .col = 3, .offset = 3 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 2, .offset = 2 },
        .end = .{ .line = 0, .col = 5, .offset = 5 },
    });
    try editor.normalizeSelections();

    try std.testing.expectEqual(@as(usize, 1), editor.selectionCount());
    const sel = editor.selectionAt(0) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 1), sel.start.offset);
    try std.testing.expectEqual(@as(usize, 5), sel.end.offset);
}

test "editor rectangular selections do not merge" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("one\ntwo\nthree");
    try editor.addRectSelection(.{ .line = 0, .col = 0, .offset = 0 }, .{ .line = 0, .col = 2, .offset = 2 });
    try editor.addRectSelection(.{ .line = 0, .col = 1, .offset = 1 }, .{ .line = 0, .col = 3, .offset = 3 });
    try editor.normalizeSelections();

    try std.testing.expectEqual(@as(usize, 2), editor.selectionCount());
    const first = editor.selectionAt(0) orelse return error.TestUnexpectedResult;
    const second = editor.selectionAt(1) orelse return error.TestUnexpectedResult;
    try std.testing.expect(first.is_rectangular);
    try std.testing.expect(second.is_rectangular);
}

test "editor expand rect selection creates per-line selections" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("one\ntwo\nthree");
    try editor.expandRectSelection(0, 2, 1, 3);
    try std.testing.expectEqual(@as(usize, 3), editor.selectionCount());
}

test "editor insert across rectangular selections" {
    const allocator = std.testing.allocator;
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    try editor.insertText("one\ntwo\nthree");
    try editor.expandRectSelection(0, 2, 1, 2);
    try editor.insertChar('X');

    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("oXe\ntXo\ntXree", after);
}
