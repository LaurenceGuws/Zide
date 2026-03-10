const std = @import("std");
const kitty_mod = @import("../kitty/graphics.zig");
const render_cache_mod = @import("render_cache.zig");
const snapshot_mod = @import("snapshot.zig");
const selection_mod = @import("selection.zig");
const view_cache = @import("view_cache.zig");

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
        .scrollback_count = self.history.scrollbackCount(),
        .scrollback_offset = self.history.scrollOffset(),
        .selection = selection_mod.selectionState(self),
        .alt_active = alt_active,
        .screen_reverse = screen.screen_reverse,
        .generation = self.output_generation.load(.acquire),
        .kitty_images = kitty.images.items,
        .kitty_placements = kitty.placements.items,
        .kitty_generation = kitty.generation,
    };
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
    return self.sync_updates_active;
}

pub fn setSyncUpdates(self: anytype, enabled: bool) void {
    self.lock();
    defer self.unlock();
    setSyncUpdatesLocked(self, enabled);
}

pub fn setSyncUpdatesLocked(self: anytype, enabled: bool) void {
    if (self.sync_updates_active == enabled) return;
    self.sync_updates_active = enabled;
    const offset: usize = self.history.scrollOffset();
    view_cache.updateViewCacheNoLock(self, self.output_generation.load(.acquire), offset);
}

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
