const app_logger = @import("../../app_logger.zig");
const terminal_publication = @import("terminal_publication.zig");

pub fn clearPublishedDamageIfGeneration(self: anytype, expected_generation: u64, clear_screen_dirty: bool) bool {
    self.lock();
    defer self.unlock();
    const current_generation = self.output_generation.load(.acquire);
    const cache = terminal_publication.renderCache(self);
    if (current_generation != expected_generation) {
        if (clear_screen_dirty) {
            const rows = cache.rows;
            const cols = cache.cols;
            const damage_rows = if (cache.damage.end_row >= cache.damage.start_row) cache.damage.end_row - cache.damage.start_row + 1 else 0;
            const damage_cols = if (cache.damage.end_col >= cache.damage.start_col) cache.damage.end_col - cache.damage.start_col + 1 else 0;
            app_logger.logger("terminal.ui.dirty_retirement").logf(
                .info,
                "result=skipped expected_generation={d} current_generation={d} dirty={s} damage_rows={d} damage_cols={d} rows={d} cols={d}",
                .{
                    expected_generation,
                    current_generation,
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
    inline for (0..2) |i| {
        self.render_caches[i].dirty = .none;
        self.render_caches[i].damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
    }
    return true;
}

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
    const log = app_logger.logger("terminal.generation_handoff");
    var current = self.presented_generation.load(.acquire);
    while (generation > current) {
        current = self.presented_generation.cmpxchgWeak(current, generation, .acq_rel, .acquire) orelse {
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
                currentGeneration(self),
                publishedGeneration(self),
                presentedGeneration(self),
            },
        );
    }
    return cleared;
}

pub fn hasPublishedGenerationBacklog(self: anytype) bool {
    return currentGeneration(self) != publishedGeneration(self);
}

fn renderCacheSyncUpdatesActiveForGeneration(self: anytype, generation: u64) bool {
    inline for (0..2) |i| {
        if (self.render_caches[i].generation == generation) {
            return self.render_caches[i].sync_updates_active;
        }
    }
    return self.core.syncUpdatesActive();
}
