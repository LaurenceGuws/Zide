const app_logger = @import("../../app_logger.zig");
const kitty_mod = @import("../kitty/graphics.zig");

pub fn scrollRegionUp(self: anytype, count: usize) void {
    const log = app_logger.logger("terminal.core");
    const screen = self.activeScreen();
    log.logf(.info, "scroll region up count={d} top={d} bottom={d}", .{ count, screen.scroll_top, screen.scroll_bottom });
    log.logStdout(.info, "scroll region up count={d}", .{count});
    const trace = app_logger.logger("terminal.trace.scroll");
            trace.logf(.info, 
            "scroll_up count={d} cursor={d},{d} origin={any} region={d}..{d}",
            .{ count, screen.cursor.row, screen.cursor.col, screen.origin_mode, screen.scroll_top, screen.scroll_bottom },
        );
    const cols = @as(usize, screen.grid.cols);
    if (cols == 0 or screen.grid.rows == 0) return;
    const n = @min(count, screen.scroll_bottom - screen.scroll_top + 1);
    if (n == 0) return;
    const blank_cell = screen.blankCell();
    if (isFullScrollRegion(self)) {
        var row: usize = 0;
        while (row < n) : (row += 1) {
            pushScrollbackRow(self, screen.scroll_top + row);
        }
        kitty_mod.updateKittyPlacementsForScroll(self);
        _ = self.clear_generation.fetchAdd(1, .acq_rel);
    }
    screen.scrollRegionUpBy(n, blank_cell);
    self.force_full_damage.store(true, .release);
    if (!isFullScrollRegion(self)) {
        kitty_mod.shiftKittyPlacementsUp(self, screen.scroll_top, screen.scroll_bottom, n);
    }
}

pub fn scrollRegionDown(self: anytype, count: usize) void {
    const screen = self.activeScreen();
    const trace = app_logger.logger("terminal.trace.scroll");
            trace.logf(.info, 
            "scroll_down count={d} cursor={d},{d} origin={any} region={d}..{d}",
            .{ count, screen.cursor.row, screen.cursor.col, screen.origin_mode, screen.scroll_top, screen.scroll_bottom },
        );
    const cols = @as(usize, screen.grid.cols);
    if (cols == 0 or screen.grid.rows == 0) return;
    const n = @min(count, screen.scroll_bottom - screen.scroll_top + 1);
    if (n == 0) return;
    const blank_cell = screen.blankCell();
    screen.scrollRegionDownBy(n, blank_cell);
    kitty_mod.shiftKittyPlacementsDown(self, screen.scroll_top, screen.scroll_bottom, n);
    _ = self.clear_generation.fetchAdd(1, .acq_rel);
    self.force_full_damage.store(true, .release);
}

pub fn scrollUp(self: anytype) void {
    const log = app_logger.logger("terminal.core");
    const screen = self.activeScreen();
    log.logf(.info, "scroll up rows={d} cols={d}", .{ screen.grid.rows, screen.grid.cols });
    log.logStdout(.info, "scroll up rows={d} cols={d}", .{ screen.grid.rows, screen.grid.cols });
    const cols = @as(usize, screen.grid.cols);
    const rows = @as(usize, screen.grid.rows);
    if (rows == 0 or cols == 0) return;

    if (isFullScrollRegion(self)) {
        pushScrollbackRow(self, 0);
        kitty_mod.updateKittyPlacementsForScroll(self);
        _ = self.clear_generation.fetchAdd(1, .acq_rel);
    }
    const blank_cell = screen.blankCell();
    screen.scrollUp(blank_cell);
    self.force_full_damage.store(true, .release);
    if (!isFullScrollRegion(self)) {
        kitty_mod.shiftKittyPlacementsUp(self, 0, rows - 1, 1);
    }
}

fn isFullScrollRegion(self: anytype) bool {
    return self.activeScreenConst().isFullScrollRegion();
}

fn pushScrollbackRow(self: anytype, row: usize) void {
    if (self.active == .alt) return;
    const screen = &self.primary;
    const cols = @as(usize, screen.grid.cols);
    if (cols == 0 or screen.grid.rows == 0) return;
    if (row >= @as(usize, screen.grid.rows)) return;
    const row_start = row * cols;
    const wrapped = screen.grid.rowWrapped(row);
    self.history.pushRow(screen.grid.cells.items[row_start .. row_start + cols], wrapped, screen.defaultCell());
    self.kitty_primary.scrollback_total += 1;
    const log = app_logger.logger("terminal.core");
    log.logf(.info, "scrollback push row={d} total={d}", .{ row, self.history.scrollbackCount() });
    log.logStdout(.info, "scrollback push total={d}", .{self.history.scrollbackCount()});
}
