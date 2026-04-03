const view_cache = @import("view_cache.zig");

pub const ViewRefreshRequest = struct {
    generation: u64,
    scroll_offset: usize,
};

pub fn consumeSelectionMutationLocked(
    self: anytype,
    effect: @import("../terminal_core.zig").TerminalCore.SelectionMutationEffect,
) bool {
    if (!effect.changed) return false;
    _ = requestViewRefreshLocked(self, effect.scroll_offset);
    return true;
}

pub fn consumeScrollOffsetMutationLocked(self: anytype, before: usize, after: usize) bool {
    const generation = requestViewRefreshIfOffsetChangedLocked(self, before, after);
    _ = generation;
    view_cache.updateViewCacheForScrollLocked(self);
    return after != before;
}

pub fn consumeFeedResultLocked(
    self: anytype,
    result: @import("../protocol/terminal_core_feed.zig").FeedResult,
    source: []const u8,
) void {
    if (!result.parsed) return;
    _ = noteParsedOutputLocked(self);
    view_cache.updateViewCacheNoLockTagged(self, pendingGeneration(self), result.scroll_offset, source);
}

pub fn bumpGeneration(self: anytype) u64 {
    return self.session.publication.pending_generation.fetchAdd(1, .acq_rel) + 1;
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
    view_cache.updateViewCacheForScrollLocked(self);
    return generation;
}

pub fn refreshScrollViewLocked(self: anytype, scroll_offset: usize) void {
    queueViewRefreshLocked(self, scroll_offset);
    view_cache.updateViewCacheForScrollLocked(self);
}

pub fn queueViewRefreshLocked(self: anytype, scroll_offset: usize) void {
    self.session.publication.view_cache_request_offset.store(@intCast(scroll_offset), .release);
    self.session.publication.view_cache_pending.store(true, .release);
    self.session.runtime.io_wait_cond.signal();
}

fn clearPendingViewRefresh(self: anytype) void {
    self.session.publication.view_cache_pending.store(false, .release);
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
    if (!self.session.publication.view_cache_pending.swap(false, .acq_rel)) return false;
    const offset: usize = @intCast(self.session.publication.view_cache_request_offset.load(.acquire));
    view_cache.updateViewCacheNoLockTagged(self, pendingGeneration(self), offset, source);
    return true;
}

pub fn publishPollUpdateLocked(self: anytype, had_data: bool, publish_source: []const u8, refresh_source: []const u8) bool {
    if (had_data) {
        publishCurrentViewLocked(self, publish_source);
    }
    return applyPendingViewRefreshLocked(self, refresh_source);
}

pub fn pendingGeneration(self: anytype) u64 {
    return self.session.publication.pending_generation.load(.acquire);
}

pub fn outputPending(self: anytype) bool {
    return self.session.publication.output_pending.load(.acquire);
}

fn clearOutputPending(self: anytype) bool {
    return self.session.publication.output_pending.swap(false, .acq_rel);
}

pub fn markOutputPending(self: anytype) void {
    self.session.publication.output_pending.store(true, .release);
}

pub fn viewRefreshPending(self: anytype) bool {
    return self.session.publication.view_cache_pending.load(.acquire);
}

fn takePendingViewRefresh(self: anytype) ?usize {
    if (!self.session.publication.view_cache_pending.swap(false, .acq_rel)) return null;
    return @intCast(self.session.publication.view_cache_request_offset.load(.acquire));
}

pub fn takePendingViewRefreshRequest(self: anytype) ?ViewRefreshRequest {
    const scroll_offset = takePendingViewRefresh(self) orelse return null;
    return .{
        .generation = pendingGeneration(self),
        .scroll_offset = scroll_offset,
    };
}

fn takeAltExitPending(self: anytype) bool {
    return self.session.publication.alt_exit_pending.swap(false, .acq_rel);
}

pub fn hasPublishedGenerationBacklog(self: anytype) bool {
    return pendingGeneration(self) != @import("terminal_publication.zig").publishedGeneration(self);
}

pub fn clearPublishedOutputPending(self: anytype) bool {
    return clearOutputPending(self);
}

pub fn noteProcessedOutput(self: anytype, processed: usize) void {
    if (processed > 0) _ = takeAltExitPending(self);
}
