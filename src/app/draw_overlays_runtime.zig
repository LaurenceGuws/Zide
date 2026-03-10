const app_config_reload_notice = @import("config_reload_notice.zig");
const app_modes = @import("modes/mod.zig");
const app_terminal_close_confirm_draw = @import("terminal/terminal_close_confirm_draw.zig");
const app_terminal_tabs_runtime = @import("terminal/terminal_tabs_runtime.zig");
const shared_types = @import("../types/mod.zig");

const layout_types = shared_types.layout;

pub const Hooks = struct {
    terminal_close_confirm_active: *const fn (*anyopaque) bool,
};

pub fn draw(state: anytype, shell: anytype, layout: layout_types.WidgetLayout, ctx: *anyopaque, hooks: Hooks) void {
    if (app_modes.ide.shouldShowTerminalCloseConfirmModal(state.app_mode, hooks.terminal_close_confirm_active(ctx))) {
        app_terminal_close_confirm_draw.draw(shell, layout, state.app_theme);
    }
    app_config_reload_notice.draw(
        shell,
        layout,
        state.app_mode,
        app_terminal_tabs_runtime.barVisible(
            state.app_mode,
            state.terminal_tab_bar_show_single_tab,
            state.terminal_workspace,
            state.terminals.items.len,
        ),
        state.config_reload_notice_until,
        state.config_reload_notice_success,
        state.app_theme,
    );
}
