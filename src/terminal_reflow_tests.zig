const std = @import("std");
const term_mod = @import("terminal/core/terminal.zig");

fn firstCodepoint(session: *term_mod.TerminalSession, global_row: usize) ?u32 {
    const history_len = session.scrollbackCount();
    const snapshot = session.snapshot();
    const cols = snapshot.cols;
    if (global_row < history_len) {
        if (session.scrollbackRow(global_row)) |row| return row[0].codepoint;
        return null;
    }
    const grid_row = global_row - history_len;
    if (grid_row >= snapshot.rows) return null;
    const row_start = grid_row * cols;
    return snapshot.cells[row_start].codepoint;
}

test "terminal reflow merges wrapped scrollback rows" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "ABCDEFG\nHIJ\n");
    try session.resize(2, 8);

    const row = session.scrollbackRow(0) orelse return error.MissingScrollback;
    try std.testing.expectEqual(@as(usize, 8), row.len);
    try std.testing.expectEqual(@as(u32, 'A'), row[0].codepoint);
    try std.testing.expectEqual(@as(u32, 'B'), row[1].codepoint);
    try std.testing.expectEqual(@as(u32, 'C'), row[2].codepoint);
    try std.testing.expectEqual(@as(u32, 'D'), row[3].codepoint);
    try std.testing.expectEqual(@as(u32, 'E'), row[4].codepoint);
    try std.testing.expectEqual(@as(u32, 'F'), row[5].codepoint);
    try std.testing.expectEqual(@as(u32, 'G'), row[6].codepoint);
    try std.testing.expectEqual(@as(u32, 0), row[7].codepoint);
}

test "terminal reflow preserves trailing blank cursor and selection" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 1, 4);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "A");
    session.debugSetCursor(0, 3);
    session.startSelection(0, 3);
    session.finishSelection();

    try session.resize(1, 8);

    const snapshot = session.snapshot();
    try std.testing.expectEqual(@as(usize, 3), snapshot.cursor.col);

    if (session.selectionState()) |selection| {
        try std.testing.expectEqual(@as(usize, 3), selection.start.col);
        try std.testing.expectEqual(@as(usize, 3), selection.end.col);
    } else {
        return error.MissingSelection;
    }
}

test "terminal reflow wraps wide scrollback rows" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 1, 8);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "ABCDEFGH\n");
    try session.resize(1, 4);

    const row0 = session.scrollbackRow(0) orelse return error.MissingScrollback;
    const row1 = session.scrollbackRow(1) orelse return error.MissingScrollback;
    try std.testing.expectEqual(@as(usize, 4), row0.len);
    try std.testing.expectEqual(@as(usize, 4), row1.len);
    try std.testing.expectEqual(@as(u32, 'A'), row0[0].codepoint);
    try std.testing.expectEqual(@as(u32, 'D'), row0[3].codepoint);
    try std.testing.expectEqual(@as(u32, 'E'), row1[0].codepoint);
    try std.testing.expectEqual(@as(u32, 'H'), row1[3].codepoint);
}

test "terminal reflow preserves scrolled anchor line" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "AAAAAA\nBBBBBB\nCCCCCC\nDDDDDD\n");
    session.scrollBy(2);

    const snapshot_before = session.snapshot();
    const total_lines_before = session.scrollbackCount() + snapshot_before.rows;
    const start_line_before = total_lines_before - snapshot_before.rows - session.scrollOffset();
    const expected = firstCodepoint(session, start_line_before) orelse return error.MissingScrollback;

    try session.resize(2, 6);

    const snapshot_after = session.snapshot();
    const total_lines_after = session.scrollbackCount() + snapshot_after.rows;
    const start_line_after = total_lines_after - snapshot_after.rows - session.scrollOffset();
    const actual = firstCodepoint(session, start_line_after) orelse return error.MissingScrollback;
    try std.testing.expectEqual(expected, actual);
}

test "terminal reflow preserves bottom anchor when not scrolled" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "111111\n222222\n333333\n444444\n");

    const snapshot_before = session.snapshot();
    const last_row_start = (snapshot_before.rows - 1) * snapshot_before.cols;
    const expected = snapshot_before.cells[last_row_start].codepoint;

    try session.resize(2, 6);

    const snapshot_after = session.snapshot();
    const last_row_start_after = (snapshot_after.rows - 1) * snapshot_after.cols;
    const actual = snapshot_after.cells[last_row_start_after].codepoint;
    try std.testing.expectEqual(expected, actual);
}

test "terminal reflow keeps selection active when scrolled" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "AAAAAA\nBBBBBB\nCCCCCC\nDDDDDD\n");
    session.scrollBy(2);

    const snapshot_before = session.snapshot();
    const total_lines_before = session.scrollbackCount() + snapshot_before.rows;
    const start_line_before = total_lines_before - snapshot_before.rows - session.scrollOffset();
    const select_row = start_line_before + 1;
    session.startSelection(select_row, 1);
    session.updateSelection(select_row, 2);
    session.finishSelection();

    try session.resize(2, 6);

    if (session.selectionState()) |selection| {
        try std.testing.expect(selection.active);
        try std.testing.expectEqual(@as(usize, 1), selection.start.col);
        try std.testing.expectEqual(@as(usize, 2), selection.end.col);
    } else {
        return error.MissingSelection;
    }
}
