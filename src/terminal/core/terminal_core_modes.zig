const std = @import("std");
const kitty_mod = @import("../kitty/graphics.zig");
const state_reset = @import("state_reset.zig");

pub fn saveCursor(self: anytype) void {
    state_reset.saveCursor(self);
}

pub fn restoreCursor(self: anytype) void {
    state_reset.restoreCursor(self);
}

pub fn enterAltScreenCore(self: anytype, clear: bool, save_cursor: bool) bool {
    if (self.core.active == .alt) return false;
    if (save_cursor) {
        saveCursor(self);
    }
    self.core.history.saveScrollOffset();
    self.core.active = .alt;
    kitty_mod.clearKittyImages(self);
    if (clear) {
        self.core.activeScreen().clear();
        self.core.activeScreen().setCursor(0, 0);
    }
    self.core.activeScreen().markDirtyAllWithReason(.alt_enter, @src());
    return true;
}

pub fn exitAltScreenCore(self: anytype, restore_cursor: bool) bool {
    if (self.core.active != .alt) return false;
    kitty_mod.clearKittyImages(self);
    self.core.active = .primary;
    self.core.history.restoreScrollOffset(self.core.primary.grid.rows);
    if (restore_cursor) {
        restoreCursor(self);
    }
    self.core.activeScreen().markDirtyAllWithReason(.alt_exit, @src());
    return true;
}
