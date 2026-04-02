const std = @import("std");
const render_cache_mod = @import("render_cache.zig");
const snapshot_mod = @import("snapshot.zig");
const publication_capture = @import("publication_capture.zig");
const publication_state = @import("publication_state.zig");
const presentation_feedback = @import("presentation_feedback.zig");
const publication_flow = @import("publication_flow.zig");
const selection_mod = @import("../selection.zig");
const view_cache = @import("view_cache.zig");
const types = @import("../../model/types.zig");

pub const KittyImageFormat = snapshot_mod.KittyImageFormat;
pub const KittyImage = snapshot_mod.KittyImage;
pub const KittyPlacement = snapshot_mod.KittyPlacement;

pub const TerminalSnapshot = snapshot_mod.TerminalSnapshot;
pub const DebugSnapshot = snapshot_mod.DebugSnapshot;
pub const RenderCache = render_cache_mod.RenderCache;
pub const Hyperlink = snapshot_mod.Hyperlink;

pub const PresentedRenderCache = presentation_feedback.PresentedRenderCache;
pub const ViewRefreshRequest = publication_flow.ViewRefreshRequest;

pub const AltExitPresentationInfo = presentation_feedback.AltExitPresentationInfo;
pub const PresentationFeedback = presentation_feedback.PresentationFeedback;
pub const PresentationCapture = publication_capture.PresentationCapture;
pub const LatestPresentationPreparation = publication_capture.LatestPresentationPreparation;
pub const GenerationState = publication_state.GenerationState;
pub const FrameState = publication_state.FrameState;

pub const CursorPos = types.CursorPos;
pub const Cell = types.Cell;
pub const CellAttrs = types.CellAttrs;
pub const Color = types.Color;

pub fn snapshot(self: anytype) TerminalSnapshot {
    if (publication_flow.viewRefreshPending(self)) {
        self.lock();
        defer self.unlock();
        _ = publication_flow.applyPendingViewRefreshLocked(self, "snapshot");
    }

    const cache = renderCache(self);
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
        .generation = cache.generation,
        .kitty_images = cache.kitty_images.items,
        .kitty_placements = cache.kitty_placements.items,
        .kitty_generation = cache.kitty_generation,
    };
}

pub fn updateViewCacheForScroll(self: anytype) void {
    view_cache.updateViewCacheForScroll(self);
}

pub fn updateViewCacheForScrollLocked(self: anytype) void {
    view_cache.updateViewCacheForScrollLocked(self);
}

pub fn renderCache(self: anytype) *const RenderCache {
    const idx = self.publication.render_cache_index.load(.acquire);
    return &self.publication.render_caches[idx];
}

pub fn renderCacheLocked(self: anytype, source: []const u8) *const RenderCache {
    _ = publication_flow.applyPendingViewRefreshLocked(self, source);
    return renderCache(self);
}

fn renderCacheForGeneration(self: anytype, generation: u64) ?*const RenderCache {
    inline for (0..2) |i| {
        const cache = &self.publication.render_caches[i];
        if (cache.generation == generation) return cache;
    }
    return null;
}

pub fn renderCacheForGenerationLocked(self: anytype, generation: u64, source: []const u8) ?*const RenderCache {
    _ = publication_flow.applyPendingViewRefreshLocked(self, source);
    return renderCacheForGeneration(self, generation);
}

fn clearPublishedDamageLocked(self: anytype) void {
    inline for (0..2) |i| {
        self.publication.render_caches[i].dirty = .none;
        self.publication.render_caches[i].damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
    }
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
    const presented_generation = presentedGeneration(self);
    if (cache.generation == presented_generation and cache.dirty == .none) return;
    _ = publication_flow.bumpGeneration(self);
    const offset: usize = self.core.scrollbackOffset();
    view_cache.updateViewCacheNoLockTagged(self, pendingGeneration(self), offset, "set_sync_updates");
}

pub fn pendingGeneration(self: anytype) u64 {
    return publication_flow.pendingGeneration(self);
}

pub fn generationState(self: anytype) GenerationState {
    return publication_state.generationState(self);
}

pub fn frameState(self: anytype, has_data: bool) FrameState {
    return publication_state.frameState(self, has_data);
}

pub fn publishedGeneration(self: anytype) u64 {
    return publication_state.publishedGeneration(self);
}

pub fn publishedGenerationChangedSince(self: anytype, baseline: u64) bool {
    return publication_state.publishedGenerationChangedSince(self, baseline);
}

pub fn presentedGeneration(self: anytype) u64 {
    return publication_state.presentedGeneration(self);
}

pub const acknowledgePresentedGeneration = presentation_feedback.acknowledgePresentedGeneration;

pub const noteAltExitPending = presentation_feedback.noteAltExitPending;
pub const completeSubmittedPresentationFeedback = presentation_feedback.completeSubmittedPresentationFeedback;
