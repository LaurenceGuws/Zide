const std = @import("std");
const kitty_mod = @import("../kitty/graphics.zig");
const render_cache_mod = @import("render_cache.zig");
const snapshot_mod = @import("snapshot.zig");
const selection_mod = @import("selection.zig");
const view_cache = @import("view_cache.zig");
const core_feed = @import("terminal_core_feed.zig");
const retirement = @import("session_rendering_retirement.zig");

pub const RenderCache = render_cache_mod.RenderCache;
pub const TerminalSnapshot = snapshot_mod.TerminalSnapshot;
pub const PresentedRenderCache = struct {
    generation: u64,
    dirty: @import("../model/screen.zig").Dirty,
};

pub const PresentationCapture = struct {
    lock_ms: f64,
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
        .dirty_cols_start = view.dirty_cols_start,
        .dirty_cols_end = view.dirty_cols_end,
        .cursor = view.cursor,
        .cursor_style = view.cursor_style,
        .cursor_visible = view.cursor_visible,
        .dirty = view.dirty,
        .damage = view.damage,
        .scrollback_count = self.core.history.scrollbackCount(),
        .scrollback_offset = self.core.history.scrollOffset(),
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
    view_cache.updateViewCacheNoLock(self, self.output_generation.load(.acquire), result.scroll_offset);
}

pub fn updateViewCacheNoLock(self: anytype, generation: u64, scroll_offset: usize) void {
    view_cache.updateViewCacheNoLock(self, generation, scroll_offset);
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
    self.lock();
    defer self.unlock();
    if (self.view_cache_pending.load(.acquire)) {
        self.updateViewCacheForScrollLocked();
    }
    const cache = renderCache(self);
    try render_cache_mod.copySnapshot(dst, self.allocator, cache);
    return .{
        .generation = cache.generation,
        .dirty = cache.dirty,
    };
}

pub fn capturePresentation(self: anytype, dst: *RenderCache) !PresentationCapture {
    const lock_start_ns = std.time.nanoTimestamp();
    const presented = try copyPublishedRenderCache(self, dst);
    const lock_end_ns = std.time.nanoTimestamp();
    return .{
        .lock_ms = @as(f64, @floatFromInt(lock_end_ns - lock_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
        .presented = presented,
    };
}

pub fn syncUpdatesActive(self: anytype) bool {
    return self.core.sync_updates_active;
}

pub fn setSyncUpdates(self: anytype, enabled: bool) void {
    self.lock();
    defer self.unlock();
    setSyncUpdatesLocked(self, enabled);
}

pub fn setSyncUpdatesLocked(self: anytype, enabled: bool) void {
    if (self.core.sync_updates_active == enabled) return;
    self.core.sync_updates_active = enabled;
    const offset: usize = self.core.history.scrollOffset();
    view_cache.updateViewCacheNoLock(self, self.output_generation.load(.acquire), offset);
}

pub fn clearPublishedDamageIfGeneration(self: anytype, expected_generation: u64, clear_screen_dirty: bool) bool {
    return retirement.clearPublishedDamageIfGeneration(self, expected_generation, clear_screen_dirty);
}

pub fn currentGeneration(self: anytype) u64 {
    return self.output_generation.load(.acquire);
}

pub fn publishedGeneration(self: anytype) u64 {
    const idx = self.render_cache_index.load(.acquire);
    return self.render_caches[idx].generation;
}

pub fn presentedGeneration(self: anytype) u64 {
    return self.presented_generation.load(.acquire);
}

pub fn notePresentedGeneration(self: anytype, generation: u64) void {
    retirement.notePresentedGeneration(self, generation);
}

pub fn acknowledgePresentedGeneration(self: anytype, generation: u64) bool {
    return retirement.acknowledgePresentedGeneration(self, generation);
}

pub fn hasPublishedGenerationBacklog(self: anytype) bool {
    return currentGeneration(self) != publishedGeneration(self);
}

pub fn noteAltExitPending(self: anytype) void {
    self.alt_exit_pending.store(true, .release);
    self.alt_exit_time_ms.store(std.time.milliTimestamp(), .release);
}

pub fn completePresentationFeedback(self: anytype, feedback: anytype) void {
    if (feedback.presented) |presented| {
        if (feedback.texture_updated or presented.dirty == .none) {
            _ = acknowledgePresentedGeneration(self, presented.generation);
        }
    }
    if (feedback.alt_exit_info) |info| {
        const exit_time_ms = self.alt_exit_time_ms.swap(-1, .acq_rel);
        const exit_to_draw_ms: f64 = if (exit_time_ms >= 0)
            @as(f64, @floatFromInt(std.time.milliTimestamp() - exit_time_ms))
        else
            -1.0;
        const log = @import("../../app_logger.zig").logger("terminal.alt");
        log.logf(.info, "alt_exit_draw_ms={d:.2} exit_to_draw_ms={d:.2} rows={d} cols={d} history={d} scroll_offset={d}", .{
            info.draw_ms,
            exit_to_draw_ms,
            info.rows,
            info.cols,
            info.history_len,
            info.scroll_offset,
        });
    }
}

pub fn finishFramePresentation(self: anytype, feedback: anytype) void {
    completePresentationFeedback(self, feedback);
}
