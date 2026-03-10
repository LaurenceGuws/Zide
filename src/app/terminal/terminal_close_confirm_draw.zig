const app_modes = @import("../modes/mod.zig");
const app_shell = @import("../../app_shell.zig");
const shared_types = @import("../../types/mod.zig");

const Shell = app_shell.Shell;
const WidgetLayout = shared_types.layout.WidgetLayout;

pub fn draw(shell: *Shell, layout: WidgetLayout, app_theme: app_shell.Theme) void {
    const modal = app_modes.ide.terminalCloseConfirmModalLayout(layout, shell.uiScaleFactor());
    const overlay = app_shell.Color{ .r = 0, .g = 0, .b = 0, .a = 160 };
    const card_bg = app_theme.ui_panel_bg;
    const card_border = app_theme.ui_border;
    const confirm_bg = app_shell.Color{ .r = 186, .g = 64, .b = 64 };
    const cancel_bg = app_theme.ui_tab_inactive_bg;

    shell.drawRect(
        @intFromFloat(layout.window.x),
        @intFromFloat(layout.window.y),
        @intFromFloat(layout.window.width),
        @intFromFloat(layout.window.height),
        overlay,
    );

    shell.drawRect(
        @intFromFloat(modal.card.x),
        @intFromFloat(modal.card.y),
        @intFromFloat(modal.card.width),
        @intFromFloat(modal.card.height),
        card_bg,
    );
    shell.drawRectOutline(
        @intFromFloat(modal.card.x),
        @intFromFloat(modal.card.y),
        @intFromFloat(modal.card.width),
        @intFromFloat(modal.card.height),
        card_border,
    );

    const scale = shell.uiScaleFactor();
    const title = "Close Running Terminal Tab?";
    const message = "This tab still has a running process. Close anyway?";
    const title_x = modal.card.x + 16.0 * scale;
    const title_y = modal.card.y + 14.0 * scale;
    const msg_y = title_y + shell.charHeight() + 10.0 * scale;
    shell.drawText(title, title_x, title_y, app_theme.ui_text);
    shell.drawText(message, title_x, msg_y, app_theme.ui_text_inactive);

    shell.drawRect(
        @intFromFloat(modal.cancel_button.x),
        @intFromFloat(modal.cancel_button.y),
        @intFromFloat(modal.cancel_button.width),
        @intFromFloat(modal.cancel_button.height),
        cancel_bg,
    );
    shell.drawRectOutline(
        @intFromFloat(modal.cancel_button.x),
        @intFromFloat(modal.cancel_button.y),
        @intFromFloat(modal.cancel_button.width),
        @intFromFloat(modal.cancel_button.height),
        card_border,
    );
    shell.drawText(
        "Cancel (Esc / N)",
        modal.cancel_button.x + 10.0 * scale,
        modal.cancel_button.y + (modal.cancel_button.height - shell.charHeight()) / 2.0,
        app_theme.ui_text,
    );

    shell.drawRect(
        @intFromFloat(modal.confirm_button.x),
        @intFromFloat(modal.confirm_button.y),
        @intFromFloat(modal.confirm_button.width),
        @intFromFloat(modal.confirm_button.height),
        confirm_bg,
    );
    shell.drawRectOutline(
        @intFromFloat(modal.confirm_button.x),
        @intFromFloat(modal.confirm_button.y),
        @intFromFloat(modal.confirm_button.width),
        @intFromFloat(modal.confirm_button.height),
        card_border,
    );
    shell.drawText(
        "Close Tab (Enter / Y)",
        modal.confirm_button.x + 10.0 * scale,
        modal.confirm_button.y + (modal.confirm_button.height - shell.charHeight()) / 2.0,
        app_shell.Color{ .r = 255, .g = 255, .b = 255 },
    );
}
