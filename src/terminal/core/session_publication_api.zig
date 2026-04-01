const terminal_publication = @import("terminal_publication.zig");

pub fn pendingGeneration(self: anytype) u64 {
    return terminal_publication.pendingGeneration(self);
}

pub fn outputPending(self: anytype) bool {
    return terminal_publication.outputPending(self);
}

pub fn clearOutputPending(self: anytype) bool {
    return terminal_publication.clearOutputPending(self);
}

pub fn markOutputPending(self: anytype) void {
    terminal_publication.markOutputPending(self);
}

pub fn viewRefreshPending(self: anytype) bool {
    return terminal_publication.viewRefreshPending(self);
}

pub fn takePendingViewRefresh(self: anytype) ?usize {
    return terminal_publication.takePendingViewRefresh(self);
}

pub fn takeAltExitPending(self: anytype) bool {
    return terminal_publication.takeAltExitPending(self);
}

pub fn consumeAltExitTimeMs(self: anytype) i64 {
    return terminal_publication.consumeAltExitTimeMs(self);
}

pub fn publishedGeneration(self: anytype) u64 {
    return terminal_publication.publishedGeneration(self);
}

pub fn presentedGeneration(self: anytype) u64 {
    return terminal_publication.presentedGeneration(self);
}

pub fn notePresentedGeneration(self: anytype, generation: u64) void {
    terminal_publication.notePresentedGeneration(self, generation);
}

pub fn acknowledgePresentedGeneration(self: anytype, generation: u64) bool {
    return terminal_publication.acknowledgePresentedGeneration(self, generation);
}

pub fn hasPublishedGenerationBacklog(self: anytype) bool {
    return terminal_publication.hasPublishedGenerationBacklog(self);
}

pub fn snapshot(self: anytype) @import("snapshot.zig").TerminalSnapshot {
    return terminal_publication.snapshot(self);
}

pub fn renderCache(self: anytype) *const @import("render_cache.zig").RenderCache {
    return terminal_publication.renderCache(self);
}

pub fn copyPublishedRenderCache(
    self: anytype,
    dst: *@import("render_cache.zig").RenderCache,
) !@import("terminal_publication.zig").PresentedRenderCache {
    return terminal_publication.copyPublishedRenderCache(self, dst);
}

pub fn capturePresentation(
    self: anytype,
    dst: *@import("render_cache.zig").RenderCache,
) !@import("terminal_publication.zig").PresentationCapture {
    return terminal_publication.capturePresentation(self, dst);
}

pub fn completePresentationFeedback(
    self: anytype,
    feedback: @import("terminal_publication.zig").PresentationFeedback,
) void {
    terminal_publication.completePresentationFeedback(self, feedback);
}

pub fn finishFramePresentation(
    self: anytype,
    feedback: @import("terminal_publication.zig").PresentationFeedback,
) void {
    terminal_publication.finishFramePresentation(self, feedback);
}

pub fn syncUpdatesActive(self: anytype) bool {
    return terminal_publication.syncUpdatesActive(self);
}

pub fn setSyncUpdates(self: anytype, enabled: bool) void {
    terminal_publication.setSyncUpdates(self, enabled);
}

pub fn setSyncUpdatesLocked(self: anytype, enabled: bool) void {
    terminal_publication.setSyncUpdatesLocked(self, enabled);
}

pub fn clearPublishedDamageIfGeneration(self: anytype, expected_generation: u64, clear_screen_dirty: bool) bool {
    return terminal_publication.clearPublishedDamageIfGeneration(self, expected_generation, clear_screen_dirty);
}

pub fn updateViewCacheForScroll(self: anytype) void {
    terminal_publication.updateViewCacheForScroll(self);
}

pub fn updateViewCacheForScrollLocked(self: anytype) void {
    terminal_publication.updateViewCacheForScrollLocked(self);
}
