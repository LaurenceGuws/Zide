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

