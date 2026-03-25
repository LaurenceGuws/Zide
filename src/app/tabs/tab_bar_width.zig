const config_mod = @import("../../config/lua_config.zig");
const app_bootstrap = @import("../bootstrap.zig");
const app_modes = @import("../modes/mod.zig");
const app_types = @import("../app_state_types.zig");
const widgets = @import("../../ui/widgets.zig");

const TabBar = widgets.TabBar;
const AppMode = app_bootstrap.AppMode;

pub fn mapMode(mode: ?config_mod.TabBarWidthMode) TabBar.WidthMode {
    return switch (mode orelse .fixed) {
        .fixed => .fixed,
        .dynamic => .dynamic,
        .label_length => .label_length,
    };
}

pub fn applyForMode(
    tab_bar: *TabBar,
    app_mode: AppMode,
    terminal_window_chrome_mode: app_types.TerminalWindowChromeMode,
    editor_tab_bar_width_mode: TabBar.WidthMode,
    terminal_tab_bar_width_mode: TabBar.WidthMode,
) void {
    tab_bar.setWidthMode(
        if (app_modes.ide.useTerminalTabBarWidthMode(app_mode))
            if (terminal_window_chrome_mode == .integrated)
                .compact_label_length
            else
                terminal_tab_bar_width_mode
        else
            editor_tab_bar_width_mode,
    );
}
