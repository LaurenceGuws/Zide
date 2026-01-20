const std = @import("std");
const renderer_mod = @import("../renderer.zig");
const common = @import("common.zig");

const Renderer = renderer_mod.Renderer;
const Color = renderer_mod.Color;
const Tooltip = common.Tooltip;

pub const TabBar = struct {
    allocator: std.mem.Allocator,
    tabs: std.ArrayList(Tab),
    active_index: usize,
    height: f32,
    tab_width: f32,
    tab_spacing: f32,

    pub const Tab = struct {
        title: []const u8,
        kind: Kind,
        modified: bool,

        pub const Kind = enum { editor, terminal };
    };

    pub fn init(allocator: std.mem.Allocator) TabBar {
        return .{
            .allocator = allocator,
            .tabs = .empty,
            .active_index = 0,
            .height = 28,
            .tab_width = 150,
            .tab_spacing = 1,
        };
    }

    pub fn deinit(self: *TabBar) void {
        self.tabs.deinit(self.allocator);
    }

    pub fn addTab(self: *TabBar, title: []const u8, kind: Tab.Kind) !void {
        try self.tabs.append(self.allocator, .{
            .title = title,
            .kind = kind,
            .modified = false,
        });
    }

    pub fn draw(self: *TabBar, r: *Renderer, x: f32, y: f32, width: f32) void {
        // Draw tab bar background
        r.drawRect(@intFromFloat(x), @intFromFloat(y), @intFromFloat(width), @intFromFloat(self.height), Color{ .r = 30, .g = 31, .b = 41 });

        if (width <= 0 or self.height <= 0) return;

        r.beginClip(@intFromFloat(x), @intFromFloat(y), @intFromFloat(width), @intFromFloat(self.height));

        var tooltip: ?Tooltip = null;
        const mouse = r.getMousePos();

        var cursor_x: f32 = x;
        for (self.tabs.items, 0..) |tab, i| {
            const is_active = i == self.active_index;

            // Tab background
            const bg = if (is_active)
                Color.bg
            else
                Color{ .r = 35, .g = 36, .b = 48 };
            r.drawRect(@intFromFloat(cursor_x), @intFromFloat(y), @intFromFloat(self.tab_width), @intFromFloat(self.height), bg);

            // Tab border
            if (is_active) {
                const border_h: f32 = @max(1.0, r.uiScaleFactor() * 2.0);
                r.drawRect(@intFromFloat(cursor_x), @intFromFloat(y + self.height - border_h), @intFromFloat(self.tab_width), @intFromFloat(border_h), Color.purple);
            }

            // Tab title
            const title_x = cursor_x + 8 * r.uiScaleFactor();
            const title_y = y + (self.height - r.char_height) / 2;

            // Modified indicator
            if (tab.modified) {
                r.drawText("* ", title_x, title_y, Color.orange);
            }

            const prefix_width: f32 = if (tab.modified) r.char_width * 2 else 0;
            const title_max = self.tab_width - 16 * r.uiScaleFactor() - prefix_width;
            const result = common.drawTruncatedText(
                r,
                tab.title,
                title_x + prefix_width,
                title_y,
                if (is_active) Color.fg else Color.comment,
                title_max,
            );
            const in_tab = mouse.x >= cursor_x and mouse.x <= cursor_x + self.tab_width and
                mouse.y >= y and mouse.y <= y + self.height;
            if (result.truncated and in_tab) {
                tooltip = .{ .text = tab.title, .x = mouse.x, .y = mouse.y };
            }

            cursor_x += self.tab_width + self.tab_spacing;
        }

        r.endClip();

        if (tooltip) |tip| {
            common.drawTooltip(r, tip.text, tip.x, tip.y);
        }
    }

    pub fn handleClick(self: *TabBar, x: f32, y: f32, bar_x: f32, bar_y: f32) bool {
        if (y < bar_y or y > bar_y + self.height) return false;
        if (x < bar_x) return false;

        const clicked_index = @as(usize, @intFromFloat((x - bar_x) / (self.tab_width + self.tab_spacing)));

        if (clicked_index < self.tabs.items.len) {
            self.active_index = clicked_index;
            return true;
        }
        return false;
    }
};
