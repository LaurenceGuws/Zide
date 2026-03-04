const std = @import("std");
const types = @import("types.zig");
const actions = @import("actions.zig");

pub const ModeTab = struct {
    id: types.TabId,
    title: []const u8,
    alive: bool = true,
};

pub const ModeSnapshot = struct {
    mode: types.ModeKind,
    tabs: []const ModeTab,
    active_tab: ?types.TabId = null,
    capabilities: types.ModeCapabilities = .{},
    diagnostics: types.Diagnostics = types.Diagnostics.none(),
};

pub const ModeContext = struct {
    allocator: std.mem.Allocator,
};

pub const ModeContract = struct {
    kind: types.ModeKind,
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
        snapshot: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) anyerror!ModeSnapshot,
        applyAction: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, action: actions.ModeAction) anyerror!bool,
    };

    pub fn deinit(self: ModeContract, allocator: std.mem.Allocator) void {
        self.vtable.deinit(self.ptr, allocator);
    }

    pub fn snapshot(self: ModeContract, allocator: std.mem.Allocator) !ModeSnapshot {
        return self.vtable.snapshot(self.ptr, allocator);
    }

    pub fn applyAction(self: ModeContract, allocator: std.mem.Allocator, action: actions.ModeAction) !bool {
        return self.vtable.applyAction(self.ptr, allocator, action);
    }
};
