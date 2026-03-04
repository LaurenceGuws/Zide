const app_editor_intent_route = @import("editor_intent_route.zig");
const app_tab_action_apply_runtime = @import("tab_action_apply_runtime.zig");
const app_modes = @import("modes/mod.zig");

pub fn routeCreateAndSync(state: anytype) !bool {
    return try app_editor_intent_route.routeCreateAndSync(
        @ptrCast(state),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const app_state = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                try app_tab_action_apply_runtime.applyEditorAndSync(app_state, action);
            }
        }.call,
    );
}
