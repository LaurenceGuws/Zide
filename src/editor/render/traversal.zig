const std = @import("std");
const selection_mod = @import("../view/selection.zig");
const layout_mod = @import("../view/layout.zig");

pub const Segment = struct {
    line_idx: usize,
    visual_row: usize,
    line_start: usize,
    line_len: usize,
    line_width: usize,
    total_visual_lines: usize,
    seg_idx: usize,
    seg_start_idx: usize,
    seg_start_col: usize,
    seg_end_col: usize,
    seg_start_byte: usize,
    seg_end_byte: usize,
    cursor_col_vis: usize,
    cursor_seg: usize,
    is_current: bool,
};

pub fn walkVisibleSegments(
    editor: anytype,
    line_text: []const u8,
    cluster_slice: ?[]const u32,
    cols: usize,
    wrap_enabled: bool,
    start_line: usize,
    start_seg: usize,
    line_idx: usize,
    visible_lines: usize,
    visual_row: *usize,
    line_width: usize,
    callback_ctx: anytype,
    comptime callback: anytype,
) void {
    const line_len = line_text.len;
    const line_start = editor.lineStart(line_idx);
    const total_visual_lines = if (wrap_enabled)
        layout_mod.visualLineCountForWidth(cols, line_width)
    else
        1;
    const seg_start_idx = if (wrap_enabled and line_idx == start_line) @min(start_seg, total_visual_lines) else 0;

    const is_current = line_idx == editor.cursor.line;
    var cursor_col_vis: usize = 0;
    var cursor_seg: usize = 0;
    if (is_current) {
        cursor_col_vis = selection_mod.visualColumnForByteIndex(line_text, editor.cursor.col, cluster_slice);
        if (cols > 0 and wrap_enabled) {
            cursor_seg = @min(cursor_col_vis / cols, if (total_visual_lines > 0) total_visual_lines - 1 else 0);
        }
    }

    var seg: usize = seg_start_idx;
    while (seg < total_visual_lines and visual_row.* < visible_lines) : (seg += 1) {
        const seg_start_col = if (wrap_enabled) seg * cols else editor.scroll_col;
        const seg_end_col = @min(line_width, seg_start_col + cols);
        const seg_start_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_start_col, cluster_slice);
        const seg_end_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_end_col, cluster_slice);
        callback(callback_ctx, .{
            .line_idx = line_idx,
            .visual_row = visual_row.*,
            .line_start = line_start,
            .line_len = line_len,
            .line_width = line_width,
            .total_visual_lines = total_visual_lines,
            .seg_idx = seg,
            .seg_start_idx = seg_start_idx,
            .seg_start_col = seg_start_col,
            .seg_end_col = seg_end_col,
            .seg_start_byte = seg_start_byte,
            .seg_end_byte = seg_end_byte,
            .cursor_col_vis = cursor_col_vis,
            .cursor_seg = cursor_seg,
            .is_current = is_current,
        });
        visual_row.* += 1;
    }
}

const FakeCursor = struct {
    line: usize,
    col: usize,
};

const FakeEditor = struct {
    cursor: FakeCursor,
    scroll_col: usize,
    line_starts: []const usize,

    fn lineStart(self: @This(), line_idx: usize) usize {
        return self.line_starts[line_idx];
    }
};

test "walkVisibleSegments respects wrapped start segment and visible row budget" {
    const editor = FakeEditor{
        .cursor = .{ .line = 1, .col = 5 },
        .scroll_col = 0,
        .line_starts = &[_]usize{ 0, 11 },
    };
    const line_text = "hello world";
    var visual_row: usize = 0;
    var seen = std.ArrayList(Segment).empty;
    defer seen.deinit(std.testing.allocator);

    const Ctx = struct {
        seen: *std.ArrayList(Segment),
        fn record(ctx: @This(), seg: Segment) void {
            ctx.seen.append(std.testing.allocator, seg) catch unreachable;
        }
    };

    traversal: {
        const ctx = Ctx{ .seen = &seen };
        walkVisibleSegments(editor, line_text, null, 4, true, 1, 1, 1, 2, &visual_row, 11, ctx, Ctx.record);
        break :traversal;
    }

    try std.testing.expectEqual(@as(usize, 2), seen.items.len);
    try std.testing.expectEqual(@as(usize, 1), seen.items[0].seg_idx);
    try std.testing.expectEqual(@as(usize, 4), seen.items[0].seg_start_col);
    try std.testing.expectEqual(@as(usize, 8), seen.items[0].seg_end_col);
    try std.testing.expectEqual(@as(usize, 2), seen.items[1].seg_idx);
    try std.testing.expectEqual(@as(usize, 8), seen.items[1].seg_start_col);
    try std.testing.expectEqual(@as(usize, 11), seen.items[1].seg_end_col);
    try std.testing.expectEqual(@as(usize, 2), visual_row);
}

test "walkVisibleSegments applies horizontal scroll for non-wrapped lines" {
    const editor = FakeEditor{
        .cursor = .{ .line = 0, .col = 0 },
        .scroll_col = 3,
        .line_starts = &[_]usize{0},
    };
    var visual_row: usize = 0;
    var captured: ?Segment = null;

    const Ctx = struct {
        slot: *?Segment,
        fn record(ctx: @This(), seg: Segment) void {
            ctx.slot.* = seg;
        }
    };

    const ctx = Ctx{ .slot = &captured };
    walkVisibleSegments(editor, "abcdef", null, 4, false, 0, 0, 0, 1, &visual_row, 6, ctx, Ctx.record);

    try std.testing.expect(captured != null);
    try std.testing.expectEqual(@as(usize, 3), captured.?.seg_start_col);
    try std.testing.expectEqual(@as(usize, 6), captured.?.seg_end_col);
    try std.testing.expectEqual(@as(usize, 3), captured.?.seg_start_byte);
    try std.testing.expectEqual(@as(usize, 6), captured.?.seg_end_byte);
}

test "walkVisibleSegments reports cursor visual segment for wrapped cursor" {
    const editor = FakeEditor{
        .cursor = .{ .line = 0, .col = 9 },
        .scroll_col = 0,
        .line_starts = &[_]usize{0},
    };
    var visual_row: usize = 0;
    var seen = std.ArrayList(Segment).empty;
    defer seen.deinit(std.testing.allocator);

    const Ctx = struct {
        seen: *std.ArrayList(Segment),
        fn record(ctx: @This(), seg: Segment) void {
            ctx.seen.append(std.testing.allocator, seg) catch unreachable;
        }
    };

    const ctx = Ctx{ .seen = &seen };
    walkVisibleSegments(editor, "hello world", null, 4, true, 0, 0, 0, 3, &visual_row, 11, ctx, Ctx.record);

    try std.testing.expectEqual(@as(usize, 3), seen.items.len);
    try std.testing.expectEqual(@as(usize, 2), seen.items[0].cursor_seg);
    try std.testing.expectEqual(@as(usize, 9), seen.items[0].cursor_col_vis);
    try std.testing.expect(seen.items[0].is_current);
}
