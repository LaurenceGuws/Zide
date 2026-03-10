pub fn clearPublishedDamageIfGeneration(self: anytype, expected_generation: u64, clear_screen_dirty: bool) bool {
    self.lock();
    defer self.unlock();
    if (self.output_generation.load(.acquire) != expected_generation) return false;
    if (clear_screen_dirty) {
        self.activeScreen().clearDirty();
    }
    inline for (0..2) |i| {
        self.render_caches[i].dirty = .none;
        self.render_caches[i].damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
    }
    return true;
}

pub fn notePresentedGeneration(self: anytype, generation: u64) void {
    self.presented_generation.store(generation, .release);
}

pub fn acknowledgePresentedGeneration(self: anytype, generation: u64) bool {
    notePresentedGeneration(self, generation);
    if (renderCacheSyncUpdatesActiveForGeneration(self, generation)) {
        return clearPublishedDamageIfGeneration(self, generation, false);
    }
    return clearPublishedDamageIfGeneration(self, generation, true);
}

fn renderCacheSyncUpdatesActiveForGeneration(self: anytype, generation: u64) bool {
    inline for (0..2) |i| {
        if (self.render_caches[i].generation == generation) {
            return self.render_caches[i].sync_updates_active;
        }
    }
    return self.core.sync_updates_active;
}
