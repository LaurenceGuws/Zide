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

