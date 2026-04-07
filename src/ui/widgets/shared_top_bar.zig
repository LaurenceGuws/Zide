const app_shell = @import("../../app_shell.zig");
const renderer_chrome_band_host = @import("../renderer/renderer_chrome_band_host.zig");
const renderer_surface_host = @import("../renderer/renderer_surface_host.zig");
const shared_types = @import("../../types/mod.zig");
const geometry = @import("shared_top_bar_geometry.zig");
const model = @import("shared_top_bar_model.zig");

const Band = renderer_chrome_band_host.Band;
const Shell = app_shell.Shell;
const LayoutRect = shared_types.layout.Rect;

/// Shared editor/IDE top bar with menu-driven app actions.
pub const SharedTopBar = struct {
    pub const Action = model.Action;

    height: f32 = 26,
    last_mouse: shared_types.input.MousePos = .{ .x = 0, .y = 0 },
    mouse_down_left: bool = false,
    open_menu: ?model.MenuKind = null,

    pub fn updateInput(self: *SharedTopBar, input: shared_types.input.InputSnapshot) void {
        self.last_mouse = input.mouse_pos;
        self.mouse_down_left = input.mouse_down[@intFromEnum(shared_types.input.MouseButton.left)];
    }

    pub fn handleClick(self: *SharedTopBar, shell: *Shell, bar: LayoutRect, model_: *const model.SharedTopBarModel, mouse: shared_types.input.MousePos) ?Action {
        if (self.open_menu) |menu| {
            if (geometry.menuItemAt(shell, model_, bar, menu, mouse)) |action| {
                self.open_menu = null;
                return action;
            }
        }

        if (geometry.labelAt(shell, model_, bar, mouse)) |label| {
            if (label.menu) |menu| {
                self.open_menu = if (self.open_menu == menu) null else menu;
            } else {
                self.open_menu = null;
            }
            return null;
        }

        self.open_menu = null;
        return null;
    }

    pub fn draw(self: *SharedTopBar, shell: *Shell, bar: LayoutRect, model_: *const model.SharedTopBarModel) void {
        const theme = shell.theme();
        const band = Band.init(shell, theme.ui_panel_bg);
        band.fillRect(
            @intFromFloat(bar.x),
            @intFromFloat(bar.y),
            @intFromFloat(bar.width),
            @intFromFloat(bar.height),
            theme.ui_panel_bg,
        );

        const scale = shell.uiScaleFactor();
        const y = bar.y + (bar.height - shell.charHeight()) / 2;
        const mouse = self.last_mouse;
        const pressed = self.mouse_down_left;
        const window_focused = shell.windowFocused();

        var x = bar.x + 10 * scale;
        for (model_.labels) |label| {
            const rect = geometry.labelRectAt(shell, x, y, label.title);
            const hovered = window_focused and rect.contains(mouse);
            const active = label.menu != null and self.open_menu == label.menu.?;
            if (hovered or active) {
                const bg = if (active or pressed) theme.ui_pressed else theme.ui_hover;
                band.fillRect(@intFromFloat(rect.x), @intFromFloat(rect.y), @intFromFloat(rect.w), @intFromFloat(rect.h), bg);
            }
            band.drawText(label.title, x, y, if (hovered or active) theme.ui_text else theme.ui_text_inactive);
            x += rect.w + 4 * scale;
        }

        if (self.open_menu) |menu| {
            drawMenu(self, shell, bar, model_, menu);
        }
    }

    pub fn contentWidth(self: *const SharedTopBar, shell: *Shell, model_: *const model.SharedTopBarModel) f32 {
        return geometry.contentWidth(shell, model_, self.height);
    }

    fn drawMenu(self: *SharedTopBar, shell: *Shell, bar: LayoutRect, model_: *const model.SharedTopBarModel, menu: model.MenuKind) void {
        const theme = shell.theme();
        const scale = shell.uiScaleFactor();
        const mouse = self.last_mouse;
        const menu_box = geometry.menuRect(shell, model_, bar, menu);
        const shadow = app_shell.Color{ .r = 0, .g = 0, .b = 0, .a = 120 };
        const menu_band = Band.init(shell, theme.ui_bar_bg);
        renderer_surface_host.drawRect(shell.rendererPtr(), @intFromFloat(menu_box.x + 3 * scale), @intFromFloat(menu_box.y + 4 * scale), @intFromFloat(menu_box.w), @intFromFloat(menu_box.h), shadow);
        menu_band.fillRect(@intFromFloat(menu_box.x), @intFromFloat(menu_box.y), @intFromFloat(menu_box.w), @intFromFloat(menu_box.h), theme.ui_bar_bg);
        menu_band.drawRectOutline(@intFromFloat(menu_box.x), @intFromFloat(menu_box.y), @intFromFloat(menu_box.w), @intFromFloat(menu_box.h), theme.ui_border);

        for (model_.itemsFor(menu), 0..) |item, idx| {
            const rect = geometry.itemRect(shell, model_, bar, menu, idx);
            const hovered = rect.contains(mouse);
            const item_bg = if (hovered) theme.ui_pressed else theme.ui_bar_bg;
            menu_band.fillRect(@intFromFloat(rect.x), @intFromFloat(rect.y), @intFromFloat(rect.w), @intFromFloat(rect.h), item_bg);
            menu_band.drawTextOnColor(item.label, rect.x + 10 * scale, rect.y + 5 * scale, theme.ui_text, item_bg);
        }
    }
};
