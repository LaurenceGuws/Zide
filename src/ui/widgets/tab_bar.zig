const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const common = @import("common.zig");
const shared_types = @import("../../types/mod.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const Tooltip = common.Tooltip;

pub const TabBar = struct {
    allocator: std.mem.Allocator,
    tabs: std.ArrayList(Tab),
    active_index: usize,
    height: f32,
    tab_width: f32,
    tab_spacing: f32,
    last_mouse: shared_types.input.MousePos,

    pub const Tab = struct {
        title: []u8,
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
            .last_mouse = .{ .x = 0, .y = 0 },
        };
    }

    pub fn deinit(self: *TabBar) void {
        for (self.tabs.items) |tab| {
            self.allocator.free(tab.title);
        }
        self.tabs.deinit(self.allocator);
    }

    pub fn addTab(self: *TabBar, title: []const u8, kind: Tab.Kind) !void {
        const owned_title = try self.allocator.dupe(u8, title);
        errdefer self.allocator.free(owned_title);
        try self.tabs.append(self.allocator, .{
            .title = owned_title,
            .kind = kind,
            .modified = false,
        });
    }

    pub fn updateInput(self: *TabBar, input: shared_types.input.InputSnapshot) void {
        self.last_mouse = input.mouse_pos;
    }

    pub fn draw(self: *TabBar, shell: *Shell, x: f32, y: f32, width: f32) ?Tooltip {
        const theme = shell.theme();
        // Draw tab bar background
        shell.drawRect(@intFromFloat(x), @intFromFloat(y), @intFromFloat(width), @intFromFloat(self.height), theme.ui_bar_bg);

        if (width <= 0 or self.height <= 0) return null;

        shell.beginClip(@intFromFloat(x), @intFromFloat(y), @intFromFloat(width), @intFromFloat(self.height));

        var tooltip: ?Tooltip = null;
        const mouse = self.last_mouse;

        var cursor_x: f32 = x;
        for (self.tabs.items, 0..) |tab, i| {
            const is_active = i == self.active_index;

            // Tab background
            const bg = if (is_active)
                theme.background
            else
                theme.ui_tab_inactive_bg;
            shell.drawRect(@intFromFloat(cursor_x), @intFromFloat(y), @intFromFloat(self.tab_width), @intFromFloat(self.height), bg);

            // Tab border
            if (is_active) {
                const border_h: f32 = @max(1.0, shell.uiScaleFactor() * 2.0);
                shell.drawRect(@intFromFloat(cursor_x), @intFromFloat(y + self.height - border_h), @intFromFloat(self.tab_width), @intFromFloat(border_h), theme.ui_accent);
            }

            // Tab title
            const title_x = cursor_x + 8 * shell.uiScaleFactor();
            const title_y = y + (self.height - shell.charHeight()) / 2;

            // Modified indicator
            if (tab.modified) {
                shell.drawText("* ", title_x, title_y, theme.ui_modified);
            }

            const prefix_width: f32 = if (tab.modified) shell.charWidth() * 2 else 0;
            const title_max = self.tab_width - 16 * shell.uiScaleFactor() - prefix_width;
            const result = common.drawTruncatedText(
                shell,
                tab.title,
                title_x + prefix_width,
                title_y,
                if (is_active) theme.ui_text else theme.ui_text_inactive,
                title_max,
            );
            const in_tab = mouse.x >= cursor_x and mouse.x <= cursor_x + self.tab_width and
                mouse.y >= y and mouse.y <= y + self.height;
            if (result.truncated and in_tab) {
                tooltip = .{ .text = tab.title, .x = mouse.x, .y = mouse.y };
            }

            cursor_x += self.tab_width + self.tab_spacing;
        }

        shell.endClip();
        return tooltip;
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
