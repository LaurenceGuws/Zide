const std = @import("std");
const render_cache_mod = @import("render_cache.zig");
const snapshot_mod = @import("snapshot.zig");
const selection_mod = @import("selection.zig");
const publication_state = @import("session_publication_state.zig");
const presentation_handoff = @import("session_presentation_handoff.zig");
const publication_updates = @import("session_publication_updates.zig");
const view_cache = @import("view_cache.zig");
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

pub const ViewportInfo = struct {
    history_len: usize,
    total_lines: usize,
    scroll_offset: usize,
    start_line: usize,
};

pub const ScrollbarInfo = struct {
    allowed: bool,
    rows: usize,
    total_lines: usize,
    scroll_offset: usize,
};

pub const AltTransition = struct {
    changed: bool,
    exited: bool,
};

pub const LifecycleTransitionInfo = struct {
    changed: bool,
    exited: bool,
    current_alt_active: bool,

    pub fn reason(self: LifecycleTransitionInfo) ?[]const u8 {
        if (!self.changed) return null;
        return if (self.current_alt_active) "alt_enter" else "alt_exit";
    }
};

pub const PartialCaptureInfo = struct {
    use_viewport_shift: bool,
    active_viewport_shift_rows: i32,
    shift_exposed_only: bool,
    reason: []const u8,
};

pub const RenderStateInfo = struct {
    screen_reverse: bool,
    draw_cursor_visible: bool,
    cursor_style: types.CursorStyle,
    has_blinking_cells: bool,
};

pub const BackgroundRunInfo = struct {
    cursor_here: bool,
    cursor_col: ?usize,
    screen_reverse: bool,
};

pub const DirtySummary = struct {
    is_clean: bool,
    dirty_tag: []const u8,
    current_reason: []const u8,
    dirty_rows_count: usize,
    damage_row_span: usize,
    damage_col_span: usize,
};

pub const DrawStateInfo = struct {
    rows: usize,
    cols: usize,
    viewport: ViewportInfo,
    render: RenderStateInfo,
    sync_updates_active: bool,
    kitty_generation: u64,
    cursor: CursorPos,
};

pub const VisibleViewDumpInfo = struct {
    rows: usize,
    cols: usize,
    generation: u64,
    scroll_offset: usize,
    alt_active: bool,
    cursor: CursorPos,
    draw_cursor_visible: bool,
    screen_reverse: bool,
};

pub const CursorPos = types.CursorPos;
pub const Cell = types.Cell;
pub const CellAttrs = types.CellAttrs;
pub const Color = types.Color;

pub fn viewportInfo(cache: *const RenderCache) ViewportInfo {
    const total_lines = cache.totalLines();
    const end_line = total_lines - cache.scroll_offset;
    return .{
        .history_len = cache.history_len,
        .total_lines = total_lines,
        .scroll_offset = cache.scroll_offset,
        .start_line = if (end_line > cache.rows) end_line - cache.rows else 0,
    };
}

pub fn scrollbarAllowed(cache: *const RenderCache, mouse_reporting_enabled: bool) bool {
    return !cache.alt_active and !mouse_reporting_enabled and cache.rows > 0 and cache.totalLines() > cache.rows;
}

pub fn scrollbarInfo(cache: *const RenderCache, mouse_reporting_enabled: bool) ScrollbarInfo {
    const viewport = viewportInfo(cache);
    return .{
        .allowed = scrollbarAllowed(cache, mouse_reporting_enabled),
        .rows = cache.rows,
        .total_lines = viewport.total_lines,
        .scroll_offset = viewport.scroll_offset,
    };
}

pub fn drawCursorVisible(cache: *const RenderCache) bool {
    return cache.scroll_offset == 0 and cache.cursor_visible;
}

pub fn altTransition(previous_alt_active: bool, cache: *const RenderCache) AltTransition {
    return .{
        .changed = previous_alt_active != cache.alt_active,
        .exited = previous_alt_active and !cache.alt_active,
    };
}

pub fn lifecycleTransitionInfo(previous_alt_active: bool, cache: *const RenderCache) LifecycleTransitionInfo {
    const transition = altTransition(previous_alt_active, cache);
    return .{
        .changed = transition.changed,
        .exited = transition.exited,
        .current_alt_active = cache.alt_active,
    };
}

pub fn partialCaptureInfo(cache: *const RenderCache) PartialCaptureInfo {
    const use_viewport_shift = cache.dirty == .partial and cache.viewport_shift_rows != 0;
    const active_viewport_shift_rows = if (use_viewport_shift) cache.viewport_shift_rows else 0;
    const shift_exposed_only = use_viewport_shift and cache.viewport_shift_exposed_only;
    return .{
        .use_viewport_shift = use_viewport_shift,
        .active_viewport_shift_rows = active_viewport_shift_rows,
        .shift_exposed_only = shift_exposed_only,
        .reason = switch (cache.dirty) {
            .full => @tagName(cache.full_dirty_reason),
            .partial => if (cache.viewport_shift_rows != 0)
                (if (cache.viewport_shift_exposed_only) "viewport_shift_exposed" else "viewport_shift")
            else
                "partial",
            .none => "clean",
        },
    };
}

pub fn renderStateInfo(cache: *const RenderCache) RenderStateInfo {
    return .{
        .screen_reverse = cache.screen_reverse,
        .draw_cursor_visible = drawCursorVisible(cache),
        .cursor_style = cache.cursor_style,
        .has_blinking_cells = cache.has_blink,
    };
}

pub fn backgroundRunInfo(cache: *const RenderCache, row: usize) BackgroundRunInfo {
    const cursor_here = cache.cursor_visible and cache.cursor.row == row and cache.cursor.col < cache.cols;
    return .{
        .cursor_here = cursor_here,
        .cursor_col = if (cursor_here) cache.cursor.col else null,
        .screen_reverse = cache.screen_reverse,
    };
}

pub fn visibleViewDumpInfo(cache: *const RenderCache) VisibleViewDumpInfo {
    const viewport = viewportInfo(cache);
    const render_state = renderStateInfo(cache);
    return .{
        .rows = cache.rows,
        .cols = cache.cols,
        .generation = cache.generation,
        .scroll_offset = viewport.scroll_offset,
        .alt_active = cache.alt_active,
        .cursor = cache.cursor,
        .draw_cursor_visible = render_state.draw_cursor_visible,
        .screen_reverse = render_state.screen_reverse,
    };
}

pub fn dirtySummary(cache: *const RenderCache) DirtySummary {
    var dirty_rows_count: usize = 0;
    var damage_row_span: usize = 0;
    var damage_col_span: usize = 0;

    if (cache.dirty != .none) {
        for (cache.dirty_rows.items) |row_dirty| {
            if (row_dirty) dirty_rows_count += 1;
        }
        if (cache.damage.end_row >= cache.damage.start_row) {
            damage_row_span = cache.damage.end_row - cache.damage.start_row + 1;
        }
        if (cache.damage.end_col >= cache.damage.start_col) {
            damage_col_span = cache.damage.end_col - cache.damage.start_col + 1;
        }
    }

    return .{
        .is_clean = cache.dirty == .none,
        .dirty_tag = @tagName(cache.dirty),
        .current_reason = partialCaptureInfo(cache).reason,
        .dirty_rows_count = dirty_rows_count,
        .damage_row_span = damage_row_span,
        .damage_col_span = damage_col_span,
    };
}

pub fn drawStateInfo(cache: *const RenderCache) DrawStateInfo {
    return .{
        .rows = cache.rows,
        .cols = cache.cols,
        .viewport = viewportInfo(cache),
        .render = renderStateInfo(cache),
        .sync_updates_active = cache.sync_updates_active,
        .kitty_generation = cache.kitty_generation,
        .cursor = cache.cursor,
    };
}

pub fn snapshot(self: anytype) TerminalSnapshot {
    if (viewRefreshPending(self)) {
        self.lock();
        defer self.unlock();
        if (viewRefreshPending(self)) {
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
        .generation = cache.generation,
        .kitty_images = cache.kitty_images.items,
        .kitty_placements = cache.kitty_placements.items,
        .kitty_generation = cache.kitty_generation,
    };
}

pub fn publishFeedResultLocked(self: anytype, result: @import("terminal_core_feed.zig").FeedResult) void {
    publication_updates.publishFeedResultLocked(self, result);
}

pub fn bumpGeneration(self: anytype) u64 {
    return publication_updates.bumpGeneration(self);
}

pub fn requestViewRefreshLocked(self: anytype, scroll_offset: usize) u64 {
    return publication_updates.requestViewRefreshLocked(self, scroll_offset);
}

pub fn queueViewRefreshLocked(self: anytype, scroll_offset: usize) void {
    publication_updates.queueViewRefreshLocked(self, scroll_offset);
}

pub fn clearPendingViewRefresh(self: anytype) void {
    publication_updates.clearPendingViewRefresh(self);
}

pub fn publishGenerationLocked(self: anytype, generation: u64, scroll_offset: usize, source: []const u8) void {
    view_cache.updateViewCacheNoLockTagged(self, generation, scroll_offset, source);
}

pub fn publishCurrentViewLocked(self: anytype, source: []const u8) void {
    publishGenerationLocked(self, pendingGeneration(self), self.core.scrollbackOffset(), source);
}

pub fn applyPendingViewRefreshLocked(self: anytype, source: []const u8) bool {
    return publication_updates.applyPendingViewRefreshLocked(self, source);
}

pub fn updateViewCacheForScroll(self: anytype) void {
    publication_updates.updateViewCacheForScroll(self);
}

pub fn updateViewCacheForScrollLocked(self: anytype) void {
    publication_updates.updateViewCacheForScrollLocked(self);
}

pub fn renderCache(self: anytype) *const RenderCache {
    const idx = self.publication.render_cache_index.load(.acquire);
    return &self.publication.render_caches[idx];
}

pub fn activeRenderCacheIndex(self: anytype) u8 {
    return self.publication.render_cache_index.load(.acquire);
}

pub fn inactiveRenderCacheIndex(self: anytype) u8 {
    return if (activeRenderCacheIndex(self) == 0) 1 else 0;
}

pub fn activeRenderCache(self: anytype) *RenderCache {
    return &self.publication.render_caches[activeRenderCacheIndex(self)];
}

pub fn inactiveRenderCache(self: anytype) *RenderCache {
    return &self.publication.render_caches[inactiveRenderCacheIndex(self)];
}

pub fn publishRenderCacheIndex(self: anytype, index: u8) void {
    self.publication.render_cache_index.store(index, .release);
}

pub fn renderCacheForGeneration(self: anytype, generation: u64) ?*const RenderCache {
    inline for (0..2) |i| {
        const cache = &self.publication.render_caches[i];
        if (cache.generation == generation) return cache;
    }
    return null;
}

pub fn clearPublishedDamage(self: anytype) void {
    inline for (0..2) |i| {
        self.publication.render_caches[i].dirty = .none;
        self.publication.render_caches[i].damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
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

pub fn pendingGeneration(self: anytype) u64 {
    return publication_state.pendingGeneration(self);
}

pub fn outputPending(self: anytype) bool {
    return publication_state.outputPending(self);
}

pub fn clearOutputPending(self: anytype) bool {
    return publication_state.clearOutputPending(self);
}

pub fn markOutputPending(self: anytype) void {
    publication_state.markOutputPending(self);
}

pub fn viewRefreshPending(self: anytype) bool {
    return publication_state.viewRefreshPending(self);
}

pub fn takePendingViewRefresh(self: anytype) ?usize {
    return publication_state.takePendingViewRefresh(self);
}

pub fn takeAltExitPending(self: anytype) bool {
    return publication_state.takeAltExitPending(self);
}

pub fn consumeAltExitTimeMs(self: anytype) i64 {
    return publication_state.consumeAltExitTimeMs(self);
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
    self.publication.alt_exit_pending.store(true, .release);
    self.publication.alt_exit_time_ms.store(std.time.milliTimestamp(), .release);
}

pub fn completePresentationFeedback(self: anytype, feedback: anytype) void {
    presentation_handoff.completePresentationFeedback(self, feedback);
}

pub fn finishFramePresentation(self: anytype, feedback: anytype) void {
    presentation_handoff.finishFramePresentation(self, feedback);
}
