const std = @import("std");

pub const ActionKind = enum {
    none,
};

pub const InputAction = struct {
    kind: ActionKind,
};

pub const InputRouter = struct {
    allocator: std.mem.Allocator,
    actions: std.ArrayList(InputAction),

    pub fn init(allocator: std.mem.Allocator) InputRouter {
        return .{
            .allocator = allocator,
            .actions = std.ArrayList(InputAction).empty,
        };
    }

    pub fn deinit(self: *InputRouter) void {
        self.actions.deinit(self.allocator);
    }

    pub fn clear(self: *InputRouter) void {
        self.actions.clearRetainingCapacity();
    }

    pub fn actionsSlice(self: *InputRouter) []const InputAction {
        return self.actions.items;
    }
};
