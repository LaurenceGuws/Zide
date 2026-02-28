const std = @import("std");
const editor_mod = @import("editor/editor.zig");
const grammar_manager_mod = @import("editor/grammar_manager.zig");
const types = @import("editor/types.zig");

const EditorFixture = struct {
    grammar_manager: grammar_manager_mod.GrammarManager,
    editor: *editor_mod.Editor,

    pub fn init(allocator: std.mem.Allocator) !EditorFixture {
        var grammar_manager = try grammar_manager_mod.GrammarManager.init(allocator);
        const editor = try editor_mod.Editor.init(allocator, &grammar_manager);
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

test "editor selectionTextAlloc merges selections" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("hello world\nsecond line\nthird");
    try editor.addSelection(.{
        .start = types.CursorPos{ .line = 0, .col = 0, .offset = 0 },
        .end = types.CursorPos{ .line = 0, .col = 5, .offset = 5 },
    });
    try editor.addSelection(.{
        .start = types.CursorPos{ .line = 0, .col = 6, .offset = 6 },
        .end = types.CursorPos{ .line = 0, .col = 11, .offset = 11 },
    });

    const text = try editor.selectionTextAlloc() orelse return error.MissingSelection;
    defer allocator.free(text);
    try std.testing.expectEqualStrings("hello\nworld", text);
}

test "editor selectionTextAlloc skips zero-length carets without stray newlines" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcdef");
    try editor.addSelection(.{
        .start = types.CursorPos{ .line = 0, .col = 0, .offset = 0 },
        .end = types.CursorPos{ .line = 0, .col = 2, .offset = 2 },
    });
    try editor.addSelection(.{
        .start = types.CursorPos{ .line = 0, .col = 3, .offset = 3 },
        .end = types.CursorPos{ .line = 0, .col = 3, .offset = 3 },
    });
    try editor.addSelection(.{
        .start = types.CursorPos{ .line = 0, .col = 4, .offset = 4 },
        .end = types.CursorPos{ .line = 0, .col = 6, .offset = 6 },
    });

    const text = try editor.selectionTextAlloc() orelse return error.MissingSelection;
    defer allocator.free(text);
    try std.testing.expectEqualStrings("ab\nef", text);
}

test "editor selectionTextAlloc preserves rectangular line slices" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcd\nefgh\nijkl");
    try editor.expandRectSelection(0, 2, 1, 3);

    const text = try editor.selectionTextAlloc() orelse return error.MissingSelection;
    defer allocator.free(text);
    try std.testing.expectEqualStrings("bc\nfg\njk", text);
}

test "rectangular selection collapses on cursor movement" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcd\nefgh");
    editor.setCursor(1, 2);
    try editor.expandRectSelection(0, 1, 1, 3);

    editor.moveCursorLeft();

    try std.testing.expectEqual(@as(usize, 0), editor.selectionCount());
    try std.testing.expectEqual(@as(usize, 6), editor.cursor.offset);
}

test "rectangular selection paste distributes clipboard lines per row" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcd\nefgh\nijkl");
    editor.setCursor(0, 1);
    try editor.expandRectSelection(0, 2, 1, 3);

    try editor.insertText("XX\nYY\nZZ");

    const text = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(text);
    try std.testing.expectEqualStrings("aXXd\neYYh\niZZl", text);
}

test "rectangular selection paste repeats a single clipboard row across all lines" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcd\nefgh\nijkl");
    editor.setCursor(0, 1);
    try editor.expandRectSelection(0, 2, 1, 3);

    try editor.insertText("QQ");

    const text = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(text);
    try std.testing.expectEqualStrings("aQQd\neQQh\niQQl", text);
}

test "rectangular selection paste cycles clipboard rows when counts mismatch" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcd\nefgh\nijkl");
    editor.setCursor(0, 1);
    try editor.expandRectSelection(0, 2, 1, 3);

    try editor.insertText("LM\nNO");

    const text = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(text);
    try std.testing.expectEqualStrings("aLMd\neNOh\niLMl", text);
}

test "rectangular selection paste trims crlf rows and preserves trailing empty row" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcd\nefgh\nijkl");
    editor.setCursor(0, 1);
    try editor.expandRectSelection(0, 2, 1, 3);

    try editor.insertText("UV\r\n\r\nWX\r\n");

    const text = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(text);
    try std.testing.expectEqualStrings("aUVd\neh\niWXl", text);
}

test "visual rectangular selection with tabs pastes against visual columns" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("\tabc\n\tdef");
    editor.setCursor(0, 0);
    try editor.expandRectSelectionVisual(0, 1, 4, 6);

    try editor.insertText("XY");

    const text = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(text);
    try std.testing.expectEqualStrings("\tXYc\n\tXYf", text);
}

test "plain multi-selection paste broadcasts the same text" {
    const allocator = std.testing.allocator;
    var fixture = try EditorFixture.init(allocator);
    defer fixture.deinit();
    const editor = fixture.editor;

    try editor.insertText("abcd");
    editor.setCursor(0, 3);
    try editor.addSelection(.{
        .start = types.CursorPos{ .line = 0, .col = 1, .offset = 1 },
        .end = types.CursorPos{ .line = 0, .col = 1, .offset = 1 },
    });
    try editor.addSelection(.{
        .start = types.CursorPos{ .line = 0, .col = 4, .offset = 4 },
        .end = types.CursorPos{ .line = 0, .col = 4, .offset = 4 },
    });

    try editor.insertText("ZZ");

    const text = try editor.buffer.readRangeAlloc(0, editor.buffer.totalLen());
    defer allocator.free(text);
    try std.testing.expectEqualStrings("aZZbcZZdZZ", text);
}
