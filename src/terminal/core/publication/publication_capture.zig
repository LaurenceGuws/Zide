const std = @import("std");
const render_cache_mod = @import("render_cache.zig");
const presentation_feedback = @import("presentation_feedback.zig");
const publication_flow = @import("publication_flow.zig");
const publication_state = @import("publication_state.zig");

pub const RenderCache = render_cache_mod.RenderCache;
pub const PresentedRenderCache = presentation_feedback.PresentedRenderCache;

pub const PresentationCapture = struct {
    lock_ms: f64,
    lock_wait_ms: f64,
    lock_hold_ms: f64,
    view_cache_ms: f64,
    cache_copy_ms: f64,
    presented: PresentedRenderCache,
};

pub const GenerationState = publication_state.GenerationState;

pub const LatestPresentationPreparation = struct {
    capture: PresentationCapture,
    generation_state: GenerationState,
    refreshed: bool,
};

const CaptureCopy = struct {
    presented: PresentedRenderCache,
    lock_wait_ms: f64,
    lock_hold_ms: f64,
    view_cache_ms: f64,
    cache_copy_ms: f64,
};

pub fn capturePresentation(self: anytype, dst: *RenderCache) !PresentationCapture {
    const copy = try captureCopy(self, dst);
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
    const published_now = publication_state.publishedGeneration(self);
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

pub fn generationState(self: anytype) GenerationState {
    return publication_state.generationState(self);
}

fn captureCopy(self: anytype, dst: *RenderCache) !CaptureCopy {
    const wait_start_ns = std.time.nanoTimestamp();
    self.lock();
    defer self.unlock();
    const lock_acquired_ns = std.time.nanoTimestamp();
    var view_cache_ms: f64 = 0.0;
    if (publication_flow.viewRefreshPending(self)) {
        const view_cache_start_ns = std.time.nanoTimestamp();
        _ = publication_flow.applyPendingViewRefreshLocked(self, "capture_copy");
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

fn renderCache(self: anytype) *const RenderCache {
    const idx = self.session.publication.render_cache_index.load(.acquire);
    return &self.session.publication.render_caches[idx];
}
