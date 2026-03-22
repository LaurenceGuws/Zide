const app_modes = @import("modes/mod.zig");
const app_top_bar_action_runtime = @import("top_bar_action_runtime.zig");
const app_top_bar_model_runtime = @import("top_bar_model_runtime.zig");
const app_top_bar_window_chrome_runtime = @import("top_bar_window_chrome_runtime.zig");
const app_window_caption_buttons_draw_runtime = @import("window_caption_buttons_draw_runtime.zig");
const app_theme_utils = @import("theme_utils.zig");
const shared_types = @import("../types/mod.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;

pub fn draw(state: anytype, shell: anytype, layout: layout_types.WidgetLayout) void {
    if (!app_modes.ide.supportsEditorSurface(state.app_mode)) return;
    if (layout.top_bar.height <= 0) return;

    shell.setTheme(app_theme_utils.windowChromeTheme(state.app_theme, shell.windowFocused()));
    state.top_bar.draw(shell, layout.top_bar, app_top_bar_model_runtime.forMode(state.app_mode));
    const chrome = app_top_bar_window_chrome_runtime.computeGeometry(shell, &state.top_bar, layout.top_bar, state.app_mode);
    if (chrome.enabled) {
        app_window_caption_buttons_draw_runtime.drawButtons(shell, chrome, state.pressed_window_caption_button);
    }
}

pub fn handleLeftClick(state: anytype, layout: layout_types.WidgetLayout, mouse: input_types.MousePos, now: f64) !bool {
    if (layout.top_bar.height <= 0) return false;

    if (state.top_bar.handleClick(state.shell, layout.top_bar, app_top_bar_model_runtime.forMode(state.app_mode), mouse)) |action| {
        try app_top_bar_action_runtime.apply(state, action);
        state.needs_redraw = true;
        state.metrics.noteInput(now);
        return true;
    }
    return false;
}
