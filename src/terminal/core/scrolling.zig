const kitty_mod = @import("../kitty/graphics.zig");
const terminal_core_mod = @import("terminal_core.zig");

const ScrollAction = terminal_core_mod.TerminalCore.ScrollAction;

pub fn consumeScrollAction(self: anytype, action: ScrollAction) void {
    switch (action) {
        .none => {},
        .scroll_region_up => |value| scrollRegionUpWithOrigin(self, value.count, value.origin),
        .scroll_full_up => |count| {
            var i: usize = 0;
            while (i < count) : (i += 1) {
                scrollUp(self);
            }
        },
        .scroll_region_down => |count| scrollRegionDown(self, count),
    }
}

pub fn scrollRegionUpWithOrigin(self: anytype, count: usize, origin: ?[]const u8) void {
    const core = if (@hasField(@TypeOf(self.*), "active") and @hasField(@TypeOf(self.*), "history"))
        self
    else
        self.core;
    const screen = core.activeScreen();
    const cols = @as(usize, screen.grid.cols);
    if (cols == 0 or screen.grid.rows == 0) return;
    const n = @min(count, screen.scroll_bottom - screen.scroll_top + 1);
    if (n == 0) return;
    const blank_cell = screen.blankCell();
    if (regionFeedsScrollback(self)) {
        var row: usize = 0;
        while (row < n) : (row += 1) {
            pushScrollbackRow(self, screen.scroll_top + row);
        }
        kitty_mod.updateKittyPlacementsForScroll(self);
    }
    screen.scrollRegionUpByWithOrigin(n, blank_cell, origin);
    if (!regionFeedsScrollback(self)) {
        kitty_mod.shiftKittyPlacementsUp(self, screen.scroll_top, screen.scroll_bottom, n);
    }
}

pub fn scrollRegionUp(self: anytype, count: usize) void {
    scrollRegionUpWithOrigin(self, count, null);
}

pub fn scrollRegionDown(self: anytype, count: usize) void {
    const core = if (@hasField(@TypeOf(self.*), "active") and @hasField(@TypeOf(self.*), "history"))
        self
    else
        self.core;
    const screen = core.activeScreen();
    const cols = @as(usize, screen.grid.cols);
    if (cols == 0 or screen.grid.rows == 0) return;
    const n = @min(count, screen.scroll_bottom - screen.scroll_top + 1);
    if (n == 0) return;
    const blank_cell = screen.blankCell();
    screen.scrollRegionDownBy(n, blank_cell);
    kitty_mod.shiftKittyPlacementsDown(self, screen.scroll_top, screen.scroll_bottom, n);
}

pub fn scrollUp(self: anytype) void {
    const core = if (@hasField(@TypeOf(self.*), "active") and @hasField(@TypeOf(self.*), "history"))
        self
    else
        self.core;
    const screen = core.activeScreen();
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
    const core = if (@hasField(@TypeOf(self.*), "active") and @hasField(@TypeOf(self.*), "history"))
        self
    else
        self.core;
    return core.activeScreenConst().isFullScrollRegion();
}

fn isTopAnchoredFullWidthRegion(self: anytype) bool {
    const core = if (@hasField(@TypeOf(self.*), "active") and @hasField(@TypeOf(self.*), "history"))
        self
    else
        self.core;
    const screen = core.activeScreenConst();
    if (core.active == .alt) return false;
    if (screen.scroll_top != 0) return false;
    if (screen.left_right_margin_mode_69) return false;
    const cols = @as(usize, screen.grid.cols);
    if (cols == 0) return false;
    return screen.leftBoundary() == 0 and screen.rightBoundary() + 1 == cols;
}

fn regionFeedsScrollback(self: anytype) bool {
    const full_region = isFullScrollRegion(self);
    const top_anchored = isTopAnchoredFullWidthRegion(self);
    const core = if (@hasField(@TypeOf(self.*), "active") and @hasField(@TypeOf(self.*), "history"))
        self
    else
        self.core;
    if (core.sync_updates_active) {
        return top_anchored and !full_region;
    }
    return full_region or top_anchored;
}

fn pushScrollbackRow(self: anytype, row: usize) void {
    const core = if (@hasField(@TypeOf(self.*), "active") and @hasField(@TypeOf(self.*), "history"))
        self
    else
        self.core;
    if (core.active == .alt) return;
    const screen = &core.primary;
    const cols = @as(usize, screen.grid.cols);
    if (cols == 0 or screen.grid.rows == 0) return;
    if (row >= @as(usize, screen.grid.rows)) return;
    const row_start = row * cols;
    const wrapped = screen.grid.rowWrapped(row);
    core.history.pushRow(screen.grid.cells.items[row_start .. row_start + cols], wrapped, screen.defaultCell());
    core.kitty_primary.scrollback_total += 1;
}
