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
    const cache = self.currentRenderCache();
    const presented_generation = self.presentedGeneration();
    if (cache.generation == presented_generation and cache.dirty == .none) return;
    _ = self.bumpPublicationGeneration();
    const offset: usize = self.core.scrollbackOffset();
    self.updateViewCacheForProtocol(self.pendingPublicationGeneration(), offset, "set_sync_updates");
}
