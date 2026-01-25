const std = @import("std");
const editor_mod = @import("editor.zig");
const shared = @import("../types/mod.zig").snapshots;

pub const Viewport = struct {
    width: u32,
    height: u32,
};

pub fn buildSnapshot(allocator: std.mem.Allocator, editor: *editor_mod.Editor, viewport: Viewport) !shared.EditorSnapshot {
    _ = allocator;
    _ = editor;
    _ = viewport;
    // TODO: populate from editor state once widget/core split lands.
    return shared.EditorSnapshot{
        .text = &[_]u8{},
        .line_offsets = &[_]u32{},
        .cursor_line = 0,
        .cursor_col = 0,
        .selection_start = null,
        .selection_end = null,
        .highlights = &[_]shared.HighlightSpan{},
    };
}
