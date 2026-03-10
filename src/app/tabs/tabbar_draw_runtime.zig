const app_modes = @import("../modes/mod.zig");
const app_terminal_tabs_runtime = @import("../terminal/terminal_tabs_runtime.zig");
const app_theme_utils = @import("../theme_utils.zig");
const widgets_common = @import("../../ui/widgets/common.zig");
const shared_types = @import("../../types/mod.zig");

const layout_types = shared_types.layout;

pub const Hooks = struct {
    apply_current_tab_bar_width_mode: *const fn (*anyopaque) void,
};

pub fn draw(state: anytype, shell: anytype, layout: layout_types.WidgetLayout, ctx: *anyopaque, hooks: Hooks) ?widgets_common.Tooltip {
    var tab_tooltip: ?widgets_common.Tooltip = null;

    if (app_modes.ide.canToggleTerminal(state.app_mode)) {
        hooks.apply_current_tab_bar_width_mode(ctx);
        shell.setTheme(state.app_theme);
        state.options_bar.draw(shell, layout.window.width);
        tab_tooltip = state.tab_bar.draw(shell, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width);
    } else if (app_modes.ide.useTerminalTabBarWidthMode(state.app_mode)) {
        hooks.apply_current_tab_bar_width_mode(ctx);
        const tab_theme = app_theme_utils.terminalTabBarTheme(state.terminal_theme, state.shell_base_theme);
        shell.setTheme(tab_theme);
        if (app_terminal_tabs_runtime.barVisible(
            state.app_mode,
            state.terminal_tab_bar_show_single_tab,
            state.terminal_workspace,
            state.terminals.items.len,
        )) {
            tab_tooltip = state.tab_bar.draw(shell, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width);
        }
    }

    return tab_tooltip;
}
