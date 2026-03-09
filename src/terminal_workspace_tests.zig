const std = @import("std");
const terminal = @import("terminal/core/terminal.zig");

test "terminal workspace create switch move close lifecycle" {
    var workspace = terminal.TerminalWorkspace.init(std.testing.allocator, .{});
    defer workspace.deinit();

    const tab_1 = try workspace.createTab(24, 80);
    const tab_2 = try workspace.createTab(24, 80);
    const tab_3 = try workspace.createTab(24, 80);

    try std.testing.expectEqual(@as(usize, 3), workspace.tabCount());
    try std.testing.expectEqual(tab_3, workspace.activeTabId().?);

    try std.testing.expect(workspace.activateTab(tab_1));
    try std.testing.expectEqual(tab_1, workspace.activeTabId().?);

    try std.testing.expect(workspace.activateNext());
    try std.testing.expectEqual(tab_2, workspace.activeTabId().?);
    try std.testing.expect(workspace.activatePrev());
    try std.testing.expectEqual(tab_1, workspace.activeTabId().?);

    try std.testing.expect(workspace.moveTab(tab_3, 0));
    try std.testing.expectEqual(tab_3, workspace.tabIdAt(0).?);
    try std.testing.expectEqual(tab_1, workspace.activeTabId().?);

    try std.testing.expect(workspace.closeTab(tab_2));
    try std.testing.expectEqual(@as(usize, 2), workspace.tabCount());
    try std.testing.expectEqual(tab_3, workspace.tabIdAt(0).?);
    try std.testing.expectEqual(tab_1, workspace.tabIdAt(1).?);

    try std.testing.expect(workspace.closeActiveTab());
    try std.testing.expectEqual(@as(usize, 1), workspace.tabCount());
    try std.testing.expectEqual(tab_3, workspace.activeTabId().?);
}

test "terminal workspace tab sync state is session-derived" {
    var workspace = terminal.TerminalWorkspace.init(std.testing.allocator, .{});
    defer workspace.deinit();
    var entry_buf = std.ArrayList(terminal.TerminalTabSyncEntry).empty;
    defer entry_buf.deinit(std.testing.allocator);
    var string_buf = std.ArrayList(u8).empty;
    defer string_buf.deinit(std.testing.allocator);

    const created = try workspace.createTabWithSession(24, 80);
    const session = created.session;
    terminal.debugFeedBytes(session, "\x1b]2;build-shell\x07");

    const sync_state = try workspace.copyTabSyncState(std.testing.allocator, &entry_buf, &string_buf);
    try std.testing.expectEqual(@as(usize, 1), sync_state.tabs.len);
    try std.testing.expectEqual(created.id, sync_state.active_tab_id.?);
    try std.testing.expectEqual(created.id, sync_state.tabs[0].id);
    try std.testing.expectEqualStrings("build-shell", sync_state.tabs[0].title(sync_state.strings));
}

test "terminal workspace first confirm close tab returns first matching tab" {
    var workspace = terminal.TerminalWorkspace.init(std.testing.allocator, .{});
    defer workspace.deinit();

    const first = try workspace.createTabWithSession(24, 80);
    const second = try workspace.createTabWithSession(24, 80);

    try std.testing.expect(workspace.firstConfirmCloseTab() == null);

    try first.session.startNoThreads(null);
    first.session.enterAltScreen(true, false);

    const target = workspace.firstConfirmCloseTab() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 0), target.index);
    try std.testing.expectEqual(first.id, target.id);

    _ = second;
}
