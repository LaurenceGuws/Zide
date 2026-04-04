pub const AltScreenEffect = struct {
    publish_snapshot: bool,
    clear_selection: bool,
    note_alt_exit_pending: bool,
};

pub fn saveCursor(self: anytype) void {
    self.core.saveCursorState();
}

pub fn restoreCursor(self: anytype) void {
    self.core.restoreCursorState();
}

pub fn enterAltScreenCore(self: anytype, clear: bool, save_cursor: bool) ?AltScreenEffect {
    if (self.core.active == .alt) return null;
    if (save_cursor) {
        saveCursor(self);
    }
    self.core.history.saveScrollOffset();
    self.core.active = .alt;
    self.core.clearActiveKittyImages();
    if (clear) {
        self.core.activeScreen().clear();
        self.core.activeScreen().setCursor(0, 0);
    }
    self.core.activeScreen().markDirtyAllWithReason(.alt_enter, @src());
    return .{
        .publish_snapshot = true,
        .clear_selection = true,
        .note_alt_exit_pending = false,
    };
}

pub fn exitAltScreenCore(self: anytype, restore_cursor: bool) ?AltScreenEffect {
    if (self.core.active != .alt) return null;
    self.core.clearActiveKittyImages();
    self.core.active = .primary;
    self.core.history.restoreScrollOffset(self.core.primary.grid.rows);
    if (restore_cursor) {
        restoreCursor(self);
    }
    self.core.activeScreen().markDirtyAllWithReason(.alt_exit, @src());
    return .{
        .publish_snapshot = true,
        .clear_selection = true,
        .note_alt_exit_pending = true,
    };
}
