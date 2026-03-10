const std = @import("std");
const core_modes = @import("terminal_core_modes.zig");
const core_reset = @import("terminal_core_reset.zig");
const input_modes = @import("input_modes.zig");
const session_rendering = @import("session_rendering.zig");

pub fn resetStateLocked(self: anytype) void {
    core_reset.resetStateCore(self);
    input_modes.resetInputModesLocked(self);
}

pub fn enterAltScreen(self: anytype, clear: bool, save_cursor: bool) void {
    if (!core_modes.enterAltScreenCore(self, clear, save_cursor)) return;
    self.clearSelectionLocked();
    input_modes.publishSnapshot(self);
}

pub fn exitAltScreen(self: anytype, restore_cursor: bool) void {
    if (!core_modes.exitAltScreenCore(self, restore_cursor)) return;
    input_modes.publishSnapshot(self);
    session_rendering.noteAltExitPending(self);
    self.clearSelectionLocked();
}
