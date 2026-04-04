const std = @import("std");
const core_modes = @import("../terminal_core_modes.zig");
const input_modes = @import("../input_modes.zig");
const terminal_publication = @import("../publication/terminal_publication.zig");
const host_selection = @import("../selection.zig");

pub fn resetStateLocked(self: anytype) void {
    self.core.resetState();
    input_modes.resetInputModesLocked(self);
}

pub fn resetState(self: anytype) void {
    self.session.control.state_mutex.lock();
    defer self.session.control.state_mutex.unlock();
    resetStateLocked(self);
}

pub fn enterAltScreen(self: anytype, clear: bool, save_cursor: bool) void {
    if (!core_modes.enterAltScreenCore(self, clear, save_cursor)) return;
    host_selection.clearSelectionLocked(self);
    input_modes.publishSnapshot(self);
}

pub fn exitAltScreen(self: anytype, restore_cursor: bool) void {
    if (!core_modes.exitAltScreenCore(self, restore_cursor)) return;
    input_modes.publishSnapshot(self);
    terminal_publication.noteAltExitPending(self);
    host_selection.clearSelectionLocked(self);
}
