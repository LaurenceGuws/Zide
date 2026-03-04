const std = @import("std");
const shared = @import("../shared/mod.zig");

pub const TabState = struct {
    tabs: std.ArrayList(shared.contracts.ModeTab),
    active_tab: ?shared.types.TabId = null,
    next_tab_id: shared.types.TabId = 1,
    title_prefix: []const u8,

    pub fn init(title_prefix: []const u8) TabState {
        return .{
            .tabs = std.ArrayList(shared.contracts.ModeTab).empty,
            .active_tab = null,
            .next_tab_id = 1,
            .title_prefix = title_prefix,
        };
    }

    pub fn deinit(self: *TabState, allocator: std.mem.Allocator) void {
        self.clearOwnedTabs(allocator);
        self.tabs.deinit(allocator);
    }

    pub fn resetFrom(self: *TabState, allocator: std.mem.Allocator, tabs: []const shared.contracts.ModeTab, active_tab: ?shared.types.TabId) !void {
        self.clearOwnedTabs(allocator);
        try self.tabs.ensureTotalCapacity(allocator, tabs.len);
        var max_id: shared.types.TabId = 0;
        for (tabs) |tab| {
            const title = try allocator.dupe(u8, tab.title);
            self.tabs.appendAssumeCapacity(.{
                .id = tab.id,
                .title = title,
                .alive = tab.alive,
            });
            if (tab.id > max_id) max_id = tab.id;
        }
        if (tabs.len == 0) {
            self.active_tab = null;
        } else if (active_tab) |wanted| {
            if (self.findTabIndex(wanted) != null) {
                self.active_tab = wanted;
            } else {
                self.active_tab = self.tabs.items[0].id;
            }
        } else {
            self.active_tab = self.tabs.items[0].id;
        }
        self.next_tab_id = max_id + 1;
    }

    pub fn applyTabAction(self: *TabState, allocator: std.mem.Allocator, action: shared.actions.TabAction) !bool {
        switch (action) {
            .create => {
                const id = self.next_tab_id;
                self.next_tab_id += 1;
                const title = try std.fmt.allocPrint(allocator, "{s} {d}", .{ self.title_prefix, id });
                try self.tabs.append(allocator, .{
                    .id = id,
                    .title = title,
                    .alive = true,
                });
                self.active_tab = id;
                return true;
            },
            .close => |id| {
                const idx = self.findTabIndex(id) orelse return false;
                const closing_active = self.active_tab != null and self.active_tab.? == id;
                const removed = self.tabs.orderedRemove(idx);
                allocator.free(removed.title);
                if (self.tabs.items.len == 0) {
                    self.active_tab = null;
                } else if (closing_active) {
                    const replacement_idx = if (idx >= self.tabs.items.len) self.tabs.items.len - 1 else idx;
                    self.active_tab = self.tabs.items[replacement_idx].id;
                }
                return true;
            },
            .activate => |id| {
                if (self.findTabIndex(id) == null) return false;
                if (self.active_tab != null and self.active_tab.? == id) return false;
                self.active_tab = id;
                return true;
            },
            .move => |m| {
                if (self.tabs.items.len <= 1) return false;
                if (m.from_index >= self.tabs.items.len) return false;
                if (m.to_index >= self.tabs.items.len) return false;
                if (m.from_index == m.to_index) return false;
                const tab = self.tabs.orderedRemove(m.from_index);
                try self.tabs.insert(allocator, m.to_index, tab);
                return true;
            },
            .activate_by_index => |idx| {
                if (idx >= self.tabs.items.len) return false;
                const id = self.tabs.items[idx].id;
                if (self.active_tab != null and self.active_tab.? == id) return false;
                self.active_tab = id;
                return true;
            },
            .next => {
                if (self.tabs.items.len <= 1) return false;
                const current_idx = self.activeTabIndex() orelse 0;
                const next_idx = (current_idx + 1) % self.tabs.items.len;
                const id = self.tabs.items[next_idx].id;
                if (self.active_tab != null and self.active_tab.? == id) return false;
                self.active_tab = id;
                return true;
            },
            .prev => {
                if (self.tabs.items.len <= 1) return false;
                const current_idx = self.activeTabIndex() orelse 0;
                const prev_idx = if (current_idx == 0) self.tabs.items.len - 1 else current_idx - 1;
                const id = self.tabs.items[prev_idx].id;
                if (self.active_tab != null and self.active_tab.? == id) return false;
                self.active_tab = id;
                return true;
            },
        }
    }

    fn findTabIndex(self: *const TabState, id: shared.types.TabId) ?usize {
        for (self.tabs.items, 0..) |tab, idx| {
            if (tab.id == id) return idx;
        }
        return null;
    }

    fn activeTabIndex(self: *const TabState) ?usize {
        const active = self.active_tab orelse return null;
        return self.findTabIndex(active);
    }

    fn clearOwnedTabs(self: *TabState, allocator: std.mem.Allocator) void {
        for (self.tabs.items) |tab| allocator.free(tab.title);
        self.tabs.clearRetainingCapacity();
    }
};

test "tab state create/activate/close flow" {
    const allocator = std.testing.allocator;
    var state = TabState.init("Test");
    defer state.deinit(allocator);

    try std.testing.expect(try state.applyTabAction(allocator, .create));
    try std.testing.expectEqual(@as(usize, 1), state.tabs.items.len);
    try std.testing.expectEqual(@as(?shared.types.TabId, 1), state.active_tab);

    try std.testing.expect(try state.applyTabAction(allocator, .create));
    try std.testing.expectEqual(@as(usize, 2), state.tabs.items.len);
    try std.testing.expectEqual(@as(?shared.types.TabId, 2), state.active_tab);

    try std.testing.expect(try state.applyTabAction(allocator, .{ .activate = 1 }));
    try std.testing.expectEqual(@as(?shared.types.TabId, 1), state.active_tab);

    try std.testing.expect(try state.applyTabAction(allocator, .{ .close = 1 }));
    try std.testing.expectEqual(@as(usize, 1), state.tabs.items.len);
    try std.testing.expectEqual(@as(?shared.types.TabId, 2), state.active_tab);
}

test "tab state move and cycling" {
    const allocator = std.testing.allocator;
    var state = TabState.init("Test");
    defer state.deinit(allocator);

    _ = try state.applyTabAction(allocator, .create); // id=1
    _ = try state.applyTabAction(allocator, .create); // id=2
    _ = try state.applyTabAction(allocator, .create); // id=3 active
    try std.testing.expectEqual(@as(usize, 3), state.tabs.items.len);

    try std.testing.expect(try state.applyTabAction(allocator, .{ .move = .{ .from_index = 2, .to_index = 0 } }));
    try std.testing.expectEqual(@as(shared.types.TabId, 3), state.tabs.items[0].id);
    try std.testing.expectEqual(@as(shared.types.TabId, 1), state.tabs.items[1].id);
    try std.testing.expectEqual(@as(shared.types.TabId, 2), state.tabs.items[2].id);

    try std.testing.expect(try state.applyTabAction(allocator, .prev));
    try std.testing.expectEqual(@as(?shared.types.TabId, 2), state.active_tab);
    try std.testing.expect(try state.applyTabAction(allocator, .next));
    try std.testing.expectEqual(@as(?shared.types.TabId, 3), state.active_tab);
}
