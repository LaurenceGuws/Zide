const std = @import("std");
const terminal_runtime = @import("../src/terminal/core/terminal_runtime.zig");
const terminal_debug = @import("../src/terminal/core/session/debug_ops.zig");
const host_types = @import("../src/terminal/core/session/host_types.zig");
const mode_effects = @import("../src/terminal/core/session/mode_effects.zig");
const session_runtime = @import("../src/terminal/core/session/runtime.zig");
const workspace_mod = @import("../src/terminal/core/workspace.zig");
const workspace_host = @import("../src/terminal/core/workspace_host.zig");

test "terminal workspace create switch move close lifecycle" {
    var workspace = workspace_mod.TerminalWorkspace.init(std.testing.allocator, .{});
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
    var workspace = workspace_mod.TerminalWorkspace.init(std.testing.allocator, .{});
    defer workspace.deinit();
    var entry_buf = std.ArrayList(workspace_mod.TabSyncEntry).empty;
    defer entry_buf.deinit(std.testing.allocator);
    var string_buf = std.ArrayList(u8).empty;
    defer string_buf.deinit(std.testing.allocator);

    const created = try workspace.createTabWithSession(24, 80);
    const session = created.session;
    terminal_debug.debugFeedBytes(session, "\x1b]2;build-shell\x07");
    terminal_debug.debugFeedBytes(session, "\x1b]9;4;1;42\x07");

    const sync_state = try workspace.copyTabSyncState(std.testing.allocator, &entry_buf, &string_buf);
    try std.testing.expectEqual(@as(usize, 1), sync_state.tabs.len);
    try std.testing.expectEqual(created.id, sync_state.active_tab_id.?);
    try std.testing.expectEqual(created.id, sync_state.tabs[0].id);
    try std.testing.expectEqualStrings("build-shell", sync_state.tabs[0].title(sync_state.strings));
    try std.testing.expectEqual(host_types.ProgressState.set, sync_state.tabs[0].progress_state);
    try std.testing.expectEqual(@as(?u8, 42), sync_state.tabs[0].progress_value);
}

test "terminal workspace first confirm close tab returns first matching tab" {
    var workspace = workspace_mod.TerminalWorkspace.init(std.testing.allocator, .{});
    defer workspace.deinit();

    const first = try workspace.createTabWithSession(24, 80);
    const second = try workspace.createTabWithSession(24, 80);

    try std.testing.expect(workspace_host.firstConfirmCloseTab(&workspace) == null);

    try session_runtime.startNoThreads(first.session, null);
    mode_effects.enterAltScreen(first.session, true, false);

    const target = workspace_host.firstConfirmCloseTab(&workspace) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 0), target.index);
    try std.testing.expectEqual(first.id, target.id);

    _ = second;
}

test "terminal workspace poll epochs reset on topology and active-tab changes" {
    var workspace = workspace_mod.TerminalWorkspace.init(std.testing.allocator, .{});
    defer workspace.deinit();

    try std.testing.expectEqual(@as(u64, 0), workspace.pollRuntimeCounters().epoch);

    const first = try workspace.createTab(24, 80);
    try std.testing.expectEqual(@as(u64, 1), workspace.pollRuntimeCounters().epoch);

    const second = try workspace.createTab(24, 80);
    try std.testing.expectEqual(@as(u64, 2), workspace.pollRuntimeCounters().epoch);

    try std.testing.expect(workspace.activateTab(first));
    try std.testing.expectEqual(@as(u64, 3), workspace.pollRuntimeCounters().epoch);

    try std.testing.expect(workspace.closeTab(second));
    try std.testing.expectEqual(@as(u64, 4), workspace.pollRuntimeCounters().epoch);
}
