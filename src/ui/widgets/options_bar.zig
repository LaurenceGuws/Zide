const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const shared_types = @import("../../types/mod.zig");

const Shell = app_shell.Shell;

/// Top options bar with a small shared app/editor action surface.
pub const OptionsBar = struct {
    pub const Action = enum {
        new_file,
        open_file,
        save,
        save_as,
        find,
        replace,
        replace_all,
        cycle_imported_theme_prev,
        cycle_imported_theme,
    };

    const MenuKind = enum {
        file,
        edit,
        view,
    };

    const MenuLabel = struct {
        title: []const u8,
        menu: ?MenuKind,
    };

    const MenuItem = struct {
        label: []const u8,
        action: Action,
    };

    const Rect = struct {
        x: f32,
        y: f32,
        w: f32,
        h: f32,

        fn contains(self: Rect, mouse: shared_types.input.MousePos) bool {
            return mouse.x >= self.x and mouse.x <= self.x + self.w and mouse.y >= self.y and mouse.y <= self.y + self.h;
        }
    };

    height: f32 = 26,
    last_mouse: shared_types.input.MousePos = .{ .x = 0, .y = 0 },
    mouse_down_left: bool = false,
    open_menu: ?MenuKind = null,

    const labels = [_]MenuLabel{
        .{ .title = "File", .menu = .file },
        .{ .title = "Edit", .menu = .edit },
        .{ .title = "Selection", .menu = null },
        .{ .title = "View", .menu = .view },
        .{ .title = "Go", .menu = null },
        .{ .title = "Run", .menu = null },
        .{ .title = "Terminal", .menu = null },
        .{ .title = "Help", .menu = null },
    };

    const file_items = [_]MenuItem{
        .{ .label = "New", .action = .new_file },
        .{ .label = "Open...", .action = .open_file },
        .{ .label = "Save", .action = .save },
        .{ .label = "Save As...", .action = .save_as },
    };

    const edit_items = [_]MenuItem{
        .{ .label = "Find", .action = .find },
        .{ .label = "Replace", .action = .replace },
        .{ .label = "Replace All", .action = .replace_all },
    };

    const view_items = [_]MenuItem{
        .{ .label = "Previous Imported Theme", .action = .cycle_imported_theme_prev },
        .{ .label = "Next Imported Theme", .action = .cycle_imported_theme },
    };

    pub fn updateInput(self: *OptionsBar, input: shared_types.input.InputSnapshot) void {
        self.last_mouse = input.mouse_pos;
        self.mouse_down_left = input.mouse_down[@intFromEnum(shared_types.input.MouseButton.left)];
    }

    pub fn handleClick(self: *OptionsBar, shell: *Shell, width: f32, mouse: shared_types.input.MousePos) ?Action {
        _ = width;
        if (self.open_menu) |menu| {
            if (menuItemAt(self, shell, menu, mouse)) |action| {
                self.open_menu = null;
                return action;
            }
        }

        if (labelAt(self, shell, mouse)) |label| {
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

    pub fn draw(self: *OptionsBar, shell: *Shell, width: f32) void {
        const theme = shell.theme();
        shell.drawRect(0, 0, @intFromFloat(width), @intFromFloat(self.height), theme.ui_panel_bg);

        const scale = shell.uiScaleFactor();
        const y: f32 = (self.height - shell.charHeight()) / 2;
        const mouse = self.last_mouse;
        const pressed = self.mouse_down_left;
        const window_focused = shell.windowFocused();

        var x: f32 = 10 * scale;
        for (labels) |label| {
            const rect = labelRect(shell, x, y, label.title);
            const hovered = window_focused and rect.contains(mouse);
            const active = label.menu != null and self.open_menu == label.menu.?;
            if (hovered or active) {
                const bg = if (active or pressed) theme.ui_pressed else theme.ui_hover;
                shell.drawRect(@intFromFloat(rect.x), @intFromFloat(rect.y), @intFromFloat(rect.w), @intFromFloat(rect.h), bg);
            }
            shell.drawText(label.title, x, y, if (hovered or active) theme.ui_text else theme.ui_text_inactive);
            x += rect.w + 4 * scale;
        }

        if (self.open_menu) |menu| {
            drawMenu(self, shell, menu);
        }
    }

    fn itemsFor(menu: MenuKind) []const MenuItem {
        return switch (menu) {
            .file => &file_items,
            .edit => &edit_items,
            .view => &view_items,
        };
    }

    fn labelRect(shell: *Shell, x: f32, y: f32, label: []const u8) Rect {
        const scale = shell.uiScaleFactor();
        const text_w = @as(f32, @floatFromInt(label.len)) * shell.charWidth();
        const pad_x: f32 = 6 * scale;
        const pad_y: f32 = 4 * scale;
        return .{
            .x = x - pad_x,
            .y = y - pad_y,
            .w = text_w + pad_x * 2,
            .h = shell.charHeight() + pad_y * 2,
        };
    }

    fn labelAt(self: *OptionsBar, shell: *Shell, mouse: shared_types.input.MousePos) ?MenuLabel {
        const scale = shell.uiScaleFactor();
        const y: f32 = (self.height - shell.charHeight()) / 2;
        var x: f32 = 10 * scale;
        for (labels) |label| {
            const rect = labelRect(shell, x, y, label.title);
            if (rect.contains(mouse)) return label;
            x += rect.w + 4 * scale;
        }
        return null;
    }

    fn menuAnchorRect(self: *OptionsBar, shell: *Shell, menu: MenuKind) ?Rect {
        const scale = shell.uiScaleFactor();
        const y: f32 = (self.height - shell.charHeight()) / 2;
        var x: f32 = 10 * scale;
        for (labels) |label| {
            const rect = labelRect(shell, x, y, label.title);
            if (label.menu != null and label.menu.? == menu) return rect;
            x += rect.w + 4 * scale;
        }
        return null;
    }

    fn menuRect(self: *OptionsBar, shell: *Shell, menu: MenuKind) Rect {
        const scale = shell.uiScaleFactor();
        const anchor = menuAnchorRect(self, shell, menu).?;
        const items = itemsFor(menu);
        var max_label_len: usize = 0;
        for (items) |item| {
            max_label_len = @max(max_label_len, item.label.len);
        }
        const pad_x: f32 = 10 * scale;
        const item_h: f32 = shell.charHeight() + 10 * scale;
        const menu_w = @as(f32, @floatFromInt(max_label_len)) * shell.charWidth() + pad_x * 2;
        return .{
            .x = anchor.x,
            .y = self.height + 4 * scale,
            .w = menu_w + 18 * scale,
            .h = item_h * @as(f32, @floatFromInt(items.len)) + 8 * scale,
        };
    }

    fn itemRect(self: *OptionsBar, shell: *Shell, menu: MenuKind, item_index: usize) Rect {
        const scale = shell.uiScaleFactor();
        const base = menuRect(self, shell, menu);
        const item_h: f32 = shell.charHeight() + 10 * scale;
        return .{
            .x = base.x + 4 * scale,
            .y = base.y + 4 * scale + item_h * @as(f32, @floatFromInt(item_index)),
            .w = base.w - 8 * scale,
            .h = item_h,
        };
    }

    fn menuItemAt(self: *OptionsBar, shell: *Shell, menu: MenuKind, mouse: shared_types.input.MousePos) ?Action {
        const items = itemsFor(menu);
        for (items, 0..) |item, idx| {
            if (itemRect(self, shell, menu, idx).contains(mouse)) return item.action;
        }
        return null;
    }

    fn drawMenu(self: *OptionsBar, shell: *Shell, menu: MenuKind) void {
        const theme = shell.theme();
        const scale = shell.uiScaleFactor();
        const mouse = self.last_mouse;
        const menu_box = menuRect(self, shell, menu);
        const shadow = app_shell.Color{ .r = 0, .g = 0, .b = 0, .a = 120 };
        shell.drawRect(@intFromFloat(menu_box.x + 3 * scale), @intFromFloat(menu_box.y + 4 * scale), @intFromFloat(menu_box.w), @intFromFloat(menu_box.h), shadow);
        shell.drawRect(@intFromFloat(menu_box.x), @intFromFloat(menu_box.y), @intFromFloat(menu_box.w), @intFromFloat(menu_box.h), theme.ui_bar_bg);
        shell.drawRectOutline(@intFromFloat(menu_box.x), @intFromFloat(menu_box.y), @intFromFloat(menu_box.w), @intFromFloat(menu_box.h), theme.ui_border);

        for (itemsFor(menu), 0..) |item, idx| {
            const rect = itemRect(self, shell, menu, idx);
            const hovered = rect.contains(mouse);
            const item_bg = if (hovered) theme.ui_pressed else theme.ui_bar_bg;
            shell.drawRect(@intFromFloat(rect.x), @intFromFloat(rect.y), @intFromFloat(rect.w), @intFromFloat(rect.h), item_bg);
            shell.drawTextOnBg(item.label, rect.x + 10 * scale, rect.y + 5 * scale, theme.ui_text, item_bg);
        }
    }
};
