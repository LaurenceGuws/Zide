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
