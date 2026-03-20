const builtin = @import("builtin");
const app_bootstrap = @import("../bootstrap.zig");
const app_shell = @import("../../app_shell.zig");
const app_terminal_tabs_runtime = @import("terminal_tabs_runtime.zig");
const app_modes = @import("../modes/mod.zig");
const app_types = @import("../app_state_types.zig");
const shared_types = @import("../../types/mod.zig");
const widgets = @import("../../ui/widgets.zig");

const Rect = shared_types.layout.Rect;
const Shell = app_shell.Shell;
const TabBar = widgets.TabBar;
const TerminalWorkspace = @import("../../terminal/core/terminal.zig").TerminalWorkspace;

pub const CaptionButton = app_types.TerminalWindowCaptionButton;

pub const Geometry = struct {
    enabled: bool,
    band: Rect,
    tab_strip_width: f32,
    tabs_used_width: f32,
    caption_rect: Rect,
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
            .minimize_rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .maximize_rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .close_rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .resize_border_px = 0,
        };
    }

    const scale = shell.uiScaleFactor();
    const button_width = @max(46.0 * scale, band.height * 1.35);
    const button_total_width = button_width * 3.0;
    const drag_min_width = @max(56.0 * scale, band.height * 1.5);
    const tab_strip_width = @max(0.0, band.width - button_total_width - drag_min_width);
    const tabs_used_width = @min(tab_strip_width, tab_bar.contentWidth(tab_strip_width, shell.charWidth(), scale));
    const buttons_x = band.x + band.width - button_total_width;
    const caption_x = band.x + tabs_used_width;
    const caption_width = @max(0.0, buttons_x - caption_x);

    return .{
        .enabled = true,
        .band = band,
        .tab_strip_width = tab_strip_width,
        .tabs_used_width = tabs_used_width,
        .caption_rect = .{
            .x = caption_x,
            .y = band.y,
            .width = caption_width,
            .height = band.height,
        },
        .minimize_rect = .{
            .x = buttons_x,
            .y = band.y,
            .width = button_width,
            .height = band.height,
        },
        .maximize_rect = .{
            .x = buttons_x + button_width,
            .y = band.y,
            .width = button_width,
            .height = band.height,
        },
        .close_rect = .{
            .x = buttons_x + (button_width * 2.0),
            .y = band.y,
            .width = button_width,
            .height = band.height,
        },
        .resize_border_px = @max(6.0, 8.0 * scale),
    };
}

pub fn buttonAt(geometry: Geometry, x: f32, y: f32) ?CaptionButton {
    if (!geometry.enabled) return null;
    if (pointInRect(x, y, geometry.minimize_rect)) return .minimize;
    if (pointInRect(x, y, geometry.maximize_rect)) return .maximize_restore;
    if (pointInRect(x, y, geometry.close_rect)) return .close;
    return null;
}

pub fn windowChromeContract(geometry: Geometry) app_shell.WindowChromeContract {
    if (!geometry.enabled) return .{};
    return .{
        .mode = .terminal_integrated,
        .caption_rect = geometry.caption_rect,
        .resize_border_px = geometry.resize_border_px,
    };
}

fn pointInRect(x: f32, y: f32, rect: Rect) bool {
    return x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height;
}
