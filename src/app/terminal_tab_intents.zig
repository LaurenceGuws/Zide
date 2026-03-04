const app_modes = @import("modes/mod.zig");

pub fn closeIntentForTabId(tab_id: ?u64) ?app_modes.shared.actions.TabAction {
    return app_modes.ide.closeIntentForActiveTab(tab_id);
}

pub fn cycleIntentForDirection(
    dir: app_modes.ide.TerminalShortcutCycleDirection,
) app_modes.shared.actions.TabAction {
    return if (dir == .next) .next else .prev;
}

pub fn activateIntentForTabId(tab_id: ?u64) ?app_modes.shared.actions.TabAction {
    if (tab_id) |id| {
        return .{ .activate = id };
    }
    return null;
}
