const std = @import("std");
const Editor = @import("editor/editor.zig").Editor;
const grammar_manager_mod = @import("editor/grammar_manager.zig");
const syntax_mod = @import("editor/syntax.zig");
const ts_api = @import("editor/treesitter_api.zig");
const shared_types = @import("types/mod.zig");
const renderer_mod = @import("ui/renderer.zig");
const cursor_mod = @import("editor/view/cursor.zig");

extern "c" fn tree_sitter_zig() *const ts_api.c_api.TSLanguage;

const EditorFixture = struct {
    grammar_manager: grammar_manager_mod.GrammarManager,
    editor: *Editor,

    pub fn init(allocator: std.mem.Allocator) !EditorFixture {
        var grammar_manager = try grammar_manager_mod.GrammarManager.init(allocator);
        const editor = try Editor.init(allocator, &grammar_manager);
        return .{
            .grammar_manager = grammar_manager,
            .editor = editor,
        };
    }

    pub fn deinit(self: *EditorFixture) void {
        self.editor.deinit();
        self.grammar_manager.deinit();
    }
};

test "editor selection replace uses single undo" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

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
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

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
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

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
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

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

test "editor undo redo restores multi-caret selection set" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcdef");
    editor.setCursor(0, 3);
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 1, .offset = 1 },
        .end = .{ .line = 0, .col = 1, .offset = 1 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 5, .offset = 5 },
        .end = .{ .line = 0, .col = 5, .offset = 5 },
    });

    try editor.insertChar('X');

    try std.testing.expect(try editor.undo());
    const after_undo = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after_undo);
    try std.testing.expectEqualStrings("abcdef", after_undo);
    try std.testing.expectEqual(@as(usize, 3), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 2), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 1), editor.selectionAt(0).?.start.offset);
    try std.testing.expectEqual(@as(usize, 5), editor.selectionAt(1).?.start.offset);

    try std.testing.expect(try editor.redo());
    const after_redo = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after_redo);
    try std.testing.expectEqualStrings("aXbcXdeXf", after_redo);
    try std.testing.expectEqual(@as(usize, 5), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 2), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 2), editor.selectionAt(0).?.start.offset);
    try std.testing.expectEqual(@as(usize, 8), editor.selectionAt(1).?.start.offset);
}

test "editor line width cache counts utf8 codepoints" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("aé文𐍈");
    const line = try editor.getLineAlloc(0);
    defer allocator.free(line);
    try std.testing.expectEqual(@as(usize, 4), editor.lineWidthCached(0, line, null));
}

test "editor line width cache uses grapheme clusters when provided" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    // "a" + combining acute accent + "b" should be 2 grapheme clusters.
    try editor.insertText("a\u{0301}b");
    const line = try editor.getLineAlloc(0);
    defer allocator.free(line);

    const clusters = [_]u32{ 0, 3 };
    try std.testing.expectEqual(@as(usize, 2), editor.lineWidthCached(0, line, &clusters));
}

test "text event utf8Slice returns live struct bytes" {
    const event: shared_types.input.TextEvent = .{
        .codepoint = 'd',
        .utf8_len = 1,
        .utf8 = .{ 'd', 0, 0, 0 },
    };

    try std.testing.expectEqualStrings("d", event.utf8Slice());
}

test "editor selection normalization merges overlaps" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

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
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

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
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("one\ntwo\nthree");
    try editor.expandRectSelection(0, 2, 1, 3);
    try std.testing.expectEqual(@as(usize, 3), editor.selectionCount());
}

test "editor insert across rectangular selections" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("one\ntwo\nthree");
    try editor.expandRectSelection(0, 2, 1, 2);
    try editor.insertChar('X');

    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("oXe\ntXo\ntXree", after);
}

test "editor insert across rectangular selections preserves caret set" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("one\ntwo\nthree");
    try editor.expandRectSelection(0, 2, 1, 2);
    try editor.insertChar('X');

    try std.testing.expectEqual(@as(usize, 3), editor.selectionCount());

    const first = editor.selectionAt(0) orelse return error.TestUnexpectedResult;
    const second = editor.selectionAt(1) orelse return error.TestUnexpectedResult;
    const third = editor.selectionAt(2) orelse return error.TestUnexpectedResult;

    try std.testing.expect(first.isEmpty());
    try std.testing.expect(second.isEmpty());
    try std.testing.expect(third.isEmpty());
    try std.testing.expectEqual(@as(usize, 2), first.start.offset);
    try std.testing.expectEqual(@as(usize, 6), second.start.offset);
    try std.testing.expectEqual(@as(usize, 10), third.start.offset);
}

test "editor delete across selections preserves caret set" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcdef");
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 1, .offset = 1 },
        .end = .{ .line = 0, .col = 2, .offset = 2 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 4, .offset = 4 },
        .end = .{ .line = 0, .col = 6, .offset = 6 },
    });

    try editor.deleteSelection();

    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("acd", after);
    try std.testing.expectEqual(@as(usize, 1), editor.selectionCount());

    const first = editor.selectionAt(0) orelse return error.TestUnexpectedResult;
    try std.testing.expect(first.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), first.start.offset);
    try std.testing.expectEqual(@as(usize, 3), editor.cursor.offset);
}

test "editor backspace across zero-length carets preserves caret set" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcdef");
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 2, .offset = 2 },
        .end = .{ .line = 0, .col = 2, .offset = 2 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 5, .offset = 5 },
        .end = .{ .line = 0, .col = 5, .offset = 5 },
    });

    try editor.deleteCharBackward();

    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("acd", after);
    try std.testing.expectEqual(@as(usize, 1), editor.selectionCount());

    const first = editor.selectionAt(0) orelse return error.TestUnexpectedResult;
    try std.testing.expect(first.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), first.start.offset);
    try std.testing.expectEqual(@as(usize, 3), editor.cursor.offset);
}

test "editor delete forward across zero-length carets preserves caret set" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcdef");
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 1, .offset = 1 },
        .end = .{ .line = 0, .col = 1, .offset = 1 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 4, .offset = 4 },
        .end = .{ .line = 0, .col = 4, .offset = 4 },
    });

    try editor.deleteCharForward();

    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("acdf", after);
    try std.testing.expectEqual(@as(usize, 2), editor.selectionCount());

    const first = editor.selectionAt(0) orelse return error.TestUnexpectedResult;
    const second = editor.selectionAt(1) orelse return error.TestUnexpectedResult;
    try std.testing.expect(first.isEmpty());
    try std.testing.expect(second.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), first.start.offset);
    try std.testing.expectEqual(@as(usize, 3), second.start.offset);
    try std.testing.expectEqual(@as(usize, 4), editor.cursor.offset);
}

test "editor backspace across mixed range and caret broadcasts both" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcdef");
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 1, .offset = 1 },
        .end = .{ .line = 0, .col = 3, .offset = 3 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 5, .offset = 5 },
        .end = .{ .line = 0, .col = 5, .offset = 5 },
    });

    try editor.deleteCharBackward();

    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("adf", after);
    try std.testing.expectEqual(@as(usize, 2), editor.selectionCount());

    const first = editor.selectionAt(0) orelse return error.TestUnexpectedResult;
    const second = editor.selectionAt(1) orelse return error.TestUnexpectedResult;
    try std.testing.expect(first.isEmpty());
    try std.testing.expect(second.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), first.start.offset);
    try std.testing.expectEqual(@as(usize, 2), second.start.offset);
}

test "editor add caret down duplicates current caret by line" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("one\ntwo\nthree");
    editor.setCursor(0, 1);

    try std.testing.expect(try editor.addCaretDown());
    try std.testing.expectEqual(@as(usize, 1), editor.selectionCount());
    const added = editor.selectionAt(0) orelse return error.TestUnexpectedResult;
    try std.testing.expect(added.isEmpty());
    try std.testing.expectEqual(@as(usize, 5), added.start.offset);
}

test "editor add caret down duplicates all current carets" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("one\ntwo\nthree");
    editor.setCursor(0, 1);
    try std.testing.expect(try editor.addCaretDown());
    try std.testing.expect(try editor.addCaretDown());

    try std.testing.expectEqual(@as(usize, 2), editor.selectionCount());
    const first = editor.selectionAt(0) orelse return error.TestUnexpectedResult;
    const second = editor.selectionAt(1) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 5), first.start.offset);
    try std.testing.expectEqual(@as(usize, 9), second.start.offset);
}

test "editor move left preserves zero-length caret set" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcdef");
    editor.setCursor(0, 3);
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 1, .offset = 1 },
        .end = .{ .line = 0, .col = 1, .offset = 1 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 5, .offset = 5 },
        .end = .{ .line = 0, .col = 5, .offset = 5 },
    });

    editor.moveCursorLeft();

    try std.testing.expectEqual(@as(usize, 2), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 2), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 0), editor.selectionAt(0).?.start.offset);
    try std.testing.expectEqual(@as(usize, 4), editor.selectionAt(1).?.start.offset);
}

test "editor extend left preserves multi-caret set as ranges" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcdef");
    editor.setCursor(0, 3);
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 1, .offset = 1 },
        .end = .{ .line = 0, .col = 1, .offset = 1 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 5, .offset = 5 },
        .end = .{ .line = 0, .col = 5, .offset = 5 },
    });

    editor.extendSelectionLeft();

    try std.testing.expectEqual(@as(usize, 2), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 3), editor.selection.?.start.offset);
    try std.testing.expectEqual(@as(usize, 2), editor.selection.?.end.offset);
    try std.testing.expectEqual(@as(usize, 2), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 1), editor.selectionAt(0).?.start.offset);
    try std.testing.expectEqual(@as(usize, 0), editor.selectionAt(0).?.end.offset);
    try std.testing.expectEqual(@as(usize, 5), editor.selectionAt(1).?.start.offset);
    try std.testing.expectEqual(@as(usize, 4), editor.selectionAt(1).?.end.offset);
}

test "editor extend word right preserves existing multi-range anchors" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta\ngamma delta");
    editor.setCursor(0, 6);
    editor.selection = .{
        .start = .{ .line = 0, .col = 0, .offset = 0 },
        .end = .{ .line = 0, .col = 6, .offset = 6 },
    };
    try editor.addSelection(.{
        .start = .{ .line = 1, .col = 0, .offset = 11 },
        .end = .{ .line = 1, .col = 5, .offset = 16 },
    });

    editor.extendSelectionWordRight();

    try std.testing.expectEqual(@as(usize, 11), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 0), editor.selection.?.start.offset);
    try std.testing.expectEqual(@as(usize, 11), editor.selection.?.end.offset);
    try std.testing.expectEqual(@as(usize, 1), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 11), editor.selectionAt(0).?.start.offset);
    try std.testing.expectEqual(@as(usize, 17), editor.selectionAt(0).?.end.offset);
}

test "editor move right collapses mixed multi-range selection set to right edges" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta\ngamma");
    editor.setCursor(0, 6);
    editor.selection = .{
        .start = .{ .line = 0, .col = 0, .offset = 0 },
        .end = .{ .line = 0, .col = 6, .offset = 6 },
    };
    try editor.addSelection(.{
        .start = .{ .line = 1, .col = 0, .offset = 11 },
        .end = .{ .line = 1, .col = 5, .offset = 16 },
    });

    editor.moveCursorRight();

    try std.testing.expect(editor.selection == null);
    try std.testing.expectEqual(@as(usize, 6), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 1), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 16), editor.selectionAt(0).?.start.offset);
    try std.testing.expectEqual(@as(usize, 16), editor.selectionAt(0).?.end.offset);
}

test "editor move up collapses mixed multi-range selection set to left edges" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta\ngamma");
    editor.setCursor(0, 6);
    editor.selection = .{
        .start = .{ .line = 0, .col = 0, .offset = 0 },
        .end = .{ .line = 0, .col = 6, .offset = 6 },
    };
    try editor.addSelection(.{
        .start = .{ .line = 1, .col = 0, .offset = 11 },
        .end = .{ .line = 1, .col = 5, .offset = 16 },
    });

    editor.moveCursorUp();

    try std.testing.expect(editor.selection == null);
    try std.testing.expectEqual(@as(usize, 0), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 1), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 11), editor.selectionAt(0).?.start.offset);
    try std.testing.expectEqual(@as(usize, 11), editor.selectionAt(0).?.end.offset);
}

test "editor move down collapses mixed multi-range selection set to right edges" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta\ngamma");
    editor.setCursor(0, 6);
    editor.selection = .{
        .start = .{ .line = 0, .col = 0, .offset = 0 },
        .end = .{ .line = 0, .col = 6, .offset = 6 },
    };
    try editor.addSelection(.{
        .start = .{ .line = 1, .col = 0, .offset = 11 },
        .end = .{ .line = 1, .col = 5, .offset = 16 },
    });

    editor.moveCursorDown();

    try std.testing.expect(editor.selection == null);
    try std.testing.expectEqual(@as(usize, 6), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 1), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 16), editor.selectionAt(0).?.start.offset);
    try std.testing.expectEqual(@as(usize, 16), editor.selectionAt(0).?.end.offset);
}

test "editor move to line end preserves zero-length caret set" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("ab\ncdef\nghi");
    editor.setCursor(0, 1);
    try editor.addSelection(.{
        .start = .{ .line = 1, .col = 1, .offset = 4 },
        .end = .{ .line = 1, .col = 1, .offset = 4 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 2, .col = 0, .offset = 8 },
        .end = .{ .line = 2, .col = 0, .offset = 8 },
    });

    editor.moveCursorToLineEnd();

    try std.testing.expectEqual(@as(usize, 2), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 2), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 7), editor.selectionAt(0).?.start.offset);
    try std.testing.expectEqual(@as(usize, 11), editor.selectionAt(1).?.start.offset);
}

test "editor insert across caret set preserves primary cursor ownership" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcdef");
    editor.setCursor(0, 3);
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 1, .offset = 1 },
        .end = .{ .line = 0, .col = 1, .offset = 1 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 5, .offset = 5 },
        .end = .{ .line = 0, .col = 5, .offset = 5 },
    });

    try editor.insertChar('X');

    try std.testing.expectEqual(@as(usize, 5), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 2), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 2), editor.selectionAt(0).?.start.offset);
    try std.testing.expectEqual(@as(usize, 8), editor.selectionAt(1).?.start.offset);
}

test "editor caret accessors expose primary and auxiliary carets separately" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcdef");
    editor.setCursor(0, 3);
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 1, .offset = 1 },
        .end = .{ .line = 0, .col = 1, .offset = 1 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 5, .offset = 5 },
        .end = .{ .line = 0, .col = 5, .offset = 5 },
    });

    try std.testing.expectEqual(@as(usize, 3), editor.primaryCaret().offset);
    try std.testing.expectEqual(@as(usize, 2), editor.auxiliaryCaretCount());
    try std.testing.expectEqual(@as(usize, 1), editor.auxiliaryCaretAt(0).?.offset);
    try std.testing.expectEqual(@as(usize, 5), editor.auxiliaryCaretAt(1).?.offset);
    try std.testing.expect(editor.auxiliaryCaretAt(2) == null);
}

test "editor core visual rectangular expansion can use cluster provider" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("e\u{0301}界x\na界bc");

    const Ctx = struct {
        fn clusters(_: *anyopaque, line_idx: usize, line_text: []const u8) ?[]const u32 {
            _ = line_text;
            return switch (line_idx) {
                0 => &[_]u32{ 0, 3, 6 },
                1 => &[_]u32{ 0, 1, 4, 5 },
                else => null,
            };
        }
    };
    var dummy: u8 = 0;
    const provider = Editor.ClusterProvider{
        .ctx = &dummy,
        .getClusters = Ctx.clusters,
    };

    try editor.expandRectSelectionVisualWithClusters(0, 1, 1, 3, &provider);

    try std.testing.expectEqual(@as(usize, 2), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 3), editor.selectionAt(0).?.start.offset);
    try std.testing.expectEqual(@as(usize, 6), editor.selectionAt(0).?.end.offset);
    try std.testing.expectEqual(@as(usize, 9), editor.selectionAt(1).?.start.offset);
    try std.testing.expectEqual(@as(usize, 12), editor.selectionAt(1).?.end.offset);
}

test "editor word movement advances by word boundaries" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta_gamma  delta");
    editor.setCursor(0, 0);
    editor.moveCursorWordRight();
    try std.testing.expectEqual(@as(usize, 6), editor.cursor.offset);
    editor.moveCursorWordRight();
    try std.testing.expectEqual(@as(usize, 18), editor.cursor.offset);
    editor.moveCursorWordLeft();
    try std.testing.expectEqual(@as(usize, 6), editor.cursor.offset);
}

test "editor extend selection word right uses current cursor as anchor" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta");
    editor.setCursor(0, 0);
    editor.extendSelectionWordRight();

    const sel = editor.selection orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 0), sel.start.offset);
    try std.testing.expectEqual(@as(usize, 6), sel.end.offset);
    try std.testing.expectEqual(@as(usize, 6), editor.cursor.offset);
}

test "editor extend selection to line end" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha\nbeta");
    editor.setCursor(0, 2);
    editor.extendSelectionToLineEnd();

    const sel = editor.selection orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 2), sel.start.offset);
    try std.testing.expectEqual(@as(usize, 5), sel.end.offset);
    try std.testing.expectEqual(@as(usize, 5), editor.cursor.offset);
}

test "editor visual move down preserves zero-length caret set" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("one\ntwo\nthree");
    editor.setCursor(0, 1);
    try editor.addSelection(.{
        .start = .{ .line = 1, .col = 1, .offset = 5 },
        .end = .{ .line = 1, .col = 1, .offset = 5 },
    });

    var renderer = FakeRenderer.init(allocator, 320, 64, 8, 16);
    defer renderer.deinit();
    var widget = FakeWidget{ .editor = editor, .gutter_width = 0, .wrap_enabled = false };

    try std.testing.expect(try widget.moveCursorVisual(&renderer, 1));
    try std.testing.expectEqual(@as(usize, 5), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 2), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 5), editor.selectionAt(0).?.start.offset);
    try std.testing.expectEqual(@as(usize, 9), editor.selectionAt(1).?.start.offset);
}

test "editor visual selection extend follows wrapped segments" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcdefghij");
    editor.setCursor(0, 1);

    var renderer = FakeRenderer.init(allocator, 74, 200, 8, 16);
    defer renderer.deinit();
    var widget = FakeWidget{ .editor = editor, .gutter_width = 50, .wrap_enabled = true };

    try std.testing.expect(widget.extendSelectionVisual(&renderer, 1));
    const down_sel = editor.selection orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 1), down_sel.start.offset);
    try std.testing.expectEqual(@as(usize, 4), down_sel.end.offset);
    try std.testing.expectEqual(@as(usize, 4), editor.cursor.offset);

    try std.testing.expect(widget.extendSelectionVisual(&renderer, 1));
    const next_sel = editor.selection orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 1), next_sel.start.offset);
    try std.testing.expectEqual(@as(usize, 7), next_sel.end.offset);
    try std.testing.expectEqual(@as(usize, 7), editor.cursor.offset);
}

test "editor visual selection extend follows logical lines when wrap is disabled" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcd\nef\nghij");
    editor.setCursor(1, 1);

    var renderer = FakeRenderer.init(allocator, 320, 200, 8, 16);
    defer renderer.deinit();
    var widget = FakeWidget{ .editor = editor, .gutter_width = 0, .wrap_enabled = false };

    try std.testing.expect(widget.extendSelectionVisual(&renderer, -1));
    const up_sel = editor.selection orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 6), up_sel.start.offset);
    try std.testing.expectEqual(@as(usize, 1), up_sel.end.offset);
    try std.testing.expectEqual(@as(usize, 1), editor.cursor.offset);

    try std.testing.expect(widget.extendSelectionVisual(&renderer, 1));
    try std.testing.expect(editor.selection == null);
    try std.testing.expectEqual(@as(usize, 6), editor.cursor.offset);
}

test "editor visual selection extend preserves multi-caret set" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("one\ntwo\nthree");
    editor.setCursor(0, 1);
    try editor.addSelection(.{
        .start = .{ .line = 1, .col = 1, .offset = 5 },
        .end = .{ .line = 1, .col = 1, .offset = 5 },
    });

    var renderer = FakeRenderer.init(allocator, 320, 200, 8, 16);
    defer renderer.deinit();
    var widget = FakeWidget{ .editor = editor, .gutter_width = 0, .wrap_enabled = false };

    try std.testing.expect(widget.extendSelectionVisual(&renderer, 1));
    try std.testing.expectEqual(@as(usize, 5), editor.cursor.offset);
    try std.testing.expectEqual(@as(usize, 1), editor.selection.?.start.offset);
    try std.testing.expectEqual(@as(usize, 5), editor.selection.?.end.offset);
    try std.testing.expectEqual(@as(usize, 1), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 5), editor.selectionAt(0).?.start.offset);
    try std.testing.expectEqual(@as(usize, 9), editor.selectionAt(0).?.end.offset);
}

const draw_mod = @import("ui/widgets/editor_widget_draw.zig");
const editor_render = @import("editor/render/renderer_ops.zig");
const cache_mod = @import("editor/render/cache.zig");

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

const Theme = struct {
    background: Color = Color{ .r = 40, .g = 42, .b = 54 },
    foreground: Color = Color{ .r = 248, .g = 248, .b = 242 },
    selection: Color = Color{ .r = 68, .g = 71, .b = 90 },
    cursor: Color = Color{ .r = 248, .g = 248, .b = 242 },
    link: Color = Color{ .r = 139, .g = 233, .b = 253 },
    line_number: Color = Color{ .r = 98, .g = 114, .b = 164 },
    line_number_bg: Color = Color{ .r = 33, .g = 34, .b = 44 },
    current_line: Color = Color{ .r = 50, .g = 52, .b = 66 },
    comment_color: Color = Color{ .r = 98, .g = 114, .b = 164 },
    string: Color = Color{ .r = 241, .g = 250, .b = 140 },
    keyword: Color = Color{ .r = 255, .g = 121, .b = 198 },
    number: Color = Color{ .r = 189, .g = 147, .b = 249 },
    function: Color = Color{ .r = 80, .g = 250, .b = 123 },
    variable: Color = Color{ .r = 248, .g = 248, .b = 242 },
    type_name: Color = Color{ .r = 139, .g = 233, .b = 253 },
    operator: Color = Color{ .r = 255, .g = 121, .b = 198 },
    builtin_color: Color = Color{ .r = 139, .g = 233, .b = 253 },
    punctuation: Color = Color{ .r = 248, .g = 248, .b = 242 },
    constant: Color = Color{ .r = 189, .g = 147, .b = 249 },
    attribute: Color = Color{ .r = 80, .g = 250, .b = 123 },
    namespace: Color = Color{ .r = 139, .g = 233, .b = 253 },
    label: Color = Color{ .r = 139, .g = 233, .b = 253 },
    error_token: Color = Color{ .r = 255, .g = 85, .b = 85 },
};

const DrawLog = struct {
    allocator: std.mem.Allocator,
    data: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) DrawLog {
        return .{ .allocator = allocator, .data = .empty };
    }

    pub fn deinit(self: *DrawLog) void {
        self.data.deinit(self.allocator);
    }

    pub fn append(self: *DrawLog, comptime fmt: []const u8, args: anytype) void {
        self.data.writer(self.allocator).print(fmt, args) catch {};
    }

    pub fn appendColor(self: *DrawLog, color: Color) void {
        self.append("#{X:0>2}{X:0>2}{X:0>2}{X:0>2}", .{ color.r, color.g, color.b, color.a });
    }

    pub fn appendEscaped(self: *DrawLog, text: []const u8) void {
        for (text) |ch| {
            switch (ch) {
                '\\' => self.append("\\\\", .{}),
                '"' => self.append("\\\"", .{}),
                '\n' => self.append("\\n", .{}),
                '\r' => self.append("\\r", .{}),
                '\t' => self.append("\\t", .{}),
                else => self.append("{c}", .{ch}),
            }
        }
    }
};

const FakeRenderer = struct {
    allocator: std.mem.Allocator,
    width: i32,
    height: i32,
    char_width: f32,
    char_height: f32,
    editor_disable_ligatures: renderer_mod.TerminalDisableLigaturesStrategy,
    theme: Theme,
    log: DrawLog,
    editor_texture_created: bool,

    pub fn init(allocator: std.mem.Allocator, width: i32, height: i32, char_width: f32, char_height: f32) FakeRenderer {
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .char_width = char_width,
            .char_height = char_height,
            .editor_disable_ligatures = .never,
            .theme = .{},
            .log = DrawLog.init(allocator),
            .editor_texture_created = false,
        };
    }

    pub fn deinit(self: *FakeRenderer) void {
        self.log.deinit();
    }

    pub fn uiScaleFactor(self: *FakeRenderer) f32 {
        _ = self;
        return 1.0;
    }

    pub fn rendererPtr(self: *FakeRenderer) *FakeRenderer {
        return self;
    }

    pub fn ensureEditorTexture(self: *FakeRenderer, width: i32, height: i32) bool {
        _ = width;
        _ = height;
        if (!self.editor_texture_created) {
            self.editor_texture_created = true;
            return true;
        }
        return false;
    }

    pub fn beginEditorTexture(self: *FakeRenderer) bool {
        _ = self;
        return true;
    }

    pub fn endEditorTexture(self: *FakeRenderer) void {
        _ = self;
    }

    pub fn beginClip(self: *FakeRenderer, x: i32, y: i32, w: i32, h: i32) void {
        _ = self;
        _ = x;
        _ = y;
        _ = w;
        _ = h;
    }

    pub fn endClip(self: *FakeRenderer) void {
        _ = self;
    }

    pub fn drawEditorTexture(self: *FakeRenderer, x: f32, y: f32) void {
        _ = self;
        _ = x;
        _ = y;
    }

    pub fn setTextInputRect(self: *FakeRenderer, x: i32, y: i32, w: i32, h: i32) void {
        _ = self;
        _ = x;
        _ = y;
        _ = w;
        _ = h;
    }

    pub fn clearLog(self: *FakeRenderer) void {
        self.log.data.clearRetainingCapacity();
    }

    pub fn drawRect(self: *FakeRenderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        self.log.append("rect {d} {d} {d} {d} ", .{ x, y, w, h });
        self.log.appendColor(color);
        self.log.append("\n", .{});
    }

    pub fn drawText(self: *FakeRenderer, text: []const u8, x: f32, y: f32, color: Color) void {
        const xi: i32 = @intFromFloat(x);
        const yi: i32 = @intFromFloat(y);
        self.log.append("text {d} {d} \"", .{ xi, yi });
        self.log.appendEscaped(text);
        self.log.append("\" ", .{});
        self.log.appendColor(color);
        self.log.append("\n", .{});
    }

    pub fn drawTextMonospace(self: *FakeRenderer, text: []const u8, x: f32, y: f32, color: Color) void {
        self.drawText(text, x, y, color);
    }

    pub fn drawTextMonospacePolicy(self: *FakeRenderer, text: []const u8, x: f32, y: f32, color: Color, disable_programming_ligatures: bool) void {
        _ = disable_programming_ligatures;
        self.drawText(text, x, y, color);
    }

    pub fn drawTextMonospaceOnBg(self: *FakeRenderer, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
        _ = bg;
        self.drawText(text, x, y, color);
    }

    pub fn drawTextMonospaceOnBgPolicy(self: *FakeRenderer, text: []const u8, x: f32, y: f32, color: Color, bg: Color, disable_programming_ligatures: bool) void {
        _ = bg;
        _ = disable_programming_ligatures;
        self.drawText(text, x, y, color);
    }

    pub fn drawEditorLineBase(
        self: *FakeRenderer,
        line_num: usize,
        y: f32,
        x: f32,
        gutter_width: f32,
        content_width: f32,
        is_current: bool,
    ) void {
        editor_render.drawEditorLineBase(self, line_num, y, x, gutter_width, content_width, is_current);
    }

    pub fn drawCursor(self: *FakeRenderer, x: f32, y: f32, mode: enum { block, line, underline }) void {
        editor_render.drawCursor(self, x, y, mode);
    }
};

const FakeWidget = struct {
    editor: *Editor,
    gutter_width: f32,
    wrap_enabled: bool,

    pub fn viewportColumns(self: *FakeWidget, r: *FakeRenderer) usize {
        const editor_width = @max(0, r.width - @as(i32, @intFromFloat(self.gutter_width)));
        if (r.char_width <= 0) return 0;
        return @as(usize, @intFromFloat(@as(f32, @floatFromInt(editor_width)) / r.char_width));
    }

    pub fn clusterOffsets(
        self: *FakeWidget,
        r: *FakeRenderer,
        line_idx: usize,
        line_text: []const u8,
        out_slice: *?[]const u32,
        out_owned: *bool,
    ) void {
        _ = self;
        _ = r;
        _ = line_idx;
        _ = line_text;
        out_slice.* = null;
        out_owned.* = false;
    }

    pub fn moveCursorVisual(self: *FakeWidget, r: *FakeRenderer, delta: i32) !bool {
        const cols = self.viewportColumns(r);

        const Ctx = struct {
            widget: *FakeWidget,
            renderer: *FakeRenderer,
        };
        const ctx = Ctx{ .widget = self, .renderer = r };

        const provider = cursor_mod.LineProvider{
            .ctx = @constCast(&ctx),
            .getLineText = struct {
                fn call(raw_ctx: *anyopaque, line_idx: usize, scratch: *cursor_mod.LineScratch) cursor_mod.LineSlice {
                    const payload: *Ctx = @ptrCast(@alignCast(raw_ctx));
                    _ = payload.renderer;
                    const editor = payload.widget.editor;
                    const line_len = editor.lineLen(line_idx);
                    if (line_len <= scratch.buf.len) {
                        const len = editor.getLine(line_idx, scratch.buf);
                        return .{ .text = scratch.buf[0..len], .owned = null };
                    }
                    const owned = editor.getLineAlloc(line_idx) catch return .{ .text = &[_]u8{}, .owned = null };
                    return .{ .text = owned, .owned = owned };
                }
            }.call,
            .getClusters = struct {
                fn call(raw_ctx: *anyopaque, line_idx: usize, line_text: []const u8) cursor_mod.ClusterSlice {
                    const payload: *Ctx = @ptrCast(@alignCast(raw_ctx));
                    var slice: ?[]const u32 = null;
                    var owned = false;
                    payload.widget.clusterOffsets(payload.renderer, line_idx, line_text, &slice, &owned);
                    return .{ .clusters = slice, .owned = owned };
                }
            }.call,
            .freeLineText = struct {
                fn call(raw_ctx: *anyopaque, owned: []u8) void {
                    const payload: *Ctx = @ptrCast(@alignCast(raw_ctx));
                    payload.widget.editor.allocator.free(owned);
                }
            }.call,
            .freeClusters = struct {
                fn call(raw_ctx: *anyopaque, owned: []const u32) void {
                    const payload: *Ctx = @ptrCast(@alignCast(raw_ctx));
                    payload.widget.editor.allocator.free(owned);
                }
            }.call,
        };

        var buf_a: [4096]u8 = undefined;
        var buf_b: [4096]u8 = undefined;
        var scratch_a = cursor_mod.LineScratch{ .buf = buf_a[0..] };
        var scratch_b = cursor_mod.LineScratch{ .buf = buf_b[0..] };
        return cursor_mod.moveCaretSetVisual(self.editor, delta, cols, self.wrap_enabled, &provider, &scratch_a, &scratch_b);
    }

    pub fn extendSelectionVisual(self: *FakeWidget, r: *FakeRenderer, delta: i32) bool {
        const cols = self.viewportColumns(r);

        const Ctx = struct {
            widget: *FakeWidget,
            renderer: *FakeRenderer,
        };
        const ctx = Ctx{ .widget = self, .renderer = r };

        const provider = cursor_mod.LineProvider{
            .ctx = @constCast(&ctx),
            .getLineText = struct {
                fn call(raw_ctx: *anyopaque, line_idx: usize, scratch: *cursor_mod.LineScratch) cursor_mod.LineSlice {
                    const payload: *Ctx = @ptrCast(@alignCast(raw_ctx));
                    _ = payload.renderer;
                    const editor = payload.widget.editor;
                    const line_len = editor.lineLen(line_idx);
                    if (line_len <= scratch.buf.len) {
                        const len = editor.getLine(line_idx, scratch.buf);
                        return .{ .text = scratch.buf[0..len], .owned = null };
                    }
                    const owned = editor.getLineAlloc(line_idx) catch return .{ .text = &[_]u8{}, .owned = null };
                    return .{ .text = owned, .owned = owned };
                }
            }.call,
            .getClusters = struct {
                fn call(raw_ctx: *anyopaque, line_idx: usize, line_text: []const u8) cursor_mod.ClusterSlice {
                    const payload: *Ctx = @ptrCast(@alignCast(raw_ctx));
                    var slice: ?[]const u32 = null;
                    var owned = false;
                    payload.widget.clusterOffsets(payload.renderer, line_idx, line_text, &slice, &owned);
                    return .{ .clusters = slice, .owned = owned };
                }
            }.call,
            .freeLineText = struct {
                fn call(raw_ctx: *anyopaque, owned: []u8) void {
                    const payload: *Ctx = @ptrCast(@alignCast(raw_ctx));
                    payload.widget.editor.allocator.free(owned);
                }
            }.call,
            .freeClusters = struct {
                fn call(raw_ctx: *anyopaque, owned: []const u32) void {
                    const payload: *Ctx = @ptrCast(@alignCast(raw_ctx));
                    payload.widget.editor.allocator.free(owned);
                }
            }.call,
        };

        var buf_a: [4096]u8 = undefined;
        var buf_b: [4096]u8 = undefined;
        var scratch_a = cursor_mod.LineScratch{ .buf = buf_a[0..] };
        var scratch_b = cursor_mod.LineScratch{ .buf = buf_b[0..] };
        return cursor_mod.extendSelectionVisual(self.editor, delta, cols, self.wrap_enabled, &provider, &scratch_a, &scratch_b);
    }
};

fn textOpsOnly(allocator: std.mem.Allocator, log: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var lines = std.mem.splitScalar(u8, log, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (!std.mem.startsWith(u8, line, "text ")) continue;
        try out.appendSlice(allocator, line);
        try out.append(allocator, '\n');
    }
    return out.toOwnedSlice(allocator);
}

test "editor render snapshot baseline" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("hello\nworld");
    editor.setCursor(1, 2);

    var renderer = FakeRenderer.init(allocator, 320, 200, 8, 16);
    defer renderer.deinit();

    var widget = FakeWidget{
        .editor = editor,
        .gutter_width = 0,
        .wrap_enabled = false,
    };

    const input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{});
    draw_mod.draw(&widget, &renderer, 0, 0, 320, 200, input);

    const expected =
        "rect 0 0 50 200 #21222CFF\n" ++
        "text 4 0 \"   1\" #6272A4FF\n" ++
        "text 58 0 \"hello\" #F8F8F2FF\n" ++
        "rect 50 16 270 16 #323442FF\n" ++
        "rect 0 16 50 16 #323442FF\n" ++
        "text 4 16 \"   2\" #F8F8F2FF\n" ++
        "text 58 16 \"world\" #F8F8F2FF\n" ++
        "rect 74 16 2 16 #F8F8F2FF\n";

    try std.testing.expectEqualStrings(expected, renderer.log.data.items);
}

test "editor render draws extra carets for zero-length selections" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcdef");
    editor.setCursor(0, 2);
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 1, .offset = 1 },
        .end = .{ .line = 0, .col = 1, .offset = 1 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 4, .offset = 4 },
        .end = .{ .line = 0, .col = 4, .offset = 4 },
    });

    var renderer = FakeRenderer.init(allocator, 320, 32, 8, 16);
    defer renderer.deinit();

    var widget = FakeWidget{
        .editor = editor,
        .gutter_width = 0,
        .wrap_enabled = false,
    };

    const input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{});
    draw_mod.draw(&widget, &renderer, 0, 0, 320, 32, input);

    const log = renderer.log.data.items;
    try std.testing.expect(std.mem.indexOf(u8, log, "rect 66 0 2 16 #F8F8F2FF\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, log, "rect 74 0 2 16 #F8F8F2FF\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, log, "rect 90 0 2 16 #F8F8F2FF\n") != null);
}

test "editor cached render snapshot baseline" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("hello\nworld");
    editor.setCursor(1, 2);

    var renderer = FakeRenderer.init(allocator, 320, 32, 8, 16);
    defer renderer.deinit();

    var widget = FakeWidget{
        .editor = editor,
        .gutter_width = 0,
        .wrap_enabled = false,
    };

    var cache = cache_mod.EditorRenderCache.init(allocator, 256);
    defer cache.deinit();

    const input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{});
    draw_mod.drawCached(&widget, &renderer, &cache, 0, 0, 320, 32, 1, input);

    const expected =
        "rect 0 0 320 32 #282A36FF\n" ++
        "rect 0 0 50 32 #21222CFF\n" ++
        "rect 0 0 320 16 #282A36FF\n" ++
        "rect 0 0 50 16 #21222CFF\n" ++
        "text 4 0 \"   1\" #6272A4FF\n" ++
        "text 58 0 \"hello\" #F8F8F2FF\n" ++
        "rect 0 16 320 16 #282A36FF\n" ++
        "rect 0 16 50 16 #21222CFF\n" ++
        "rect 50 16 270 16 #323442FF\n" ++
        "rect 0 16 50 16 #323442FF\n" ++
        "text 4 16 \"   2\" #F8F8F2FF\n" ++
        "text 58 16 \"world\" #F8F8F2FF\n" ++
        "rect 74 16 2 16 #F8F8F2FF\n";

    try std.testing.expectEqualStrings(expected, renderer.log.data.items);
}

test "editor cached render draws extra carets for zero-length selections" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcdef");
    editor.setCursor(0, 2);
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 1, .offset = 1 },
        .end = .{ .line = 0, .col = 1, .offset = 1 },
    });
    try editor.addSelection(.{
        .start = .{ .line = 0, .col = 4, .offset = 4 },
        .end = .{ .line = 0, .col = 4, .offset = 4 },
    });

    var renderer = FakeRenderer.init(allocator, 320, 32, 8, 16);
    defer renderer.deinit();

    var widget = FakeWidget{
        .editor = editor,
        .gutter_width = 0,
        .wrap_enabled = false,
    };

    var cache = cache_mod.EditorRenderCache.init(allocator, 256);
    defer cache.deinit();

    const input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{});
    draw_mod.drawCached(&widget, &renderer, &cache, 0, 0, 320, 32, 1, input);

    const log = renderer.log.data.items;
    try std.testing.expect(std.mem.indexOf(u8, log, "rect 66 0 2 16 #F8F8F2FF\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, log, "rect 74 0 2 16 #F8F8F2FF\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, log, "rect 90 0 2 16 #F8F8F2FF\n") != null);
}

test "editor render cache dirty line update" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("one\ntwo\nthree");
    editor.setCursor(0, 0);

    var renderer = FakeRenderer.init(allocator, 320, 48, 8, 16);
    defer renderer.deinit();

    var widget = FakeWidget{
        .editor = editor,
        .gutter_width = 0,
        .wrap_enabled = false,
    };

    var cache = cache_mod.EditorRenderCache.init(allocator, 512);
    defer cache.deinit();

    const input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{});
    draw_mod.drawCached(&widget, &renderer, &cache, 0, 0, 320, 48, 1, input);
    renderer.clearLog();
    editor.setCursor(1, 0);
    draw_mod.drawCached(&widget, &renderer, &cache, 0, 0, 320, 48, 2, input);

    const log = renderer.log.data.items;
    try std.testing.expect(log.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, log, "one") != null);
    try std.testing.expect(std.mem.indexOf(u8, log, "two") != null);
}

test "editor render cache redraws on search change" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta alpha");

    var renderer = FakeRenderer.init(allocator, 320, 32, 8, 16);
    defer renderer.deinit();

    var widget = FakeWidget{ .editor = editor, .gutter_width = 0, .wrap_enabled = false };
    var cache = cache_mod.EditorRenderCache.init(allocator, 256);
    defer cache.deinit();
    const input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{});

    draw_mod.drawCached(&widget, &renderer, &cache, 0, 0, 320, 32, 1, input);
    renderer.clearLog();
    draw_mod.drawCached(&widget, &renderer, &cache, 0, 0, 320, 32, 2, input);
    try std.testing.expectEqual(@as(usize, 0), renderer.log.data.items.len);

    try editor.setSearchQuery("alpha");
    draw_mod.drawCached(&widget, &renderer, &cache, 0, 0, 320, 32, 3, input);
    try std.testing.expect(renderer.log.data.items.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, renderer.log.data.items, "#44475A98") != null);
}

test "editor render cache redraws on selection change" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta");

    var renderer = FakeRenderer.init(allocator, 320, 32, 8, 16);
    defer renderer.deinit();

    var widget = FakeWidget{ .editor = editor, .gutter_width = 0, .wrap_enabled = false };
    var cache = cache_mod.EditorRenderCache.init(allocator, 256);
    defer cache.deinit();
    const input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{});

    draw_mod.drawCached(&widget, &renderer, &cache, 0, 0, 320, 32, 1, input);
    renderer.clearLog();
    draw_mod.drawCached(&widget, &renderer, &cache, 0, 0, 320, 32, 2, input);
    try std.testing.expectEqual(@as(usize, 0), renderer.log.data.items.len);

    editor.selection = .{
        .start = .{ .line = 0, .col = 0, .offset = 0 },
        .end = .{ .line = 0, .col = 5, .offset = 5 },
    };
    draw_mod.drawCached(&widget, &renderer, &cache, 0, 0, 320, 32, 3, input);
    try std.testing.expect(renderer.log.data.items.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, renderer.log.data.items, "#44475AFF") != null);
}

test "editor render cache redraws on highlight epoch change" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("const foo = bar;\n");

    var renderer = FakeRenderer.init(allocator, 320, 32, 8, 16);
    defer renderer.deinit();
    var widget = FakeWidget{ .editor = editor, .gutter_width = 0, .wrap_enabled = false };
    var cache = cache_mod.EditorRenderCache.init(allocator, 256);
    defer cache.deinit();
    const input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{});

    draw_mod.drawCached(&widget, &renderer, &cache, 0, 0, 320, 32, 1, input);
    renderer.clearLog();
    draw_mod.drawCached(&widget, &renderer, &cache, 0, 0, 320, 32, 2, input);
    try std.testing.expectEqual(@as(usize, 0), renderer.log.data.items.len);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const query =
        \\((identifier) @keyword (#eq? @keyword "foo"))
    ;
    try tmp.dir.writeFile(.{ .sub_path = "highlights.scm", .data = query });
    const query_path = try tmp.dir.realpathAlloc(allocator, "highlights.scm");
    defer allocator.free(query_path);

    editor.highlighter = try syntax_mod.createHighlighterForLanguage(
        allocator,
        editor.buffer,
        "zig",
        tree_sitter_zig(),
        .{ .highlights = query_path },
        null,
    );
    editor.highlight_epoch +|= 1;
    draw_mod.drawCached(&widget, &renderer, &cache, 0, 0, 320, 32, 3, input);
    try std.testing.expect(renderer.log.data.items.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, renderer.log.data.items, "#FF79C6FF") != null);
}

test "editor search query scaffold tracks matches" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta alpha");
    try editor.setSearchQuery("alpha");

    const matches = editor.searchMatches();
    try std.testing.expectEqual(@as(usize, 2), matches.len);
    try std.testing.expectEqual(@as(usize, 0), matches[0].start);
    try std.testing.expectEqual(@as(usize, 5), matches[0].end);
    try std.testing.expectEqual(@as(usize, 11), matches[1].start);
    try std.testing.expectEqual(@as(usize, 16), matches[1].end);

    try editor.setSearchQuery(null);
    try std.testing.expectEqual(@as(usize, 0), editor.searchMatches().len);
}

test "editor search next/prev moves active match and cursor" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta alpha");
    try editor.setSearchQuery("alpha");

    const first = editor.searchActiveMatch() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 0), first.start);

    try std.testing.expect(editor.activateNextSearchMatch());
    const second = editor.searchActiveMatch() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 11), second.start);
    try std.testing.expectEqual(@as(usize, 11), editor.cursor.offset);

    try std.testing.expect(editor.activatePrevSearchMatch());
    const wrapped = editor.searchActiveMatch() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 0), wrapped.start);
    try std.testing.expectEqual(@as(usize, 0), editor.cursor.offset);
}

test "editor search query picks first match at or after cursor" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta alpha beta");
    editor.setCursor(0, 6);
    try editor.setSearchQuery("beta");

    const active = editor.searchActiveMatch() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 6), active.start);

    editor.setCursor(0, 11);
    try editor.setSearchQuery("beta");
    const next_active = editor.searchActiveMatch() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 17), next_active.start);
}

test "editor focus search active match jumps without advancing" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta alpha");
    editor.setCursor(0, 6);
    try editor.setSearchQuery("alpha");

    const active = editor.searchActiveMatch() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 11), active.start);
    try std.testing.expectEqual(@as(usize, 6), editor.cursor.offset);

    try std.testing.expect(editor.focusSearchActiveMatch());
    try std.testing.expectEqual(@as(usize, 11), editor.cursor.offset);

    try std.testing.expect(editor.activateNextSearchMatch());
    const wrapped = editor.searchActiveMatch() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 0), wrapped.start);
}

test "taking highlight dirty range preserves search state" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta alpha");
    try editor.setSearchQuery("alpha");
    try std.testing.expectEqual(@as(usize, 2), editor.searchMatches().len);

    const dirty = editor.takeHighlightDirtyRange() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 0), dirty.start_line);
    try std.testing.expectEqual(@as(usize, 1), dirty.end_line);
    try std.testing.expectEqual(@as(usize, 2), editor.searchMatches().len);

    const active = editor.searchActiveMatch() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 0), active.start);
}

test "editor regex search finds pattern matches" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("foo bar baz\n");
    try editor.setSearchQueryRegex("ba.");

    const matches = editor.searchMatches();
    try std.testing.expectEqual(@as(usize, 2), matches.len);
    try std.testing.expectEqual(@as(usize, 4), matches[0].start);
    try std.testing.expectEqual(@as(usize, 7), matches[0].end);
    try std.testing.expectEqual(@as(usize, 8), matches[1].start);
    try std.testing.expectEqual(@as(usize, 11), matches[1].end);
}

test "editor replace active search match advances to next result" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta alpha");
    try editor.setSearchQuery("alpha");

    try std.testing.expect(try editor.replaceActiveSearchMatch("omega"));

    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("omega beta alpha", after);

    const active = editor.searchActiveMatch() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 11), active.start);
    try std.testing.expectEqual(@as(usize, 11), editor.cursor.offset);

    try std.testing.expect(try editor.undo());
    const undone = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(undone);
    try std.testing.expectEqualStrings("alpha beta alpha", undone);
    try std.testing.expectEqual(@as(usize, 2), editor.searchMatches().len);
}

test "editor replace all search matches is grouped undo" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("foo bar foo baz foo");
    try editor.setSearchQuery("foo");

    try std.testing.expectEqual(@as(usize, 3), try editor.replaceAllSearchMatches("qux"));

    const after = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(after);
    try std.testing.expectEqualStrings("qux bar qux baz qux", after);
    try std.testing.expectEqual(@as(usize, 0), editor.searchMatches().len);

    try std.testing.expect(try editor.undo());
    const undone = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(undone);
    try std.testing.expectEqualStrings("foo bar foo baz foo", undone);
    try std.testing.expectEqual(@as(usize, 3), editor.searchMatches().len);
}

test "editor undo redo refreshes search matches" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta beta");
    try editor.setSearchQuery("beta");
    try std.testing.expectEqual(@as(usize, 2), editor.searchMatches().len);

    editor.selection = .{
        .start = .{ .line = 0, .col = 11, .offset = 11 },
        .end = .{ .line = 0, .col = 15, .offset = 15 },
    };
    try editor.deleteSelection();
    try std.testing.expectEqual(@as(usize, 1), editor.searchMatches().len);

    try std.testing.expect(try editor.undo());
    try std.testing.expectEqual(@as(usize, 2), editor.searchMatches().len);

    try std.testing.expect(try editor.redo());
    try std.testing.expectEqual(@as(usize, 1), editor.searchMatches().len);
}

test "editor search recompute preserves active match nearest previous position" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta alpha beta");
    try editor.setSearchQuery("beta");
    try std.testing.expect(editor.activateNextSearchMatch());

    const before = editor.searchActiveMatch() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 17), before.start);

    editor.setCursor(0, 0);
    try editor.insertText("X");

    const after = editor.searchActiveMatch() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 18), after.start);
}

test "editor immediate and cached draw agree for conceal/url highlights" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("const foo = bar;\n");

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const query =
        \\((identifier) @keyword (#eq? @keyword "foo") (#set! @keyword conceal "X"))
        \\((identifier) @keyword (#eq? @keyword "bar") (#set! @keyword url "https://zide.dev"))
    ;
    try tmp.dir.writeFile(.{ .sub_path = "highlights.scm", .data = query });
    const query_path = try tmp.dir.realpathAlloc(allocator, "highlights.scm");
    defer allocator.free(query_path);

    editor.highlighter = try syntax_mod.createHighlighterForLanguage(
        allocator,
        editor.buffer,
        "zig",
        tree_sitter_zig(),
        .{ .highlights = query_path },
        null,
    );
    editor.highlight_epoch +|= 1;

    const input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{});

    var immediate_renderer = FakeRenderer.init(allocator, 320, 32, 8, 16);
    defer immediate_renderer.deinit();
    var widget = FakeWidget{ .editor = editor, .gutter_width = 0, .wrap_enabled = false };
    draw_mod.draw(&widget, &immediate_renderer, 0, 0, 320, 32, input);

    var cached_renderer = FakeRenderer.init(allocator, 320, 32, 8, 16);
    defer cached_renderer.deinit();
    var cache = cache_mod.EditorRenderCache.init(allocator, 256);
    defer cache.deinit();
    draw_mod.drawCached(&widget, &cached_renderer, &cache, 0, 0, 320, 32, 1, input);

    const immediate_text = try textOpsOnly(allocator, immediate_renderer.log.data.items);
    defer allocator.free(immediate_text);
    const cached_text = try textOpsOnly(allocator, cached_renderer.log.data.items);
    defer allocator.free(cached_text);

    try std.testing.expectEqualStrings(immediate_text, cached_text);
    try std.testing.expect(std.mem.indexOf(u8, immediate_text, "\"X\" #FF79C6FF") != null);
    try std.testing.expect(std.mem.indexOf(u8, immediate_text, "\"bar\" #8BE9FDFF") != null);
}

test "editor immediate and cached draw distinguish active search match" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("alpha beta alpha");
    try editor.setSearchQuery("alpha");

    const input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{});
    var widget = FakeWidget{ .editor = editor, .gutter_width = 0, .wrap_enabled = false };

    var immediate_renderer = FakeRenderer.init(allocator, 320, 32, 8, 16);
    defer immediate_renderer.deinit();
    draw_mod.draw(&widget, &immediate_renderer, 0, 0, 320, 32, input);

    var cached_renderer = FakeRenderer.init(allocator, 320, 32, 8, 16);
    defer cached_renderer.deinit();
    var cache = cache_mod.EditorRenderCache.init(allocator, 256);
    defer cache.deinit();
    draw_mod.drawCached(&widget, &cached_renderer, &cache, 0, 0, 320, 32, 1, input);

    const immediate_log = immediate_renderer.log.data.items;
    const cached_log = cached_renderer.log.data.items;
    try std.testing.expect(std.mem.indexOf(u8, immediate_log, "#44475A98") != null);
    try std.testing.expect(std.mem.indexOf(u8, immediate_log, "#44475A50") != null);
    try std.testing.expect(std.mem.indexOf(u8, cached_log, "#44475A98") != null);
    try std.testing.expect(std.mem.indexOf(u8, cached_log, "#44475A50") != null);
}
