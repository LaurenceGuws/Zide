const std = @import("std");
const render_cache_mod = @import("render_cache.zig");

pub const PresentedRenderCache = struct {
    generation: u64,
    dirty: @import("../../model/screen.zig").Dirty,
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
    alt_exit_info: ?AltExitPresentationInfo = null,
};

pub fn consumeAltExitTimeMs(self: anytype) i64 {
    return self.session.publication.alt_exit_time_ms.swap(-1, .acq_rel);
}

pub fn noteAltExitPending(self: anytype) void {
    self.session.publication.alt_exit_pending.store(true, .release);
    self.session.publication.alt_exit_time_ms.store(std.time.milliTimestamp(), .release);
}

pub fn acknowledgePresentedGeneration(self: anytype, generation: u64) bool {
    self.lock();
    defer self.unlock();
    return retirePresentedGenerationLocked(self, generation);
}

pub fn completeSubmittedPresentationFeedback(self: anytype, feedback: anytype, submission: anytype) void {
    if (!submission.succeeded) return;
    completePresentationFeedback(self, feedback, submission);
}

fn submittedPresentationMatchesFeedback(feedback: anytype, submission: anytype) bool {
    const presented = feedback.presented orelse return false;
    if (!submission.terminal_presented) return false;
    const submitted_generation = submission.terminal_presented_generation orelse return false;
    return submitted_generation == presented.generation;
}

fn completePresentationFeedback(self: anytype, feedback: anytype, submission: anytype) void {
    if (submittedPresentationMatchesFeedback(feedback, submission)) {
        if (feedback.presented) |presented| {
            _ = acknowledgePresentedGeneration(self, presented.generation);
        }
    }
    if (feedback.alt_exit_info) |info| {
        const exit_time_ms = consumeAltExitTimeMs(self);
        const exit_to_draw_ms: f64 = if (exit_time_ms >= 0)
            @as(f64, @floatFromInt(std.time.milliTimestamp() - exit_time_ms))
        else
            -1.0;
        _ = info;
        _ = exit_to_draw_ms;
    }
}

fn retirePresentedGenerationLocked(self: anytype, generation: u64) bool {
    notePresentedGeneration(self, generation);
    if (pendingGeneration(self) != generation) return false;

    if (shouldClearScreenDirtyOnPresentationRetirement(self, generation)) {
        self.core.activeScreen().clearDirty();
    }
    clearPublishedDamageLocked(self);
    return true;
}

fn shouldClearScreenDirtyOnPresentationRetirement(self: anytype, generation: u64) bool {
    if (renderCacheForGeneration(self, generation)) |cache| {
        return !cache.sync_updates_active;
    }
    return !self.core.syncUpdatesActive();
}

fn notePresentedGeneration(self: anytype, generation: u64) void {
    var current = self.session.publication.presented_generation.load(.acquire);
    while (generation > current) {
        current = self.session.publication.presented_generation.cmpxchgWeak(current, generation, .acq_rel, .acquire) orelse return;
    }
}

fn pendingGeneration(self: anytype) u64 {
    return self.session.publication.pending_generation.load(.acquire);
}

fn renderCache(self: anytype) *const render_cache_mod.RenderCache {
    const idx = self.session.publication.render_cache_index.load(.acquire);
    return &self.session.publication.render_caches[idx];
}

fn renderCacheForGeneration(self: anytype, generation: u64) ?*const render_cache_mod.RenderCache {
    inline for (0..2) |i| {
        const cache = &self.session.publication.render_caches[i];
        if (cache.generation == generation) return cache;
    }
    return null;
}

fn clearPublishedDamageLocked(self: anytype) void {
    inline for (0..2) |i| {
        self.session.publication.render_caches[i].dirty = .none;
        self.session.publication.render_caches[i].damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
    }
}
