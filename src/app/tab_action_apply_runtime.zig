const app_tab_action_apply = @import("tab_action_apply.zig");
const app_mode_adapter_sync_runtime = @import("mode_adapter_sync_runtime.zig");
const app_modes = @import("modes/mod.zig");

pub fn applyTerminalAndSync(state: anytype, action: app_modes.shared.actions.TabAction) !void {
    app_tab_action_apply.applyTerminal(state.allocator, state.app_mode, &state.terminal_mode_adapter, action);
    try app_mode_adapter_sync_runtime.sync(state);
}

pub fn applyEditorAndSync(state: anytype, action: app_modes.shared.actions.TabAction) !void {
    app_tab_action_apply.applyEditor(state.allocator, state.app_mode, &state.editor_mode_adapter, action);
    try app_mode_adapter_sync_runtime.sync(state);
}
