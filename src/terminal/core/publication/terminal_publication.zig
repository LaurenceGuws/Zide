const std = @import("std");
const render_cache_mod = @import("render_cache.zig");
const snapshot_mod = @import("snapshot.zig");
const presentation_feedback = @import("presentation_feedback.zig");
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

pub const PresentationCapture = struct {
    lock_ms: f64,
    lock_wait_ms: f64,
    lock_hold_ms: f64,
    view_cache_ms: f64,
    cache_copy_ms: f64,
    presented: PresentedRenderCache,
};

pub const LatestPresentationPreparation = struct {
    capture: PresentationCapture,
    generation_state: GenerationState,
    refreshed: bool,
};

pub const ViewRefreshRequest = struct {
    generation: u64,
    scroll_offset: usize,
};

const CaptureCopy = struct {
    presented: PresentedRenderCache,
    lock_wait_ms: f64,
    lock_hold_ms: f64,
    view_cache_ms: f64,
    cache_copy_ms: f64,
};

pub const AltExitPresentationInfo = presentation_feedback.AltExitPresentationInfo;
pub const PresentationFeedback = presentation_feedback.PresentationFeedback;

pub const GenerationState = struct {
    pending: u64,
    published: u64,
    presented: u64,
};

pub const FrameState = struct {
    has_data: bool = false,
    session_ptr: usize = 0,
    pending_generation: u64 = 0,
    published_generation: u64 = 0,
    presented_generation: u64 = 0,
    redraw_pending: bool = false,
    parse_backlog: bool = false,
    output_pressure: bool = false,
};

pub const CursorPos = types.CursorPos;
pub const Cell = types.Cell;
pub const CellAttrs = types.CellAttrs;
pub const Color = types.Color;

pub fn snapshot(self: anytype) TerminalSnapshot {
    if (viewRefreshPending(self)) {
        self.lock();
        defer self.unlock();
        _ = applyPendingViewRefreshLocked(self, "snapshot");
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

pub fn publishFeedResultLocked(self: anytype, result: @import("../protocol/terminal_core_feed.zig").FeedResult) void {
    if (!result.parsed) return;
    _ = noteParsedOutputLocked(self);
    view_cache.updateViewCacheNoLockTagged(self, pendingGeneration(self), result.scroll_offset, "publish_feed_result");
}

pub fn bumpGeneration(self: anytype) u64 {
    return self.publication.pending_generation.fetchAdd(1, .acq_rel) + 1;
}

pub fn noteParsedOutputLocked(self: anytype) u64 {
    return bumpGeneration(self);
}

pub fn requestViewRefreshLocked(self: anytype, scroll_offset: usize) u64 {
    const generation = bumpGeneration(self);
    queueViewRefreshLocked(self, scroll_offset);
    return generation;
}

pub fn requestViewRefreshIfOffsetChangedLocked(self: anytype, before: usize, after: usize) u64 {
    if (after != before) {
        return requestViewRefreshLocked(self, after);
    }
    queueViewRefreshLocked(self, after);
    return pendingGeneration(self);
}

pub fn refreshScrollViewForOffsetChangeLocked(self: anytype, before: usize, after: usize) u64 {
    const generation = requestViewRefreshIfOffsetChangedLocked(self, before, after);
    updateViewCacheForScrollLocked(self);
    return generation;
}

pub fn refreshScrollViewLocked(self: anytype, scroll_offset: usize) void {
    queueViewRefreshLocked(self, scroll_offset);
    updateViewCacheForScrollLocked(self);
}

pub fn queueViewRefreshLocked(self: anytype, scroll_offset: usize) void {
    self.publication.view_cache_request_offset.store(@intCast(scroll_offset), .release);
    self.publication.view_cache_pending.store(true, .release);
    self.runtime.io_wait_cond.signal();
}

fn clearPendingViewRefresh(self: anytype) void {
    self.publication.view_cache_pending.store(false, .release);
}

pub fn publishGenerationLocked(self: anytype, generation: u64, scroll_offset: usize, source: []const u8) void {
    view_cache.updateViewCacheNoLockTagged(self, generation, scroll_offset, source);
}

pub fn publishCurrentViewLocked(self: anytype, source: []const u8) void {
    publishGenerationLocked(self, pendingGeneration(self), self.core.scrollbackOffset(), source);
}

pub fn bumpAndPublishCurrentViewLocked(self: anytype, source: []const u8) u64 {
    const generation = bumpGeneration(self);
    publishGenerationLocked(self, generation, self.core.scrollbackOffset(), source);
    return generation;
}

pub fn publishPendingGenerationLocked(self: anytype, scroll_offset: usize, source: []const u8) void {
    publishGenerationLocked(self, pendingGeneration(self), scroll_offset, source);
}

pub fn publishPendingOutputLocked(self: anytype, scroll_offset: usize, source: []const u8) void {
    publishPendingGenerationLocked(self, scroll_offset, source);
    markOutputPending(self);
}

pub fn publishViewRefreshRequestLocked(self: anytype, request: ViewRefreshRequest, source: []const u8) void {
    publishGenerationLocked(self, request.generation, request.scroll_offset, source);
}

pub fn replacePendingRefreshWithCurrentViewLocked(self: anytype, source: []const u8) void {
    clearPendingViewRefresh(self);
    publishCurrentViewLocked(self, source);
}

pub fn publishCurrentViewForScrollOffsetChangeLocked(
    self: anytype,
    before: usize,
    after: usize,
    source: []const u8,
) void {
    if (after != before) {
        _ = bumpGeneration(self);
    }
    replacePendingRefreshWithCurrentViewLocked(self, source);
}

pub fn applyPendingViewRefreshLocked(self: anytype, source: []const u8) bool {
    if (!self.publication.view_cache_pending.swap(false, .acq_rel)) return false;
    const offset: usize = @intCast(self.publication.view_cache_request_offset.load(.acquire));
    view_cache.updateViewCacheNoLockTagged(self, pendingGeneration(self), offset, source);
    return true;
}

pub fn publishPollUpdateLocked(self: anytype, had_data: bool, publish_source: []const u8, refresh_source: []const u8) bool {
    if (had_data) {
        publishCurrentViewLocked(self, publish_source);
    }
    return applyPendingViewRefreshLocked(self, refresh_source);
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
    _ = applyPendingViewRefreshLocked(self, source);
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
    _ = applyPendingViewRefreshLocked(self, source);
    return renderCacheForGeneration(self, generation);
}

fn clearPublishedDamageLocked(self: anytype) void {
    inline for (0..2) |i| {
        self.publication.render_caches[i].dirty = .none;
        self.publication.render_caches[i].damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
    }
}

pub fn capturePresentation(self: anytype, dst: *RenderCache) !PresentationCapture {
    const copy = try captureCopy(self, dst, true);
    return .{
        .lock_ms = copy.lock_wait_ms + copy.lock_hold_ms,
        .lock_wait_ms = copy.lock_wait_ms,
        .lock_hold_ms = copy.lock_hold_ms,
        .view_cache_ms = copy.view_cache_ms,
        .cache_copy_ms = copy.cache_copy_ms,
        .presented = copy.presented,
    };
}

pub fn prepareLatestPresentation(self: anytype, dst: *RenderCache) !LatestPresentationPreparation {
    var capture = try capturePresentation(self, dst);
    const published_now = publishedGeneration(self);
    var refreshed = false;
    if (published_now > capture.presented.generation) {
        const refreshed_capture = try capturePresentation(self, dst);
        if (refreshed_capture.presented.generation > capture.presented.generation) {
            capture = refreshed_capture;
            refreshed = true;
        }
    }
    return .{
        .capture = capture,
        .generation_state = generationState(self),
        .refreshed = refreshed,
    };
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
    _ = bumpGeneration(self);
    const offset: usize = self.core.scrollbackOffset();
    view_cache.updateViewCacheNoLockTagged(self, pendingGeneration(self), offset, "set_sync_updates");
}

pub fn pendingGeneration(self: anytype) u64 {
    return self.publication.pending_generation.load(.acquire);
}

pub fn generationState(self: anytype) GenerationState {
    return .{
        .pending = pendingGeneration(self),
        .published = publishedGeneration(self),
        .presented = presentedGeneration(self),
    };
}

pub fn frameState(self: anytype, has_data: bool) FrameState {
    const generation_state = generationState(self);
    const parse_backlog = generation_state.pending != generation_state.published;
    const redraw_pending = generation_state.published != generation_state.presented;
    return .{
        .has_data = has_data,
        .session_ptr = @intFromPtr(self),
        .pending_generation = generation_state.pending,
        .published_generation = generation_state.published,
        .presented_generation = generation_state.presented,
        .redraw_pending = redraw_pending,
        .parse_backlog = parse_backlog,
        .output_pressure = has_data or parse_backlog,
    };
}

pub fn outputPending(self: anytype) bool {
    return self.publication.output_pending.load(.acquire);
}

fn clearOutputPending(self: anytype) bool {
    return self.publication.output_pending.swap(false, .acq_rel);
}

pub fn markOutputPending(self: anytype) void {
    self.publication.output_pending.store(true, .release);
}

pub fn viewRefreshPending(self: anytype) bool {
    return self.publication.view_cache_pending.load(.acquire);
}

fn takePendingViewRefresh(self: anytype) ?usize {
    if (!self.publication.view_cache_pending.swap(false, .acq_rel)) return null;
    return @intCast(self.publication.view_cache_request_offset.load(.acquire));
}

pub fn takePendingViewRefreshRequest(self: anytype) ?ViewRefreshRequest {
    const scroll_offset = takePendingViewRefresh(self) orelse return null;
    return .{
        .generation = pendingGeneration(self),
        .scroll_offset = scroll_offset,
    };
}

fn takeAltExitPending(self: anytype) bool {
    return self.publication.alt_exit_pending.swap(false, .acq_rel);
}

pub fn publishedGeneration(self: anytype) u64 {
    return renderCache(self).generation;
}

pub fn publishedGenerationChangedSince(self: anytype, baseline: u64) bool {
    return publishedGeneration(self) != baseline;
}

pub fn presentedGeneration(self: anytype) u64 {
    return self.publication.presented_generation.load(.acquire);
}

pub const acknowledgePresentedGeneration = presentation_feedback.acknowledgePresentedGeneration;

pub fn hasPublishedGenerationBacklog(self: anytype) bool {
    return pendingGeneration(self) != publishedGeneration(self);
}

pub fn clearPublishedOutputPending(self: anytype) bool {
    return clearOutputPending(self);
}

pub fn noteProcessedOutput(self: anytype, processed: usize) void {
    if (processed > 0) _ = takeAltExitPending(self);
}

pub const noteAltExitPending = presentation_feedback.noteAltExitPending;
pub const completeSubmittedPresentationFeedback = presentation_feedback.completeSubmittedPresentationFeedback;

fn captureCopy(self: anytype, dst: *RenderCache, log_capture: bool) !CaptureCopy {
    _ = log_capture;
    const wait_start_ns = std.time.nanoTimestamp();
    self.lock();
    defer self.unlock();
    const lock_acquired_ns = std.time.nanoTimestamp();
    var view_cache_ms: f64 = 0.0;
    if (viewRefreshPending(self)) {
        const view_cache_start_ns = std.time.nanoTimestamp();
        _ = applyPendingViewRefreshLocked(self, "capture_copy");
        const view_cache_end_ns = std.time.nanoTimestamp();
        view_cache_ms = @as(f64, @floatFromInt(view_cache_end_ns - view_cache_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
    }
    const copy_start_ns = std.time.nanoTimestamp();
    const cache = renderCache(self);
    try render_cache_mod.copySnapshot(dst, self.allocator, cache);
    const copy_end_ns = std.time.nanoTimestamp();
    const presented = PresentedRenderCache{
        .generation = cache.generation,
        .dirty = cache.dirty,
    };
    const lock_release_ns = std.time.nanoTimestamp();
    const lock_wait_ms = @as(f64, @floatFromInt(lock_acquired_ns - wait_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
    const lock_hold_ms = @as(f64, @floatFromInt(lock_release_ns - lock_acquired_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
    return .{
        .presented = presented,
        .lock_wait_ms = lock_wait_ms,
        .lock_hold_ms = lock_hold_ms,
        .view_cache_ms = view_cache_ms,
        .cache_copy_ms = @as(f64, @floatFromInt(copy_end_ns - copy_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
    };
}
