const app_mode_adapter_parity = @import("mode_adapter_parity.zig");
const app_mode_adapter_sync = @import("mode_adapter_sync.zig");

pub fn sync(state: anytype) !void {
    const editor_mode_adapter = if (state.editor_mode_adapter) |*editor| editor else return;
    try app_mode_adapter_sync.syncFromTabBar(
        state.allocator,
        state.active_kind,
        state.tab_bar.tabs.items,
        state.tab_bar.active_index,
        editor_mode_adapter,
        &state.terminal_mode_adapter,
    );
    app_mode_adapter_parity.logIfMismatch(
        state.allocator,
        state.active_kind,
        state.tab_bar.tabs.items,
        state.tab_bar.active_index,
        editor_mode_adapter,
        &state.terminal_mode_adapter,
    );
}
