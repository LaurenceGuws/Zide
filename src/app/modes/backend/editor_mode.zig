const std = @import("std");
const shared = @import("../shared/mod.zig");

pub const EditorMode = struct {
    tabs: std.ArrayList(shared.contracts.ModeTab),
    active_tab: ?shared.types.TabId = null,
    next_tab_id: shared.types.TabId = 1,

    pub fn init(allocator: std.mem.Allocator) EditorMode {
        _ = allocator;
        return .{
            .tabs = std.ArrayList(shared.contracts.ModeTab).empty,
            .active_tab = null,
            .next_tab_id = 1,
        };
    }

    pub fn deinit(self: *EditorMode, allocator: std.mem.Allocator) void {
        for (self.tabs.items) |tab| allocator.free(tab.title);
        self.tabs.deinit(allocator);
    }

    pub fn asContract(self: *EditorMode) shared.contracts.ModeContract {
        return .{
            .kind = .editor,
            .ptr = self,
            .vtable = &vtable,
        };
    }

    fn deinitErased(ptr: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *EditorMode = @ptrCast(@alignCast(ptr));
        self.deinit(allocator);
    }

    fn snapshotErased(ptr: *anyopaque, _: std.mem.Allocator) anyerror!shared.contracts.ModeSnapshot {
        const self: *EditorMode = @ptrCast(@alignCast(ptr));
        return .{
            .mode = .editor,
            .tabs = self.tabs.items,
            .active_tab = self.active_tab,
            .capabilities = .{
                .supports_tabs = true,
                .supports_reorder = true,
                .supports_mixed_views = false,
            },
            .diagnostics = .{},
        };
    }

    fn applyActionErased(ptr: *anyopaque, allocator: std.mem.Allocator, action: shared.actions.ModeAction) anyerror!bool {
        const self: *EditorMode = @ptrCast(@alignCast(ptr));
        switch (action) {
            .tab => |tab_action| return self.applyTabAction(allocator, tab_action),
            .focus, .theme => return false,
        }
    }

    fn applyTabAction(self: *EditorMode, allocator: std.mem.Allocator, action: shared.actions.TabAction) !bool {
        switch (action) {
            .create => {
                const id = self.next_tab_id;
                self.next_tab_id += 1;
                const title = try std.fmt.allocPrint(allocator, "Editor {d}", .{id});
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

    fn findTabIndex(self: *const EditorMode, id: shared.types.TabId) ?usize {
        for (self.tabs.items, 0..) |tab, idx| {
            if (tab.id == id) return idx;
        }
        return null;
    }

    fn activeTabIndex(self: *const EditorMode) ?usize {
        const active = self.active_tab orelse return null;
        return self.findTabIndex(active);
    }

    const vtable: shared.contracts.ModeContract.VTable = .{
        .deinit = deinitErased,
        .snapshot = snapshotErased,
        .applyAction = applyActionErased,
    };
};
