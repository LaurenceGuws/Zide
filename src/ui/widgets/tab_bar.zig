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
    drag_active: bool,
    drag_index: usize,
    drag_moved: bool,

    pub const Tab = struct {
        title: []u8,
        kind: Kind,
        modified: bool,
        terminal_tab_id: ?u64 = null,

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
            .drag_active = false,
            .drag_index = 0,
            .drag_moved = false,
        };
    }

    pub fn deinit(self: *TabBar) void {
        for (self.tabs.items) |tab| {
            self.allocator.free(tab.title);
        }
        self.tabs.deinit(self.allocator);
    }

    pub fn clearTabs(self: *TabBar) void {
        for (self.tabs.items) |tab| {
            self.allocator.free(tab.title);
        }
        self.tabs.clearRetainingCapacity();
        self.active_index = 0;
        self.drag_active = false;
        self.drag_index = 0;
        self.drag_moved = false;
    }

    pub fn addTab(self: *TabBar, title: []const u8, kind: Tab.Kind) !void {
        const owned_title = try self.allocator.dupe(u8, title);
        errdefer self.allocator.free(owned_title);
        try self.tabs.append(self.allocator, .{
            .title = owned_title,
            .kind = kind,
            .modified = false,
            .terminal_tab_id = null,
        });
    }

    pub fn addTerminalTab(self: *TabBar, title: []const u8, terminal_tab_id: u64) !void {
        const owned_title = try self.allocator.dupe(u8, title);
        errdefer self.allocator.free(owned_title);
        try self.tabs.append(self.allocator, .{
            .title = owned_title,
            .kind = .terminal,
            .modified = false,
            .terminal_tab_id = terminal_tab_id,
        });
    }

    pub fn setTabTitle(self: *TabBar, index: usize, title: []const u8) !void {
        if (index >= self.tabs.items.len) return;
        if (std.mem.eql(u8, self.tabs.items[index].title, title)) return;
        const owned_title = try self.allocator.dupe(u8, title);
        self.allocator.free(self.tabs.items[index].title);
        self.tabs.items[index].title = owned_title;
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
            const is_dragging_tab = self.drag_active and i == self.drag_index;
            const tab_y = if (is_dragging_tab) y - @max(1.0, shell.uiScaleFactor() * 2.0) else y;
            const tab_h = if (is_dragging_tab) self.height + @max(1.0, shell.uiScaleFactor() * 2.0) else self.height;

            // Tab background
            const bg = if (is_active)
                theme.background
            else
                theme.ui_tab_inactive_bg;
            shell.drawRect(
                @intFromFloat(cursor_x),
                @intFromFloat(tab_y),
                @intFromFloat(self.tab_width),
                @intFromFloat(tab_h),
                if (is_dragging_tab) theme.ui_hover else bg,
            );

            // Tab border
            if (is_active) {
                const border_h: f32 = @max(1.0, shell.uiScaleFactor() * 2.0);
                shell.drawRect(
                    @intFromFloat(cursor_x),
                    @intFromFloat(tab_y + tab_h - border_h),
                    @intFromFloat(self.tab_width),
                    @intFromFloat(border_h),
                    theme.ui_accent,
                );
            }
            if (is_dragging_tab) {
                const top_h: f32 = @max(1.0, shell.uiScaleFactor() * 2.0);
                shell.drawRect(
                    @intFromFloat(cursor_x),
                    @intFromFloat(tab_y),
                    @intFromFloat(self.tab_width),
                    @intFromFloat(top_h),
                    theme.ui_accent,
                );
            }

            // Tab title
            const title_x = cursor_x + 8 * shell.uiScaleFactor();
            const title_y = tab_y + (tab_h - shell.charHeight()) / 2;

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
        const clicked_index = self.tabIndexAtPoint(x, y, bar_x, bar_y) orelse return false;
        if (clicked_index < self.tabs.items.len) {
            self.active_index = clicked_index;
            return true;
        }
        return false;
    }

    pub fn terminalTabIdAtVisual(self: *const TabBar, visual_index: usize) ?u64 {
        if (visual_index >= self.tabs.items.len) return null;
        const tab = self.tabs.items[visual_index];
        if (tab.kind != .terminal) return null;
        return tab.terminal_tab_id;
    }

    pub fn indexOfTerminalTabId(self: *const TabBar, terminal_tab_id: u64) ?usize {
        for (self.tabs.items, 0..) |tab, i| {
            if (tab.kind == .terminal and tab.terminal_tab_id != null and tab.terminal_tab_id.? == terminal_tab_id) return i;
        }
        return null;
    }

    pub fn removeTabAt(self: *TabBar, index: usize) void {
        if (index >= self.tabs.items.len) return;
        const removed = self.tabs.orderedRemove(index);
        self.allocator.free(removed.title);
        if (self.tabs.items.len == 0) {
            self.active_index = 0;
            self.drag_active = false;
            self.drag_index = 0;
            return;
        }
        if (self.active_index > index) {
            self.active_index -= 1;
        } else if (self.active_index >= self.tabs.items.len) {
            self.active_index = self.tabs.items.len - 1;
        }
        if (self.drag_active) {
            if (self.drag_index == index) {
                self.drag_active = false;
            } else if (self.drag_index > index) {
                self.drag_index -= 1;
            }
        }
    }

    pub fn beginDrag(self: *TabBar, x: f32, y: f32, bar_x: f32, bar_y: f32) bool {
        const idx = self.tabIndexAtPoint(x, y, bar_x, bar_y) orelse return false;
        if (idx >= self.tabs.items.len) return false;
        self.drag_active = true;
        self.drag_index = idx;
        self.drag_moved = false;
        return true;
    }

    pub fn updateDrag(self: *TabBar, x: f32, y: f32, bar_x: f32, bar_y: f32, mouse_down: bool) bool {
        if (!self.drag_active) return false;
        if (!mouse_down) {
            self.drag_active = false;
            return false;
        }
        const target = self.tabIndexAtPoint(x, y, bar_x, bar_y) orelse return false;
        if (target >= self.tabs.items.len) return false;
        if (target == self.drag_index) return false;
        self.moveTabVisual(self.drag_index, target);
        self.drag_index = target;
        self.drag_moved = true;
        return true;
    }

    pub const DragEndState = struct {
        active: bool,
        moved: bool,
    };

    pub fn endDrag(self: *TabBar) DragEndState {
        const state = DragEndState{
            .active = self.drag_active,
            .moved = self.drag_moved,
        };
        self.drag_active = false;
        self.drag_moved = false;
        return state;
    }

    pub fn isDragging(self: *const TabBar) bool {
        return self.drag_active;
    }

    fn moveTabVisual(self: *TabBar, from_index: usize, to_index: usize) void {
        if (from_index >= self.tabs.items.len or to_index >= self.tabs.items.len) return;
        if (from_index == to_index) return;

        const moved = self.tabs.orderedRemove(from_index);
        self.tabs.insert(self.allocator, to_index, moved) catch return;

        if (self.active_index == from_index) {
            self.active_index = to_index;
        } else if (from_index < self.active_index and self.active_index <= to_index) {
            self.active_index -= 1;
        } else if (to_index <= self.active_index and self.active_index < from_index) {
            self.active_index += 1;
        }
    }

    fn tabIndexAtPoint(self: *const TabBar, x: f32, y: f32, bar_x: f32, bar_y: f32) ?usize {
        if (y < bar_y or y > bar_y + self.height) return null;
        if (x < bar_x) return null;
        const idx = @as(usize, @intFromFloat((x - bar_x) / (self.tab_width + self.tab_spacing)));
        if (idx >= self.tabs.items.len) return null;
        return idx;
    }
};
