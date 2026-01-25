const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const shared_types = @import("../../types/mod.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;

/// Side navigation bar (VSCode activity bar)
pub const SideNav = struct {
    width: f32 = 52,

    pub fn draw(self: *SideNav, shell: *Shell, height: f32, y: f32, input: shared_types.input.InputSnapshot) void {
        // Background
        shell.drawRect(0, @intFromFloat(y), @intFromFloat(self.width), @intFromFloat(height), Color{ .r = 30, .g = 31, .b = 41 });

        const Item = struct {
            icon: []const u8,
            badge: ?u8,
            active: bool,
        };
        const top_items = [_]Item{
            .{ .icon = "", .badge = 1, .active = true }, // Workspace 1
            .{ .icon = "", .badge = 2, .active = false }, // Workspace 2
            .{ .icon = "", .badge = 3, .active = false }, // Workspace 3
        };
        const bottom_items = [_]Item{
            .{ .icon = "", .badge = null, .active = false }, // Search
            .{ .icon = "", .badge = null, .active = false }, // Source Control
            .{ .icon = "", .badge = null, .active = false }, // Run/Debug
            .{ .icon = "", .badge = null, .active = false }, // Extensions
            .{ .icon = "", .badge = null, .active = false }, // Settings
            .{ .icon = "󰏗", .badge = null, .active = false }, // Accounts
        };

        const scale = shell.uiScaleFactor();
        const icon_size: f32 = 32 * scale;
        const icon_h_unit: f32 = shell.iconCharHeight();
        const badge_size: f32 = shell.fontSize() * 1.0;
        const badge_h_unit: f32 = shell.charHeight() * (badge_size / shell.fontSize());
        const spacing: f32 = 12 * scale;
        const mouse = input.mouse_pos;
        const pressed = input.mouse_down[@intFromEnum(shared_types.input.MouseButton.left)];
        const hover_pad_x: f32 = 8 * scale;
        const hover_pad_y: f32 = 8 * scale;

        const icon_x_pad: f32 = self.width * 0.30;
        const icon_text_offset: f32 = 1 * scale;
        var icon_y: f32 = y + 10 * scale;
        for (top_items) |item| {
            const icon_x: f32 = icon_x_pad;
            const bx = icon_x - hover_pad_x;
            const by = icon_y - hover_pad_y;
            const bw = icon_size + hover_pad_x * 2;
            const bh = icon_size + hover_pad_y * 2;
            const hovered = mouse.x >= bx and mouse.x <= bx + bw and mouse.y >= by and mouse.y <= by + bh;

            if (hovered or item.active) {
                const bg = if (pressed and hovered) Color{ .r = 58, .g = 60, .b = 78 } else Color.selection;
                shell.drawRect(@intFromFloat(bx), @intFromFloat(by), @intFromFloat(bw), @intFromFloat(bh), bg);
            }
            if (item.active) {
                shell.drawRect(0, @intFromFloat(by), 2, @intFromFloat(bh), Color.purple);
            }

            const icon_color = if (item.active or hovered) Color.fg else Color.comment;
            const icon_text_x = icon_x + icon_text_offset;
            const icon_text_y = icon_y + (icon_size - icon_h_unit) / 2;
            shell.drawIconText(item.icon, icon_text_x, icon_text_y, icon_color);

            if (item.badge) |count| {
                var buf: [4]u8 = undefined;
                const text = std.fmt.bufPrint(&buf, "{d}", .{count}) catch "";
                const text_h = badge_h_unit;
                const badge_x = icon_x + icon_text_offset + 2;
                const badge_y = icon_y + (icon_size - text_h) / 2 + 1;
                shell.drawTextSized(text, badge_x, badge_y, badge_size, Color.fg);
            }

            icon_y += icon_size + spacing;
        }

        var bottom_y: f32 = y + height - 10 * scale - icon_size;
        var i: usize = 0;
        while (i < bottom_items.len) : (i += 1) {
            const item = bottom_items[bottom_items.len - 1 - i];
            const icon_x: f32 = icon_x_pad;
            const bx = icon_x - hover_pad_x;
            const by = bottom_y - hover_pad_y;
            const bw = icon_size + hover_pad_x * 2;
            const bh = icon_size + hover_pad_y * 2;
            const hovered = mouse.x >= bx and mouse.x <= bx + bw and mouse.y >= by and mouse.y <= by + bh;

            if (hovered or item.active) {
                const bg = if (pressed and hovered) Color{ .r = 58, .g = 60, .b = 78 } else Color.selection;
                shell.drawRect(@intFromFloat(bx), @intFromFloat(by), @intFromFloat(bw), @intFromFloat(bh), bg);
            }
            if (item.active) {
                shell.drawRect(0, @intFromFloat(by), 2, @intFromFloat(bh), Color.purple);
            }

            const icon_color = if (item.active or hovered) Color.fg else Color.comment;
            const icon_text_x = icon_x + icon_text_offset;
            const icon_text_y = bottom_y + (icon_size - icon_h_unit) / 2;
            shell.drawIconText(item.icon, icon_text_x, icon_text_y, icon_color);

            bottom_y -= icon_size + spacing;
        }
    }
};
