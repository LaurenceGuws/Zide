const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const std = @import("std");

const AppMode = app_bootstrap.AppMode;

pub fn canHandleIntent(
    app_mode: AppMode,
    intent: app_modes.ide.TerminalShortcutIntent,
) bool {
    return switch (intent) {
        .focus => app_modes.ide.canHandleTerminalTabFocusShortcuts(app_mode),
        else => app_modes.ide.canHandleTerminalTabShortcuts(app_mode),
    };
}

test "canHandleIntent respects mode gating for terminal shortcuts" {
    try std.testing.expect(canHandleIntent(.terminal, .create));
    try std.testing.expect(canHandleIntent(.terminal, .{ .cycle = .next }));
    try std.testing.expect(canHandleIntent(.terminal, .{ .focus = .{
        .index = 0,
        .intent = .{ .activate_by_index = 0 },
    } }));

    try std.testing.expect(!canHandleIntent(.editor, .create));
    try std.testing.expect(!canHandleIntent(.editor, .{ .focus = .{
        .index = 0,
        .intent = .{ .activate_by_index = 0 },
    } }));
}
