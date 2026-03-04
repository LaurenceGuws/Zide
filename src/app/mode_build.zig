const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const root = @import("root");

pub const AppMode = app_bootstrap.AppMode;

pub const focused_mode: ?AppMode = if (@hasDecl(root, "zide_focused_mode"))
    @field(root, "zide_focused_mode")
else
    null;

pub inline fn effectiveMode(runtime_mode: AppMode) AppMode {
    return if (comptime focused_mode) |mode| mode else runtime_mode;
}

pub inline fn hasFocusedMode() bool {
    return comptime focused_mode != null;
}

test "mode_build defaults to runtime mode when no focused root mode is declared" {
    try std.testing.expect(!hasFocusedMode());
    try std.testing.expectEqual(AppMode.ide, effectiveMode(.ide));
    try std.testing.expectEqual(AppMode.editor, effectiveMode(.editor));
    try std.testing.expectEqual(AppMode.terminal, effectiveMode(.terminal));
    try std.testing.expectEqual(AppMode.font_sample, effectiveMode(.font_sample));
}
