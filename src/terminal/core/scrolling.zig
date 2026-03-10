const kitty_mod = @import("../kitty/graphics.zig");

pub fn scrollRegionUp(self: anytype, count: usize) void {
    const screen = self.core.activeScreen();
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
    }
    screen.scrollRegionUpBy(n, blank_cell);
    if (!isFullScrollRegion(self)) {
        kitty_mod.shiftKittyPlacementsUp(self, screen.scroll_top, screen.scroll_bottom, n);
    }
}

pub fn scrollRegionDown(self: anytype, count: usize) void {
    const screen = self.core.activeScreen();
    const cols = @as(usize, screen.grid.cols);
    if (cols == 0 or screen.grid.rows == 0) return;
    const n = @min(count, screen.scroll_bottom - screen.scroll_top + 1);
    if (n == 0) return;
    const blank_cell = screen.blankCell();
    screen.scrollRegionDownBy(n, blank_cell);
    kitty_mod.shiftKittyPlacementsDown(self, screen.scroll_top, screen.scroll_bottom, n);
}

pub fn scrollUp(self: anytype) void {
    const screen = self.core.activeScreen();
    const cols = @as(usize, screen.grid.cols);
    const rows = @as(usize, screen.grid.rows);
    if (rows == 0 or cols == 0) return;

    if (isFullScrollRegion(self)) {
        pushScrollbackRow(self, 0);
        kitty_mod.updateKittyPlacementsForScroll(self);
    }
    const blank_cell = screen.blankCell();
    screen.scrollUp(blank_cell);
    if (!isFullScrollRegion(self)) {
        kitty_mod.shiftKittyPlacementsUp(self, 0, rows - 1, 1);
    }
}

fn isFullScrollRegion(self: anytype) bool {
    return self.core.activeScreenConst().isFullScrollRegion();
}

fn pushScrollbackRow(self: anytype, row: usize) void {
    if (self.core.active == .alt) return;
    const screen = &self.core.primary;
    const cols = @as(usize, screen.grid.cols);
    if (cols == 0 or screen.grid.rows == 0) return;
    if (row >= @as(usize, screen.grid.rows)) return;
    const row_start = row * cols;
    const wrapped = screen.grid.rowWrapped(row);
    self.core.history.pushRow(screen.grid.cells.items[row_start .. row_start + cols], wrapped, screen.defaultCell());
    self.core.kitty_primary.scrollback_total += 1;
}
