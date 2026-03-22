const app_modes = @import("../modes/mod.zig");
const app_shell = @import("../../app_shell.zig");
const app_terminal_window_chrome_runtime = @import("../terminal/window_chrome_runtime.zig");
const app_theme_utils = @import("../theme_utils.zig");
const app_window_caption_buttons_draw_runtime = @import("../window_caption_buttons_draw_runtime.zig");
const widgets_common = @import("../../ui/widgets/common.zig");
const shared_types = @import("../../types/mod.zig");

const layout_types = shared_types.layout;
const Color = app_shell.Color;

pub const Hooks = struct {
    apply_current_tab_bar_width_mode: *const fn (*anyopaque) void,
};

pub fn draw(state: anytype, shell: anytype, layout: layout_types.WidgetLayout, ctx: *anyopaque, hooks: Hooks) ?widgets_common.Tooltip {
    var tab_tooltip: ?widgets_common.Tooltip = null;

    if (app_modes.ide.supportsEditorSurface(state.app_mode)) {
        hooks.apply_current_tab_bar_width_mode(ctx);
        shell.setTheme(state.app_theme);
        if (layout.tab_bar.height > 0) {
            tab_tooltip = state.tab_bar.draw(shell, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width);
        }
    } else if (app_modes.ide.useTerminalTabBarWidthMode(state.app_mode)) {
        hooks.apply_current_tab_bar_width_mode(ctx);
        const tab_theme = app_theme_utils.terminalTabBarTheme(state.terminal_theme, state.shell_base_theme);
        const chrome_theme = app_theme_utils.windowChromeTheme(tab_theme, shell.windowFocused());
        shell.setTheme(chrome_theme);
        if (app_terminal_window_chrome_runtime.barVisible(
            state.app_mode,
            state.terminal_window_chrome_mode,
            state.terminal_tab_bar_show_single_tab,
            state.terminal_workspace,
            state.terminals.items.len,
        )) {
            const chrome = app_terminal_window_chrome_runtime.computeGeometry(
                shell,
                &state.tab_bar,
                layout.tab_bar,
                state.app_mode,
                state.terminal_window_chrome_mode,
            );
            if (chrome.enabled) {
                drawIntegratedBackground(shell, chrome.band, chrome_theme.ui_bar_bg);
                tab_tooltip = state.tab_bar.drawWithIconProvider(
                    shell,
                    chrome.band.x,
                    chrome.band.y,
                    chrome.tab_strip_width,
                    state.terminal_shell_icon_cache.iconProvider(),
                );
                drawIntegratedButtons(state, shell, chrome);
            } else {
                tab_tooltip = state.tab_bar.drawWithIconProvider(
                    shell,
                    layout.tab_bar.x,
                    layout.tab_bar.y,
                    layout.tab_bar.width,
                    state.terminal_shell_icon_cache.iconProvider(),
                );
            }
        }
    }

    return tab_tooltip;
}

fn drawIntegratedBackground(shell: anytype, band: layout_types.Rect, color: Color) void {
    shell.drawRect(
        @intFromFloat(band.x),
        @intFromFloat(band.y),
        @intFromFloat(band.width),
        @intFromFloat(band.height),
        color,
    );
}

fn drawIntegratedButtons(state: anytype, shell: anytype, chrome: app_terminal_window_chrome_runtime.Geometry) void {
    app_window_caption_buttons_draw_runtime.drawButtons(shell, chrome, state.pressed_window_caption_button);
}
