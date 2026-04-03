const std = @import("std");
const builtin = @import("builtin");
const snapshot_mod = @import("publication/snapshot.zig");
const render_cache = @import("publication/render_cache.zig");
const terminal_publication = @import("publication/terminal_publication.zig");
const publication_flow = @import("publication/publication_flow.zig");
const sync_updates = @import("protocol/sync_updates.zig");
const terminal_core_feed = @import("protocol/terminal_core_feed.zig");
const terminal_core_protocol = @import("protocol/terminal_core_protocol.zig");
const input_modes = @import("input_modes.zig");
const session_config = @import("session/config.zig");
const session_interaction = @import("session/interaction.zig");
const mode_effects = @import("session/mode_effects.zig");
const scrollback_view = @import("scrollback_view.zig");
const session_input = @import("session/input.zig");
const terminal_selection = @import("selection.zig");
const host_queries = @import("session/host_queries.zig");
const session_runtime = @import("session/runtime.zig");
const scrolling = @import("scrolling.zig");
const host_types = @import("session/host_types.zig");
const types = @import("../model/types.zig");
const runtime_mod = @import("terminal_runtime.zig");
const terminal_transport = @import("runtime/terminal_transport.zig");
const pty_mod = @import("../io/pty.zig");

const TerminalRuntimeShell = runtime_mod.TerminalRuntimeShell;
const Cell = types.Cell;
const Color = types.Color;
const Dirty = render_cache.Dirty;
const VTERM_KEY_ENTER = runtime_mod.VTERM_KEY_ENTER;
const VTERM_MOD_NONE = runtime_mod.VTERM_MOD_NONE;
const Pty = pty_mod.Pty;

fn expectSnapshotRow(snapshot: snapshot_mod.TerminalSnapshot, row: usize, expected: []const u8) !void {
    const cells = snapshot.rowSlice(row);
    try std.testing.expectEqual(expected.len, cells.len);
    for (cells, expected) |cell, ch| {
        try std.testing.expectEqual(@as(u32, ch), cell.codepoint);
    }
}

fn snapshotContainsAscii(snapshot: snapshot_mod.TerminalSnapshot, needle: []const u8) bool {
    var row: usize = 0;
    while (row < snapshot.rows) : (row += 1) {
        const cells = snapshot.rowSlice(row);
        var line: [512]u8 = [_]u8{0} ** 512;
        var len: usize = 0;
        for (cells) |cell| {
            const cp = cell.codepoint;
            const ch: u8 = if (cp == 0 or cp > 0x7f) ' ' else @intCast(cp);
            if (len < line.len) {
                line[len] = ch;
                len += 1;
            }
        }
        if (std.mem.indexOf(u8, line[0..len], needle) != null) return true;
    }
    return false;
}

test "external transport poll updates screen and metadata" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 12);
    defer session.deinit();
    session_runtime.attachExternalTransport(session);

    try std.testing.expect(host_queries.isAlive(session));

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b]0;ext-title\x07hello\r\n"));
    try session_runtime.poll(session);

    const snapshot = terminal_publication.snapshot(session);
    try std.testing.expectEqualStrings("ext-title", snapshot.title);
    try expectSnapshotRow(snapshot, 0, "hello       ");

    var title_buf = std.ArrayList(u8).empty;
    defer title_buf.deinit(allocator);
    var cwd_buf = std.ArrayList(u8).empty;
    defer cwd_buf.deinit(allocator);
    const metadata = try host_queries.copyMetadata(session, allocator, &title_buf, &cwd_buf);
    try std.testing.expect(metadata.alive);
    try std.testing.expectEqualStrings("ext-title", metadata.title);
}

test "external transport close updates alive metadata" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 12);
    defer session.deinit();
    session_runtime.attachExternalTransport(session);

    try std.testing.expect(host_queries.isAlive(session));
    try std.testing.expect(session_runtime.closeExternalTransport(session));
    try std.testing.expect(!host_queries.isAlive(session));

    var title_buf = std.ArrayList(u8).empty;
    defer title_buf.deinit(allocator);
    var cwd_buf = std.ArrayList(u8).empty;
    defer cwd_buf.deinit(allocator);
    const metadata = try host_queries.copyMetadata(session, allocator, &title_buf, &cwd_buf);
    try std.testing.expect(!metadata.alive);
}

test "external transport sendText queues outbound bytes" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 12);
    defer session.deinit();
    session_runtime.attachExternalTransport(session);

    try session_input.sendText(session, "abc");
    const bytes = (try session_runtime.takeExternalOutgoingBytes(session, allocator)).?;
    defer allocator.free(bytes);

    try std.testing.expectEqualStrings("abc", bytes);
}

test "resizeWithCellSize uses current cell metrics for in-band resize report" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 12);
    defer session.deinit();
    session_runtime.attachExternalTransport(session);
    session.session.interaction.host_contract.inband_resize_notifications_2048 = true;

    try session_runtime.resizeWithCellSize(session, 3, 4, 8, 16);

    const bytes = (try session_runtime.takeExternalOutgoingBytes(session, allocator)).?;
    defer allocator.free(bytes);
    try std.testing.expectEqualStrings("\x1b[48;3;4;48;32t", bytes);
}

test "alt screen core helpers preserve cursor save restore behavior" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 3, 8);
    defer session.deinit();

    session.primary.setCursor(2, 3);
    mode_effects.enterAltScreen(session, true, true);
    try std.testing.expect(session.core.isAltActive());
    try std.testing.expectEqual(@as(usize, 0), session.core.activeScreen().cursor.row);
    try std.testing.expectEqual(@as(usize, 0), session.core.activeScreen().cursor.col);

    session.core.activeScreen().setCursor(1, 1);
    mode_effects.exitAltScreen(session, true);
    try std.testing.expect(!session.core.isAltActive());
    try std.testing.expectEqual(@as(usize, 2), session.core.activeScreen().cursor.row);
    try std.testing.expectEqual(@as(usize, 3), session.core.activeScreen().cursor.col);
}

test "full-region scroll publishes partial cache damage at live bottom" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 3, 4);
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

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    scrolling.scrollUp(session);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(i32, 1), cache.viewport_shift_rows);
    try std.testing.expect(cache.viewport_shift_exposed_only);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
    try std.testing.expectEqual(@as(usize, 1), session.core.scrollbackInfo().total_rows);
}

test "pty-backed session sendText writes through session writer boundary" {
    if (builtin.target.os.tag == .windows) return;

    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 8);
    defer session.deinit();

    var pty = Pty.init(
        allocator,
        .{
            .rows = 2,
            .cols = 8,
            .cell_width = 8,
            .cell_height = 16,
        },
        "/bin/cat",
    ) catch |err| switch (err) {
        error.OpenPtyFailed => return,
        else => return err,
    };
    session_runtime.attachPtyTransport(session, pty);

    try session_input.sendText(session, "abc");

    const start_ms = std.time.milliTimestamp();
    while (std.time.milliTimestamp() - start_ms < 3000) {
        try session_runtime.poll(session);
        const snapshot = terminal_publication.snapshot(session);
        if (snapshot.rowSlice(0).len >= 3 and
            snapshot.rowSlice(0)[0].codepoint == 'a' and
            snapshot.rowSlice(0)[1].codepoint == 'b' and
            snapshot.rowSlice(0)[2].codepoint == 'c')
        {
            return;
        }
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }

    try expectSnapshotRow(terminal_publication.snapshot(session), 0, "abc     ");
}

test "pty-backed session sendKey enter writes through session writer boundary" {
    if (builtin.target.os.tag == .windows) return;

    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 4, 16);
    defer session.deinit();

    var pty = Pty.init(
        allocator,
        .{
            .rows = 4,
            .cols = 16,
            .cell_width = 8,
            .cell_height = 16,
        },
        "/bin/sh",
    ) catch |err| switch (err) {
        error.OpenPtyFailed => return,
        else => return err,
    };
    session_runtime.attachPtyTransport(session, pty);

    try session_input.sendText(session, "printf hi; exit");
    try session_input.sendKey(session, VTERM_KEY_ENTER, VTERM_MOD_NONE);

    const start_ms = std.time.milliTimestamp();
    while (std.time.milliTimestamp() - start_ms < 4000) {
        try session_runtime.poll(session);
        const snapshot = terminal_publication.snapshot(session);
        if (snapshotContainsAscii(snapshot, "hi")) return;
        if (!host_queries.isAlive(session)) break;
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }

    try std.testing.expect(snapshotContainsAscii(terminal_publication.snapshot(session), "hi"));
}

test "top-anchored partial scroll region retires rows into scrollback" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 6, 4);
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

    terminal_core_feed.feedOutputBytes(session, "\x1b[1;3r");
    terminal_core_protocol.scrollRegionUpWithOrigin(session, 1, "test.top_anchored_scroll_region");

    try std.testing.expectEqual(@as(usize, 1), session.core.scrollbackInfo().total_rows);
    const history_row = session.scrollbackRow(0) orelse return error.TestExpectedEqual;
    try std.testing.expectEqual(@as(usize, 4), history_row.len);
    for (history_row) |cell| {
        try std.testing.expectEqual(@as(u32, 'A'), cell.codepoint);
    }

    const snapshot = terminal_publication.snapshot(session);
    try expectSnapshotRow(snapshot, 0, "BBBB");
    try expectSnapshotRow(snapshot, 1, "CCCC");
}

test "feedOutputBytes keeps incremental damage after baseline publish" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 1, 4);
    defer session.deinit();

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    terminal_core_feed.feedOutputBytes(session, "A");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
}

test "carriage return plus erase line rewrites current row in place" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 4, 20);
    defer session.deinit();

    terminal_core_feed.feedOutputBytes(session, "hello");
    terminal_core_feed.feedOutputBytes(session, "\r\x1b[2Kbye");

    try std.testing.expectEqual(@as(usize, 0), session.core.scrollbackInfo().total_rows);
    const snapshot = terminal_publication.snapshot(session);
    try expectSnapshotRow(snapshot, 0, "bye                 ");

    terminal_core_feed.feedOutputBytes(session, "\r\x1b[2Kstep 1");
    terminal_core_feed.feedOutputBytes(session, "\r\x1b[2Kstep 2");

    try std.testing.expectEqual(@as(usize, 0), session.core.scrollbackInfo().total_rows);
    try expectSnapshotRow(terminal_publication.snapshot(session), 0, "step 2              ");
}

test "zig progress redraw pattern rewrites block instead of appending" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 6, 20);
    defer session.deinit();

    debugSetCursor(&session, 4, 0);

    terminal_core_feed.feedOutputBytes(session, "\x1b[Jbuild one\nitem a\n\r\x1bM\x1bM");
    terminal_core_feed.feedOutputBytes(session, "\x1b[Jbuild two\nitem b\n\r\x1bM\x1bM");

    const snapshot = terminal_publication.snapshot(session);
    try std.testing.expectEqual(@as(usize, 0), snapshot.scrollback_count);
    try expectSnapshotRow(snapshot, 2, "build two           ");
    try expectSnapshotRow(snapshot, 3, "item b              ");
}

test "zig progress redraw invalidates cleared tail rows" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 6, 20);
    defer session.deinit();

    debugSetCursor(&session, 4, 0);
    terminal_core_feed.feedOutputBytes(session, "\x1b[Jbuild one\nitem a\n\r\x1bM\x1bM");

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    terminal_core_feed.feedOutputBytes(session, "\x1b[Jbuild two\nitem b\n\r\x1bM\x1bM");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 5), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 19), cache.damage.end_col);
}

test "bottom-edge in-place redraw keeps blank separator rows dirty" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 68, 24);
    defer session.deinit();

    debugSetCursor(&session, 67, 0);

    terminal_core_feed.feedOutputBytes(session, "\x1b[?2026h");
    try std.testing.expect(sync_updates.active(session));

    terminal_core_feed.feedOutputBytes(session, "\x1b[Jfirst row\nsecond row\nthird row\nfourth row\r\x1bM\x1bM\x1bM\x1bM");

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    terminal_core_feed.feedOutputBytes(session, "\x1b[Jfull line\n\nnext header\n\n\r\x1bM\x1bM\x1bM\x1bM");

    const snapshot = terminal_publication.snapshot(session);
    try std.testing.expectEqual(@as(usize, 0), snapshot.scrollback_count);
    try expectSnapshotRow(snapshot, 64, "full line               ");
    try expectSnapshotRow(snapshot, 65, "                        ");
    try expectSnapshotRow(snapshot, 66, "next header             ");
    try expectSnapshotRow(snapshot, 67, "                        ");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 64), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 67), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 23), cache.damage.end_col);
    try std.testing.expect(cache.dirty_rows.items[64]);
    try std.testing.expect(cache.dirty_rows.items[65]);
    try std.testing.expect(cache.dirty_rows.items[66]);
    try std.testing.expect(cache.dirty_rows.items[67]);
}

test "synchronized zig progress redraw does not retire intermediate scrollback" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 68, 20);
    defer session.deinit();

    debugSetCursor(&session, 67, 0);

    terminal_core_feed.feedOutputBytes(session, "\x1b[?2026h");
    try std.testing.expect(sync_updates.active(session));

    terminal_core_feed.feedOutputBytes(session, "\x1b[Jbuild one\nitem a\n\r\x1bM\x1bM");
    terminal_core_feed.feedOutputBytes(session, "\x1b[Jbuild two\nitem b\n\r\x1bM\x1bM");

    try std.testing.expectEqual(@as(usize, 0), session.core.scrollbackInfo().total_rows);

    terminal_core_feed.feedOutputBytes(session, "\x1b[?2026l");
    try std.testing.expect(!sync_updates.active(session));

    const snapshot = terminal_publication.snapshot(session);
    try std.testing.expectEqual(@as(usize, 0), snapshot.scrollback_count);
    try expectSnapshotRow(snapshot, 65, "build two           ");
    try expectSnapshotRow(snapshot, 66, "item b              ");
}

test "synchronized top-anchored partial scroll region retires rows into scrollback" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 6, 4);
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

    terminal_core_feed.feedOutputBytes(session, "\x1b[?2026h");
    try std.testing.expect(sync_updates.active(session));

    terminal_core_feed.feedOutputBytes(session, "\x1b[1;3r");
    terminal_core_protocol.scrollRegionUpWithOrigin(session, 1, "test.sync_top_anchored_scroll_region");

    try std.testing.expectEqual(@as(usize, 1), session.core.scrollbackInfo().total_rows);
    const history_row = session.scrollbackRow(0) orelse return error.TestExpectedEqual;
    try std.testing.expectEqual(@as(usize, 4), history_row.len);
    for (history_row) |cell| {
        try std.testing.expectEqual(@as(u32, 'A'), cell.codepoint);
    }

    const snapshot = terminal_publication.snapshot(session);
    try expectSnapshotRow(snapshot, 0, "BBBB");
    try expectSnapshotRow(snapshot, 1, "CCCC");
}

test "single-chunk synchronized progress sequence keeps newline scroll inside sync window" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 68, 20);
    defer session.deinit();

    debugSetCursor(&session, 67, 0);
    terminal_core_feed.feedOutputBytes(session, "\x1b[?2026h\x1b[Jbuild one\nitem a\r\x1bM\x1b[?2026l");

    try std.testing.expectEqual(@as(usize, 0), session.core.scrollbackInfo().total_rows);
    try std.testing.expect(!sync_updates.active(session));

    const snapshot = terminal_publication.snapshot(session);
    try std.testing.expectEqual(@as(usize, 0), snapshot.scrollback_count);
    try expectSnapshotRow(snapshot, 66, "build one           ");
    try expectSnapshotRow(snapshot, 67, "item a              ");
}

test "reverse index moves cursor up inside scroll region" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 6, 8);
    defer session.deinit();

    debugSetCursor(&session, 4, 2);
    terminal_core_feed.feedOutputBytes(session, "\x1bM");

    const cursor = terminal_core_protocol.getCursorPos(session);
    try std.testing.expectEqual(@as(usize, 3), cursor.row);
    try std.testing.expectEqual(@as(usize, 2), cursor.col);
}

test "real zig redraw chunk rewrites in place at bottom edge" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 68, 80);
    defer session.deinit();

    debugSetCursor(&session, 67, 0);
    terminal_core_feed.feedOutputBytes(
        session,
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

    try std.testing.expectEqual(@as(usize, 0), session.core.scrollbackInfo().total_rows);
    try std.testing.expect(!sync_updates.active(session));

    const snapshot = terminal_publication.snapshot(session);
    try expectSnapshotRow(snapshot, 63, "[3] Compile Build Script                                                         ");
    try expectSnapshotRow(snapshot, 64, "qq [1137/5878] Linking                                                           ");
    try expectSnapshotRow(snapshot, 65, "qq [1133/1376] Code Generation                                                   ");
    try expectSnapshotRow(snapshot, 66, "q  [7017] Semantic Analysis                                                      ");
    try expectSnapshotRow(snapshot, 67, "   q  Target.powerpc.all_features                                                ");
}

test "osc 9;4 progress reports update structured host progress state" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 4, 20);
    defer session.deinit();

    terminal_core_feed.feedOutputBytes(session, "\x1b]9;4;1;42\x07");
    var activity = host_queries.currentActivityMetadata(session);
    try std.testing.expectEqual(host_types.ProgressState.set, activity.progress.state);
    try std.testing.expectEqual(@as(?u8, 42), activity.progress.value);

    terminal_core_feed.feedOutputBytes(session, "\x1b]9;4;3\x07");
    activity = host_queries.currentActivityMetadata(session);
    try std.testing.expectEqual(host_types.ProgressState.indeterminate, activity.progress.state);
    try std.testing.expectEqual(@as(?u8, null), activity.progress.value);

    terminal_core_feed.feedOutputBytes(session, "\x1b]9;4;0\x07");
    activity = host_queries.currentActivityMetadata(session);
    try std.testing.expectEqual(host_types.ProgressState.none, activity.progress.state);
    try std.testing.expectEqual(@as(?u8, null), activity.progress.value);
}

test "repeat guide chunks do not grow scrollback unexpectedly" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 4, 10);
    defer session.deinit();
    session_runtime.attachExternalTransport(session);

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[H1| |aaa \x1b[2;1H2| |bbb \x1b[3;1H3| |ccc \x1b[4;1H4| |ddd "));
    try session_runtime.poll(session);
    try std.testing.expectEqual(@as(usize, 0), session.core.scrollbackInfo().total_rows);

    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[H5\x1b[2;1H+>"));
    try session_runtime.poll(session);
    try std.testing.expectEqual(@as(usize, 0), session.core.scrollbackInfo().total_rows);

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[1;4H|\x1b[2;4H|"));
    try session_runtime.poll(session);

    try std.testing.expectEqual(@as(usize, 0), session.core.scrollbackInfo().total_rows);

    const snapshot = session.snapshot();
    try expectSnapshotRow(snapshot, 0, "5| |aaa   ");
    try expectSnapshotRow(snapshot, 1, "+> |bbb   ");
    try expectSnapshotRow(snapshot, 2, "3| |ccc   ");
    try expectSnapshotRow(snapshot, 3, "4| |ddd   ");
}

test "repeat guide chunks publish current broad cache contract" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 4, 10);
    defer session.deinit();
    session_runtime.attachExternalTransport(session);

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[H1| |aaa \x1b[2;1H2| |bbb \x1b[3;1H3| |ccc \x1b[4;1H4| |ddd "));
    try session_runtime.poll(session);
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[H5\x1b[2;1H+>"));
    try session_runtime.poll(session);

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[1;4H|\x1b[2;4H|"));
    try session_runtime.poll(session);

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 9), cache.damage.end_col);
}

test "first repeat guide packet keeps bottom row clean today" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 4, 10);
    defer session.deinit();
    session_runtime.attachExternalTransport(session);

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[H1| |aaa \x1b[2;1H2| |bbb \x1b[3;1H3| |ccc \x1b[4;1H4| |ddd "));
    try session_runtime.poll(session);
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[H5\x1b[2;1H+>"));
    try session_runtime.poll(session);

    const cache = terminal_publication.renderCache(session);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
    try std.testing.expect(!cache.dirty_rows.items[2]);
    try std.testing.expect(!cache.dirty_rows.items[3]);
}

test "repeat guide chunks mark unexpected bottom row dirty today" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 4, 10);
    defer session.deinit();
    session_runtime.attachExternalTransport(session);

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[H1| |aaa \x1b[2;1H2| |bbb \x1b[3;1H3| |ccc \x1b[4;1H4| |ddd "));
    try session_runtime.poll(session);
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[H5\x1b[2;1H+>"));
    try session_runtime.poll(session);

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[1;4H|\x1b[2;4H|"));
    try session_runtime.poll(session);

    const cache = terminal_publication.renderCache(session);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
    try std.testing.expect(!cache.dirty_rows.items[2]);
    try std.testing.expect(cache.dirty_rows.items[3]);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_start.items[3]);
    try std.testing.expectEqual(@as(u16, 9), cache.dirty_cols_end.items[3]);
}

test "repeat guide second packet keeps raw screen bottom row clean" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 4, 10);
    defer session.deinit();
    session_runtime.attachExternalTransport(session);

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[H1| |aaa \x1b[2;1H2| |bbb \x1b[3;1H3| |ccc \x1b[4;1H4| |ddd "));
    try session_runtime.poll(session);
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[H5\x1b[2;1H+>"));
    try session_runtime.poll(session);

    try std.testing.expect(try session_runtime.enqueueExternalBytes(session, "\x1b[1;4H|\x1b[2;4H|"));
    try session_runtime.poll(session);

    const view = session.core.activeScreenConst().snapshotView();
    try std.testing.expect(view.dirty_rows[0]);
    try std.testing.expect(view.dirty_rows[1]);
    try std.testing.expect(!view.dirty_rows[2]);
    try std.testing.expect(!view.dirty_rows[3]);
}

test "manual repeat guide publication still dirties bottom row today" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 4, 10);
    defer session.deinit();

    session.debugFeedBytes("\x1b[H1| |aaa \x1b[2;1H2| |bbb \x1b[3;1H3| |ccc \x1b[4;1H4| |ddd ");
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    session.debugFeedBytes("\x1b[H5\x1b[2;1H+>");
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    session.debugFeedBytes("\x1b[1;4H|\x1b[2;4H|");
    const view = session.core.activeScreenConst().snapshotView();
    try std.testing.expect(view.dirty_rows[0]);
    try std.testing.expect(view.dirty_rows[1]);
    try std.testing.expect(!view.dirty_rows[2]);
    try std.testing.expect(!view.dirty_rows[3]);

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expect(cache.dirty_rows.items[3]);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_start.items[3]);
    try std.testing.expectEqual(@as(u16, 9), cache.dirty_cols_end.items[3]);
}

test "acknowledgePresentedGeneration derives sync dirty retirement from cache" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 1, 4);
    defer session.deinit();

    session.primary.markDirtyAllWithReason(.unknown, @src());
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    const normal_generation = terminal_publication.renderCache(session).generation;
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, normal_generation));
    try std.testing.expectEqual(Dirty.none, session.primary.grid.dirty);

    session.primary.markDirtyAllWithReason(.unknown, @src());
    sync_updates.set(session, true);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    const sync_generation = terminal_publication.renderCache(session).generation;
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, sync_generation));
    try std.testing.expectEqual(Dirty.full, session.primary.grid.dirty);
}

test "row hash refinement does not skip unpresented top rows" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 3, 4);
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

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    scrolling.scrollUp(session);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    scrolling.scrollUp(session);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expect(cache.dirty_rows.items[0]);
}

test "live-bottom history growth keeps blank exposed row dirty" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();

    // Start with a blank bottom row so the newly exposed row after scroll is
    // also blank. If the shift path incorrectly narrows blank exposed rows
    // against the previously presented cache, bottom-row damage would vanish.
    var col: usize = 0;
    while (col < 4) : (col += 1) {
        var cell_a = base;
        cell_a.codepoint = 'A';
        session.primary.grid.cells.items[col] = cell_a;

        var cell_b = base;
        cell_b.codepoint = 'B';
        session.primary.grid.cells.items[4 + col] = cell_b;

        session.primary.grid.cells.items[8 + col] = base;
    }
    session.primary.setCursor(2, 0);

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    scrolling.scrollUp(session);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(i32, 1), cache.viewport_shift_rows);
    try std.testing.expect(cache.viewport_shift_exposed_only);
    try std.testing.expect(cache.dirty_rows.items[2]);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
    try std.testing.expectEqual(@as(u32, 0), cache.cells.items[8].codepoint);
    try std.testing.expectEqual(@as(u32, 0), cache.cells.items[9].codepoint);
    try std.testing.expectEqual(@as(u32, 0), cache.cells.items[10].codepoint);
    try std.testing.expectEqual(@as(u32, 0), cache.cells.items[11].codepoint);
}

test "row hash refinement does not suppress newly dirty rows against unpresented cache" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
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

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    var cell = session.primary.grid.cells.items[0];
    cell.codepoint = 'Z';
    session.primary.grid.cells.items[0] = cell;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const unpresented_generation = terminal_publication.renderCache(session).generation;
    try std.testing.expect(unpresented_generation != terminal_publication.presentedGeneration(session));
    try std.testing.expectEqual(Dirty.partial, terminal_publication.renderCache(session).dirty);

    session.primary.clearDirty();
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expect(cache.generation != terminal_publication.presentedGeneration(session));
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
    try std.testing.expectEqual(@as(u32, 'Z'), cache.cells.items[0].codepoint);
}

test "snapshot view preserves disjoint same-row dirty spans" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 20);
    defer session.deinit();

    session.primary.clearDirty();
    session.primary.grid.markDirtyRangeWithOrigin("test.small_region", 0, 0, 2, 5);
    session.primary.grid.markDirtyRangeWithOrigin("test.body_rewrite", 0, 0, 10, 18);

    const view = session.core.activeScreenConst().snapshotView();
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 20);
    defer session.deinit();

    session.primary.clearDirty();
    session.primary.grid.markDirtyRangeWithOrigin("test.small_region", 0, 0, 2, 5);
    session.primary.grid.markDirtyRangeWithOrigin("test.body_rewrite", 0, 0, 10, 18);

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    sync_updates.set(session, true);

    const cache = terminal_publication.renderCache(session);
    try std.testing.expect(sync_updates.active(session));
    try std.testing.expectEqual(Dirty.none, cache.dirty);
    try std.testing.expectEqual(@as(u64, 0), cache.full_dirty_seq);
}

test "setSyncUpdates enable does not publish dirty screen state on presented generation" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    const baseline_generation = terminal_publication.renderCache(session).generation;
    var cell = session.primary.defaultCell();
    cell.codepoint = 'Z';
    session.primary.grid.cells.items[0] = cell;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);

    sync_updates.set(session, true);

    var cache = terminal_publication.renderCache(session);
    try std.testing.expect(sync_updates.active(session));
    try std.testing.expectEqual(baseline_generation, cache.generation);
    try std.testing.expectEqual(Dirty.none, cache.dirty);

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(baseline_generation + 1, cache.generation);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
}

test "setSyncUpdates disable stays clean when no buffered changes exist" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    sync_updates.set(session, true);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    sync_updates.set(session, false);

    const cache = terminal_publication.renderCache(session);
    try std.testing.expect(!sync_updates.active(session));
    try std.testing.expectEqual(Dirty.none, cache.dirty);
}

test "setSyncUpdates disable preserves buffered partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    sync_updates.set(session, true);

    var cell = session.primary.defaultCell();
    cell.codepoint = 'Z';
    session.primary.grid.cells.items[0] = cell;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    sync_updates.set(session, false);

    const cache = terminal_publication.renderCache(session);
    try std.testing.expect(!sync_updates.active(session));
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
}

test "visible history changes publish partial cache damage without force-full" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
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

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    const new_fg = Color{ .r = 0x11, .g = 0x22, .b = 0x33, .a = 0xff };
    session.history.updateDefaultColors(base.attrs.fg, base.attrs.bg, new_fg, base.attrs.bg);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expectEqual(new_fg, cache.cells.items[0].attrs.fg);
}

test "visible history changes without presented diff base stay partial" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
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

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    const new_fg = Color{ .r = 0x44, .g = 0x55, .b = 0x66, .a = 0xff };
    session.history.updateDefaultColors(base.attrs.fg, base.attrs.bg, new_fg, base.attrs.bg);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
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
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    scrollback_view.setScrollOffset(session, 1);

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(i32, 1), cache.viewport_shift_rows);
    try std.testing.expect(cache.viewport_shift_exposed_only);
    try std.testing.expect(!cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
}

test "scrollback offset change advances published generation" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    session.debugPushScrollbackRow("AAAA");
    session.debugPushScrollbackRow("BBBB");
    session.debugSetGridRow(0, "CCCC");
    session.debugSetGridRow(1, "DDDD");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    const baseline_generation = terminal_publication.renderCache(session).generation;
    scrollback_view.setScrollOffset(session, 1);

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(@as(usize, 1), cache.scroll_offset);
    try std.testing.expect(cache.generation != baseline_generation);
}

test "session snapshot reflects pinned scrollback viewport" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();
    session_runtime.attachExternalTransport(session);

    terminal_core_feed.feedOutputBytes(session, "AAAA\r\nBBBB\r\nCCCC\r\nDDDD\r\n");

    const live_snapshot = terminal_publication.snapshot(session);
    try expectSnapshotRow(live_snapshot, 0, "CCCC");
    try expectSnapshotRow(live_snapshot, 1, "DDDD");

    scrollback_view.setScrollOffset(session, 1);

    const pinned_snapshot = terminal_publication.snapshot(session);
    try expectSnapshotRow(pinned_snapshot, 0, "BBBB");
    try expectSnapshotRow(pinned_snapshot, 1, "CCCC");
}

test "acknowledgePresentedGeneration does not retire newer scrollback view publication" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    session.debugPushScrollbackRow("AAAA");
    session.debugPushScrollbackRow("BBBB");
    session.debugSetGridRow(0, "CCCC");
    session.debugSetGridRow(1, "DDDD");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    const baseline_generation = terminal_publication.renderCache(session).generation;
    scrollback_view.setScrollOffset(session, 1);

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expect(!terminal_publication.acknowledgePresentedGeneration(session, baseline_generation));
    try std.testing.expectEqual(Dirty.partial, terminal_publication.renderCache(session).dirty);
    try std.testing.expectEqual(@as(usize, 1), terminal_publication.renderCache(session).scroll_offset);
}

test "acknowledgePresentedGeneration does not retire newer normal publication" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    const baseline_generation = terminal_publication.renderCache(session).generation;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
    try std.testing.expect(!terminal_publication.acknowledgePresentedGeneration(session, baseline_generation));
    try std.testing.expectEqual(cache.generation - 1, terminal_publication.presentedGeneration(session));
    try std.testing.expectEqual(Dirty.partial, terminal_publication.renderCache(session).dirty);
    try std.testing.expectEqual(@as(usize, 0), terminal_publication.renderCache(session).damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), terminal_publication.renderCache(session).damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), terminal_publication.renderCache(session).damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), terminal_publication.renderCache(session).damage.end_col);
}

test "retired startup baseline allows first in-place overwrite to publish partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 1, 9);
    defer session.deinit();

    const base = session.primary.defaultCell();
    session.primary.clearDirty();
    session.alt.clearDirty();

    var col: usize = 0;
    while (col < 8) : (col += 1) {
        var cell = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(col));
        session.primary.grid.cells.items[col] = cell;
    }
    session.primary.grid.cells.items[8] = base;
    session.primary.grid.markDirtyRange(0, 0, 0, 7);

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    const baseline_generation = terminal_publication.renderCache(session).generation;
    try std.testing.expectEqual(Dirty.partial, terminal_publication.renderCache(session).dirty);
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, baseline_generation));
    try std.testing.expectEqual(Dirty.none, session.primary.grid.dirty);

    var overwrite_col: usize = 0;
    while (overwrite_col < 4) : (overwrite_col += 1) {
        var cell = session.primary.grid.cells.items[overwrite_col];
        cell.codepoint = @as(u32, 'W') + @as(u32, @intCast(overwrite_col));
        session.primary.grid.cells.items[overwrite_col] = cell;
    }
    session.primary.grid.markDirtyRange(0, 0, 0, 3);

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
    try std.testing.expect(cache.row_dirty_span_counts.items[0] >= 1);
    try std.testing.expectEqual(@as(u16, 0), cache.row_dirty_spans.items[0][0].start);
    try std.testing.expectEqual(@as(u16, 3), cache.row_dirty_spans.items[0][0].end);
}

test "unretired full baseline promotes first in-place overwrite to full damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 1, 9);
    defer session.deinit();

    const base = session.primary.defaultCell();
    session.primary.clearDirty();
    session.alt.clearDirty();

    var col: usize = 0;
    while (col < 8) : (col += 1) {
        var cell = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(col));
        session.primary.grid.cells.items[col] = cell;
    }
    session.primary.grid.cells.items[8] = base;
    session.primary.markDirtyAllWithReason(.resize_reflow, @src());

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    const baseline_generation = terminal_publication.renderCache(session).generation;
    terminal_publication.notePresentedGeneration(session, baseline_generation);
    try std.testing.expectEqual(Dirty.full, terminal_publication.renderCache(session).dirty);

    var overwrite_col: usize = 0;
    while (overwrite_col < 4) : (overwrite_col += 1) {
        var cell = session.primary.grid.cells.items[overwrite_col];
        cell.codepoint = @as(u32, 'W') + @as(u32, @intCast(overwrite_col));
        session.primary.grid.cells.items[overwrite_col] = cell;
    }
    session.primary.grid.markDirtyRange(0, 0, 0, 3);

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.full, cache.dirty);
    try std.testing.expectEqual(types.FullDirtyReason.resize_reflow, cache.full_dirty_reason);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 8), cache.damage.end_col);
}

test "clean publication does not overwrite unpresented dirty publication" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    var cell = session.primary.grid.cells.items[0];
    cell.codepoint = 'Z';
    session.primary.grid.cells.items[0] = cell;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const dirty_generation = terminal_publication.renderCache(session).generation;
    try std.testing.expectEqual(Dirty.partial, terminal_publication.renderCache(session).dirty);
    try std.testing.expectEqual(@as(u32, 'Z'), terminal_publication.renderCache(session).cells.items[0].codepoint);

    session.primary.clearDirty();
    session.alt.clearDirty();
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(dirty_generation + 1, cache.generation);
    try std.testing.expect(cache.generation != terminal_publication.presentedGeneration(session));
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    terminal_publication.notePresentedGeneration(session, 7);
    terminal_publication.notePresentedGeneration(session, 3);

    try std.testing.expectEqual(@as(u64, 7), terminal_publication.presentedGeneration(session));
}

test "cursor style updates publish through cache without texture invalidation" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    session.primary.cursor_style = .{ .shape = .bar, .blink = false };
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.none, cache.dirty);
    try std.testing.expectEqual(types.CursorStyle{ .shape = .bar, .blink = false }, cache.cursor_style);
}

test "kitty generation delta does not force full damage when cell damage is partial" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    session.kitty_primary.generation += 1;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
}

test "kitty generation delta without visible damage stays clean" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    session.kitty_primary.generation += 1;
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.none, cache.dirty);
}

test "kitty placement move stays dirty even when text cells are unchanged" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
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

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    session.kitty_primary.placements.items[0].row = 1;
    session.kitty_primary.placements.items[0].anchor_row = 1;
    session.kitty_primary.generation += 1;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    session.primary.grid.markDirtyRange(1, 1, 0, 0);

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    _ = session.clear_generation.fetchAdd(1, .acq_rel);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.none, cache.dirty);
}

test "default color remap stays on partial path" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    const old_attrs = session.primary.default_attrs;
    const new_fg = Color{ .r = 0xaa, .g = 0xbb, .b = 0xcc, .a = 0xff };
    session_config.setDefaultColors(session, new_fg, old_attrs.bg);

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 3), cache.dirty_cols_end.items[0]);
    try std.testing.expectEqual(new_fg, cache.cells.items[0].attrs.fg);
}

test "screen reverse toggle stays on partial path" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    session.core.activeScreen().setScreenReverse(true);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expect(cache.screen_reverse);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 3), cache.dirty_cols_end.items[0]);
}

test "visible history change narrows to projected diff against presented base" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
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

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    const history_row = session.history.scrollback.lineByIndexMut(0).?;
    history_row.cells[0].codepoint = 'Z';
    session.history.markScrollbackChanged();
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
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

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    const first_update = session.history.scrollback.lineByIndexMut(0).?;
    first_update.cells[0].codepoint = 'Z';
    session.history.markScrollbackChanged();
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const second_update = session.history.scrollback.lineByIndexMut(0).?;
    second_update.cells[1].codepoint = 'Y';
    session.history.markScrollbackChanged();
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
}

test "visible history change with blank separator rows stays conservative against unpresented base" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 4, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row_a = [_]Cell{ base, base, base, base };
    var row_b = [_]Cell{ base, base, base, base };
    var row_c = [_]Cell{ base, base, base, base };
    var row_d = [_]Cell{ base, base, base, base };
    for (&row_a, 0..) |*cell, col| cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(col));
    for (&row_b, 0..) |*cell, col| cell.codepoint = @as(u32, 'E') + @as(u32, @intCast(col));
    for (&row_c, 0..) |*cell, col| cell.codepoint = @as(u32, 'I') + @as(u32, @intCast(col));
    for (&row_d, 0..) |*cell, col| cell.codepoint = @as(u32, 'M') + @as(u32, @intCast(col));

    session.history.pushRow(&row_a, false, base);
    session.history.pushRow(&row_b, false, base);
    session.history.pushRow(&row_c, false, base);
    session.history.pushRow(&row_d, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, base);
    session.history.setScrollOffset(session.primary.grid.rows, 4);

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    const first_update = session.history.scrollback.lineByIndexMut(0).?;
    first_update.cells[0].codepoint = 'Z';
    session.history.markScrollbackChanged();
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const second_row = session.history.scrollback.lineByIndexMut(1).?;
    for (second_row.cells[0..4]) |*cell| cell.* = base;
    const fourth_row = session.history.scrollback.lineByIndexMut(3).?;
    for (fourth_row.cells[0..4]) |*cell| cell.* = base;
    session.history.markScrollbackChanged();
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
    try std.testing.expect(cache.dirty_rows.items[2]);
    try std.testing.expect(cache.dirty_rows.items[3]);
    try std.testing.expectEqual(@as(u32, 'Z'), cache.cells.items[0].codepoint);
    try std.testing.expectEqual(@as(u32, 0), cache.cells.items[4].codepoint);
    try std.testing.expectEqual(@as(u32, 'I'), cache.cells.items[8].codepoint);
    try std.testing.expectEqual(@as(u32, 0), cache.cells.items[12].codepoint);
}

test "debug scrollback helpers preserve visible-history baseline shape" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    session.debugPushScrollbackRow("ABCD");
    session.debugPushScrollbackRow("EFGH");
    session.debugSetScrollOffset(2);
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(@as(usize, 2), cache.history_len);
    try std.testing.expectEqual(@as(usize, 4), cache.totalLines());
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    session.debugPushScrollbackRow("ABCD");
    session.debugPushScrollbackRow("EFGH");
    session.debugSetScrollOffset(2);
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    session.debugSetScrollbackCell(0, 0, 'Z');

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(@as(usize, 2), cache.history_len);
    try std.testing.expectEqual(@as(usize, 4), cache.totalLines());
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    session.debugPushScrollbackRow("ABCD");
    session.debugPushScrollbackRow("EFGH");
    session.debugSetScrollOffset(2);
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    session.debugSetScrollbackCell(0, 0, 'Z');
    session.debugSetScrollbackCell(0, 1, 'Y');

    const cache = terminal_publication.renderCache(session);
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    session.debugSetCursor(1, 0);
    session.debugPushScrollbackRow("ABCD");
    session.debugPushScrollbackRow("EFGH");
    session.debugSetScrollOffset(2);
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    session.debugSetScrollbackCell(0, 0, 'Z');
    session.debugSetScrollbackCell(0, 1, 'Y');

    const cache = terminal_publication.renderCache(session);
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();
    session_runtime.attachExternalTransport(session);

    session.debugSetCursor(1, 0);
    session.debugPushScrollbackRow("ABCD");
    session.debugPushScrollbackRow("EFGH");
    session.debugSetScrollOffset(2);
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    session.debugSetScrollbackCell(0, 0, 'Z');
    session.debugSetScrollbackCell(0, 1, 'Y');

    const cache = terminal_publication.renderCache(session);
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var cell = base;
    cell.codepoint = 'A';
    session.primary.grid.cells.items[0] = cell;

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    terminal_selection.selectRange(session, .{ .row = 0, .col = 0 }, .{ .row = 0, .col = 0 }, true);

    var cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expect(cache.dirty_rows.items[0]);

    terminal_selection.selectRange(session, .{ .row = 0, .col = 0 }, .{ .row = 0, .col = 0 }, true);

    cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expect(cache.generation != terminal_publication.presentedGeneration(session));
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
}

test "eraseDisplay cursor-to-end keeps partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    for (session.primary.grid.cells.items, 0..) |*cell, idx| {
        cell.* = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(idx % 4));
    }
    session.primary.setCursor(1, 1);

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    terminal_core_protocol.eraseDisplay(session, 0);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.end_row);
}

test "eraseDisplay start-to-cursor keeps partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    for (session.primary.grid.cells.items, 0..) |*cell, idx| {
        cell.* = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(idx % 4));
    }
    session.primary.setCursor(1, 2);

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    terminal_core_protocol.eraseDisplay(session, 1);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
}

test "eraseDisplay full keeps full-width partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    for (session.primary.grid.cells.items, 0..) |*cell, idx| {
        cell.* = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(idx % 4));
    }

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    terminal_core_protocol.eraseDisplay(session, 2);
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
}

test "screen clear stays on partial path" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    for (session.primary.grid.cells.items, 0..) |*cell, idx| {
        cell.* = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(idx % 4));
    }

    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");
    terminal_publication.notePresentedGeneration(session, terminal_publication.renderCache(session).generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(terminal_publication.acknowledgePresentedGeneration(session, terminal_publication.renderCache(session).generation));

    session.core.activeScreen().clear();
    _ = publication_flow.bumpAndPublishCurrentViewLocked(session, "test_publication");

    const cache = terminal_publication.renderCache(session);
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
}

test "selection plain text export is terminal-owned across history and grid" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
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

    terminal_selection.startSelection(session, 0, 1);
    terminal_selection.updateSelection(session, 1, 1);
    terminal_selection.finishSelection(session);

    const text_opt = try session.core.selectionPlainTextAlloc(allocator);
    try std.testing.expect(text_opt != null);
    const text = text_opt.?;
    defer allocator.free(text);

    try std.testing.expectEqualStrings("B\nCD", text);
}

test "selectRangeLocked applies and finishes selection in one backend step" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    session.lock();
    terminal_selection.selectRangeLocked(session, .{ .row = 0, .col = 1 }, .{ .row = 1, .col = 2 }, true);
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 2);
    defer session.deinit();

    session.lock();
    try std.testing.expect(!terminal_selection.clearSelectionIfActiveLocked(session));
    try std.testing.expect(!terminal_selection.finishSelectionIfActiveLocked(session));

    terminal_selection.selectCellLocked(session, .{ .row = 0, .col = 1 }, false);
    try std.testing.expect(terminal_selection.clearSelectionIfActiveLocked(session));
    try std.testing.expect(session.selectionState() == null);

    terminal_selection.selectCellLocked(session, .{ .row = 1, .col = 0 }, false);
    try std.testing.expect(terminal_selection.finishSelectionIfActiveLocked(session));
    session.unlock();

    const selection = session.selectionState().?;
    try std.testing.expect(selection.active);
    try std.testing.expect(!selection.selecting);
}

test "selection drag helpers update ordered ranges and late-start cells" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 2);
    defer session.deinit();

    session.lock();
    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[1].codepoint = 'X';

    try std.testing.expect(!terminal_selection.selectOrUpdateCellInRowLocked(session, &[_]Cell{ base, base }, 0, 0));
    try std.testing.expect(terminal_selection.selectOrUpdateCellInRowLocked(session, &row, 1, 1));
    var selection = session.selectionState().?;
    try std.testing.expectEqual(@as(usize, 1), selection.start.row);
    try std.testing.expectEqual(@as(usize, 1), selection.start.col);
    try std.testing.expectEqual(@as(usize, 1), selection.end.row);
    try std.testing.expectEqual(@as(usize, 1), selection.end.col);

    try std.testing.expect(terminal_selection.selectOrderedRangeLocked(
        session,
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base, base, base };
    row[0].codepoint = 'f';
    row[1].codepoint = 'o';
    row[2].codepoint = 'o';
    row[3].codepoint = '!';

    session.lock();
    const word_click = terminal_selection.beginClickSelectionLocked(session, &row, 3, 1, 2);
    try std.testing.expect(word_click.started);
    try std.testing.expectEqual(.word, word_click.gesture.mode);
    try std.testing.expectEqual(@as(usize, 3), word_click.gesture.row);
    try std.testing.expectEqual(@as(usize, 0), word_click.gesture.col_start);
    try std.testing.expectEqual(@as(usize, 2), word_click.gesture.col_end);

    try std.testing.expect(terminal_selection.extendGestureSelectionLocked(session, word_click.gesture, &row, 4, 3));
    var selection = session.selectionState().?;
    try std.testing.expectEqual(@as(usize, 3), selection.start.row);
    try std.testing.expectEqual(@as(usize, 0), selection.start.col);
    try std.testing.expectEqual(@as(usize, 4), selection.end.row);
    try std.testing.expectEqual(@as(usize, 3), selection.end.col);

    terminal_selection.clearSelectionLocked(session);
    const line_click = terminal_selection.beginClickSelectionLocked(session, &row, 5, 2, 3);
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 2);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[0].codepoint = 'A';
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, session.primary.defaultCell());
    session.history.setScrollOffset(session.primary.grid.rows, 1);

    session.lock();
    try std.testing.expect(scrollback_view.resetToLiveBottomLocked(session));
    try std.testing.expectEqual(@as(usize, 0), session.history.scrollOffset());
    try std.testing.expect(!scrollback_view.resetToLiveBottomLocked(session));
    session.unlock();
}

test "scrollSelectionDragLocked scrolls history view in drag direction" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 2);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[0].codepoint = 'A';
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, session.primary.defaultCell());
    session.history.setScrollOffset(session.primary.grid.rows, 1);

    session.lock();
    try std.testing.expect(scrollback_view.scrollSelectionDragLocked(session, false));
    try std.testing.expectEqual(@as(usize, 0), session.history.scrollOffset());
    try std.testing.expect(scrollback_view.scrollSelectionDragLocked(session, true));
    try std.testing.expectEqual(@as(usize, 1), session.history.scrollOffset());
    session.unlock();
}

test "setScrollOffsetFromNormalizedTrackLocked maps scrollbar track ratio to history offset" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 2);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[0].codepoint = 'A';
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, session.primary.defaultCell());

    session.lock();
    try std.testing.expectEqual(@as(?usize, 3), scrollback_view.setScrollOffsetFromNormalizedTrackLocked(session, 0.0));
    try std.testing.expectEqual(@as(usize, 3), session.history.scrollOffset());
    try std.testing.expectEqual(@as(?usize, 0), scrollback_view.setScrollOffsetFromNormalizedTrackLocked(session, 1.0));
    try std.testing.expectEqual(@as(usize, 0), session.history.scrollOffset());
    session.unlock();
}

test "scrollWheelLocked applies backend wheel policy" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 2);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[0].codepoint = 'A';
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, session.primary.defaultCell());

    session.lock();
    try std.testing.expect(scrollback_view.scrollWheelLocked(session, 1));
    try std.testing.expectEqual(@as(usize, 3), session.history.scrollOffset());
    try std.testing.expect(scrollback_view.scrollWheelLocked(session, -1));
    try std.testing.expectEqual(@as(usize, 0), session.history.scrollOffset());
    try std.testing.expect(!scrollback_view.scrollWheelLocked(session, 0));
    session.unlock();
}

test "scrollback plain text export is terminal-owned" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 4);
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

    const text = try session.core.scrollbackPlainTextAlloc(allocator);
    defer allocator.free(text);

    try std.testing.expectEqualStrings("AB\nCD\nEF\n", text);
}

test "scrollback ansi text export is terminal-owned" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 1, 1);
    defer session.deinit();

    var cell = session.primary.defaultCell();
    cell.codepoint = 'A';
    session.primary.grid.cells.items[0] = cell;

    const text = try session.core.scrollbackAnsiTextAlloc(allocator);
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

    var session = try TerminalRuntimeShell.init(allocator, 2, 3);
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
    const range = try session.core.copyScrollbackRange(allocator, 0, 0, &cells);

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

    var session = try TerminalRuntimeShell.init(allocator, 2, 2);
    defer session.deinit();

    input_modes.setKeypadMode(session, true);
    input_modes.setAppCursorKeys(session, true);
    try std.testing.expect(session_input.appKeypadEnabled(session));
    try std.testing.expect(session.session.interaction.protocol_modes.input_snapshot.app_cursor_keys.load(.acquire));

    mode_effects.resetState(session);

    try std.testing.expect(!session_input.appKeypadEnabled(session));
    try std.testing.expect(!session.session.interaction.protocol_modes.input_snapshot.app_cursor_keys.load(.acquire));
}

test "feedOutputBytes publishes keypad mode through locked parser path" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 2);
    defer session.deinit();

    terminal_core_feed.feedOutputBytes(session, "\x1b=");
    try std.testing.expect(session_input.appKeypadEnabled(session));

    terminal_core_feed.feedOutputBytes(session, "\x1b>");
    try std.testing.expect(!session_input.appKeypadEnabled(session));
}

test "feedOutputBytes publishes kitty key mode flags through locked parser path" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 2);
    defer session.deinit();

    terminal_core_feed.feedOutputBytes(session, "\x1b[>13u");
    try std.testing.expectEqual(@as(u32, 13), session_interaction.keyModeFlagsValue(session));

    terminal_core_feed.feedOutputBytes(session, "\x1b[<1u");
    try std.testing.expectEqual(@as(u32, 0), session_interaction.keyModeFlagsValue(session));
}

test "feedOutputBytes RIS resets input modes and clears screen" {
    const allocator = std.testing.allocator;

    var session = try TerminalRuntimeShell.init(allocator, 2, 2);
    defer session.deinit();

    terminal_core_feed.feedOutputBytes(
        session,
        "\x1b[?1004h" ++
            "\x1b[?2004h" ++
            "\x1b[?1002h" ++
            "\x1b[?1006h" ++
            "\x1b[?1016h" ++
            "\x1b[?1h" ++
            "\x1b=" ++
            "AB",
    );

    try std.testing.expect(session_interaction.focusReportingEnabled(session));
    try std.testing.expect(session_interaction.bracketedPasteEnabled(session));
    try std.testing.expect(session_interaction.mouseReportingEnabled(session));
    try std.testing.expect(session.mouseModeSgrPixelsEnabled());
    try std.testing.expect(session_input.appCursorKeysEnabled(session));
    try std.testing.expect(session_input.appKeypadEnabled(session));
    try std.testing.expectEqual(@as(u32, 'A'), terminal_core_protocol.getCell(session, 0, 0).codepoint);
    try std.testing.expectEqual(@as(u32, 'B'), terminal_core_protocol.getCell(session, 0, 1).codepoint);

    terminal_core_feed.feedOutputBytes(session, "\x1bc");

    try std.testing.expect(!session_interaction.focusReportingEnabled(session));
    try std.testing.expect(!session_interaction.bracketedPasteEnabled(session));
    try std.testing.expect(!session_interaction.mouseReportingEnabled(session));
    try std.testing.expect(!session.mouseModeSgrPixelsEnabled());
    try std.testing.expect(!session_input.appCursorKeysEnabled(session));
    try std.testing.expect(!session_input.appKeypadEnabled(session));
    try std.testing.expectEqual(@as(u32, 0), terminal_core_protocol.getCell(session, 0, 0).codepoint);
    try std.testing.expectEqual(@as(u32, 0), terminal_core_protocol.getCell(session, 0, 1).codepoint);
}
