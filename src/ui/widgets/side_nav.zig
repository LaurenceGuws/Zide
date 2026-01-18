const std = @import("std");
const renderer_mod = @import("../renderer.zig");

const Renderer = renderer_mod.Renderer;
const Color = renderer_mod.Color;

/// Side navigation bar (VSCode activity bar)
pub const SideNav = struct {
    width: f32 = 52,

    pub fn draw(self: *SideNav, r: *Renderer, height: f32, y: f32) void {
        // Background
        r.drawRect(0, @intFromFloat(y), @intFromFloat(self.width), @intFromFloat(height), Color{ .r = 30, .g = 31, .b = 41 });

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

        const icon_size: f32 = 32;
        const icon_h_unit: f32 = r.icon_char_height;
        const badge_size: f32 = r.font_size * 1.0;
        const badge_h_unit: f32 = r.char_height * (badge_size / r.font_size);
        const spacing: f32 = 12;
        const mouse = r.getMousePos();
        const pressed = r.isMouseButtonDown(renderer_mod.MOUSE_LEFT);

        const icon_x_pad: f32 = self.width * 0.30;
        const icon_text_offset: f32 = 1;
        var icon_y: f32 = y + 10;
        for (top_items) |item| {
            const icon_x: f32 = icon_x_pad;
            const bx = icon_x - 8;
            const by = icon_y - 6;
            const bw = icon_size + 16;
            const bh = icon_size + 12;
            const hovered = mouse.x >= bx and mouse.x <= bx + bw and mouse.y >= by and mouse.y <= by + bh;

            if (hovered or item.active) {
                const bg = if (pressed and hovered) Color{ .r = 58, .g = 60, .b = 78 } else Color.selection;
                r.drawRect(@intFromFloat(bx), @intFromFloat(by), @intFromFloat(bw), @intFromFloat(bh), bg);
            }
            if (item.active) {
                r.drawRect(0, @intFromFloat(by), 2, @intFromFloat(bh), Color.purple);
            }

            const icon_color = if (item.active or hovered) Color.fg else Color.comment;
            const icon_text_x = icon_x + icon_text_offset;
            const icon_text_y = icon_y + (icon_size - icon_h_unit) / 2;
            r.drawIconText(item.icon, icon_text_x, icon_text_y, icon_color);

            if (item.badge) |count| {
                var buf: [4]u8 = undefined;
                const text = std.fmt.bufPrint(&buf, "{d}", .{count}) catch "";
                const text_h = badge_h_unit;
                const badge_x = icon_x + icon_text_offset + 2;
                const badge_y = icon_y + (icon_size - text_h) / 2 + 1;
                r.drawTextSized(text, badge_x, badge_y, badge_size, Color.fg);
            }

            icon_y += icon_size + spacing;
        }

        var bottom_y: f32 = y + height - 10 - icon_size;
        var i: usize = 0;
        while (i < bottom_items.len) : (i += 1) {
            const item = bottom_items[bottom_items.len - 1 - i];
            const icon_x: f32 = icon_x_pad;
            const bx = icon_x - 8;
            const by = bottom_y - 6;
            const bw = icon_size + 16;
            const bh = icon_size + 12;
            const hovered = mouse.x >= bx and mouse.x <= bx + bw and mouse.y >= by and mouse.y <= by + bh;

            if (hovered or item.active) {
                const bg = if (pressed and hovered) Color{ .r = 58, .g = 60, .b = 78 } else Color.selection;
                r.drawRect(@intFromFloat(bx), @intFromFloat(by), @intFromFloat(bw), @intFromFloat(bh), bg);
            }
            if (item.active) {
                r.drawRect(0, @intFromFloat(by), 2, @intFromFloat(bh), Color.purple);
            }

            const icon_color = if (item.active or hovered) Color.fg else Color.comment;
            const icon_text_x = icon_x + icon_text_offset;
            const icon_text_y = bottom_y + (icon_size - icon_h_unit) / 2;
            r.drawIconText(item.icon, icon_text_x, icon_text_y, icon_color);

            bottom_y -= icon_size + spacing;
        }
    }
};
