const builtin = @import("builtin");
const app_bootstrap = @import("../bootstrap.zig");
const app_shell = @import("../../app_shell.zig");
const app_terminal_tabs_runtime = @import("terminal_tabs_runtime.zig");
const app_modes = @import("../modes/mod.zig");
const app_types = @import("../app_state_types.zig");
const window_caption_buttons_runtime = @import("../window_caption_buttons_runtime.zig");
const shared_types = @import("../../types/mod.zig");
const widgets = @import("../../ui/widgets.zig");

const Rect = shared_types.layout.Rect;
const Shell = app_shell.Shell;
const TabBar = widgets.TabBar;
const TerminalWorkspace = @import("../../terminal/core/terminal_runtime.zig").TerminalWorkspace;

pub const CaptionButton = app_types.WindowCaptionButton;

pub const Geometry = struct {
    enabled: bool,
    band: Rect,
    tab_strip_width: f32,
    tabs_used_width: f32,
    caption_rect: Rect,
    sink_rect: Rect,
    minimize_rect: Rect,
    maximize_rect: Rect,
    close_rect: Rect,
    resize_border_px: f32,
};

pub fn isIntegratedActive(app_mode: app_bootstrap.AppMode, terminal_window_chrome_mode: app_types.TerminalWindowChromeMode) bool {
    return builtin.os.tag == .windows and
        app_modes.ide.isTerminalOnly(app_mode) and
        terminal_window_chrome_mode == .integrated;
}

pub fn barVisible(
    app_mode: app_bootstrap.AppMode,
    terminal_window_chrome_mode: app_types.TerminalWindowChromeMode,
    show_single_tab: bool,
    terminal_workspace: ?TerminalWorkspace,
    terminals_len: usize,
) bool {
    if (isIntegratedActive(app_mode, terminal_window_chrome_mode)) return true;
    return app_terminal_tabs_runtime.barVisible(app_mode, show_single_tab, terminal_workspace, terminals_len);
}

pub fn computeGeometry(
    shell: *Shell,
    tab_bar: *TabBar,
    band: Rect,
    app_mode: app_bootstrap.AppMode,
    terminal_window_chrome_mode: app_types.TerminalWindowChromeMode,
) Geometry {
    if (!isIntegratedActive(app_mode, terminal_window_chrome_mode) or band.height <= 0 or band.width <= 0) {
        return .{
            .enabled = false,
            .band = band,
            .tab_strip_width = band.width,
            .tabs_used_width = band.width,
            .caption_rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .sink_rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .minimize_rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .maximize_rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .close_rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .resize_border_px = 0,
        };
    }

    const rects = window_caption_buttons_runtime.computeRects(shell, band, tab_bar.contentWidth(band.width, shell.charWidth(), shell.uiScaleFactor()));
    const tab_strip_width = @max(0.0, rects.minimize_rect.x - band.x);
    const tabs_used_width = @min(tab_strip_width, tab_bar.contentWidth(tab_strip_width, shell.charWidth(), shell.uiScaleFactor()));
    const adjusted_rects = window_caption_buttons_runtime.computeRects(shell, band, tabs_used_width);

    return .{
        .enabled = true,
        .band = band,
        .tab_strip_width = tab_strip_width,
        .tabs_used_width = tabs_used_width,
        .caption_rect = adjusted_rects.caption_rect,
        .sink_rect = adjusted_rects.sink_rect,
        .minimize_rect = adjusted_rects.minimize_rect,
        .maximize_rect = adjusted_rects.maximize_rect,
        .close_rect = adjusted_rects.close_rect,
        .resize_border_px = adjusted_rects.resize_border_px,
    };
}

pub fn buttonAt(geometry: Geometry, x: f32, y: f32) ?CaptionButton {
    if (!geometry.enabled) return null;
    return window_caption_buttons_runtime.buttonAt(geometry, x, y);
}

pub fn captionDragAt(geometry: Geometry, x: f32, y: f32) bool {
    if (!geometry.enabled) return false;
    return window_caption_buttons_runtime.captionDragAt(geometry, x, y);
}

pub fn windowChromeContract(geometry: Geometry) app_shell.WindowChromeContract {
    if (!geometry.enabled) return .{};
    return window_caption_buttons_runtime.windowChromeContract(.terminal_integrated, geometry);
}
