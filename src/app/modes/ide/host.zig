const std = @import("std");
const shared = @import("../shared/mod.zig");
const backend = @import("../backend/mod.zig");

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

    pub fn applyAction(self: *IdeHost, action: shared.actions.ModeAction) !bool {
        switch (action) {
            .focus => |focus| switch (focus) {
                .set => |target| {
                    self.active = switch (target.view) {
                        .editor => .editor,
                        .terminal => .terminal,
                    };
                    return false;
                },
                .clear => return false,
            },
            .tab => {
                return self.activeContract().applyAction(self.allocator, action);
            },
            .theme => {
                // Theme routing is host-level policy for now.
                return false;
            },
        }
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

test "ide host routes tab action to active mode" {
    const allocator = std.testing.allocator;
    var editor = backend.EditorMode.init(allocator);
    var terminal = backend.TerminalMode.init(allocator);
    defer editor.deinit(allocator);
    defer terminal.deinit(allocator);

    var host = IdeHost.init(allocator, editor.asContract(), terminal.asContract());

    try std.testing.expect(try host.applyAction(.{ .tab = .create }));
    var all = try host.snapshotAll();
    try std.testing.expectEqual(@as(usize, 1), all.editor.tabs.len);
    try std.testing.expectEqual(@as(usize, 0), all.terminal.tabs.len);

    _ = try host.applyAction(.{ .focus = .{ .set = .{ .view = .terminal, .tab_id = 0 } } });
    try std.testing.expect(try host.applyAction(.{ .tab = .create }));
    all = try host.snapshotAll();
    try std.testing.expectEqual(@as(usize, 1), all.editor.tabs.len);
    try std.testing.expectEqual(@as(usize, 1), all.terminal.tabs.len);
}

test "ide host active snapshot follows focus routing" {
    const allocator = std.testing.allocator;
    var editor = backend.EditorMode.init(allocator);
    var terminal = backend.TerminalMode.init(allocator);
    defer editor.deinit(allocator);
    defer terminal.deinit(allocator);
    var host = IdeHost.init(allocator, editor.asContract(), terminal.asContract());

    _ = try host.applyAction(.{ .tab = .create }); // editor
    var snap = try host.snapshotActive();
    try std.testing.expectEqual(shared.types.ModeKind.editor, snap.mode);

    _ = try host.applyAction(.{ .focus = .{ .set = .{ .view = .terminal, .tab_id = 0 } } });
    _ = try host.applyAction(.{ .tab = .create }); // terminal
    snap = try host.snapshotActive();
    try std.testing.expectEqual(shared.types.ModeKind.terminal, snap.mode);
}
