const std = @import("std");
const shared = @import("../shared/mod.zig");
const backend = @import("mod.zig");

pub const BootstrapOptions = struct {
    seed_editor_tab: bool = true,
    seed_terminal_tab: bool = true,
};

pub fn initEditorMode(allocator: std.mem.Allocator, opts: BootstrapOptions) !backend.EditorMode {
    var mode = backend.EditorMode.init(allocator);
    if (opts.seed_editor_tab) {
        _ = try mode.asContract().applyAction(allocator, .{ .tab = .create });
    }
    return mode;
}

pub fn initTerminalMode(allocator: std.mem.Allocator, opts: BootstrapOptions) !backend.TerminalMode {
    var mode = backend.TerminalMode.init(allocator);
    if (opts.seed_terminal_tab) {
        _ = try mode.asContract().applyAction(allocator, .{ .tab = .create });
    }
    return mode;
}

test "bootstrap seeds tabs by default" {
    const allocator = std.testing.allocator;
    const opts = BootstrapOptions{};

    var editor = try initEditorMode(allocator, opts);
    defer editor.deinit(allocator);
    var terminal = try initTerminalMode(allocator, opts);
    defer terminal.deinit(allocator);

    const editor_snap = try editor.asContract().snapshot(allocator);
    const terminal_snap = try terminal.asContract().snapshot(allocator);

    try std.testing.expectEqual(@as(usize, 1), editor_snap.tabs.len);
    try std.testing.expectEqual(@as(usize, 1), terminal_snap.tabs.len);
}

test "bootstrap can start empty" {
    const allocator = std.testing.allocator;
    const opts = BootstrapOptions{
        .seed_editor_tab = false,
        .seed_terminal_tab = false,
    };

    var editor = try initEditorMode(allocator, opts);
    defer editor.deinit(allocator);
    var terminal = try initTerminalMode(allocator, opts);
    defer terminal.deinit(allocator);

    const editor_snap = try editor.asContract().snapshot(allocator);
    const terminal_snap = try terminal.asContract().snapshot(allocator);

    try std.testing.expectEqual(@as(usize, 0), editor_snap.tabs.len);
    try std.testing.expectEqual(@as(usize, 0), terminal_snap.tabs.len);
}
