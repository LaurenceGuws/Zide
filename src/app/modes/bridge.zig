const std = @import("std");
const modes = @import("mod.zig");

pub const TabView = struct {
    id: modes.shared.types.TabId,
    title: []const u8,
    alive: bool = true,
};

pub fn syncEditorModeFromViews(
    mode: *modes.backend.EditorMode,
    allocator: std.mem.Allocator,
    tabs: []const TabView,
    active_tab: ?modes.shared.types.TabId,
) !void {
    var temp_tabs = std.ArrayList(modes.shared.contracts.ModeTab).empty;
    defer temp_tabs.deinit(allocator);
    try temp_tabs.ensureTotalCapacity(allocator, tabs.len);
    for (tabs) |tab| {
        temp_tabs.appendAssumeCapacity(.{
            .id = tab.id,
            .title = tab.title,
            .alive = tab.alive,
        });
    }
    const snapshot = modes.shared.contracts.ModeSnapshot{
        .mode = .editor,
        .tabs = temp_tabs.items,
        .active_tab = active_tab,
        .capabilities = .{
            .supports_tabs = true,
            .supports_reorder = true,
            .supports_mixed_views = false,
        },
        .diagnostics = .{},
    };
    try mode.syncFromSnapshot(allocator, snapshot);
}

pub fn syncTerminalModeFromViews(
    mode: *modes.backend.TerminalMode,
    allocator: std.mem.Allocator,
    tabs: []const TabView,
    active_tab: ?modes.shared.types.TabId,
) !void {
    var temp_tabs = std.ArrayList(modes.shared.contracts.ModeTab).empty;
    defer temp_tabs.deinit(allocator);
    try temp_tabs.ensureTotalCapacity(allocator, tabs.len);
    for (tabs) |tab| {
        temp_tabs.appendAssumeCapacity(.{
            .id = tab.id,
            .title = tab.title,
            .alive = tab.alive,
        });
    }
    const snapshot = modes.shared.contracts.ModeSnapshot{
        .mode = .terminal,
        .tabs = temp_tabs.items,
        .active_tab = active_tab,
        .capabilities = .{
            .supports_tabs = true,
            .supports_reorder = true,
            .supports_mixed_views = false,
        },
        .diagnostics = .{},
    };
    try mode.syncFromSnapshot(allocator, snapshot);
}

test "bridge sync editor mode from tab views" {
    const allocator = std.testing.allocator;
    var mode = modes.backend.EditorMode.init(allocator);
    defer mode.deinit(allocator);

    const views = [_]TabView{
        .{ .id = 10, .title = "A", .alive = true },
        .{ .id = 12, .title = "B", .alive = false },
    };
    try syncEditorModeFromViews(&mode, allocator, views[0..], 12);

    const snap = try mode.asContract().snapshot(allocator);
    try std.testing.expectEqual(@as(usize, 2), snap.tabs.len);
    try std.testing.expectEqual(@as(?modes.shared.types.TabId, 12), snap.active_tab);
    try std.testing.expectEqualStrings("A", snap.tabs[0].title);
    try std.testing.expectEqualStrings("B", snap.tabs[1].title);
    try std.testing.expectEqual(false, snap.tabs[1].alive);
}

test "bridge sync terminal mode from tab views" {
    const allocator = std.testing.allocator;
    var mode = modes.backend.TerminalMode.init(allocator);
    defer mode.deinit(allocator);

    const views = [_]TabView{
        .{ .id = 1, .title = "T1", .alive = true },
        .{ .id = 2, .title = "T2", .alive = true },
        .{ .id = 3, .title = "T3", .alive = true },
    };
    try syncTerminalModeFromViews(&mode, allocator, views[0..], 2);

    const snap = try mode.asContract().snapshot(allocator);
    try std.testing.expectEqual(@as(usize, 3), snap.tabs.len);
    try std.testing.expectEqual(@as(?modes.shared.types.TabId, 2), snap.active_tab);
    try std.testing.expectEqualStrings("T1", snap.tabs[0].title);
    try std.testing.expectEqualStrings("T2", snap.tabs[1].title);
    try std.testing.expectEqualStrings("T3", snap.tabs[2].title);
}
