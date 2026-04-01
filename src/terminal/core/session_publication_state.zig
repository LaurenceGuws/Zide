const app_logger = @import("../../app_logger.zig");
const terminal_publication = @import("terminal_publication.zig");

pub fn outputPending(self: anytype) bool {
    return self.publication.output_pending.load(.acquire);
}

pub fn clearOutputPending(self: anytype) bool {
    return self.publication.output_pending.swap(false, .acq_rel);
}

pub fn markOutputPending(self: anytype) void {
    self.publication.output_pending.store(true, .release);
}

pub fn viewRefreshPending(self: anytype) bool {
    return self.publication.view_cache_pending.load(.acquire);
}

pub fn takePendingViewRefresh(self: anytype) ?usize {
    if (!self.publication.view_cache_pending.swap(false, .acq_rel)) return null;
    return @intCast(self.publication.view_cache_request_offset.load(.acquire));
}

pub fn takeAltExitPending(self: anytype) bool {
    return self.publication.alt_exit_pending.swap(false, .acq_rel);
}

pub fn consumeAltExitTimeMs(self: anytype) i64 {
    return self.publication.alt_exit_time_ms.swap(-1, .acq_rel);
}

pub fn clearPublishedDamageIfGeneration(self: anytype, expected_generation: u64, clear_screen_dirty: bool) bool {
    self.lock();
    defer self.unlock();
    const pending_generation = self.publication.pending_generation.load(.acquire);
    const cache = terminal_publication.renderCache(self);
    if (pending_generation != expected_generation) {
        if (clear_screen_dirty) {
            const rows = cache.rows;
            const cols = cache.cols;
            const damage_rows = if (cache.damage.end_row >= cache.damage.start_row) cache.damage.end_row - cache.damage.start_row + 1 else 0;
            const damage_cols = if (cache.damage.end_col >= cache.damage.start_col) cache.damage.end_col - cache.damage.start_col + 1 else 0;
            app_logger.logger("terminal.ui.dirty_retirement").logf(
                .info,
                "result=skipped expected_generation={d} pending_generation={d} dirty={s} damage_rows={d} damage_cols={d} rows={d} cols={d}",
                .{
                    expected_generation,
                    pending_generation,
                    @tagName(cache.dirty),
                    damage_rows,
                    damage_cols,
                    rows,
                    cols,
                },
            );
        }
        return false;
    }
    if (clear_screen_dirty) {
        const rows = cache.rows;
        const cols = cache.cols;
        const damage_rows = if (cache.damage.end_row >= cache.damage.start_row) cache.damage.end_row - cache.damage.start_row + 1 else 0;
        const damage_cols = if (cache.damage.end_col >= cache.damage.start_col) cache.damage.end_col - cache.damage.start_col + 1 else 0;
        app_logger.logger("terminal.ui.dirty_retirement").logf(
            .info,
            "result=cleared generation={d} dirty={s} damage_rows={d} damage_cols={d} rows={d} cols={d}",
            .{
                expected_generation,
                @tagName(cache.dirty),
                damage_rows,
                damage_cols,
                rows,
                cols,
            },
        );
        self.activeScreen().clearDirty();
    }
    terminal_publication.clearPublishedDamage(self);
    return true;
}

pub fn pendingGeneration(self: anytype) u64 {
    return self.publication.pending_generation.load(.acquire);
}

pub fn publishedGeneration(self: anytype) u64 {
    return terminal_publication.renderCache(self).generation;
}

pub fn presentedGeneration(self: anytype) u64 {
    return self.publication.presented_generation.load(.acquire);
}

pub fn notePresentedGeneration(self: anytype, generation: u64) void {
    const log = app_logger.logger("terminal.generation_handoff");
    var current = self.publication.presented_generation.load(.acquire);
    while (generation > current) {
        current = self.publication.presented_generation.cmpxchgWeak(current, generation, .acq_rel, .acquire) orelse {
            if (log.enabled_file or log.enabled_console) {
                log.logf(
                    .info,
                    "stage=note_presented sid={x} presented={d}->{d}",
                    .{ @intFromPtr(self), current, generation },
                );
            }
            return;
        };
    }
}

pub fn acknowledgePresentedGeneration(self: anytype, generation: u64) bool {
    const log = app_logger.logger("terminal.generation_handoff");
    notePresentedGeneration(self, generation);
    const sync_updates_active = renderCacheSyncUpdatesActiveForGeneration(self, generation);
    const cleared = if (sync_updates_active)
        clearPublishedDamageIfGeneration(self, generation, false)
    else
        clearPublishedDamageIfGeneration(self, generation, true);
    if (log.enabled_file or log.enabled_console) {
        log.logf(
            .info,
            "stage=ack_presented sid={x} generation={d} cleared={d} sync_updates={d} cur={d} pub={d} presented={d}",
            .{
                @intFromPtr(self),
                generation,
                @intFromBool(cleared),
                @intFromBool(sync_updates_active),
                pendingGeneration(self),
                publishedGeneration(self),
                presentedGeneration(self),
            },
        );
    }
    return cleared;
}

pub fn hasPublishedGenerationBacklog(self: anytype) bool {
    return pendingGeneration(self) != publishedGeneration(self);
}

fn renderCacheSyncUpdatesActiveForGeneration(self: anytype, generation: u64) bool {
    if (terminal_publication.renderCacheForGeneration(self, generation)) |cache| {
        return cache.sync_updates_active;
    }
    return self.core.syncUpdatesActive();
}
