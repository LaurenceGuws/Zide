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

test "terminal workspace metadata is session-derived" {
    var workspace = terminal.TerminalWorkspace.init(std.testing.allocator, .{});
    defer workspace.deinit();
    var title_buf = std.ArrayList(u8).empty;
    defer title_buf.deinit(std.testing.allocator);
    var cwd_buf = std.ArrayList(u8).empty;
    defer cwd_buf.deinit(std.testing.allocator);

    _ = try workspace.createTab(24, 80);
    const session = workspace.activeSession().?;
    terminal.debugFeedBytes(session, "\x1b]2;build-shell\x07");

    const metadata = (try workspace.copyMetadataAt(std.testing.allocator, workspace.activeIndex(), &title_buf, &cwd_buf)).?;
    try std.testing.expectEqualStrings("build-shell", metadata.title);
    try std.testing.expectEqual(metadata.id, workspace.activeTabId().?);
}
