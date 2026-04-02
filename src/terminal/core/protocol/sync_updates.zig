const publication_flow = @import("../publication/publication_flow.zig");
const publication_state = @import("../publication/publication_state.zig");
const view_cache = @import("../publication/view_cache.zig");

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
    const cache = renderCache(self);
    const presented_generation = publication_state.presentedGeneration(self);
    if (cache.generation == presented_generation and cache.dirty == .none) return;
    _ = publication_flow.bumpGeneration(self);
    const offset: usize = self.core.scrollbackOffset();
    view_cache.updateViewCacheNoLockTagged(self, publication_flow.pendingGeneration(self), offset, "set_sync_updates");
}

fn renderCache(self: anytype) *const @import("../publication/render_cache.zig").RenderCache {
    const idx = self.publication.render_cache_index.load(.acquire);
    return &self.publication.render_caches[idx];
}
