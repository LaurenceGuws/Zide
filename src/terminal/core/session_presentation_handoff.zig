const std = @import("std");
const render_cache_mod = @import("render_cache.zig");
const terminal_publication = @import("terminal_publication.zig");

pub const RenderCache = render_cache_mod.RenderCache;
pub const PresentedRenderCache = terminal_publication.PresentedRenderCache;
pub const PresentationCapture = terminal_publication.PresentationCapture;

const CaptureCopy = struct {
    presented: PresentedRenderCache,
    lock_wait_ms: f64,
    lock_hold_ms: f64,
    view_cache_ms: f64,
    cache_copy_ms: f64,
};

fn captureCopy(self: anytype, dst: *RenderCache, log_capture: bool) !CaptureCopy {
    const handoff_log = @import("../../app_logger.zig").logger("terminal.generation_handoff");
    const wait_start_ns = std.time.nanoTimestamp();
    self.lock();
    defer self.unlock();
    const lock_acquired_ns = std.time.nanoTimestamp();
    const current_generation = self.output_generation.load(.acquire);
    const published_generation = @import("session_publication_state.zig").publishedGeneration(self);
    const presented_generation = @import("session_publication_state.zig").presentedGeneration(self);
    const had_view_cache_pending = self.view_cache_pending.load(.acquire);
    var view_cache_ms: f64 = 0.0;
    if (had_view_cache_pending) {
        const view_cache_start_ns = std.time.nanoTimestamp();
        terminal_publication.updateViewCacheForScrollLocked(self);
        const view_cache_end_ns = std.time.nanoTimestamp();
        view_cache_ms = @as(f64, @floatFromInt(view_cache_end_ns - view_cache_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
    }
    const copy_start_ns = std.time.nanoTimestamp();
    const cache = terminal_publication.renderCache(self);
    try render_cache_mod.copySnapshot(dst, self.allocator, cache);
    const copy_end_ns = std.time.nanoTimestamp();
    const presented = PresentedRenderCache{
        .generation = cache.generation,
        .dirty = cache.dirty,
    };
    const lock_release_ns = std.time.nanoTimestamp();
    const lock_wait_ms = @as(f64, @floatFromInt(lock_acquired_ns - wait_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
    const lock_hold_ms = @as(f64, @floatFromInt(lock_release_ns - lock_acquired_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
    if (log_capture and (handoff_log.enabled_file or handoff_log.enabled_console)) {
        handoff_log.logf(
            .info,
            "stage=capture sid={x} view_cache_pending={d} cur={d} pub_before={d} presented={d} captured={d} dirty={s} lock_wait_ms={d:.2} view_cache_ms={d:.2} copy_ms={d:.2}",
            .{
                @intFromPtr(self),
                @intFromBool(had_view_cache_pending),
                current_generation,
                published_generation,
                presented_generation,
                presented.generation,
                @tagName(presented.dirty),
                lock_wait_ms,
                view_cache_ms,
                @as(f64, @floatFromInt(copy_end_ns - copy_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
            },
        );
    }
    return .{
        .presented = presented,
        .lock_wait_ms = lock_wait_ms,
        .lock_hold_ms = lock_hold_ms,
        .view_cache_ms = view_cache_ms,
        .cache_copy_ms = @as(f64, @floatFromInt(copy_end_ns - copy_start_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
    };
}

pub fn copyPublishedRenderCache(self: anytype, dst: *RenderCache) !PresentedRenderCache {
    return (try captureCopy(self, dst, false)).presented;
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

pub fn completePresentationFeedback(self: anytype, feedback: anytype) void {
    if (feedback.presented) |presented| {
        if (feedback.texture_updated or presented.dirty == .none) {
            _ = @import("session_publication_state.zig").acknowledgePresentedGeneration(self, presented.generation);
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
