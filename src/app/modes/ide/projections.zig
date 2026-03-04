const std = @import("std");
const runtime_bridge = @import("../runtime_bridge.zig");
const host = @import("host.zig");
const tab_bar_mod = @import("../../../ui/widgets/tab_bar.zig");
const Tab = tab_bar_mod.TabBar.Tab;

fn tabId(tab: Tab) u64 {
    if (@hasField(Tab, "id")) {
        return tab.id;
    }
    return tab.terminal_tab_id orelse 0;
}

pub fn buildTabProjections(
    allocator: std.mem.Allocator,
    tabs: []const Tab,
) !std.ArrayList(runtime_bridge.AppTabProjection) {
    var projections = std.ArrayList(runtime_bridge.AppTabProjection).empty;
    try projections.ensureTotalCapacity(allocator, tabs.len);
    for (tabs) |tab| {
        projections.appendAssumeCapacity(.{
            .kind = switch (tab.kind) {
                .editor => .editor,
                .terminal => .terminal,
            },
            .id = tabId(tab),
            .title = tab.title,
            .alive = true,
        });
    }
    return projections;
}

pub fn activeProjectionForTabBar(
    active_kind: host.ActiveMode,
    tabs: []const Tab,
    active_index: usize,
) runtime_bridge.ActiveProjection {
    return .{
        .kind = active_kind,
        .id = if (tabs.len > 0 and active_index < tabs.len)
            tabId(tabs[active_index])
        else
            null,
    };
}
