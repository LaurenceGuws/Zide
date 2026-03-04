const std = @import("std");
const shared = @import("../shared/mod.zig");

pub const ActiveMode = enum {
    editor,
    terminal,
};

pub const IdeHost = struct {
    allocator: std.mem.Allocator,
    editor: shared.contracts.ModeContract,
    terminal: shared.contracts.ModeContract,
    active: ActiveMode = .editor,

    pub fn init(
        allocator: std.mem.Allocator,
        editor: shared.contracts.ModeContract,
        terminal: shared.contracts.ModeContract,
    ) IdeHost {
        return .{
            .allocator = allocator,
            .editor = editor,
            .terminal = terminal,
            .active = .editor,
        };
    }

    pub fn deinit(self: *IdeHost) void {
        self.editor.deinit(self.allocator);
        self.terminal.deinit(self.allocator);
    }

    pub fn setActive(self: *IdeHost, active: ActiveMode) void {
        self.active = active;
    }

    pub fn activeContract(self: *IdeHost) shared.contracts.ModeContract {
        return switch (self.active) {
            .editor => self.editor,
            .terminal => self.terminal,
        };
    }

    pub fn snapshotActive(self: *IdeHost) !shared.contracts.ModeSnapshot {
        return self.activeContract().snapshot(self.allocator);
    }

    pub fn applyActiveAction(self: *IdeHost, action: shared.actions.ModeAction) !bool {
        return self.activeContract().applyAction(self.allocator, action);
    }

    pub fn snapshotAll(self: *IdeHost) !struct {
        editor: shared.contracts.ModeSnapshot,
        terminal: shared.contracts.ModeSnapshot,
    } {
        return .{
            .editor = try self.editor.snapshot(self.allocator),
            .terminal = try self.terminal.snapshot(self.allocator),
        };
    }
};
