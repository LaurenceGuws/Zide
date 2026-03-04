const std = @import("std");
const shared = @import("../shared/mod.zig");
const backend = @import("../backend/mod.zig");
const app_bootstrap = @import("../../bootstrap.zig");

pub const ActiveMode = enum {
    editor,
    terminal,
};

pub const MouseClickRoute = enum {
    ide,
    terminal,
    editor,
};

pub fn initialActiveMode(app_mode: app_bootstrap.AppMode) ActiveMode {
    return if (app_mode == .terminal) .terminal else .editor;
}

pub fn initialTerminalVisibility(app_mode: app_bootstrap.AppMode) bool {
    return app_mode == .terminal;
}

pub fn isTerminalOnly(app_mode: app_bootstrap.AppMode) bool {
    return app_mode == .terminal;
}

pub fn isEditorOnly(app_mode: app_bootstrap.AppMode) bool {
    return app_mode == .editor;
}

pub fn isIde(app_mode: app_bootstrap.AppMode) bool {
    return app_mode == .ide;
}

pub fn isFontSample(app_mode: app_bootstrap.AppMode) bool {
    return app_mode == .font_sample;
}

pub fn supportsEditorSurface(app_mode: app_bootstrap.AppMode) bool {
    return app_mode != .terminal and app_mode != .font_sample;
}

pub fn supportsTerminalSurface(app_mode: app_bootstrap.AppMode) bool {
    return app_mode != .editor and app_mode != .font_sample;
}

pub fn routedActiveMode(app_mode: app_bootstrap.AppMode, active: ActiveMode) ActiveMode {
    return switch (app_mode) {
        .terminal => .terminal,
        .editor => .editor,
        else => active,
    };
}

pub fn canToggleTerminal(app_mode: app_bootstrap.AppMode) bool {
    return isIde(app_mode);
}

pub fn shouldUseTerminalWorkspace(app_mode: app_bootstrap.AppMode) bool {
    return isTerminalOnly(app_mode);
}

pub fn hasTerminalInputScope(app_mode: app_bootstrap.AppMode, show_terminal: bool) bool {
    return isTerminalOnly(app_mode) or show_terminal;
}

pub fn usesIdeTerminalStrip(app_mode: app_bootstrap.AppMode) bool {
    return isIde(app_mode);
}

pub fn useTerminalTabBarWidthMode(app_mode: app_bootstrap.AppMode) bool {
    return isTerminalOnly(app_mode);
}

pub fn terminalTabBarVisible(
    app_mode: app_bootstrap.AppMode,
    show_single_tab: bool,
    tab_count: usize,
) bool {
    if (!isTerminalOnly(app_mode)) return false;
    if (show_single_tab) return true;
    return tab_count >= 2;
}

pub fn canCreateEditorFromShortcut(app_mode: app_bootstrap.AppMode) bool {
    return app_mode != .terminal;
}

pub fn canHandleTerminalTabShortcuts(app_mode: app_bootstrap.AppMode) bool {
    return isTerminalOnly(app_mode);
}

pub fn canHandleTerminalTabFocusShortcuts(app_mode: app_bootstrap.AppMode) bool {
    return isTerminalOnly(app_mode);
}

pub fn mouseClickRoute(app_mode: app_bootstrap.AppMode) MouseClickRoute {
    return switch (app_mode) {
        .ide => .ide,
        .terminal => .terminal,
        else => .editor,
    };
}

pub fn canDriveTerminalTabDrag(app_mode: app_bootstrap.AppMode) bool {
    return isTerminalOnly(app_mode);
}

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

test "mode policy helpers route focused mode deterministically" {
    try std.testing.expectEqual(ActiveMode.terminal, routedActiveMode(.terminal, .editor));
    try std.testing.expectEqual(ActiveMode.editor, routedActiveMode(.editor, .terminal));
    try std.testing.expectEqual(ActiveMode.terminal, routedActiveMode(.ide, .terminal));
    try std.testing.expect(supportsEditorSurface(.ide));
    try std.testing.expect(supportsTerminalSurface(.ide));
    try std.testing.expect(!supportsEditorSurface(.terminal));
    try std.testing.expect(!supportsTerminalSurface(.editor));
    try std.testing.expect(isIde(.ide));
    try std.testing.expect(isFontSample(.font_sample));
    try std.testing.expect(canToggleTerminal(.ide));
    try std.testing.expect(!canToggleTerminal(.terminal));
    try std.testing.expect(shouldUseTerminalWorkspace(.terminal));
    try std.testing.expect(!shouldUseTerminalWorkspace(.ide));
    try std.testing.expect(hasTerminalInputScope(.terminal, false));
    try std.testing.expect(hasTerminalInputScope(.ide, true));
    try std.testing.expect(!hasTerminalInputScope(.editor, false));
    try std.testing.expect(usesIdeTerminalStrip(.ide));
    try std.testing.expect(!usesIdeTerminalStrip(.terminal));
    try std.testing.expect(useTerminalTabBarWidthMode(.terminal));
    try std.testing.expect(!useTerminalTabBarWidthMode(.ide));
    try std.testing.expect(terminalTabBarVisible(.terminal, true, 1));
    try std.testing.expect(terminalTabBarVisible(.terminal, false, 2));
    try std.testing.expect(!terminalTabBarVisible(.terminal, false, 1));
    try std.testing.expect(!terminalTabBarVisible(.ide, true, 4));
    try std.testing.expect(canCreateEditorFromShortcut(.ide));
    try std.testing.expect(canCreateEditorFromShortcut(.font_sample));
    try std.testing.expect(!canCreateEditorFromShortcut(.terminal));
    try std.testing.expect(canHandleTerminalTabShortcuts(.terminal));
    try std.testing.expect(!canHandleTerminalTabShortcuts(.editor));
    try std.testing.expect(canHandleTerminalTabFocusShortcuts(.terminal));
    try std.testing.expect(!canHandleTerminalTabFocusShortcuts(.ide));
    try std.testing.expectEqual(MouseClickRoute.ide, mouseClickRoute(.ide));
    try std.testing.expectEqual(MouseClickRoute.terminal, mouseClickRoute(.terminal));
    try std.testing.expectEqual(MouseClickRoute.editor, mouseClickRoute(.editor));
    try std.testing.expect(canDriveTerminalTabDrag(.terminal));
    try std.testing.expect(!canDriveTerminalTabDrag(.ide));
}
