pub fn active(self: anytype) bool {
    return self.core.syncUpdatesActive();
}

pub fn set(self: anytype, enabled: bool) void {
    self.lock();
    defer self.unlock();
    setLocked(self, enabled);
}

pub fn setLocked(self: anytype, enabled: bool) void {
    if (!self.core.setSyncUpdates(enabled)) return;
    if (!self.syncUpdateNeedsPublication()) return;
    const offset: usize = self.core.scrollbackOffset();
    self.publishSyncUpdate(offset);
}
