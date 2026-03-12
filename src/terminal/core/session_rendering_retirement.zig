const app_logger = @import("../../app_logger.zig");

pub fn clearPublishedDamageIfGeneration(self: anytype, expected_generation: u64, clear_screen_dirty: bool) bool {
    self.lock();
    defer self.unlock();
    const current_generation = self.output_generation.load(.acquire);
    if (current_generation != expected_generation) {
        if (clear_screen_dirty) {
            const view = self.activeScreenConst().snapshotView();
            const rows = view.rows;
            const cols = view.cols;
            const damage_rows = if (view.damage.end_row >= view.damage.start_row) view.damage.end_row - view.damage.start_row + 1 else 0;
            const damage_cols = if (view.damage.end_col >= view.damage.start_col) view.damage.end_col - view.damage.start_col + 1 else 0;
            app_logger.logger("terminal.ui.dirty_retirement").logf(
                .info,
                "result=skipped expected_generation={d} current_generation={d} dirty={s} damage_rows={d} damage_cols={d} rows={d} cols={d}",
                .{
                    expected_generation,
                    current_generation,
                    @tagName(view.dirty),
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
        const view = self.activeScreenConst().snapshotView();
        const rows = view.rows;
        const cols = view.cols;
        const damage_rows = if (view.damage.end_row >= view.damage.start_row) view.damage.end_row - view.damage.start_row + 1 else 0;
        const damage_cols = if (view.damage.end_col >= view.damage.start_col) view.damage.end_col - view.damage.start_col + 1 else 0;
        app_logger.logger("terminal.ui.dirty_retirement").logf(
            .info,
            "result=cleared generation={d} dirty={s} damage_rows={d} damage_cols={d} rows={d} cols={d}",
            .{
                expected_generation,
                @tagName(view.dirty),
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

pub fn notePresentedGeneration(self: anytype, generation: u64) void {
    var current = self.presented_generation.load(.acquire);
    while (generation > current) {
        current = self.presented_generation.cmpxchgWeak(current, generation, .acq_rel, .acquire) orelse return;
    }
}

pub fn acknowledgePresentedGeneration(self: anytype, generation: u64) bool {
    notePresentedGeneration(self, generation);
    if (renderCacheSyncUpdatesActiveForGeneration(self, generation)) {
        return clearPublishedDamageIfGeneration(self, generation, false);
    }
    return clearPublishedDamageIfGeneration(self, generation, true);
}

fn renderCacheSyncUpdatesActiveForGeneration(self: anytype, generation: u64) bool {
    inline for (0..2) |i| {
        if (self.render_caches[i].generation == generation) {
            return self.render_caches[i].sync_updates_active;
        }
    }
    return self.core.sync_updates_active;
}
