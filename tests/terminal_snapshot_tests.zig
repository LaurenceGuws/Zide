const std = @import("std");
const terminal_runtime = @import("../src/terminal/core/terminal_runtime.zig");
const terminal_debug = @import("../src/terminal/core/terminal_debug.zig");
const terminal_publication = @import("../src/terminal/core/publication/terminal_publication.zig");
const adapter = @import("../src/terminal/core/snapshot_adapter.zig");
const shared = @import("../src/types/mod.zig").snapshots;

test "terminal snapshot adapter empty" {
    const allocator = std.testing.allocator;

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 1, 1);
    defer session.deinit();

    const snapshot = session.snapshot();
    const shared_snapshot = adapter.toSharedSnapshot(snapshot);

    try std.testing.expectEqual(snapshot.rows, shared_snapshot.rows);
    try std.testing.expectEqual(snapshot.cols, shared_snapshot.cols);
    try std.testing.expectEqual(@as(usize, 0), shared_snapshot.cells.len);
    try std.testing.expectEqual(snapshot.cursor.row, shared_snapshot.cursor_row);
    try std.testing.expectEqual(snapshot.cursor.col, shared_snapshot.cursor_col);
    try std.testing.expect(shared_snapshot.selection == null);
    _ = @as(shared.TerminalSnapshot, shared_snapshot);
}

test "terminal snapshot adapter remains empty after write" {
    const allocator = std.testing.allocator;

    var session = try terminal_runtime.PtyTerminalRuntime.init(allocator, 2, 2);
    defer session.deinit();

    terminal_debug.debugFeedBytes(session, "hi");

    const snapshot = session.snapshot();
    const shared_snapshot = adapter.toSharedSnapshot(snapshot);

    try std.testing.expectEqual(snapshot.rows, shared_snapshot.rows);
    try std.testing.expectEqual(snapshot.cols, shared_snapshot.cols);
    try std.testing.expectEqual(@as(usize, 0), shared_snapshot.cells.len);
    try std.testing.expectEqual(snapshot.cursor.row, shared_snapshot.cursor_row);
    try std.testing.expectEqual(snapshot.cursor.col, shared_snapshot.cursor_col);
    try std.testing.expect(shared_snapshot.selection == null);
}
