const std = @import("std");
const kitty_mod = @import("../kitty/graphics.zig");
const render_cache_mod = @import("render_cache.zig");
const snapshot_mod = @import("snapshot.zig");
const selection_mod = @import("selection.zig");
const view_cache = @import("view_cache.zig");
const core_feed = @import("terminal_core_feed.zig");
const publication_state = @import("session_publication_state.zig");
const presentation_handoff = @import("session_presentation_handoff.zig");

pub const RenderCache = render_cache_mod.RenderCache;
pub const TerminalSnapshot = snapshot_mod.TerminalSnapshot;
pub const PresentedRenderCache = struct {
    generation: u64,
    dirty: @import("../model/screen.zig").Dirty,
};

pub const PresentationCapture = struct {
    lock_ms: f64,
    lock_wait_ms: f64,
    lock_hold_ms: f64,
    view_cache_ms: f64,
    cache_copy_ms: f64,
    presented: PresentedRenderCache,
};

pub fn snapshot(self: anytype) TerminalSnapshot {
    const screen = self.activeScreenConst();
    const view = screen.snapshotView();
    const alt_active = self.isAltActive();
    const kitty = kitty_mod.kittyStateConst(self);
    return .{
        .rows = view.rows,
        .cols = view.cols,
        .cells = view.cells,
        .dirty_rows = view.dirty_rows,
        .row_dirty_span_counts = view.row_dirty_span_counts,
        .row_dirty_span_overflow = view.row_dirty_span_overflow,
        .row_dirty_spans = view.row_dirty_spans,
        .dirty_cols_start = view.dirty_cols_start,
        .dirty_cols_end = view.dirty_cols_end,
        .cursor = view.cursor,
        .cursor_style = view.cursor_style,
        .cursor_visible = view.cursor_visible,
        .dirty = view.dirty,
        .damage = view.damage,
        .scrollback_count = self.core.scrollbackCount(),
        .scrollback_offset = self.core.scrollbackOffset(),
        .selection = selection_mod.selectionState(self),
        .alt_active = alt_active,
        .screen_reverse = screen.screen_reverse,
        .generation = self.output_generation.load(.acquire),
        .kitty_images = kitty.images.items,
        .kitty_placements = kitty.placements.items,
        .kitty_generation = kitty.generation,
    };
}

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

pub fn renderCache(self: anytype) *const RenderCache {
    const idx = self.render_cache_index.load(.acquire);
    return &self.render_caches[idx];
}

pub fn copyPublishedRenderCache(self: anytype, dst: *RenderCache) !PresentedRenderCache {
    return presentation_handoff.copyPublishedRenderCache(self, dst);
}

pub fn capturePresentation(self: anytype, dst: *RenderCache) !PresentationCapture {
    return presentation_handoff.capturePresentation(self, dst);
}

pub fn syncUpdatesActive(self: anytype) bool {
    return self.core.syncUpdatesActive();
}

pub fn setSyncUpdates(self: anytype, enabled: bool) void {
    self.lock();
    defer self.unlock();
    setSyncUpdatesLocked(self, enabled);
}

pub fn setSyncUpdatesLocked(self: anytype, enabled: bool) void {
    if (!self.core.setSyncUpdates(enabled)) return;
    const cache = renderCache(self);
    const presented_generation = publication_state.presentedGeneration(self);
    if (cache.generation == presented_generation and cache.dirty == .none) return;
    _ = self.output_generation.fetchAdd(1, .acq_rel);
    const offset: usize = self.core.scrollbackOffset();
    view_cache.updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), offset, "set_sync_updates");
}

pub fn clearPublishedDamageIfGeneration(self: anytype, expected_generation: u64, clear_screen_dirty: bool) bool {
    return publication_state.clearPublishedDamageIfGeneration(self, expected_generation, clear_screen_dirty);
}

pub fn currentGeneration(self: anytype) u64 {
    return publication_state.currentGeneration(self);
}

pub fn publishedGeneration(self: anytype) u64 {
    return publication_state.publishedGeneration(self);
}

pub fn presentedGeneration(self: anytype) u64 {
    return publication_state.presentedGeneration(self);
}

pub fn notePresentedGeneration(self: anytype, generation: u64) void {
    publication_state.notePresentedGeneration(self, generation);
}

pub fn acknowledgePresentedGeneration(self: anytype, generation: u64) bool {
    return publication_state.acknowledgePresentedGeneration(self, generation);
}

pub fn hasPublishedGenerationBacklog(self: anytype) bool {
    return publication_state.hasPublishedGenerationBacklog(self);
}

pub fn noteAltExitPending(self: anytype) void {
    self.alt_exit_pending.store(true, .release);
    self.alt_exit_time_ms.store(std.time.milliTimestamp(), .release);
}

pub fn completePresentationFeedback(self: anytype, feedback: anytype) void {
    presentation_handoff.completePresentationFeedback(self, feedback);
}

pub fn finishFramePresentation(self: anytype, feedback: anytype) void {
    presentation_handoff.finishFramePresentation(self, feedback);
}
