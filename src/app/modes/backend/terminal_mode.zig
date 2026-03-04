const std = @import("std");
const shared = @import("../shared/mod.zig");

pub const TerminalMode = struct {
    tabs: std.ArrayList(shared.contracts.ModeTab),
    active_tab: ?shared.types.TabId = null,

    pub fn init(allocator: std.mem.Allocator) TerminalMode {
        _ = allocator;
        return .{
            .tabs = std.ArrayList(shared.contracts.ModeTab).empty,
            .active_tab = null,
        };
    }

    pub fn deinit(self: *TerminalMode, allocator: std.mem.Allocator) void {
        self.tabs.deinit(allocator);
    }

    pub fn asContract(self: *TerminalMode) shared.contracts.ModeContract {
        return .{
            .kind = .terminal,
            .ptr = self,
            .vtable = &vtable,
        };
    }

    fn deinitErased(ptr: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *TerminalMode = @ptrCast(@alignCast(ptr));
        self.deinit(allocator);
    }

    fn snapshotErased(ptr: *anyopaque, _: std.mem.Allocator) anyerror!shared.contracts.ModeSnapshot {
        const self: *TerminalMode = @ptrCast(@alignCast(ptr));
        return .{
            .mode = .terminal,
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
        const self: *TerminalMode = @ptrCast(@alignCast(ptr));
        _ = allocator;
        _ = self;
        _ = action;
        return false;
    }

    const vtable: shared.contracts.ModeContract.VTable = .{
        .deinit = deinitErased,
        .snapshot = snapshotErased,
        .applyAction = applyActionErased,
    };
};
