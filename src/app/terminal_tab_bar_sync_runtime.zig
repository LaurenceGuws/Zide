const app_modes = @import("modes/mod.zig");
const app_terminal_tab_bar_sync = @import("terminal_tab_bar_sync.zig");
const app_mode_adapter_sync_runtime = @import("mode_adapter_sync_runtime.zig");

pub fn syncIfWorkspace(state: anytype) !void {
    if (!app_modes.ide.shouldUseTerminalWorkspace(state.app_mode)) return;
    try app_terminal_tab_bar_sync.syncFromWorkspace(&state.tab_bar, &state.terminal_workspace);
    try app_mode_adapter_sync_runtime.sync(state);
}
