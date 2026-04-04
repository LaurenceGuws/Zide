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
    const effect = core_modes.enterAltScreenCore(self, clear, save_cursor) orelse return;
    if (effect.clear_selection) {
        host_selection.clearSelectionLocked(self);
    }
    if (effect.publish_snapshot) {
        input_modes.publishSnapshot(self);
    }
}

pub fn exitAltScreen(self: anytype, restore_cursor: bool) void {
    const effect = core_modes.exitAltScreenCore(self, restore_cursor) orelse return;
    if (effect.publish_snapshot) {
        input_modes.publishSnapshot(self);
    }
    if (effect.note_alt_exit_pending) {
        terminal_publication.noteAltExitPending(self);
    }
    if (effect.clear_selection) {
        host_selection.clearSelectionLocked(self);
    }
}
