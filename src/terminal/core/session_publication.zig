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
    self.presented_generation.store(generation, .release);
}

pub fn acknowledgePresentedGeneration(self: anytype, generation: u64) bool {
    notePresentedGeneration(self, generation);
    if (renderCacheSyncUpdatesActiveForGeneration(self, generation)) {
        return self.clearPublishedDamageIfGeneration(generation, false);
    }
    return self.clearPublishedDamageIfGeneration(generation, true);
}

fn renderCacheSyncUpdatesActiveForGeneration(self: anytype, generation: u64) bool {
    inline for (0..2) |i| {
        if (self.render_caches[i].generation == generation) {
            return self.render_caches[i].sync_updates_active;
        }
    }
    return self.sync_updates_active;
}

pub fn hasPublishedGenerationBacklog(self: anytype) bool {
    return currentGeneration(self) != publishedGeneration(self);
}

pub fn pollBacklogHint(self: anytype) bool {
    return self.hasData() or hasPublishedGenerationBacklog(self);
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
            @as(f64, @floatFromInt(@import("std").time.milliTimestamp() - exit_time_ms))
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
