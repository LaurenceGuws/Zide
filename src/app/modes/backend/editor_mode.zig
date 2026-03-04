const std = @import("std");
const shared = @import("../shared/mod.zig");
const tab_state_mod = @import("tab_state.zig");

pub const EditorMode = struct {
    tab_state: tab_state_mod.TabState,

    pub fn init(allocator: std.mem.Allocator) EditorMode {
        _ = allocator;
        return .{
            .tab_state = tab_state_mod.TabState.init("Editor"),
        };
    }

    pub fn deinit(self: *EditorMode, allocator: std.mem.Allocator) void {
        self.tab_state.deinit(allocator);
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
            .tabs = self.tab_state.tabs.items,
            .active_tab = self.tab_state.active_tab,
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
            .tab => |tab_action| return self.tab_state.applyTabAction(allocator, tab_action),
            .focus, .theme => return false,
        }
    }

    const vtable: shared.contracts.ModeContract.VTable = .{
        .deinit = deinitErased,
        .snapshot = snapshotErased,
        .applyAction = applyActionErased,
    };
};
