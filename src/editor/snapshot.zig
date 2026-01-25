const std = @import("std");
const editor_mod = @import("editor.zig");
const shared = @import("../types/mod.zig").snapshots;

pub const Viewport = struct {
    width: u32,
    height: u32,
};

pub fn buildSnapshot(allocator: std.mem.Allocator, editor: *editor_mod.Editor, viewport: Viewport) !shared.EditorSnapshot {
    _ = viewport;
    const line_count = editor.lineCount();
    const line_offsets = if (line_count == 0)
        &[_]u32{}
    else blk: {
        var out = try allocator.alloc(u32, line_count);
        var i: usize = 0;
        const max_u32 = std.math.maxInt(u32);
        while (i < line_count) : (i += 1) {
            const start = editor.lineStart(i);
            out[i] = if (start > max_u32) max_u32 else @as(u32, @intCast(start));
        }
        break :blk out;
    };

    // TODO: populate text/highlights once widget/core split lands.
    return shared.EditorSnapshot{
        .text = &[_]u8{},
        .line_offsets = line_offsets,
        .cursor_line = @as(u32, @intCast(editor.cursor.line)),
        .cursor_col = @as(u32, @intCast(editor.cursor.col)),
        .selection_start = null,
        .selection_end = null,
        .highlights = &[_]shared.HighlightSpan{},
    };
}
