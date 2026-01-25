const std = @import("std");
const editor_mod = @import("editor/editor.zig");
const grammar_manager_mod = @import("editor/grammar_manager.zig");
const snapshot_mod = @import("editor/snapshot.zig");
const shared = @import("types/mod.zig").snapshots;

test "editor snapshot stub is empty" {
    const allocator = std.testing.allocator;

    var grammar_manager = try grammar_manager_mod.GrammarManager.init(allocator);
    defer grammar_manager.deinit();

    var editor = try editor_mod.Editor.init(allocator, &grammar_manager);
    defer editor.deinit();

    const snapshot = try snapshot_mod.buildSnapshot(allocator, editor, .{ .width = 0, .height = 0 });
    try std.testing.expectEqual(@as(usize, 0), snapshot.text.len);
    try std.testing.expectEqual(@as(usize, 0), snapshot.line_offsets.len);
    try std.testing.expectEqual(@as(usize, 0), snapshot.highlights.len);
    try std.testing.expectEqual(@as(u32, 0), snapshot.cursor_line);
    try std.testing.expectEqual(@as(u32, 0), snapshot.cursor_col);
    try std.testing.expect(snapshot.selection_start == null);
    try std.testing.expect(snapshot.selection_end == null);
    _ = @as(shared.EditorSnapshot, snapshot);
}
