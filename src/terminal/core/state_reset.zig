pub fn saveCursor(self: anytype) void {
    self.core.saveCursorState();
}

pub fn restoreCursor(self: anytype) void {
    self.core.restoreCursorState();
}
