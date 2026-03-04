const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const app_shell = @import("../app_shell.zig");
const shared_types = @import("../types/mod.zig");

const AppMode = app_bootstrap.AppMode;
const WidgetLayout = shared_types.layout.WidgetLayout;
const Shell = app_shell.Shell;

pub fn draw(
    shell: *Shell,
    layout: WidgetLayout,
    app_mode: AppMode,
    terminal_tab_bar_visible: bool,
    config_reload_notice_until: f64,
    config_reload_notice_success: bool,
    app_theme: app_shell.Theme,
) void {
    const now = app_shell.getTime();
    if (now >= config_reload_notice_until) return;

    const text = if (config_reload_notice_success) "Config reloaded" else "Config reload failed";
    const scale = shell.uiScaleFactor();
    const pad_x = 10.0 * scale;
    const pad_y = 6.0 * scale;
    const text_w = @as(f32, @floatFromInt(text.len)) * shell.charWidth();
    const notice_w = text_w + pad_x * 2.0;
    const notice_h = shell.charHeight() + pad_y * 2.0;
    const margin = 10.0 * scale;
    const x = layout.window.width - notice_w - margin;
    const y = app_modes.ide.configReloadNoticeY(
        app_mode,
        terminal_tab_bar_visible,
        layout,
        margin,
    );

    const bg = if (config_reload_notice_success)
        app_theme.ui_accent
    else
        app_shell.Color{ .r = 186, .g = 64, .b = 64 };
    const fg = if (config_reload_notice_success)
        app_theme.background
    else
        app_shell.Color{ .r = 255, .g = 255, .b = 255 };

    shell.drawRect(
        @intFromFloat(x),
        @intFromFloat(y),
        @intFromFloat(notice_w),
        @intFromFloat(notice_h),
        bg,
    );
    shell.drawRectOutline(
        @intFromFloat(x),
        @intFromFloat(y),
        @intFromFloat(notice_w),
        @intFromFloat(notice_h),
        app_theme.ui_border,
    );
    shell.drawText(
        text,
        x + pad_x,
        y + (notice_h - shell.charHeight()) / 2.0,
        fg,
    );
}
