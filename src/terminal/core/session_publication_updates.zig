const view_cache = @import("view_cache.zig");
const core_feed = @import("terminal_core_feed.zig");

pub fn publishFeedResultLocked(self: anytype, result: core_feed.FeedResult) void {
    if (!result.parsed) return;
    _ = self.output_generation.fetchAdd(1, .acq_rel);
    view_cache.updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), result.scroll_offset, "publish_feed_result");
}

pub fn updateViewCacheNoLock(self: anytype, generation: u64, scroll_offset: usize) void {
    view_cache.updateViewCacheNoLockTagged(self, generation, scroll_offset, "session_rendering_direct");
}

pub fn updateViewCacheForScroll(self: anytype) void {
    view_cache.updateViewCacheForScroll(self);
}

pub fn updateViewCacheForScrollLocked(self: anytype) void {
    view_cache.updateViewCacheForScrollLocked(self);
}

pub fn setSyncUpdates(self: anytype, enabled: bool) void {
    self.lock();
    defer self.unlock();
    setSyncUpdatesLocked(self, enabled);
}

pub fn setSyncUpdatesLocked(self: anytype, enabled: bool) void {
    if (!self.core.setSyncUpdates(enabled)) return;
    const cache = @import("session_rendering.zig").renderCache(self);
    const presented_generation = @import("session_publication_state.zig").presentedGeneration(self);
    if (cache.generation == presented_generation and cache.dirty == .none) return;
    _ = self.output_generation.fetchAdd(1, .acq_rel);
    const offset: usize = self.core.scrollbackOffset();
    view_cache.updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), offset, "set_sync_updates");
}
