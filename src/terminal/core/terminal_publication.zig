const std = @import("std");
const render_cache_mod = @import("render_cache.zig");
const snapshot_mod = @import("snapshot.zig");
const selection_mod = @import("selection.zig");
const publication_state = @import("session_publication_state.zig");
const presentation_handoff = @import("session_presentation_handoff.zig");
const publication_updates = @import("session_publication_updates.zig");
const types = @import("../model/types.zig");

pub const KittyImageFormat = snapshot_mod.KittyImageFormat;
pub const KittyImage = snapshot_mod.KittyImage;
pub const KittyPlacement = snapshot_mod.KittyPlacement;

pub const TerminalSnapshot = snapshot_mod.TerminalSnapshot;
pub const DebugSnapshot = snapshot_mod.DebugSnapshot;
pub const RenderCache = render_cache_mod.RenderCache;
pub const Hyperlink = snapshot_mod.Hyperlink;

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

pub const AltExitPresentationInfo = struct {
    draw_ms: f64,
    rows: usize,
    cols: usize,
    history_len: usize,
    scroll_offset: usize,
};

pub const PresentationFeedback = struct {
    presented: ?PresentedRenderCache = null,
    texture_updated: bool = false,
    alt_exit_info: ?AltExitPresentationInfo = null,
};

pub const CursorPos = types.CursorPos;
pub const Cell = types.Cell;
pub const CellAttrs = types.CellAttrs;
pub const Color = types.Color;

pub fn snapshot(self: anytype) TerminalSnapshot {
    if (self.view_cache_pending.load(.acquire)) {
        self.lock();
        defer self.unlock();
        if (self.view_cache_pending.load(.acquire)) {
            updateViewCacheForScrollLocked(self);
        }
    }

    const cache = self.renderCache();
    const scrollback_offset = self.core.scrollbackOffset();
    return .{
        .rows = cache.rows,
        .cols = cache.cols,
        .cells = cache.cells.items,
        .dirty_rows = cache.dirty_rows.items,
        .row_dirty_span_counts = cache.row_dirty_span_counts.items,
        .row_dirty_span_overflow = cache.row_dirty_span_overflow.items,
        .row_dirty_spans = cache.row_dirty_spans.items,
        .dirty_cols_start = cache.dirty_cols_start.items,
        .dirty_cols_end = cache.dirty_cols_end.items,
        .cursor = cache.cursor,
        .cursor_style = cache.cursor_style,
        .cursor_visible = cache.cursor_visible,
        .dirty = cache.dirty,
        .damage = cache.damage,
        .scrollback_count = self.core.scrollbackCount(),
        .scrollback_offset = scrollback_offset,
        .selection = selection_mod.selectionState(self),
        .alt_active = cache.alt_active,
        .screen_reverse = cache.screen_reverse,
        .generation = self.output_generation.load(.acquire),
        .kitty_images = cache.kitty_images.items,
        .kitty_placements = cache.kitty_placements.items,
        .kitty_generation = cache.kitty_generation,
    };
}

pub fn publishFeedResultLocked(self: anytype, result: @import("terminal_core_feed.zig").FeedResult) void {
    publication_updates.publishFeedResultLocked(self, result);
}

pub fn updateViewCacheNoLock(self: anytype, generation: u64, scroll_offset: usize) void {
    publication_updates.updateViewCacheNoLock(self, generation, scroll_offset);
}

pub fn updateViewCacheForScroll(self: anytype) void {
    publication_updates.updateViewCacheForScroll(self);
}

pub fn updateViewCacheForScrollLocked(self: anytype) void {
    publication_updates.updateViewCacheForScrollLocked(self);
}

pub fn renderCache(self: anytype) *const RenderCache {
    const idx = self.render_cache_index.load(.acquire);
    return &self.render_caches[idx];
}

pub fn renderCacheForGeneration(self: anytype, generation: u64) ?*const RenderCache {
    inline for (0..2) |i| {
        const cache = &self.render_caches[i];
        if (cache.generation == generation) return cache;
    }
    return null;
}

pub fn clearPublishedDamage(self: anytype) void {
    inline for (0..2) |i| {
        self.render_caches[i].dirty = .none;
        self.render_caches[i].damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
    }
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
    publication_updates.setSyncUpdates(self, enabled);
}

pub fn setSyncUpdatesLocked(self: anytype, enabled: bool) void {
    publication_updates.setSyncUpdatesLocked(self, enabled);
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
