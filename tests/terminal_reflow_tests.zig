const std = @import("std");
const terminal_runtime = @import("../src/terminal/core/terminal_runtime.zig");
const terminal_debug = @import("../src/terminal/core/session/debug_ops.zig");
const session_runtime = @import("../src/terminal/core/session/runtime.zig");
const terminal_core_modes = @import("../src/terminal/core/terminal_core_modes.zig");
const terminal_publication = @import("../src/terminal/core/publication/terminal_publication.zig");

fn firstCodepoint(session: *terminal_runtime.PtyTerminalRuntime, global_row: usize) ?u32 {
    const snapshot = session.snapshot();
    const history_len = snapshot.scrollback_count;
    if (global_row < history_len) {
        var cells = std.ArrayList(terminal_publication.Cell).empty;
        defer cells.deinit(std.testing.allocator);
        const range = session.copyScrollbackRange(std.testing.allocator, global_row, 1, &cells) catch return null;
        if (range.row_count == 1 and range.cols > 0) return cells.items[0].codepoint;
        return null;
    }
    const cols = snapshot.cols;
    const grid_row = global_row - history_len;
    if (grid_row >= snapshot.rows) return null;
    const row_start = grid_row * cols;
    return snapshot.cells[row_start].codepoint;
}

fn codepointAt(session: *terminal_runtime.PtyTerminalRuntime, global_row: usize, col: usize) ?u32 {
    const snapshot = session.snapshot();
    const history_len = snapshot.scrollback_count;
    if (global_row < history_len) {
        var cells = std.ArrayList(terminal_publication.Cell).empty;
        defer cells.deinit(std.testing.allocator);
        const range = session.copyScrollbackRange(std.testing.allocator, global_row, 1, &cells) catch return null;
        if (range.row_count != 1 or col >= range.cols) return null;
        return cells.items[col].codepoint;
    }
    const grid_row = global_row - history_len;
    if (grid_row >= snapshot.rows) return null;
    if (col >= snapshot.cols) return null;
    const row_start = grid_row * snapshot.cols;
    return snapshot.cells[row_start + col].codepoint;
}

fn rowMatches(session: *terminal_runtime.PtyTerminalRuntime, global_row: usize, expected: []const u8) bool {
    var i: usize = 0;
    while (i < expected.len) : (i += 1) {
        const cp = codepointAt(session, global_row, i) orelse return false;
        if (cp != expected[i]) return false;
    }
    return true;
}

fn bottomNonBlankRowFirstCodepoint(session: *terminal_runtime.PtyTerminalRuntime) ?u32 {
    const snapshot = session.snapshot();
    const total = snapshot.scrollback_count + snapshot.rows;
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

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 2, 4);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "ABCDEFG\nHIJ\n");
    try session_runtime.resize(session, 2, 8);

    const snapshot = session.snapshot();
    const total_rows = snapshot.scrollback_count + snapshot.rows;
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

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 1, 4);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "A");
    terminal_debug.debugSetCursor(session, 0, 3);
    session.startSelection(0, 3);
    session.finishSelection();

    try session_runtime.resize(session, 1, 8);

    const snapshot = session.snapshot();
    try std.testing.expectEqual(@as(usize, 3), snapshot.cursor.col);

    if (snapshot.selection) |selection| {
        try std.testing.expectEqual(@as(usize, 3), selection.start.col);
        try std.testing.expectEqual(@as(usize, 3), selection.end.col);
    } else {
        return error.MissingSelection;
    }
}

test "terminal reflow wraps wide scrollback rows" {
    const allocator = std.testing.allocator;

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 1, 8);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "ABCDEFGH\n");
    try session_runtime.resize(session, 1, 4);

    const snapshot = session.snapshot();
    const total_rows = snapshot.scrollback_count + snapshot.rows;
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

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 2, 4);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "AAAAAA\nBBBBBB\nCCCCCC\nDDDDDD\n");
    session.scrollBy(2);

    const snapshot_before = session.snapshot();
    const total_lines_before = snapshot_before.scrollback_count + snapshot_before.rows;
    const start_line_before = total_lines_before - snapshot_before.rows - snapshot_before.scrollback_offset;
    const expected = firstCodepoint(session, start_line_before) orelse return error.MissingScrollback;

    try session_runtime.resize(session, 2, 6);

    const snapshot_after = session.snapshot();
    const total_lines_after = snapshot_after.scrollback_count + snapshot_after.rows;
    const start_line_after = total_lines_after - snapshot_after.rows - snapshot_after.scrollback_offset;
    const actual = firstCodepoint(session, start_line_after) orelse return error.MissingScrollback;
    try std.testing.expectEqual(expected, actual);
}

test "terminal reflow preserves bottom anchor when not scrolled" {
    const allocator = std.testing.allocator;

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 2, 4);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "111111\n222222\n333333\n444444\n");

    const expected = bottomNonBlankRowFirstCodepoint(session) orelse return error.MissingScrollback;

    try session_runtime.resize(session, 2, 6);

    const actual = bottomNonBlankRowFirstCodepoint(session) orelse return error.MissingScrollback;
    try std.testing.expectEqual(expected, actual);
}

test "terminal reflow keeps selection active when scrolled" {
    const allocator = std.testing.allocator;

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 2, 4);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "AAAAAA\nBBBBBB\nCCCCCC\nDDDDDD\n");
    session.scrollBy(2);

    const snapshot_before = session.snapshot();
    const total_lines_before = snapshot_before.scrollback_count + snapshot_before.rows;
    const start_line_before = total_lines_before - snapshot_before.rows - snapshot_before.scrollback_offset;
    const select_row = start_line_before + 1;
    session.startSelection(select_row, 1);
    session.updateSelection(select_row, 2);
    session.finishSelection();

    try session_runtime.resize(session, 2, 6);

    if (session.snapshot().selection) |selection| {
        try std.testing.expect(selection.active);
        try std.testing.expectEqual(@as(usize, 1), selection.start.col);
        try std.testing.expectEqual(@as(usize, 2), selection.end.col);
    } else {
        return error.MissingSelection;
    }
}

test "terminal reflow preserves selection content after resize" {
    const allocator = std.testing.allocator;

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 2, 4);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "AAAAAA\nBBBBBB\nCCCCCC\nDDDDDD\n");
    session.scrollBy(2);

    const snapshot_before = session.snapshot();
    const total_lines_before = snapshot_before.scrollback_count + snapshot_before.rows;
    const start_line_before = total_lines_before - snapshot_before.rows - snapshot_before.scrollback_offset;
    const select_row = start_line_before + 1;
    session.startSelection(select_row, 1);
    session.updateSelection(select_row, 2);
    session.finishSelection();

    const expected = codepointAt(session, select_row, 1) orelse return error.MissingSelection;

    try session_runtime.resize(session, 2, 6);

    if (session.snapshot().selection) |selection| {
        const actual = codepointAt(session, selection.start.row, selection.start.col) orelse return error.MissingSelection;
        try std.testing.expectEqual(expected, actual);
    } else {
        return error.MissingSelection;
    }
}

test "terminal reflow expands scrollback when narrowing" {
    const allocator = std.testing.allocator;

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 2, 6);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "AAAAAA\nBBBBBB\nCCCCCC\nDDDDDD\nEEEEEE\n");

    const scrollback_before = session.snapshot().scrollback_count;
    try session_runtime.resize(session, 2, 3);
    const scrollback_after = session.snapshot().scrollback_count;

    try std.testing.expect(scrollback_after >= scrollback_before);
}

test "terminal selection survives output while scrolled" {
    const allocator = std.testing.allocator;

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 2, 6);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "AAAAAA\nBBBBBB\nCCCCCC\nDDDDDD\n");
    session.scrollBy(2);

    const snapshot_before = session.snapshot();
    const total_lines_before = snapshot_before.scrollback_count + snapshot_before.rows;
    const start_line_before = total_lines_before - snapshot_before.rows - snapshot_before.scrollback_offset;
    const select_row = start_line_before + 1;
    session.startSelection(select_row, 1);
    session.updateSelection(select_row, 4);
    session.finishSelection();

    terminal_debug.debugFeedBytes(session, "EEEEEE\n");

    if (session.snapshot().selection) |selection| {
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

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 2, 8);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "ab\n");
    session.startSelection(0, 0);
    session.updateSelection(0, 7);
    session.finishSelection();
    terminal_publication.updateViewCacheForScrollLocked(session);

    const cache = terminal_publication.renderCache(session);
    try std.testing.expect(cache.hasSelection());
    try std.testing.expectEqual(@as(usize, 2), cache.selection_rows.items.len);
    try std.testing.expect(cache.selection_rows.items[0]);
    try std.testing.expectEqual(@as(u16, 0), cache.selection_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 1), cache.selection_cols_end.items[0]);
}

test "terminal view cache suppresses blank rows in multi-row selection overlay" {
    const allocator = std.testing.allocator;

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 2, 8);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "ab\n");
    session.startSelection(0, 0);
    session.updateSelection(1, 7);
    session.finishSelection();
    terminal_publication.updateViewCacheForScrollLocked(session);

    const cache = terminal_publication.renderCache(session);
    try std.testing.expect(cache.hasSelection());
    try std.testing.expectEqual(@as(usize, 2), cache.selection_rows.items.len);
    try std.testing.expect(cache.selection_rows.items[0]);
    try std.testing.expect(!cache.selection_rows.items[1]);
    try std.testing.expectEqual(@as(u16, 0), cache.selection_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 1), cache.selection_cols_end.items[0]);
}

test "terminal locked scroll refresh consumes pending view cache update" {
    const allocator = std.testing.allocator;

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 2, 4);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "AAAA\nBBBB\nCCCC\nDDDD\n");
    terminal_publication.updateViewCacheForScrollLocked(session);

    session.lock();
    defer session.unlock();

    session.scrollBy(1);
    try std.testing.expect(session.viewRefreshPending());
    try std.testing.expectEqual(@as(usize, 0), terminal_publication.renderCache(session).scroll_offset);

    terminal_publication.updateViewCacheForScrollLocked(session);

    try std.testing.expect(!session.viewRefreshPending());
    try std.testing.expectEqual(session.snapshot().scrollback_offset, terminal_publication.renderCache(session).scroll_offset);
}

test "terminal reflow remaps saved cursor" {
    const allocator = std.testing.allocator;

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 2, 4);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "ABCDEFGH");
    session.primary.setCursor(1, 1);
    terminal_core_modes.saveCursor(session);

    try session_runtime.resize(session, 2, 3);

    try std.testing.expect(session.primary.saved_cursor.active);
    try std.testing.expect(session.primary.saved_cursor.cursor.row < 2);
    try std.testing.expectEqual(@as(usize, 2), session.primary.saved_cursor.cursor.col);
}

test "terminal reflow preserves multi-row cell roots" {
    const allocator = std.testing.allocator;

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 2, 4);
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

    try session_runtime.resize(session, 2, 3);

    const snapshot = session.snapshot();
    try std.testing.expectEqual(@as(u32, 'X'), snapshot.cells[0 * 3 + 1].codepoint);
    try std.testing.expectEqual(@as(u8, 0), snapshot.cells[0 * 3 + 1].y);
    try std.testing.expect(snapshot.cells[1 * 3 + 1].y <= 1);
}

test "terminal reflow keeps top content visible without scrollback" {
    const allocator = std.testing.allocator;

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 4, 8);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "HELLO\n");

    try session_runtime.resize(session, 2, 10);

    const snapshot = session.snapshot();
    try std.testing.expectEqual(@as(usize, 0), snapshot.scrollback_count);
    try std.testing.expectEqual(@as(u32, 'H'), snapshot.cells[0].codepoint);
}
