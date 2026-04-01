const terminal_publication = @import("terminal_publication.zig");

pub fn outputPending(self: anytype) bool {
    return self.publication.output_pending.load(.acquire);
}

pub fn clearOutputPending(self: anytype) bool {
    return self.publication.output_pending.swap(false, .acq_rel);
}

pub fn markOutputPending(self: anytype) void {
    self.publication.output_pending.store(true, .release);
}

pub fn viewRefreshPending(self: anytype) bool {
    return self.publication.view_cache_pending.load(.acquire);
}

pub fn takePendingViewRefresh(self: anytype) ?usize {
    if (!self.publication.view_cache_pending.swap(false, .acq_rel)) return null;
    return @intCast(self.publication.view_cache_request_offset.load(.acquire));
}

pub fn takeAltExitPending(self: anytype) bool {
    return self.publication.alt_exit_pending.swap(false, .acq_rel);
}

pub fn consumeAltExitTimeMs(self: anytype) i64 {
    return self.publication.alt_exit_time_ms.swap(-1, .acq_rel);
}

pub fn clearPublishedDamageIfGeneration(self: anytype, expected_generation: u64, clear_screen_dirty: bool) bool {
    self.lock();
    defer self.unlock();
    const pending_generation = self.publication.pending_generation.load(.acquire);
    if (pending_generation != expected_generation) return false;
    if (clear_screen_dirty) {
        self.activeScreen().clearDirty();
    }
    terminal_publication.clearPublishedDamage(self);
    return true;
}

pub fn pendingGeneration(self: anytype) u64 {
    return self.publication.pending_generation.load(.acquire);
}

pub fn publishedGeneration(self: anytype) u64 {
    return terminal_publication.renderCache(self).generation;
}

pub fn presentedGeneration(self: anytype) u64 {
    return self.publication.presented_generation.load(.acquire);
}

pub fn notePresentedGeneration(self: anytype, generation: u64) void {
    var current = self.publication.presented_generation.load(.acquire);
    while (generation > current) {
        current = self.publication.presented_generation.cmpxchgWeak(current, generation, .acq_rel, .acquire) orelse return;
    }
}

pub fn acknowledgePresentedGeneration(self: anytype, generation: u64) bool {
    notePresentedGeneration(self, generation);
    const sync_updates_active = renderCacheSyncUpdatesActiveForGeneration(self, generation);
    const cleared = if (sync_updates_active)
        clearPublishedDamageIfGeneration(self, generation, false)
    else
        clearPublishedDamageIfGeneration(self, generation, true);
    return cleared;
}

pub fn hasPublishedGenerationBacklog(self: anytype) bool {
    return pendingGeneration(self) != publishedGeneration(self);
}

fn renderCacheSyncUpdatesActiveForGeneration(self: anytype, generation: u64) bool {
    if (terminal_publication.renderCacheForGeneration(self, generation)) |cache| {
        return cache.sync_updates_active;
    }
    return self.core.syncUpdatesActive();
}
