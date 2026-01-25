const std = @import("std");
const term_mod = @import("terminal/core/terminal.zig");
const adapter = @import("terminal/core/snapshot_adapter.zig");
const shared = @import("types/mod.zig").snapshots;

test "terminal snapshot adapter empty" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 1, 1);
    defer session.deinit();

    const snapshot = session.snapshot();
    const shared_snapshot = adapter.toSharedSnapshot(snapshot);

    try std.testing.expectEqual(snapshot.rows, shared_snapshot.rows);
    try std.testing.expectEqual(snapshot.cols, shared_snapshot.cols);
    try std.testing.expectEqual(@as(usize, 0), shared_snapshot.cells.len);
    try std.testing.expectEqual(@as(u16, 0), shared_snapshot.cursor_row);
    try std.testing.expectEqual(@as(u16, 0), shared_snapshot.cursor_col);
    try std.testing.expect(shared_snapshot.selection == null);
    _ = @as(shared.TerminalSnapshot, shared_snapshot);
}

test "terminal snapshot adapter remains empty after write" {
    const allocator = std.testing.allocator;

    var session = try term_mod.TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    term_mod.debugFeedBytes(session, "hi");

    const snapshot = session.snapshot();
    const shared_snapshot = adapter.toSharedSnapshot(snapshot);

    try std.testing.expectEqual(snapshot.rows, shared_snapshot.rows);
    try std.testing.expectEqual(snapshot.cols, shared_snapshot.cols);
    try std.testing.expectEqual(@as(usize, 0), shared_snapshot.cells.len);
    try std.testing.expectEqual(@as(u16, 0), shared_snapshot.cursor_row);
    try std.testing.expectEqual(@as(u16, 0), shared_snapshot.cursor_col);
    try std.testing.expect(shared_snapshot.selection == null);
}
