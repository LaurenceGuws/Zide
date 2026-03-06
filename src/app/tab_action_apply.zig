const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");

const AppMode = app_bootstrap.AppMode;

pub fn applyTerminal(
    allocator: std.mem.Allocator,
    app_mode: AppMode,
    adapter: *app_modes.backend.TerminalMode,
    tab_action: app_modes.shared.actions.TabAction,
) !void {
    if (!app_modes.ide.canHandleTerminalTabShortcuts(app_mode)) return;
    const contract = adapter.asContract();
    _ = try contract.applyAction(allocator, .{ .tab = tab_action });
}

pub fn applyEditor(
    allocator: std.mem.Allocator,
    app_mode: AppMode,
    adapter: *app_modes.backend.EditorMode,
    tab_action: app_modes.shared.actions.TabAction,
) !void {
    if (!app_modes.ide.supportsEditorSurface(app_mode)) return;
    const contract = adapter.asContract();
    _ = try contract.applyAction(allocator, .{ .tab = tab_action });
}

test "applyTerminal respects mode gate" {
    const allocator = std.testing.allocator;
    var terminal = try app_modes.backend.bootstrap.initTerminalMode(allocator, .{
        .seed_editor_tab = false,
        .seed_terminal_tab = false,
    });
    defer terminal.deinit(allocator);

    try applyTerminal(allocator, .editor, &terminal, .create);
    var snap = try terminal.asContract().snapshot(allocator);
    try std.testing.expectEqual(@as(usize, 0), snap.tabs.len);

    try applyTerminal(allocator, .terminal, &terminal, .create);
    snap = try terminal.asContract().snapshot(allocator);
    try std.testing.expectEqual(@as(usize, 1), snap.tabs.len);
}

test "applyEditor respects mode gate" {
    const allocator = std.testing.allocator;
    var editor = try app_modes.backend.bootstrap.initEditorMode(allocator, .{
        .seed_editor_tab = false,
        .seed_terminal_tab = false,
    });
    defer editor.deinit(allocator);

    try applyEditor(allocator, .terminal, &editor, .create);
    var snap = try editor.asContract().snapshot(allocator);
    try std.testing.expectEqual(@as(usize, 0), snap.tabs.len);

    try applyEditor(allocator, .ide, &editor, .create);
    snap = try editor.asContract().snapshot(allocator);
    try std.testing.expectEqual(@as(usize, 1), snap.tabs.len);
}
