const view_cache = @import("../publication/view_cache.zig");
const core_feed = @import("../protocol/terminal_core_feed.zig");
const terminal_publication = @import("../publication/terminal_publication.zig");

pub fn bumpGeneration(self: anytype) u64 {
    return self.publication.pending_generation.fetchAdd(1, .acq_rel) + 1;
}

pub fn requestViewRefreshLocked(self: anytype, scroll_offset: usize) u64 {
    const generation = bumpGeneration(self);
    queueViewRefreshLocked(self, scroll_offset);
    return generation;
}

pub fn queueViewRefreshLocked(self: anytype, scroll_offset: usize) void {
    self.publication.view_cache_request_offset.store(@intCast(scroll_offset), .release);
    self.publication.view_cache_pending.store(true, .release);
    self.runtime.io_wait_cond.signal();
}

pub fn clearPendingViewRefresh(self: anytype) void {
    self.publication.view_cache_pending.store(false, .release);
}

pub fn applyPendingViewRefreshLocked(self: anytype, source: []const u8) bool {
    if (!self.publication.view_cache_pending.swap(false, .acq_rel)) return false;
    const offset: usize = @intCast(self.publication.view_cache_request_offset.load(.acquire));
    view_cache.updateViewCacheNoLockTagged(self, terminal_publication.pendingGeneration(self), offset, source);
    return true;
}

pub fn publishFeedResultLocked(self: anytype, result: core_feed.FeedResult) void {
    if (!result.parsed) return;
    _ = bumpGeneration(self);
    view_cache.updateViewCacheNoLockTagged(self, terminal_publication.pendingGeneration(self), result.scroll_offset, "publish_feed_result");
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
    const cache = terminal_publication.renderCache(self);
    const presented_generation = terminal_publication.presentedGeneration(self);
    if (cache.generation == presented_generation and cache.dirty == .none) return;
    _ = bumpGeneration(self);
    const offset: usize = self.core.scrollbackOffset();
    view_cache.updateViewCacheNoLockTagged(self, terminal_publication.pendingGeneration(self), offset, "set_sync_updates");
}
