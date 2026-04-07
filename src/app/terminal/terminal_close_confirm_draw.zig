const app_modes = @import("../modes/mod.zig");
const app_shell = @import("../../app_shell.zig");
const app_state_types = @import("../app_state_types.zig");
const renderer_surface_host = @import("../../ui/renderer/renderer_surface_host.zig");
const workspace_host = @import("../../terminal/core/workspace_host.zig");
const shared_types = @import("../../types/mod.zig");

const Shell = app_shell.Shell;
const WidgetLayout = shared_types.layout.WidgetLayout;

fn closeConfirmMessage(ctx: ?app_state_types.TerminalCloseConfirmContext) []const u8 {
    if (ctx) |value| {
        if (value.foreground_process_present and value.foreground_process_label.len > 0) {
            return "This tab still has a foreground process. Close anyway?";
        }
        if (value.semantic_command_active) {
            return "This tab still has an active command. Close anyway?";
        }
    }
    return "This tab still has a running process. Close anyway?";
}

pub fn draw(state: anytype, shell: *Shell, layout: WidgetLayout, app_theme: app_shell.Theme) void {
    const modal = app_modes.ide.terminalCloseConfirmModalLayout(layout, shell.uiScaleFactor());
    const overlay = app_shell.Color{ .r = 0, .g = 0, .b = 0, .a = 160 };
    const card_bg = app_theme.ui_panel_bg;
    const card_border = app_theme.ui_border;
    const confirm_bg = app_shell.Color{ .r = 186, .g = 64, .b = 64 };
    const cancel_bg = app_theme.ui_tab_inactive_bg;
    const confirm_ctx = if (state.terminal_workspace) |*workspace|
        if (state.terminal_close_confirm_tab) |tab_id|
            workspace_host.closeConfirmContextForTabId(workspace, tab_id)
        else
            null
    else
        null;

    renderer_surface_host.drawRect(shell.rendererPtr(),
        @intFromFloat(layout.window.x),
        @intFromFloat(layout.window.y),
        @intFromFloat(layout.window.width),
        @intFromFloat(layout.window.height),
        overlay,
    );

    renderer_surface_host.drawRect(shell.rendererPtr(),
        @intFromFloat(modal.card.x),
        @intFromFloat(modal.card.y),
        @intFromFloat(modal.card.width),
        @intFromFloat(modal.card.height),
        card_bg,
    );
    renderer_surface_host.drawRectOutline(shell.rendererPtr(),
        @intFromFloat(modal.card.x),
        @intFromFloat(modal.card.y),
        @intFromFloat(modal.card.width),
        @intFromFloat(modal.card.height),
        card_border,
    );

    const scale = shell.uiScaleFactor();
    const title = "Close Running Terminal Tab?";
    const message = closeConfirmMessage(confirm_ctx);
    const title_x = modal.card.x + 16.0 * scale;
    const title_y = modal.card.y + 14.0 * scale;
    const msg_y = title_y + shell.charHeight() + 10.0 * scale;
    shell.drawText(title, title_x, title_y, app_theme.ui_text);
    shell.drawText(message, title_x, msg_y, app_theme.ui_text_inactive);

    renderer_surface_host.drawRect(shell.rendererPtr(),
        @intFromFloat(modal.cancel_button.x),
        @intFromFloat(modal.cancel_button.y),
        @intFromFloat(modal.cancel_button.width),
        @intFromFloat(modal.cancel_button.height),
        cancel_bg,
    );
    renderer_surface_host.drawRectOutline(shell.rendererPtr(),
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

    renderer_surface_host.drawRect(shell.rendererPtr(),
        @intFromFloat(modal.confirm_button.x),
        @intFromFloat(modal.confirm_button.y),
        @intFromFloat(modal.confirm_button.width),
        @intFromFloat(modal.confirm_button.height),
        confirm_bg,
    );
    renderer_surface_host.drawRectOutline(shell.rendererPtr(),
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
