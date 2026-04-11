const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const app_logger = @import("../../app_logger.zig");
const renderer_chrome_band_host = @import("../renderer/renderer_chrome_band_host.zig");
const common = @import("common.zig");
const shared_types = @import("../../types/mod.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const Band = renderer_chrome_band_host.Band;
const Tooltip = common.Tooltip;

pub const TabBar = struct {
    pub const WidthMode = enum {
        fixed,
        dynamic,
        label_length,
        compact_label_length,
    };

    allocator: std.mem.Allocator,
    tabs: std.ArrayList(Tab),
    active_index: usize,
    height: f32,
    tab_width: f32,
    tab_spacing: f32,
    width_mode: WidthMode,
    last_mouse: shared_types.input.MousePos,
    last_char_width: f32,
    last_ui_scale: f32,
    drag_active: bool,
    drag_origin_index: usize,
    drag_index: usize,
    drag_moved: bool,

    pub const Tab = struct {
        title: []u8,
        kind: Kind,
        modified: bool,
        terminal_tab_id: ?u64 = null,
        icon_path: ?[]u8 = null,

        pub const Kind = enum { editor, terminal };
    };

    pub const IconProvider = struct {
        ctx: *anyopaque,
        draw: *const fn (ctx: *anyopaque, shell: *Shell, icon_path: []const u8, x: f32, y: f32, size: f32) bool,
    };

    pub fn init(allocator: std.mem.Allocator) TabBar {
        return .{
            .allocator = allocator,
            .tabs = .empty,
            .active_index = 0,
            .height = 24,
            .tab_width = 150,
            .tab_spacing = 1,
            .width_mode = .fixed,
            .last_mouse = .{ .x = 0, .y = 0 },
            .last_char_width = 8,
            .last_ui_scale = 1,
            .drag_active = false,
            .drag_origin_index = 0,
            .drag_index = 0,
            .drag_moved = false,
        };
    }

    pub fn deinit(self: *TabBar) void {
        for (self.tabs.items) |tab| {
            self.allocator.free(tab.title);
            if (tab.icon_path) |icon_path| self.allocator.free(icon_path);
        }
        self.tabs.deinit(self.allocator);
    }

    pub fn clearTabs(self: *TabBar) void {
        for (self.tabs.items) |tab| {
            self.allocator.free(tab.title);
            if (tab.icon_path) |icon_path| self.allocator.free(icon_path);
        }
        self.tabs.clearRetainingCapacity();
        self.active_index = 0;
        self.drag_active = false;
        self.drag_origin_index = 0;
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
            .icon_path = null,
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
            .icon_path = null,
        });
    }

    pub fn setTabTitle(self: *TabBar, index: usize, title: []const u8) !void {
        if (index >= self.tabs.items.len) return;
        if (std.mem.eql(u8, self.tabs.items[index].title, title)) return;
        const owned_title = try self.allocator.dupe(u8, title);
        self.allocator.free(self.tabs.items[index].title);
        self.tabs.items[index].title = owned_title;
    }

    pub fn setTabModified(self: *TabBar, index: usize, modified: bool) void {
        if (index >= self.tabs.items.len) return;
        self.tabs.items[index].modified = modified;
    }

    pub fn setTabIconPath(self: *TabBar, index: usize, icon_path: ?[]const u8) !void {
        if (index >= self.tabs.items.len) return;
        if (icon_path) |path| {
            if (self.tabs.items[index].icon_path) |existing| {
                if (std.mem.eql(u8, existing, path)) return;
                self.allocator.free(existing);
            }
            self.tabs.items[index].icon_path = try self.allocator.dupe(u8, path);
        } else {
            if (self.tabs.items[index].icon_path) |existing| {
                self.allocator.free(existing);
            }
            self.tabs.items[index].icon_path = null;
        }
    }

    pub fn clearTabIcons(self: *TabBar) void {
        for (self.tabs.items) |*tab| {
            if (tab.icon_path) |icon_path| {
                self.allocator.free(icon_path);
                tab.icon_path = null;
            }
        }
    }

    pub fn updateInput(self: *TabBar, input: shared_types.input.InputSnapshot) void {
        self.last_mouse = input.mouse_pos;
    }

    pub fn setWidthMode(self: *TabBar, mode: WidthMode) void {
        self.width_mode = mode;
    }

    pub fn draw(self: *TabBar, shell: *Shell, x: f32, y: f32, width: f32) ?Tooltip {
        return self.drawWithIconProvider(shell, x, y, width, null);
    }

    pub fn drawWithIconProvider(self: *TabBar, shell: *Shell, x: f32, y: f32, width: f32, icon_provider: ?IconProvider) ?Tooltip {
        const theme = shell.theme();
        var band = Band.init(shell, theme.ui_bar_bg);
        self.last_char_width = shell.charWidth();
        self.last_ui_scale = shell.uiScaleFactor();
        // Draw tab bar background
        band.fillRect(@intFromFloat(x), @intFromFloat(y), @intFromFloat(width), @intFromFloat(self.height), theme.ui_bar_bg);

        if (width <= 0 or self.height <= 0) {
            band.flush();
            return null;
        }

        shell.beginClip(@intFromFloat(x), @intFromFloat(y), @intFromFloat(width), @intFromFloat(self.height));

        var tooltip: ?Tooltip = null;
        const mouse = self.last_mouse;
        const window_focused = shell.windowFocused();
        const count = self.tabs.items.len;
        const spacing_total = if (count > 1) self.tab_spacing * @as(f32, @floatFromInt(count - 1)) else 0;
        const available_for_tabs = @max(0, width - spacing_total);

        var natural_sum: f32 = 0;
        if (self.width_mode == .label_length) {
            for (self.tabs.items) |tab| {
                natural_sum += self.naturalTabWidth(tab, self.last_char_width, self.last_ui_scale);
            }
            if (natural_sum <= 0) natural_sum = @as(f32, @floatFromInt(@max(@as(usize, 1), count)));
        }

        var cursor_x: f32 = x;
        for (self.tabs.items, 0..) |tab, i| {
            var tab_w = self.tabWidthForIndex(i, count, available_for_tabs, natural_sum, self.last_char_width, self.last_ui_scale);
            if (i + 1 == count and (self.width_mode == .dynamic or self.width_mode == .label_length)) {
                tab_w = @max(0, x + width - cursor_x);
            }
            const is_active = i == self.active_index;
            const is_dragging_tab = self.drag_active and i == self.drag_index;
            const tab_y = if (is_dragging_tab) y - @max(1.0, shell.uiScaleFactor() * 2.0) else y;
            const tab_h = if (is_dragging_tab) self.height + @max(1.0, shell.uiScaleFactor() * 2.0) else self.height;

            // Tab background
            const bg = if (is_active)
                theme.background
            else
                theme.ui_tab_inactive_bg;
            band.fillRect(
                @intFromFloat(cursor_x),
                @intFromFloat(tab_y),
                @intFromFloat(tab_w),
                @intFromFloat(tab_h),
                if (is_dragging_tab) theme.ui_hover else bg,
            );

            // Tab border
            if (is_active) {
                const border_h: f32 = @max(1.0, shell.uiScaleFactor() * 2.0);
                band.fillRect(
                    @intFromFloat(cursor_x),
                    @intFromFloat(tab_y + tab_h - border_h),
                    @intFromFloat(tab_w),
                    @intFromFloat(border_h),
                    theme.ui_accent,
                );
            }
            if (is_dragging_tab) {
                const top_h: f32 = @max(1.0, shell.uiScaleFactor() * 2.0);
                band.fillRect(
                    @intFromFloat(cursor_x),
                    @intFromFloat(tab_y),
                    @intFromFloat(tab_w),
                    @intFromFloat(top_h),
                    theme.ui_accent,
                );
            }

            // Tab title
            var title_x = cursor_x + 8 * shell.uiScaleFactor();
            const title_y = tab_y + (tab_h - shell.charHeight()) / 2;
            const icon_reserved = self.tabIconAdvance(tab, shell.uiScaleFactor());

            if (icon_provider) |provider| {
                if (tab.icon_path) |icon_path| {
                    const icon_size = self.tabIconSize(shell.uiScaleFactor());
                    const icon_y = tab_y + (tab_h - icon_size) * 0.5;
                    _ = provider.draw(provider.ctx, shell, icon_path, title_x, icon_y, icon_size);
                    title_x += icon_reserved;
                }
            } else if (icon_reserved > 0) {
                title_x += icon_reserved;
            }

            // Modified indicator
            if (tab.modified) {
                band.drawText("* ", title_x, title_y, theme.ui_modified);
            }

            const prefix_width: f32 = if (tab.modified) shell.charWidth() * 2 else 0;
            const title_max = @max(0, tab_w - 16 * shell.uiScaleFactor() - prefix_width - icon_reserved);
            var truncated_buf: [256]u8 = undefined;
            const result = common.truncateText(
                shell,
                tab.title,
                title_max,
                truncated_buf[0..],
            );
            band.drawText(result.text, title_x + prefix_width, title_y, if (is_active) theme.ui_text else theme.ui_text_inactive);
            const in_tab = window_focused and mouse.x >= cursor_x and mouse.x <= cursor_x + tab_w and
                mouse.y >= y and mouse.y <= y + self.height;
            if (result.truncated and in_tab) {
                tooltip = .{ .text = tab.title, .x = mouse.x, .y = mouse.y };
            }

            cursor_x += tab_w + self.tab_spacing;
        }

        band.flush();
        shell.endClip();
        return tooltip;
    }

    pub fn handleClick(self: *TabBar, x: f32, y: f32, bar_x: f32, bar_y: f32, bar_width: f32) bool {
        const clicked_index = self.tabIndexAtPoint(x, y, bar_x, bar_y, bar_width) orelse return false;
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
        if (removed.icon_path) |icon_path| self.allocator.free(icon_path);
        if (self.tabs.items.len == 0) {
            self.active_index = 0;
            self.drag_active = false;
            self.drag_origin_index = 0;
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

    pub fn beginDrag(self: *TabBar, x: f32, y: f32, bar_x: f32, bar_y: f32, bar_width: f32) bool {
        const idx = self.tabIndexAtPoint(x, y, bar_x, bar_y, bar_width) orelse return false;
        if (idx >= self.tabs.items.len) return false;
        self.drag_active = true;
        self.drag_origin_index = idx;
        self.drag_index = idx;
        self.drag_moved = false;
        return true;
    }

    pub fn updateDrag(self: *TabBar, x: f32, y: f32, bar_x: f32, bar_y: f32, bar_width: f32, mouse_down: bool) bool {
        if (!self.drag_active) return false;
        if (!mouse_down) {
            self.drag_active = false;
            return false;
        }
        const target = self.tabIndexAtPoint(x, y, bar_x, bar_y, bar_width) orelse return false;
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
        from_index: usize,
        to_index: usize,
    };

    pub fn endDrag(self: *TabBar) DragEndState {
        const state = DragEndState{
            .active = self.drag_active,
            .moved = self.drag_moved,
            .from_index = self.drag_origin_index,
            .to_index = self.drag_index,
        };
        self.drag_active = false;
        self.drag_origin_index = 0;
        self.drag_moved = false;
        return state;
    }

    pub fn isDragging(self: *const TabBar) bool {
        return self.drag_active;
    }

    pub fn contentWidth(self: *const TabBar, max_width: f32, char_width: f32, ui_scale: f32) f32 {
        const count = self.tabs.items.len;
        if (count == 0 or max_width <= 0) return 0;

        const spacing_total = if (count > 1) self.tab_spacing * @as(f32, @floatFromInt(count - 1)) else 0;
        const available_for_tabs = @max(0, max_width - spacing_total);
        if (available_for_tabs <= 0) return 0;

        var natural_sum: f32 = 0;
        if (self.width_mode == .label_length or self.width_mode == .compact_label_length) {
            for (self.tabs.items) |tab| {
                natural_sum += self.naturalTabWidth(tab, char_width, ui_scale);
            }
            if (natural_sum <= 0) natural_sum = @as(f32, @floatFromInt(@max(@as(usize, 1), count)));
        }

        var used: f32 = 0;
        for (self.tabs.items, 0..) |_, i| {
            var tab_w = self.tabWidthForIndex(i, count, available_for_tabs, natural_sum, char_width, ui_scale);
            if (i + 1 == count and (self.width_mode == .dynamic or self.width_mode == .label_length)) {
                tab_w = @max(0, available_for_tabs - used);
            }
            used += tab_w;
        }
        return @min(max_width, used + spacing_total);
    }

    fn moveTabVisual(self: *TabBar, from_index: usize, to_index: usize) void {
        const log = app_logger.logger("ui.tab_bar");
        if (from_index >= self.tabs.items.len or to_index >= self.tabs.items.len) return;
        if (from_index == to_index) return;

        const moved = self.tabs.orderedRemove(from_index);
        self.tabs.insert(self.allocator, to_index, moved) catch |err| {
            log.logf(.warning, "visual tab move insert failed from={d} to={d}: {s}", .{ from_index, to_index, @errorName(err) });
            return;
        };

        if (self.active_index == from_index) {
            self.active_index = to_index;
        } else if (from_index < self.active_index and self.active_index <= to_index) {
            self.active_index -= 1;
        } else if (to_index <= self.active_index and self.active_index < from_index) {
            self.active_index += 1;
        }
    }

    fn tabIndexAtPoint(self: *const TabBar, x: f32, y: f32, bar_x: f32, bar_y: f32, bar_width: f32) ?usize {
        if (y < bar_y or y > bar_y + self.height) return null;
        if (x < bar_x or x > bar_x + bar_width) return null;
        const count = self.tabs.items.len;
        if (count == 0) return null;

        const spacing_total = if (count > 1) self.tab_spacing * @as(f32, @floatFromInt(count - 1)) else 0;
        const available_for_tabs = @max(0, bar_width - spacing_total);
        var natural_sum: f32 = 0;
        if (self.width_mode == .label_length) {
            for (self.tabs.items) |tab| {
                natural_sum += self.naturalTabWidth(tab, self.last_char_width, self.last_ui_scale);
            }
            if (natural_sum <= 0) natural_sum = @as(f32, @floatFromInt(@max(@as(usize, 1), count)));
        }

        var cursor_x = bar_x;
        for (0..count) |i| {
            var tab_w = self.tabWidthForIndex(i, count, available_for_tabs, natural_sum, self.last_char_width, self.last_ui_scale);
            if (i + 1 == count and (self.width_mode == .dynamic or self.width_mode == .label_length)) {
                tab_w = @max(0, bar_x + bar_width - cursor_x);
            }
            if (x >= cursor_x and x <= cursor_x + tab_w) return i;
            cursor_x += tab_w + self.tab_spacing;
        }
        return null;
    }

    fn tabWidthForIndex(
        self: *const TabBar,
        index: usize,
        count: usize,
        available_for_tabs: f32,
        natural_sum: f32,
        char_width: f32,
        ui_scale: f32,
    ) f32 {
        if (count == 0) return 0;
        return switch (self.width_mode) {
            .fixed => self.tab_width,
            .dynamic => available_for_tabs / @as(f32, @floatFromInt(count)),
            .label_length => blk: {
                const natural = self.naturalTabWidth(self.tabs.items[index], char_width, ui_scale);
                break :blk if (natural_sum > 0) (available_for_tabs * (natural / natural_sum)) else (available_for_tabs / @as(f32, @floatFromInt(count)));
            },
            .compact_label_length => blk: {
                const natural = self.naturalTabWidth(self.tabs.items[index], char_width, ui_scale);
                if (natural_sum > available_for_tabs and natural_sum > 0) {
                    break :blk available_for_tabs * (natural / natural_sum);
                }
                break :blk natural;
            },
        };
    }

    fn naturalTabWidth(self: *const TabBar, tab: Tab, char_width: f32, ui_scale: f32) f32 {
        const text_w = @as(f32, @floatFromInt(tab.title.len)) * char_width;
        const mod_w = if (tab.modified) char_width * 2 else 0;
        const padding = 16 * ui_scale;
        return @max(48 * ui_scale, text_w + mod_w + padding + self.tabIconAdvance(tab, ui_scale));
    }

    fn tabIconSize(self: *const TabBar, ui_scale: f32) f32 {
        _ = self;
        return @max(12 * ui_scale, 16 * ui_scale);
    }

    fn tabIconAdvance(self: *const TabBar, tab: Tab, ui_scale: f32) f32 {
        if (tab.icon_path == null) return 0;
        const gap = 6 * ui_scale;
        return self.tabIconSize(ui_scale) + gap;
    }
};
