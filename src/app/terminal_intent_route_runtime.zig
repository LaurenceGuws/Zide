const app_terminal_runtime_intents = @import("terminal_runtime_intents.zig");
const app_tab_action_apply_runtime = @import("tab_action_apply_runtime.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");

const TerminalTabId = terminal_mod.TerminalTabId;

pub fn routeActiveAndSync(state: anytype, intent: app_terminal_runtime_intents.Intent) !bool {
    return try app_terminal_runtime_intents.routeForActiveWorkspaceTabAndSync(
        intent,
        &state.terminal_workspace,
        @ptrCast(state),
        struct {
            fn call(raw: *anyopaque, action: @import("modes/mod.zig").shared.actions.TabAction) !void {
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
            fn call(raw: *anyopaque, action: @import("modes/mod.zig").shared.actions.TabAction) !void {
                const app_state = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                try app_tab_action_apply_runtime.applyTerminalAndSync(app_state, action);
            }
        }.call,
    );
}
