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

fn codepointAt(session: *term_mod.TerminalSession, global_row: usize, col: usize) ?u32 {
    const history_len = session.scrollbackCount();
    const snapshot = session.snapshot();
    if (global_row < history_len) {
        if (session.scrollbackRow(global_row)) |row| {
            if (col >= row.len) return null;
            return row[col].codepoint;
        }
        return null;
    }
    const grid_row = global_row - history_len;
    if (grid_row >= snapshot.rows) return null;
    if (col >= snapshot.cols) return null;
    const row_start = grid_row * snapshot.cols;
    return snapshot.cells[row_start + col].codepoint;
}

fn rowMatches(session: *term_mod.TerminalSession, global_row: usize, expected: []const u8) bool {
    var i: usize = 0;
    while (i < expected.len) : (i += 1) {
        const cp = codepointAt(session, global_row, i) orelse return false;
        if (cp != expected[i]) return false;
    }
    return true;
}

fn bottomNonBlankRowFirstCodepoint(session: *term_mod.TerminalSession) ?u32 {
    const snapshot = session.snapshot();
    const total = session.scrollbackCount() + snapshot.rows;
    var idx: usize = total;
    while (idx > 0) {
        idx -= 1;
        const cp = codepointAt(session, idx, 0) orelse continue;
        if (cp != 0) return cp;
    }
    return null;
}

test "terminal reflow merges wrapped scrollback rows" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "ABCDEFG\nHIJ\n");
    try session.resize(2, 8);

    const snapshot = session.snapshot();
    const total_rows = session.scrollbackCount() + snapshot.rows;
    var found = false;
    var row: usize = 0;
    while (row < total_rows) : (row += 1) {
        if (rowMatches(session, row, "ABCDEFG")) {
            found = true;
            break;
        }
    }
    try std.testing.expect(found);
}

test "terminal reflow preserves trailing blank cursor and selection" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 1, 4);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "A");
    term_mod.debugSetCursor(session, 0, 3);
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

    const snapshot = session.snapshot();
    const total_rows = session.scrollbackCount() + snapshot.rows;
    try std.testing.expect(total_rows >= 2);

    var found = false;
    var row: usize = 0;
    while (row + 1 < total_rows) : (row += 1) {
        if (rowMatches(session, row, "ABCD") and rowMatches(session, row + 1, "EFGH")) {
            found = true;
            break;
        }
    }
    try std.testing.expect(found);
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

    const expected = bottomNonBlankRowFirstCodepoint(session) orelse return error.MissingScrollback;

    try session.resize(2, 6);

    const actual = bottomNonBlankRowFirstCodepoint(session) orelse return error.MissingScrollback;
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

test "terminal reflow preserves selection content after resize" {
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

    const expected = codepointAt(session, select_row, 1) orelse return error.MissingSelection;

    try session.resize(2, 6);

    if (session.selectionState()) |selection| {
        const actual = codepointAt(session, selection.start.row, selection.start.col) orelse return error.MissingSelection;
        try std.testing.expectEqual(expected, actual);
    } else {
        return error.MissingSelection;
    }
}

test "terminal reflow expands scrollback when narrowing" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 6);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "AAAAAA\nBBBBBB\nCCCCCC\nDDDDDD\nEEEEEE\n");

    const scrollback_before = session.scrollbackCount();
    try session.resize(2, 3);
    const scrollback_after = session.scrollbackCount();

    try std.testing.expect(scrollback_after >= scrollback_before);
}

test "terminal selection survives output while scrolled" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 6);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "AAAAAA\nBBBBBB\nCCCCCC\nDDDDDD\n");
    session.scrollBy(2);

    const snapshot_before = session.snapshot();
    const total_lines_before = session.scrollbackCount() + snapshot_before.rows;
    const start_line_before = total_lines_before - snapshot_before.rows - session.scrollOffset();
    const select_row = start_line_before + 1;
    session.startSelection(select_row, 1);
    session.updateSelection(select_row, 4);
    session.finishSelection();

    term_mod.debugFeedBytes(session, "EEEEEE\n");

    if (session.selectionState()) |selection| {
        try std.testing.expect(selection.active);
        try std.testing.expectEqual(select_row, selection.start.row);
        try std.testing.expectEqual(@as(usize, 1), selection.start.col);
        try std.testing.expectEqual(@as(usize, 4), selection.end.col);
    } else {
        return error.MissingSelection;
    }
}

test "terminal view cache selection clamps row end to last content column" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 8);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "ab\n");
    session.startSelection(0, 0);
    session.updateSelection(0, 7);
    session.finishSelection();
    session.updateViewCacheForScrollLocked();

    const cache = session.renderCache();
    try std.testing.expect(cache.selection_active);
    try std.testing.expectEqual(@as(usize, 2), cache.selection_rows.items.len);
    try std.testing.expect(cache.selection_rows.items[0]);
    try std.testing.expectEqual(@as(u16, 0), cache.selection_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 1), cache.selection_cols_end.items[0]);
}

test "terminal view cache suppresses blank rows in multi-row selection overlay" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 8);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "ab\n");
    session.startSelection(0, 0);
    session.updateSelection(1, 7);
    session.finishSelection();
    session.updateViewCacheForScrollLocked();

    const cache = session.renderCache();
    try std.testing.expect(cache.selection_active);
    try std.testing.expectEqual(@as(usize, 2), cache.selection_rows.items.len);
    try std.testing.expect(cache.selection_rows.items[0]);
    try std.testing.expect(!cache.selection_rows.items[1]);
    try std.testing.expectEqual(@as(u16, 0), cache.selection_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 1), cache.selection_cols_end.items[0]);
}

test "terminal locked scroll refresh consumes pending view cache update" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "AAAA\nBBBB\nCCCC\nDDDD\n");
    session.updateViewCacheForScrollLocked();

    session.lock();
    defer session.unlock();

    session.scrollBy(1);
    try std.testing.expect(session.view_cache_pending.load(.acquire));
    try std.testing.expectEqual(@as(usize, 0), session.renderCache().scroll_offset);

    session.updateViewCacheForScrollLocked();

    try std.testing.expect(!session.view_cache_pending.load(.acquire));
    try std.testing.expectEqual(session.scrollOffset(), session.renderCache().scroll_offset);
}

test "terminal reflow remaps saved cursor" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "ABCDEFGH");
    session.primary.setCursor(1, 1);
    session.saveCursor();

    try session.resize(2, 3);

    try std.testing.expect(session.primary.saved_cursor.active);
    try std.testing.expect(session.primary.saved_cursor.cursor.row < 2);
    try std.testing.expectEqual(@as(usize, 2), session.primary.saved_cursor.cursor.col);
}

test "terminal reflow preserves multi-row cell roots" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const default_cell = session.primary.defaultCell();
    const idx_root = 0 * 4 + 1;
    const idx_cont = 1 * 4 + 1;
    session.primary.grid.cells.items[idx_root] = .{
        .codepoint = 'X',
        .width = 1,
        .height = 2,
        .x = 0,
        .y = 0,
        .attrs = default_cell.attrs,
    };
    session.primary.grid.cells.items[idx_cont] = .{
        .codepoint = 0,
        .width = 1,
        .height = 2,
        .x = 0,
        .y = 1,
        .attrs = default_cell.attrs,
    };

    try session.resize(2, 3);

    const snapshot = session.snapshot();
    try std.testing.expectEqual(@as(u32, 'X'), snapshot.cells[0 * 3 + 1].codepoint);
    try std.testing.expectEqual(@as(u8, 0), snapshot.cells[0 * 3 + 1].y);
    try std.testing.expect(snapshot.cells[1 * 3 + 1].y <= 1);
}

test "terminal reflow keeps top content visible without scrollback" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 4, 8);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "HELLO\n");

    try session.resize(2, 10);

    try std.testing.expectEqual(@as(usize, 0), session.scrollbackCount());
    const snapshot = session.snapshot();
    try std.testing.expectEqual(@as(u32, 'H'), snapshot.cells[0].codepoint);
}
