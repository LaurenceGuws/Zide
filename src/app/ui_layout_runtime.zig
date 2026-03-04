const app_modes = @import("modes/mod.zig");
const app_terminal_tabs_runtime = @import("terminal_tabs_runtime.zig");
const shared_types = @import("../types/mod.zig");

const layout_types = shared_types.layout;

pub const Hooks = struct {
    apply_current_tab_bar_width_mode: *const fn (*anyopaque) void,
};

pub fn applyUiScale(state: anytype, scale: f32, ctx: *anyopaque, hooks: Hooks) void {
    state.options_bar.height = 26 * scale;
    state.tab_bar.height = 28 * scale;
    state.tab_bar.tab_width = 150 * scale;
    state.tab_bar.tab_spacing = @max(1, scale);
    state.status_bar.height = 24 * scale;
    state.side_nav.width = 52 * scale;
    hooks.apply_current_tab_bar_width_mode(ctx);
}

pub fn computeLayout(state: anytype, width: f32, height: f32) layout_types.WidgetLayout {
    return app_modes.ide.computeLayoutForMode(
        state.app_mode,
        width,
        height,
        state.options_bar.height,
        state.tab_bar.height,
        state.side_nav.width,
        state.status_bar.height,
        state.terminal_height,
        state.show_terminal,
        app_terminal_tabs_runtime.barVisible(
            state.app_mode,
            state.terminal_tab_bar_show_single_tab,
            state.terminal_workspace,
            state.terminals.items.len,
        ),
    );
}
