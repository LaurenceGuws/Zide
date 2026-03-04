const app_modes = @import("modes/mod.zig");

pub fn syncFromTabBar(
    allocator: @import("std").mem.Allocator,
    active_kind: app_modes.ide.ActiveMode,
    tabs: anytype,
    active_index: usize,
    editor_mode_adapter: anytype,
    terminal_mode_adapter: anytype,
) !void {
    var projections = try app_modes.ide.buildTabProjections(allocator, tabs);
    defer projections.deinit(allocator);

    const active_projection = app_modes.ide.activeProjectionForTabBar(
        active_kind,
        tabs,
        active_index,
    );

    try app_modes.runtime_bridge.syncModesFromProjections(
        allocator,
        editor_mode_adapter,
        terminal_mode_adapter,
        projections.items,
        active_projection,
    );
}

