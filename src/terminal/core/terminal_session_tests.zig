const std = @import("std");
const builtin = @import("builtin");
const types = @import("../model/types.zig");
const session_mod = @import("terminal_session.zig");
const terminal_transport = @import("terminal_transport.zig");
const pty_mod = @import("../io/pty.zig");

const TerminalSession = session_mod.TerminalSession;
const Cell = session_mod.Cell;
const Color = session_mod.Color;
const Dirty = session_mod.Dirty;
const Pty = pty_mod.Pty;

fn expectSnapshotRow(snapshot: session_mod.TerminalSnapshot, row: usize, expected: []const u8) !void {
    const cells = snapshot.rowSlice(row);
    try std.testing.expectEqual(expected.len, cells.len);
    for (cells, expected) |cell, ch| {
        try std.testing.expectEqual(@as(u32, ch), cell.codepoint);
    }
}

test "external transport poll updates screen and metadata" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 12);
    defer session.deinit();
    session.attachExternalTransport();

    try std.testing.expect(session.isAlive());

    try std.testing.expect(try session.enqueueExternalBytes("\x1b]0;ext-title\x07hello\r\n"));
    try session.poll();

    const snapshot = session.snapshot();
    try std.testing.expectEqualStrings("ext-title", snapshot.title);
    try expectSnapshotRow(snapshot, 0, "hello       ");

    var title_buf = std.ArrayList(u8).empty;
    defer title_buf.deinit(allocator);
    var cwd_buf = std.ArrayList(u8).empty;
    defer cwd_buf.deinit(allocator);
    const metadata = try session.copyMetadata(allocator, &title_buf, &cwd_buf);
    try std.testing.expect(metadata.alive);
    try std.testing.expectEqualStrings("ext-title", metadata.title);
}

test "external transport close updates alive metadata" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 12);
    defer session.deinit();
    session.attachExternalTransport();

    try std.testing.expect(session.isAlive());
    try std.testing.expect(session.closeExternalTransport());
    try std.testing.expect(!session.isAlive());

    var title_buf = std.ArrayList(u8).empty;
    defer title_buf.deinit(allocator);
    var cwd_buf = std.ArrayList(u8).empty;
    defer cwd_buf.deinit(allocator);
    const metadata = try session.copyMetadata(allocator, &title_buf, &cwd_buf);
    try std.testing.expect(!metadata.alive);
}

test "alt screen core helpers preserve cursor save restore behavior" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 3, 8);
    defer session.deinit();

    session.primary.setCursor(2, 3);
    session.enterAltScreen(true, true);
    try std.testing.expect(session.core.isAltActive());
    try std.testing.expectEqual(@as(usize, 0), session.activeScreen().cursor.row);
    try std.testing.expectEqual(@as(usize, 0), session.activeScreen().cursor.col);

    session.activeScreen().setCursor(1, 1);
    session.exitAltScreen(true);
    try std.testing.expect(!session.core.isAltActive());
    try std.testing.expectEqual(@as(usize, 2), session.activeScreen().cursor.row);
    try std.testing.expectEqual(@as(usize, 3), session.activeScreen().cursor.col);
}

test "full-region scroll publishes partial cache damage at live bottom" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row: usize = 0;
    while (row < 3) : (row += 1) {
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            var cell = base;
            cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(row));
            session.primary.grid.cells.items[row * 4 + col] = cell;
        }
    }
    session.primary.setCursor(2, 0);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.scrollUp();
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(i32, 1), cache.viewport_shift_rows);
    try std.testing.expect(cache.viewport_shift_exposed_only);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
    try std.testing.expectEqual(@as(usize, 1), session.scrollbackInfo().total_rows);
}

test "pty-backed session sendText writes through session writer boundary" {
    if (builtin.target.os.tag == .windows) return;

    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 8);
    defer session.deinit();

    var pty = Pty.init(
        allocator,
        .{ .rows = 2, .cols = 8, .cell_width = 8, .cell_height = 16 },
        "/bin/cat",
    ) catch |err| switch (err) {
        error.OpenPtyFailed => return,
        else => return err,
    };
    session.attachPtyTransport(pty);

    try session.sendText("abc");

    const start_ms = std.time.milliTimestamp();
    while (std.time.milliTimestamp() - start_ms < 3000) {
        try session.poll();
        const snapshot = session.snapshot();
        if (snapshot.rowSlice(0).len >= 3 and
            snapshot.rowSlice(0)[0].codepoint == 'a' and
            snapshot.rowSlice(0)[1].codepoint == 'b' and
            snapshot.rowSlice(0)[2].codepoint == 'c')
        {
            return;
        }
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }

    try expectSnapshotRow(session.snapshot(), 0, "abc     ");
}

test "top-anchored partial scroll region retires rows into scrollback" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 6, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    inline for ([_]struct { row: usize, cp: u8 }{
        .{ .row = 0, .cp = 'A' },
        .{ .row = 1, .cp = 'B' },
        .{ .row = 2, .cp = 'C' },
    }) |entry| {
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            var cell = base;
            cell.codepoint = entry.cp;
            session.primary.grid.cells.items[entry.row * 4 + col] = cell;
        }
    }

    session.feedOutputBytes("\x1b[1;3r");
    session.scrollRegionUpWithOrigin(1, "test.top_anchored_scroll_region");

    try std.testing.expectEqual(@as(usize, 1), session.scrollbackInfo().total_rows);
    const history_row = session.scrollbackRow(0) orelse return error.TestExpectedEqual;
    try std.testing.expectEqual(@as(usize, 4), history_row.len);
    for (history_row) |cell| {
        try std.testing.expectEqual(@as(u32, 'A'), cell.codepoint);
    }

    const snapshot = session.snapshot();
    try expectSnapshotRow(snapshot, 0, "BBBB");
    try expectSnapshotRow(snapshot, 1, "CCCC");
}

test "feedOutputBytes keeps incremental damage after baseline publish" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 1, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.feedOutputBytes("A");

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
}

test "carriage return plus erase line rewrites current row in place" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 4, 20);
    defer session.deinit();

    session.feedOutputBytes("hello");
    session.feedOutputBytes("\r\x1b[2Kbye");

    try std.testing.expectEqual(@as(usize, 0), session.scrollbackInfo().total_rows);
    const snapshot = session.snapshot();
    try expectSnapshotRow(snapshot, 0, "bye                 ");

    session.feedOutputBytes("\r\x1b[2Kstep 1");
    session.feedOutputBytes("\r\x1b[2Kstep 2");

    try std.testing.expectEqual(@as(usize, 0), session.scrollbackInfo().total_rows);
    try expectSnapshotRow(session.snapshot(), 0, "step 2              ");
}

test "zig progress redraw pattern rewrites block instead of appending" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 6, 20);
    defer session.deinit();

    debugSetCursor(&session, 4, 0);

    session.feedOutputBytes("\x1b[Jbuild one\nitem a\n\r\x1bM\x1bM");
    session.feedOutputBytes("\x1b[Jbuild two\nitem b\n\r\x1bM\x1bM");

    const snapshot = session.snapshot();
    try std.testing.expectEqual(@as(usize, 0), snapshot.scrollback_count);
    try expectSnapshotRow(snapshot, 2, "build two           ");
    try expectSnapshotRow(snapshot, 3, "item b              ");
}

test "zig progress redraw invalidates cleared tail rows" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 6, 20);
    defer session.deinit();

    debugSetCursor(&session, 4, 0);
    session.feedOutputBytes("\x1b[Jbuild one\nitem a\n\r\x1bM\x1bM");

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.feedOutputBytes("\x1b[Jbuild two\nitem b\n\r\x1bM\x1bM");

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 5), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 19), cache.damage.end_col);
}

test "synchronized zig progress redraw does not retire intermediate scrollback" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 68, 20);
    defer session.deinit();

    debugSetCursor(&session, 67, 0);

    session.feedOutputBytes("\x1b[?2026h");
    try std.testing.expect(session.syncUpdatesActive());

    session.feedOutputBytes("\x1b[Jbuild one\nitem a\n\r\x1bM\x1bM");
    session.feedOutputBytes("\x1b[Jbuild two\nitem b\n\r\x1bM\x1bM");

    try std.testing.expectEqual(@as(usize, 0), session.scrollbackInfo().total_rows);

    session.feedOutputBytes("\x1b[?2026l");
    try std.testing.expect(!session.syncUpdatesActive());

    const snapshot = session.snapshot();
    try std.testing.expectEqual(@as(usize, 0), snapshot.scrollback_count);
    try expectSnapshotRow(snapshot, 65, "build two           ");
    try expectSnapshotRow(snapshot, 66, "item b              ");
}

test "synchronized top-anchored partial scroll region retires rows into scrollback" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 6, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    inline for ([_]struct { row: usize, cp: u8 }{
        .{ .row = 0, .cp = 'A' },
        .{ .row = 1, .cp = 'B' },
        .{ .row = 2, .cp = 'C' },
    }) |entry| {
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            var cell = base;
            cell.codepoint = entry.cp;
            session.primary.grid.cells.items[entry.row * 4 + col] = cell;
        }
    }

    session.feedOutputBytes("\x1b[?2026h");
    try std.testing.expect(session.syncUpdatesActive());

    session.feedOutputBytes("\x1b[1;3r");
    session.scrollRegionUpWithOrigin(1, "test.sync_top_anchored_scroll_region");

    try std.testing.expectEqual(@as(usize, 1), session.scrollbackInfo().total_rows);
    const history_row = session.scrollbackRow(0) orelse return error.TestExpectedEqual;
    try std.testing.expectEqual(@as(usize, 4), history_row.len);
    for (history_row) |cell| {
        try std.testing.expectEqual(@as(u32, 'A'), cell.codepoint);
    }

    const snapshot = session.snapshot();
    try expectSnapshotRow(snapshot, 0, "BBBB");
    try expectSnapshotRow(snapshot, 1, "CCCC");
}

test "single-chunk synchronized progress sequence keeps newline scroll inside sync window" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 68, 20);
    defer session.deinit();

    debugSetCursor(&session, 67, 0);
    session.feedOutputBytes("\x1b[?2026h\x1b[Jbuild one\nitem a\r\x1bM\x1b[?2026l");

    try std.testing.expectEqual(@as(usize, 0), session.scrollbackInfo().total_rows);
    try std.testing.expect(!session.syncUpdatesActive());

    const snapshot = session.snapshot();
    try std.testing.expectEqual(@as(usize, 0), snapshot.scrollback_count);
    try expectSnapshotRow(snapshot, 66, "build one           ");
    try expectSnapshotRow(snapshot, 67, "item a              ");
}

test "reverse index moves cursor up inside scroll region" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 6, 8);
    defer session.deinit();

    debugSetCursor(&session, 4, 2);
    session.feedOutputBytes("\x1bM");

    const cursor = session.getCursorPos();
    try std.testing.expectEqual(@as(usize, 3), cursor.row);
    try std.testing.expectEqual(@as(usize, 2), cursor.col);
}

test "real zig redraw chunk rewrites in place at bottom edge" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 68, 80);
    defer session.deinit();

    debugSetCursor(&session, 67, 0);
    session.feedOutputBytes(
        "\x1b[?2026h" ++
            "\x1b[J" ++
            "[3] Compile Build Script\r\n" ++
            "\x1b(0tq\x1b(B [1137/5878] Linking\r\n" ++
            "\x1b(0tq\x1b(B [1133/1376] Code Generation\r\n" ++
            "\x1b(0mq\x1b(B [7017] Semantic Analysis\r\n" ++
            "   \x1b(0mq\x1b(B Target.powerpc.all_features\r\n" ++
            "\x1b]9;4;3\x07" ++
            "\r\x1bM\x1bM\x1bM\x1bM\x1bM" ++
            "\x1b[?2026l",
    );

    try std.testing.expectEqual(@as(usize, 0), session.scrollbackInfo().total_rows);
    try std.testing.expect(!session.syncUpdatesActive());

    const snapshot = session.snapshot();
    try expectSnapshotRow(snapshot, 63, "[3] Compile Build Script                                                         ");
    try expectSnapshotRow(snapshot, 64, "qq [1137/5878] Linking                                                           ");
    try expectSnapshotRow(snapshot, 65, "qq [1133/1376] Code Generation                                                   ");
    try expectSnapshotRow(snapshot, 66, "q  [7017] Semantic Analysis                                                      ");
    try expectSnapshotRow(snapshot, 67, "   q  Target.powerpc.all_features                                                ");
}

test "repeat guide chunks do not grow scrollback unexpectedly" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 4, 10);
    defer session.deinit();
    session.attachExternalTransport();

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[H1| |aaa \x1b[2;1H2| |bbb \x1b[3;1H3| |ccc \x1b[4;1H4| |ddd "));
    try session.poll();
    try std.testing.expectEqual(@as(usize, 0), session.scrollbackInfo().total_rows);

    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[H5\x1b[2;1H+>"));
    try session.poll();
    try std.testing.expectEqual(@as(usize, 0), session.scrollbackInfo().total_rows);

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[1;4H|\x1b[2;4H|"));
    try session.poll();

    try std.testing.expectEqual(@as(usize, 0), session.scrollbackInfo().total_rows);

    const snapshot = session.snapshot();
    try expectSnapshotRow(snapshot, 0, "5| |aaa   ");
    try expectSnapshotRow(snapshot, 1, "+> |bbb   ");
    try expectSnapshotRow(snapshot, 2, "3| |ccc   ");
    try expectSnapshotRow(snapshot, 3, "4| |ddd   ");
}

test "repeat guide chunks publish current broad cache contract" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 4, 10);
    defer session.deinit();
    session.attachExternalTransport();

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[H1| |aaa \x1b[2;1H2| |bbb \x1b[3;1H3| |ccc \x1b[4;1H4| |ddd "));
    try session.poll();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[H5\x1b[2;1H+>"));
    try session.poll();

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[1;4H|\x1b[2;4H|"));
    try session.poll();

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 9), cache.damage.end_col);
}

test "first repeat guide packet keeps bottom row clean today" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 4, 10);
    defer session.deinit();
    session.attachExternalTransport();

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[H1| |aaa \x1b[2;1H2| |bbb \x1b[3;1H3| |ccc \x1b[4;1H4| |ddd "));
    try session.poll();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[H5\x1b[2;1H+>"));
    try session.poll();

    const cache = session.renderCache();
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
    try std.testing.expect(!cache.dirty_rows.items[2]);
    try std.testing.expect(!cache.dirty_rows.items[3]);
}

test "repeat guide chunks mark unexpected bottom row dirty today" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 4, 10);
    defer session.deinit();
    session.attachExternalTransport();

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[H1| |aaa \x1b[2;1H2| |bbb \x1b[3;1H3| |ccc \x1b[4;1H4| |ddd "));
    try session.poll();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[H5\x1b[2;1H+>"));
    try session.poll();

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[1;4H|\x1b[2;4H|"));
    try session.poll();

    const cache = session.renderCache();
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
    try std.testing.expect(!cache.dirty_rows.items[2]);
    try std.testing.expect(cache.dirty_rows.items[3]);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_start.items[3]);
    try std.testing.expectEqual(@as(u16, 9), cache.dirty_cols_end.items[3]);
}

test "repeat guide second packet keeps raw screen bottom row clean" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 4, 10);
    defer session.deinit();
    session.attachExternalTransport();

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[H1| |aaa \x1b[2;1H2| |bbb \x1b[3;1H3| |ccc \x1b[4;1H4| |ddd "));
    try session.poll();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[H5\x1b[2;1H+>"));
    try session.poll();

    try std.testing.expect(try session.enqueueExternalBytes("\x1b[1;4H|\x1b[2;4H|"));
    try session.poll();

    const view = session.activeScreenConst().snapshotView();
    try std.testing.expect(view.dirty_rows[0]);
    try std.testing.expect(view.dirty_rows[1]);
    try std.testing.expect(!view.dirty_rows[2]);
    try std.testing.expect(!view.dirty_rows[3]);
}

test "manual repeat guide publication still dirties bottom row today" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 4, 10);
    defer session.deinit();

    session.debugFeedBytes("\x1b[H1| |aaa \x1b[2;1H2| |bbb \x1b[3;1H3| |ccc \x1b[4;1H4| |ddd ");
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.debugFeedBytes("\x1b[H5\x1b[2;1H+>");
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    session.debugFeedBytes("\x1b[1;4H|\x1b[2;4H|");
    const view = session.activeScreenConst().snapshotView();
    try std.testing.expect(view.dirty_rows[0]);
    try std.testing.expect(view.dirty_rows[1]);
    try std.testing.expect(!view.dirty_rows[2]);
    try std.testing.expect(!view.dirty_rows[3]);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expect(cache.dirty_rows.items[3]);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_start.items[3]);
    try std.testing.expectEqual(@as(u16, 9), cache.dirty_cols_end.items[3]);
}

test "acknowledgePresentedGeneration derives sync dirty retirement from cache" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 1, 4);
    defer session.deinit();

    session.primary.markDirtyAllWithReason(.unknown, @src());
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    const normal_generation = session.renderCache().generation;
    try std.testing.expect(session.acknowledgePresentedGeneration(normal_generation));
    try std.testing.expectEqual(Dirty.none, session.primary.grid.dirty);

    session.primary.markDirtyAllWithReason(.unknown, @src());
    session.setSyncUpdates(true);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    const sync_generation = session.renderCache().generation;
    try std.testing.expect(session.acknowledgePresentedGeneration(sync_generation));
    try std.testing.expectEqual(Dirty.full, session.primary.grid.dirty);
}

test "row hash refinement does not skip unpresented top rows" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row: usize = 0;
    while (row < 3) : (row += 1) {
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            var cell = base;
            cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(row));
            session.primary.grid.cells.items[row * 4 + col] = cell;
        }
    }
    session.primary.setCursor(2, 0);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.scrollUp();
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    session.scrollUp();
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expect(cache.dirty_rows.items[0]);
}

test "row hash refinement does not suppress newly dirty rows against unpresented cache" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row: usize = 0;
    while (row < 2) : (row += 1) {
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            var cell = base;
            cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(row));
            session.primary.grid.cells.items[row * 4 + col] = cell;
        }
    }

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    var cell = session.primary.grid.cells.items[0];
    cell.codepoint = 'Z';
    session.primary.grid.cells.items[0] = cell;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const unpresented_generation = session.renderCache().generation;
    try std.testing.expect(unpresented_generation != session.presentedGeneration());
    try std.testing.expectEqual(Dirty.partial, session.renderCache().dirty);

    session.primary.clearDirty();
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expect(cache.generation != session.presentedGeneration());
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
    try std.testing.expectEqual(@as(u32, 'Z'), cache.cells.items[0].codepoint);
}

test "snapshot view preserves disjoint same-row dirty spans" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 20);
    defer session.deinit();

    session.primary.clearDirty();
    session.primary.grid.markDirtyRangeWithOrigin("test.small_region", 0, 0, 2, 5);
    session.primary.grid.markDirtyRangeWithOrigin("test.body_rewrite", 0, 0, 10, 18);

    const view = session.activeScreenConst().snapshotView();
    try std.testing.expect(view.dirty_rows[0]);
    try std.testing.expectEqual(@as(u8, 2), view.row_dirty_span_counts[0]);
    try std.testing.expect(!view.row_dirty_span_overflow[0]);
    try std.testing.expectEqual(@as(u16, 2), view.row_dirty_spans[0][0].start);
    try std.testing.expectEqual(@as(u16, 5), view.row_dirty_spans[0][0].end);
    try std.testing.expectEqual(@as(u16, 10), view.row_dirty_spans[0][1].start);
    try std.testing.expectEqual(@as(u16, 18), view.row_dirty_spans[0][1].end);
    try std.testing.expectEqual(@as(u16, 2), view.dirty_cols_start[0]);
    try std.testing.expectEqual(@as(u16, 18), view.dirty_cols_end[0]);
}

test "view cache preserves disjoint same-row dirty spans" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 20);
    defer session.deinit();

    session.primary.clearDirty();
    session.primary.grid.markDirtyRangeWithOrigin("test.small_region", 0, 0, 2, 5);
    session.primary.grid.markDirtyRangeWithOrigin("test.body_rewrite", 0, 0, 10, 18);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expectEqual(@as(u8, 2), cache.row_dirty_span_counts.items[0]);
    try std.testing.expect(!cache.row_dirty_span_overflow.items[0]);
    try std.testing.expectEqual(@as(u16, 2), cache.row_dirty_spans.items[0][0].start);
    try std.testing.expectEqual(@as(u16, 5), cache.row_dirty_spans.items[0][0].end);
    try std.testing.expectEqual(@as(u16, 10), cache.row_dirty_spans.items[0][1].start);
    try std.testing.expectEqual(@as(u16, 18), cache.row_dirty_spans.items[0][1].end);
    try std.testing.expectEqual(@as(u16, 2), cache.dirty_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 18), cache.dirty_cols_end.items[0]);
}

test "setSyncUpdates enable does not force redraw when screen is otherwise clean" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.setSyncUpdates(true);

    const cache = session.renderCache();
    try std.testing.expect(session.syncUpdatesActive());
    try std.testing.expectEqual(Dirty.none, cache.dirty);
    try std.testing.expectEqual(@as(u64, 0), cache.full_dirty_seq);
}

test "setSyncUpdates enable does not publish dirty screen state on presented generation" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    const baseline_generation = session.renderCache().generation;
    var cell = session.primary.defaultCell();
    cell.codepoint = 'Z';
    session.primary.grid.cells.items[0] = cell;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);

    session.setSyncUpdates(true);

    var cache = session.renderCache();
    try std.testing.expect(session.syncUpdatesActive());
    try std.testing.expectEqual(baseline_generation, cache.generation);
    try std.testing.expectEqual(Dirty.none, cache.dirty);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    cache = session.renderCache();
    try std.testing.expectEqual(baseline_generation + 1, cache.generation);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
}

test "setSyncUpdates disable stays clean when no buffered changes exist" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    session.setSyncUpdates(true);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.setSyncUpdates(false);

    const cache = session.renderCache();
    try std.testing.expect(!session.syncUpdatesActive());
    try std.testing.expectEqual(Dirty.none, cache.dirty);
}

test "setSyncUpdates disable preserves buffered partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.setSyncUpdates(true);

    var cell = session.primary.defaultCell();
    cell.codepoint = 'Z';
    session.primary.grid.cells.items[0] = cell;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    session.setSyncUpdates(false);

    const cache = session.renderCache();
    try std.testing.expect(!session.syncUpdatesActive());
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
}

test "visible history changes publish partial cache damage without force-full" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row_a = [_]Cell{ base, base, base, base };
    var row_b = [_]Cell{ base, base, base, base };
    for (&row_a, 0..) |*cell, col| cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(col));
    for (&row_b, 0..) |*cell, col| cell.codepoint = @as(u32, 'E') + @as(u32, @intCast(col));

    session.history.pushRow(&row_a, false, base);
    session.history.pushRow(&row_b, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, base);
    session.history.setScrollOffset(session.primary.grid.rows, 2);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    const new_fg = Color{ .r = 0x11, .g = 0x22, .b = 0x33, .a = 0xff };
    session.history.updateDefaultColors(base.attrs.fg, base.attrs.bg, new_fg, base.attrs.bg);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expectEqual(new_fg, cache.cells.items[0].attrs.fg);
}

test "visible history changes without presented diff base stay partial" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row_a = [_]Cell{ base, base, base, base };
    var row_b = [_]Cell{ base, base, base, base };
    for (&row_a, 0..) |*cell, col| cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(col));
    for (&row_b, 0..) |*cell, col| cell.codepoint = @as(u32, 'E') + @as(u32, @intCast(col));

    session.history.pushRow(&row_a, false, base);
    session.history.pushRow(&row_b, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, base);
    session.history.setScrollOffset(session.primary.grid.rows, 2);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    const new_fg = Color{ .r = 0x44, .g = 0x55, .b = 0x66, .a = 0xff };
    session.history.updateDefaultColors(base.attrs.fg, base.attrs.bg, new_fg, base.attrs.bg);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 3), cache.dirty_cols_end.items[0]);
    try std.testing.expectEqual(new_fg, cache.cells.items[0].attrs.fg);
}

test "scrollback offset change publishes shift-exposed partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var history_rows = [_][4]Cell{
        .{ base, base, base, base },
        .{ base, base, base, base },
        .{ base, base, base, base },
        .{ base, base, base, base },
    };
    for (&history_rows, 0..) |*history_row, row_idx| {
        for (history_row, 0..) |*cell, col| {
            cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(row_idx * 4 + col));
        }
        session.history.pushRow(history_row, false, base);
    }

    session.history.ensureViewCache(session.primary.grid.cols, base);
    session.history.setScrollOffset(session.primary.grid.rows, 2);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.setScrollOffset(1);

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(i32, 1), cache.viewport_shift_rows);
    try std.testing.expect(cache.viewport_shift_exposed_only);
    try std.testing.expect(!cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
}

test "scrollback offset change advances published generation" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    session.debugPushScrollbackRow("AAAA");
    session.debugPushScrollbackRow("BBBB");
    session.debugSetGridRow(0, "CCCC");
    session.debugSetGridRow(1, "DDDD");
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    const baseline_generation = session.renderCache().generation;
    session.setScrollOffset(1);

    const cache = session.renderCache();
    try std.testing.expectEqual(@as(usize, 1), cache.scroll_offset);
    try std.testing.expect(cache.generation != baseline_generation);
}

test "acknowledgePresentedGeneration does not retire newer scrollback view publication" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    session.debugPushScrollbackRow("AAAA");
    session.debugPushScrollbackRow("BBBB");
    session.debugSetGridRow(0, "CCCC");
    session.debugSetGridRow(1, "DDDD");
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    const baseline_generation = session.renderCache().generation;
    session.setScrollOffset(1);

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expect(!session.acknowledgePresentedGeneration(baseline_generation));
    try std.testing.expectEqual(Dirty.partial, session.renderCache().dirty);
    try std.testing.expectEqual(@as(usize, 1), session.renderCache().scroll_offset);
}

test "acknowledgePresentedGeneration does not retire newer normal publication" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    const baseline_generation = session.renderCache().generation;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
    try std.testing.expect(!session.acknowledgePresentedGeneration(baseline_generation));
    try std.testing.expectEqual(cache.generation - 1, session.presentedGeneration());
    try std.testing.expectEqual(Dirty.partial, session.renderCache().dirty);
    try std.testing.expectEqual(@as(usize, 0), session.renderCache().damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), session.renderCache().damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), session.renderCache().damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), session.renderCache().damage.end_col);
}

test "clean publication does not overwrite unpresented dirty publication" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    var cell = session.primary.grid.cells.items[0];
    cell.codepoint = 'Z';
    session.primary.grid.cells.items[0] = cell;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const dirty_generation = session.renderCache().generation;
    try std.testing.expectEqual(Dirty.partial, session.renderCache().dirty);
    try std.testing.expectEqual(@as(u32, 'Z'), session.renderCache().cells.items[0].codepoint);

    session.primary.clearDirty();
    session.alt.clearDirty();
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(dirty_generation + 1, cache.generation);
    try std.testing.expect(cache.generation != session.presentedGeneration());
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
    try std.testing.expectEqual(@as(u32, 'Z'), cache.cells.items[0].codepoint);
}

test "notePresentedGeneration does not regress presented generation" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    session.notePresentedGeneration(7);
    session.notePresentedGeneration(3);

    try std.testing.expectEqual(@as(u64, 7), session.presentedGeneration());
}

test "cursor style updates publish through cache without texture invalidation" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.primary.cursor_style = .{ .shape = .bar, .blink = false };
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.none, cache.dirty);
    try std.testing.expectEqual(types.CursorStyle{ .shape = .bar, .blink = false }, cache.cursor_style);
}

test "kitty generation delta does not force full damage when cell damage is partial" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.kitty_primary.generation += 1;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
}

test "kitty generation delta without visible damage stays clean" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.kitty_primary.generation += 1;
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.none, cache.dirty);
}

test "kitty placement move stays dirty even when text cells are unchanged" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const image_data = try allocator.alloc(u8, 4);
    @memset(image_data, 0);
    try session.kitty_primary.images.append(allocator, .{
        .id = 7,
        .width = 1,
        .height = 1,
        .format = .rgba,
        .data = image_data,
        .version = 1,
    });
    try session.kitty_primary.placements.append(allocator, .{
        .image_id = 7,
        .placement_id = 1,
        .row = 0,
        .col = 0,
        .cols = 1,
        .rows = 1,
        .z = 0,
        .anchor_row = 0,
        .is_virtual = false,
        .parent_image_id = 0,
        .parent_placement_id = 0,
        .offset_x = 0,
        .offset_y = 0,
    });
    session.kitty_primary.generation = 1;

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.kitty_primary.placements.items[0].row = 1;
    session.kitty_primary.placements.items[0].anchor_row = 1;
    session.kitty_primary.generation += 1;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    session.primary.grid.markDirtyRange(1, 1, 0, 0);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
    try std.testing.expectEqual(@as(usize, 1), cache.kitty_placements.items.len);
    try std.testing.expectEqual(@as(u16, 1), cache.kitty_placements.items[0].row);
}

test "clear generation delta without visible damage stays clean" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    _ = session.clear_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.none, cache.dirty);
}

test "default color remap stays on partial path" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    const old_attrs = session.primary.default_attrs;
    const new_fg = Color{ .r = 0xaa, .g = 0xbb, .b = 0xcc, .a = 0xff };
    session.setDefaultColors(new_fg, old_attrs.bg);

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 3), cache.dirty_cols_end.items[0]);
    try std.testing.expectEqual(new_fg, cache.cells.items[0].attrs.fg);
}

test "screen reverse toggle stays on partial path" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.activeScreen().setScreenReverse(true);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expect(cache.screen_reverse);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 3), cache.dirty_cols_end.items[0]);
}

test "visible history change narrows to projected diff against presented base" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row_a = [_]Cell{ base, base, base, base };
    var row_b = [_]Cell{ base, base, base, base };
    for (&row_a, 0..) |*cell, col| cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(col));
    for (&row_b, 0..) |*cell, col| cell.codepoint = @as(u32, 'E') + @as(u32, @intCast(col));

    session.history.pushRow(&row_a, false, base);
    session.history.pushRow(&row_b, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, base);
    session.history.setScrollOffset(session.primary.grid.rows, 2);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    const history_row = session.history.scrollback.lineByIndexMut(0).?;
    history_row.cells[0].codepoint = 'Z';
    session.history.markScrollbackChanged();
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(!cache.dirty_rows.items[1]);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_end.items[0]);
    try std.testing.expectEqual(@as(u32, 'Z'), cache.cells.items[0].codepoint);
}

test "visible history change stays conservative against unpresented base" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row_a = [_]Cell{ base, base, base, base };
    var row_b = [_]Cell{ base, base, base, base };
    for (&row_a, 0..) |*cell, col| cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(col));
    for (&row_b, 0..) |*cell, col| cell.codepoint = @as(u32, 'E') + @as(u32, @intCast(col));

    session.history.pushRow(&row_a, false, base);
    session.history.pushRow(&row_b, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, base);
    session.history.setScrollOffset(session.primary.grid.rows, 2);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    const first_update = session.history.scrollback.lineByIndexMut(0).?;
    first_update.cells[0].codepoint = 'Z';
    session.history.markScrollbackChanged();
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const second_update = session.history.scrollback.lineByIndexMut(0).?;
    second_update.cells[1].codepoint = 'Y';
    session.history.markScrollbackChanged();
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
}

test "debug scrollback helpers preserve visible-history baseline shape" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    session.debugPushScrollbackRow("ABCD");
    session.debugPushScrollbackRow("EFGH");
    session.debugSetScrollOffset(2);
    session.notePresentedGeneration(session.renderCache().generation);
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    const cache = session.renderCache();
    try std.testing.expectEqual(@as(usize, 2), cache.history_len);
    try std.testing.expectEqual(@as(usize, 4), cache.total_lines);
    try std.testing.expectEqual(@as(usize, 2), cache.scroll_offset);
    try std.testing.expectEqual(Dirty.none, cache.dirty);
    try std.testing.expectEqualStrings("ABCD", &[_]u8{
        @intCast(cache.cells.items[0].codepoint),
        @intCast(cache.cells.items[1].codepoint),
        @intCast(cache.cells.items[2].codepoint),
        @intCast(cache.cells.items[3].codepoint),
    });
    try std.testing.expectEqualStrings("EFGH", &[_]u8{
        @intCast(cache.cells.items[4].codepoint),
        @intCast(cache.cells.items[5].codepoint),
        @intCast(cache.cells.items[6].codepoint),
        @intCast(cache.cells.items[7].codepoint),
    });
}

test "debug scrollback cell mutation keeps two-row visible-history shape" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    session.debugPushScrollbackRow("ABCD");
    session.debugPushScrollbackRow("EFGH");
    session.debugSetScrollOffset(2);
    session.notePresentedGeneration(session.renderCache().generation);
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.debugSetScrollbackCell(0, 0, 'Z');

    const cache = session.renderCache();
    try std.testing.expectEqual(@as(usize, 2), cache.history_len);
    try std.testing.expectEqual(@as(usize, 4), cache.total_lines);
    try std.testing.expectEqual(@as(usize, 2), cache.scroll_offset);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(!cache.dirty_rows.items[1]);
    try std.testing.expectEqualStrings("ZBCD", &[_]u8{
        @intCast(cache.cells.items[0].codepoint),
        @intCast(cache.cells.items[1].codepoint),
        @intCast(cache.cells.items[2].codepoint),
        @intCast(cache.cells.items[3].codepoint),
    });
    try std.testing.expectEqualStrings("EFGH", &[_]u8{
        @intCast(cache.cells.items[4].codepoint),
        @intCast(cache.cells.items[5].codepoint),
        @intCast(cache.cells.items[6].codepoint),
        @intCast(cache.cells.items[7].codepoint),
    });
}

test "debug scrollback helper stays conservative on second unpresented visible-history mutation" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    session.debugPushScrollbackRow("ABCD");
    session.debugPushScrollbackRow("EFGH");
    session.debugSetScrollOffset(2);
    session.notePresentedGeneration(session.renderCache().generation);
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.debugSetScrollbackCell(0, 0, 'Z');
    session.debugSetScrollbackCell(0, 1, 'Y');

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
}

test "debug scrollback helper with replay cursor setup stays conservative on second visible-history mutation" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    session.debugSetCursor(1, 0);
    session.debugPushScrollbackRow("ABCD");
    session.debugPushScrollbackRow("EFGH");
    session.debugSetScrollOffset(2);
    session.notePresentedGeneration(session.renderCache().generation);
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.debugSetScrollbackCell(0, 0, 'Z');
    session.debugSetScrollbackCell(0, 1, 'Y');

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
}

test "debug scrollback helper with replay transport setup stays conservative on second visible-history mutation" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();
    session.attachExternalTransport();

    session.debugSetCursor(1, 0);
    session.debugPushScrollbackRow("ABCD");
    session.debugPushScrollbackRow("EFGH");
    session.debugSetScrollOffset(2);
    session.notePresentedGeneration(session.renderCache().generation);
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.debugSetScrollbackCell(0, 0, 'Z');
    session.debugSetScrollbackCell(0, 1, 'Y');

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
}

test "selection dirty expansion does not suppress repeated unpresented selection state" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var cell = base;
    cell.codepoint = 'A';
    session.primary.grid.cells.items[0] = cell;

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.selectRange(.{ .row = 0, .col = 0 }, .{ .row = 0, .col = 0 }, true);

    var cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expect(cache.dirty_rows.items[0]);

    session.selectRange(.{ .row = 0, .col = 0 }, .{ .row = 0, .col = 0 }, true);

    cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expect(cache.generation != session.presentedGeneration());
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
}

test "eraseDisplay cursor-to-end keeps partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    for (session.primary.grid.cells.items, 0..) |*cell, idx| {
        cell.* = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(idx % 4));
    }
    session.primary.setCursor(1, 1);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.eraseDisplay(0);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.end_row);
}

test "eraseDisplay start-to-cursor keeps partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    for (session.primary.grid.cells.items, 0..) |*cell, idx| {
        cell.* = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(idx % 4));
    }
    session.primary.setCursor(1, 2);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.eraseDisplay(1);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
}

test "eraseDisplay full keeps full-width partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    for (session.primary.grid.cells.items, 0..) |*cell, idx| {
        cell.* = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(idx % 4));
    }

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.eraseDisplay(2);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
}

test "screen clear stays on partial path" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    for (session.primary.grid.cells.items, 0..) |*cell, idx| {
        cell.* = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(idx % 4));
    }

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.activeScreen().clear();
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
}

test "selection plain text export is terminal-owned across history and grid" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var history_row = [_]Cell{ base, base, base, base };
    history_row[0].codepoint = 'A';
    history_row[1].codepoint = 'B';
    session.history.pushRow(&history_row, false, base);

    session.primary.grid.cells.items[0] = base;
    session.primary.grid.cells.items[1] = base;
    session.primary.grid.cells.items[2] = base;
    session.primary.grid.cells.items[3] = base;
    session.primary.grid.cells.items[0].codepoint = 'C';
    session.primary.grid.cells.items[1].codepoint = 'D';

    session.startSelection(0, 1);
    session.updateSelection(1, 1);
    session.finishSelection();

    const text_opt = try session.selectionPlainTextAlloc(allocator);
    try std.testing.expect(text_opt != null);
    const text = text_opt.?;
    defer allocator.free(text);

    try std.testing.expectEqualStrings("B\nCD", text);
}

test "selectRangeLocked applies and finishes selection in one backend step" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    session.lock();
    session.selectRangeLocked(.{ .row = 0, .col = 1 }, .{ .row = 1, .col = 2 }, true);
    session.unlock();

    const selection = session.selectionState().?;
    try std.testing.expect(selection.active);
    try std.testing.expect(!selection.selecting);
    try std.testing.expectEqual(@as(usize, 0), selection.start.row);
    try std.testing.expectEqual(@as(usize, 1), selection.start.col);
    try std.testing.expectEqual(@as(usize, 1), selection.end.row);
    try std.testing.expectEqual(@as(usize, 2), selection.end.col);
}

test "selection helper clears and finishes only when active" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    session.lock();
    try std.testing.expect(!session.clearSelectionIfActiveLocked());
    try std.testing.expect(!session.finishSelectionIfActiveLocked());

    session.selectCellLocked(.{ .row = 0, .col = 1 }, false);
    try std.testing.expect(session.clearSelectionIfActiveLocked());
    try std.testing.expect(session.selectionState() == null);

    session.selectCellLocked(.{ .row = 1, .col = 0 }, false);
    try std.testing.expect(session.finishSelectionIfActiveLocked());
    session.unlock();

    const selection = session.selectionState().?;
    try std.testing.expect(selection.active);
    try std.testing.expect(!selection.selecting);
}

test "selection drag helpers update ordered ranges and late-start cells" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    session.lock();
    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[1].codepoint = 'X';

    try std.testing.expect(!session.selectOrUpdateCellInRowLocked(&[_]Cell{ base, base }, 0, 0));
    try std.testing.expect(session.selectOrUpdateCellInRowLocked(&row, 1, 1));
    var selection = session.selectionState().?;
    try std.testing.expectEqual(@as(usize, 1), selection.start.row);
    try std.testing.expectEqual(@as(usize, 1), selection.start.col);
    try std.testing.expectEqual(@as(usize, 1), selection.end.row);
    try std.testing.expectEqual(@as(usize, 1), selection.end.col);

    try std.testing.expect(session.selectOrderedRangeLocked(
        .{ .row = 1, .col = 0 },
        .{ .row = 1, .col = 1 },
        .{ .row = 0, .col = 0 },
        .{ .row = 0, .col = 1 },
        false,
    ));
    session.unlock();

    selection = session.selectionState().?;
    try std.testing.expectEqual(@as(usize, 0), selection.start.row);
    try std.testing.expectEqual(@as(usize, 0), selection.start.col);
    try std.testing.expectEqual(@as(usize, 1), selection.end.row);
    try std.testing.expectEqual(@as(usize, 1), selection.end.col);
}

test "click selection helpers own word and line gesture policy" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base, base, base };
    row[0].codepoint = 'f';
    row[1].codepoint = 'o';
    row[2].codepoint = 'o';
    row[3].codepoint = '!';

    session.lock();
    const word_click = session.beginClickSelectionLocked(&row, 3, 1, 2);
    try std.testing.expect(word_click.started);
    try std.testing.expectEqual(.word, word_click.gesture.mode);
    try std.testing.expectEqual(@as(usize, 3), word_click.gesture.row);
    try std.testing.expectEqual(@as(usize, 0), word_click.gesture.col_start);
    try std.testing.expectEqual(@as(usize, 2), word_click.gesture.col_end);

    try std.testing.expect(session.extendGestureSelectionLocked(word_click.gesture, &row, 4, 3));
    var selection = session.selectionState().?;
    try std.testing.expectEqual(@as(usize, 3), selection.start.row);
    try std.testing.expectEqual(@as(usize, 0), selection.start.col);
    try std.testing.expectEqual(@as(usize, 4), selection.end.row);
    try std.testing.expectEqual(@as(usize, 3), selection.end.col);

    session.clearSelectionLocked();
    const line_click = session.beginClickSelectionLocked(&row, 5, 2, 3);
    try std.testing.expect(line_click.started);
    try std.testing.expectEqual(.line, line_click.gesture.mode);
    try std.testing.expectEqual(@as(usize, 5), line_click.gesture.row);
    try std.testing.expectEqual(@as(usize, 3), line_click.gesture.col_end);
    session.unlock();

    selection = session.selectionState().?;
    try std.testing.expectEqual(@as(usize, 5), selection.start.row);
    try std.testing.expectEqual(@as(usize, 0), selection.start.col);
    try std.testing.expectEqual(@as(usize, 5), selection.end.row);
    try std.testing.expectEqual(@as(usize, 3), selection.end.col);
}

test "resetToLiveBottomLocked resets scrollback offset only when needed" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[0].codepoint = 'A';
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, session.primary.defaultCell());
    session.history.setScrollOffset(session.primary.grid.rows, 1);

    session.lock();
    try std.testing.expect(session.resetToLiveBottomLocked());
    try std.testing.expectEqual(@as(usize, 0), session.history.scrollOffset());
    try std.testing.expect(!session.resetToLiveBottomLocked());
    session.unlock();
}

test "scrollSelectionDragLocked scrolls history view in drag direction" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[0].codepoint = 'A';
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, session.primary.defaultCell());
    session.history.setScrollOffset(session.primary.grid.rows, 1);

    session.lock();
    try std.testing.expect(session.scrollSelectionDragLocked(false));
    try std.testing.expectEqual(@as(usize, 0), session.history.scrollOffset());
    try std.testing.expect(session.scrollSelectionDragLocked(true));
    try std.testing.expectEqual(@as(usize, 1), session.history.scrollOffset());
    session.unlock();
}

test "setScrollOffsetFromNormalizedTrackLocked maps scrollbar track ratio to history offset" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[0].codepoint = 'A';
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, session.primary.defaultCell());

    session.lock();
    try std.testing.expectEqual(@as(?usize, 3), session.setScrollOffsetFromNormalizedTrackLocked(0.0));
    try std.testing.expectEqual(@as(usize, 3), session.history.scrollOffset());
    try std.testing.expectEqual(@as(?usize, 0), session.setScrollOffsetFromNormalizedTrackLocked(1.0));
    try std.testing.expectEqual(@as(usize, 0), session.history.scrollOffset());
    session.unlock();
}

test "scrollWheelLocked applies backend wheel policy" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[0].codepoint = 'A';
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, session.primary.defaultCell());

    session.lock();
    try std.testing.expect(session.scrollWheelLocked(1));
    try std.testing.expectEqual(@as(usize, 3), session.history.scrollOffset());
    try std.testing.expect(session.scrollWheelLocked(-1));
    try std.testing.expectEqual(@as(usize, 0), session.history.scrollOffset());
    try std.testing.expect(!session.scrollWheelLocked(0));
    session.unlock();
}

test "scrollback plain text export is terminal-owned" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var history_row = [_]Cell{ base, base, base, base };
    history_row[0].codepoint = 'A';
    history_row[1].codepoint = 'B';
    session.history.pushRow(&history_row, false, base);

    session.primary.grid.cells.items[0] = base;
    session.primary.grid.cells.items[1] = base;
    session.primary.grid.cells.items[2] = base;
    session.primary.grid.cells.items[3] = base;
    session.primary.grid.cells.items[4] = base;
    session.primary.grid.cells.items[5] = base;
    session.primary.grid.cells.items[6] = base;
    session.primary.grid.cells.items[7] = base;
    session.primary.grid.cells.items[0].codepoint = 'C';
    session.primary.grid.cells.items[1].codepoint = 'D';
    session.primary.grid.cells.items[4].codepoint = 'E';
    session.primary.grid.cells.items[5].codepoint = 'F';

    const text = try session.scrollbackPlainTextAlloc(allocator);
    defer allocator.free(text);

    try std.testing.expectEqualStrings("AB\nCD\nEF\n", text);
}

test "scrollback ansi text export is terminal-owned" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 1, 1);
    defer session.deinit();

    var cell = session.primary.defaultCell();
    cell.codepoint = 'A';
    session.primary.grid.cells.items[0] = cell;

    const text = try session.scrollbackAnsiTextAlloc(allocator);
    defer allocator.free(text);

    const expected = try std.fmt.allocPrint(
        allocator,
        "\x1b[0;38;2;{d};{d};{d};48;2;{d};{d};{d};58;2;{d};{d};{d}mA\x1b[0m\n",
        .{
            cell.attrs.fg.r,
            cell.attrs.fg.g,
            cell.attrs.fg.b,
            cell.attrs.bg.r,
            cell.attrs.bg.g,
            cell.attrs.bg.b,
            cell.attrs.underline_color.r,
            cell.attrs.underline_color.g,
            cell.attrs.underline_color.b,
        },
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, text);
}

test "scrollback range export is terminal-owned" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 3);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row0 = [_]Cell{ base, base, base };
    var row1 = [_]Cell{ base, base, base };
    row0[0].codepoint = 'A';
    row0[1].codepoint = 'B';
    row1[0].codepoint = 'C';
    row1[1].codepoint = 'D';
    session.history.pushRow(&row0, false, base);
    session.history.pushRow(&row1, false, base);

    var cells = std.ArrayList(Cell).empty;
    defer cells.deinit(allocator);
    const range = try session.copyScrollbackRange(allocator, 0, 0, &cells);

    try std.testing.expectEqual(@as(usize, 2), range.total_rows);
    try std.testing.expectEqual(@as(usize, 2), range.row_count);
    try std.testing.expectEqual(@as(usize, 3), range.cols);
    try std.testing.expectEqual(@as(usize, 6), cells.items.len);
    try std.testing.expectEqual(@as(u32, 'A'), cells.items[0].codepoint);
    try std.testing.expectEqual(@as(u32, 'B'), cells.items[1].codepoint);
    try std.testing.expectEqual(@as(u32, 'C'), cells.items[3].codepoint);
    try std.testing.expectEqual(@as(u32, 'D'), cells.items[4].codepoint);
}

test "terminal reset republishes input snapshot state" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    session.setKeypadMode(true);
    session.setAppCursorKeys(true);
    try std.testing.expect(session.appKeypadEnabled());
    try std.testing.expect(session.input_snapshot.app_cursor_keys.load(.acquire));

    session.resetState();

    try std.testing.expect(!session.appKeypadEnabled());
    try std.testing.expect(!session.input_snapshot.app_cursor_keys.load(.acquire));
}

test "feedOutputBytes publishes keypad mode through locked parser path" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    session.feedOutputBytes("\x1b=");
    try std.testing.expect(session.appKeypadEnabled());

    session.feedOutputBytes("\x1b>");
    try std.testing.expect(!session.appKeypadEnabled());
}

test "feedOutputBytes publishes kitty key mode flags through locked parser path" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    session.feedOutputBytes("\x1b[>13u");
    try std.testing.expectEqual(@as(u32, 13), session.keyModeFlagsValue());

    session.feedOutputBytes("\x1b[<1u");
    try std.testing.expectEqual(@as(u32, 0), session.keyModeFlagsValue());
}

test "feedOutputBytes RIS resets input modes and clears screen" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    session.feedOutputBytes(
        "\x1b[?1004h" ++
            "\x1b[?2004h" ++
            "\x1b[?1002h" ++
            "\x1b[?1006h" ++
            "\x1b[?1016h" ++
            "\x1b[?1h" ++
            "\x1b=" ++
            "AB",
    );

    try std.testing.expect(session.focusReportingEnabled());
    try std.testing.expect(session.bracketedPasteEnabled());
    try std.testing.expect(session.mouseReportingEnabled());
    try std.testing.expect(session.mouseModeSgrPixelsEnabled());
    try std.testing.expect(session.appCursorKeysEnabled());
    try std.testing.expect(session.appKeypadEnabled());
    try std.testing.expectEqual(@as(u32, 'A'), session.getCell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u32, 'B'), session.getCell(0, 1).codepoint);

    session.feedOutputBytes("\x1bc");

    try std.testing.expect(!session.focusReportingEnabled());
    try std.testing.expect(!session.bracketedPasteEnabled());
    try std.testing.expect(!session.mouseReportingEnabled());
    try std.testing.expect(!session.mouseModeSgrPixelsEnabled());
    try std.testing.expect(!session.appCursorKeysEnabled());
    try std.testing.expect(!session.appKeypadEnabled());
    try std.testing.expectEqual(@as(u32, 0), session.getCell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u32, 0), session.getCell(0, 1).codepoint);
}
