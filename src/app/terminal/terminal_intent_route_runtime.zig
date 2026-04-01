const app_terminal_runtime_intents = @import("terminal_runtime_intents.zig");
const app_tab_action_apply_runtime = @import("../tabs/tab_action_apply_runtime.zig");
const app_modes = @import("../modes/mod.zig");
const workspace_mod = @import("../../terminal/core/workspace.zig");

const TerminalTabId = workspace_mod.TabId;

pub fn routeActiveAndSync(state: anytype, intent: app_terminal_runtime_intents.Intent) !bool {
    return try app_terminal_runtime_intents.routeForActiveWorkspaceTabAndSync(
        intent,
        &state.terminal_workspace,
        @ptrCast(state),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const app_state = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                try app_tab_action_apply_runtime.applyTerminalAndSync(app_state, action);
            }
        }.call,
    );
}

pub fn routeByTabIdAndSync(
    state: anytype,
    intent: app_terminal_runtime_intents.Intent,
    tab_id: ?TerminalTabId,
) !bool {
    return try app_terminal_runtime_intents.routeByTabIdAndSync(
        intent,
        tab_id,
        @ptrCast(state),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const app_state = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                try app_tab_action_apply_runtime.applyTerminalAndSync(app_state, action);
            }
        }.call,
    );
}
