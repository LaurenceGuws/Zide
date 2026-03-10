const types = @import("../types.zig");

pub fn setCursor(self: anytype, row: usize, col: usize) void {
    self.cursor = .{ .row = row, .col = col };
    self.clampCursorToMargins();
}

pub fn backspace(self: anytype) void {
    if (self.cursor.col > 0) {
        self.cursor.col -= 1;
        self.wrap_next = false;
        return;
    }
    if (self.reverse_wrap and self.cursor.row > self.scroll_top and self.grid.rowWrapped(self.cursor.row - 1)) {
        self.cursor.row -= 1;
        self.cursor.col = @as(usize, self.grid.cols - 1);
    }
    self.wrap_next = false;
}

pub fn tab(self: anytype) void {
    if (self.grid.cols == 0) return;
    const max_col = self.rightBoundary();
    const next = self.tabstops.next(self.cursor.col, max_col);
    self.cursor.col = @min(next, max_col);
    self.wrap_next = false;
}

pub fn backTab(self: anytype) void {
    if (self.grid.cols == 0) return;
    self.cursor.col = @max(self.leftBoundary(), self.tabstops.prev(self.cursor.col));
    self.wrap_next = false;
}

pub fn clearTabAtCursor(self: anytype) void {
    self.tabstops.clearAt(self.cursor.col);
}

pub fn setTabAtCursor(self: anytype) void {
    self.tabstops.setAt(self.cursor.col);
}

pub fn resetTabStops(self: anytype) void {
    self.tabstops.reset();
}

pub fn clearAllTabs(self: anytype) void {
    self.tabstops.clearAll();
}

pub fn carriageReturn(self: anytype) void {
    self.cursor.col = self.leftBoundary();
    self.wrap_next = false;
}

pub fn cursorUp(self: anytype, delta: usize) void {
    if (self.origin_mode) {
        if (self.cursor.row > self.scroll_top + delta) {
            self.cursor.row -= delta;
        } else {
            self.cursor.row = self.scroll_top;
        }
    } else {
        self.cursor.row = if (self.cursor.row > delta) self.cursor.row - delta else 0;
    }
    self.wrap_next = false;
}

pub fn cursorDown(self: anytype, delta: usize) void {
    if (self.origin_mode) {
        const max_row = @min(@as(usize, self.grid.rows - 1), self.scroll_bottom);
        self.cursor.row = @min(max_row, self.cursor.row + delta);
    } else {
        const max_row = @as(usize, self.grid.rows - 1);
        self.cursor.row = @min(max_row, self.cursor.row + delta);
    }
    self.wrap_next = false;
}

pub fn cursorForward(self: anytype, delta: usize) void {
    const max_col = self.rightBoundary();
    self.cursor.col = @min(max_col, self.cursor.col + delta);
    self.wrap_next = false;
}

pub fn cursorBack(self: anytype, delta: usize) void {
    const left_bound = self.leftBoundary();
    var remaining = delta;
    while (remaining > 0) : (remaining -= 1) {
        if (self.cursor.col > left_bound) {
            self.cursor.col -= 1;
            continue;
        }
        if (self.reverse_wrap and self.cursor.row > self.scroll_top and self.grid.rowWrapped(self.cursor.row - 1)) {
            self.cursor.row -= 1;
            self.cursor.col = @as(usize, self.grid.cols - 1);
            continue;
        }
        break;
    }
    self.wrap_next = false;
}

pub fn setReverseWrap(self: anytype, enabled: bool) void {
    self.reverse_wrap = enabled;
}

pub fn cursorNextLine(self: anytype, delta: usize) void {
    if (self.origin_mode) {
        const max_row = @min(@as(usize, self.grid.rows - 1), self.scroll_bottom);
        self.cursor.row = @min(max_row, self.cursor.row + delta);
    } else {
        const max_row = @as(usize, self.grid.rows - 1);
        self.cursor.row = @min(max_row, self.cursor.row + delta);
    }
    self.cursor.col = self.leftBoundary();
    self.wrap_next = false;
}

pub fn cursorPrevLine(self: anytype, delta: usize) void {
    if (self.origin_mode) {
        if (self.cursor.row > self.scroll_top + delta) {
            self.cursor.row -= delta;
        } else {
            self.cursor.row = self.scroll_top;
        }
    } else {
        self.cursor.row = if (self.cursor.row > delta) self.cursor.row - delta else 0;
    }
    self.cursor.col = self.leftBoundary();
    self.wrap_next = false;
}

pub fn cursorColAbsolute(self: anytype, col_1: i32) void {
    const col = @min(@as(usize, self.grid.cols - 1), @as(usize, @intCast(col_1 - 1)));
    self.cursor.col = col;
    self.clampCursorToMargins();
    self.wrap_next = false;
}

pub fn cursorPosAbsolute(self: anytype, row_1: i32, col_1: i32) void {
    var row: usize = @intCast(@max(row_1 - 1, 0));
    if (self.origin_mode) {
        row = self.scroll_top + row;
        const max_row = @min(@as(usize, self.grid.rows - 1), self.scroll_bottom);
        if (row > max_row) row = max_row;
    } else {
        row = @min(@as(usize, self.grid.rows - 1), row);
    }
    const col = @min(@as(usize, self.grid.cols - 1), @as(usize, @intCast(col_1 - 1)));
    self.cursor.row = row;
    self.cursor.col = col;
    self.clampCursorToMargins();
    self.wrap_next = false;
}

pub fn cursorRowAbsolute(self: anytype, row_1: i32) void {
    var row: usize = @intCast(@max(row_1 - 1, 0));
    if (self.origin_mode) {
        row = self.scroll_top + row;
        const max_row = @min(@as(usize, self.grid.rows - 1), self.scroll_bottom);
        if (row > max_row) row = max_row;
    } else {
        row = @min(@as(usize, self.grid.rows - 1), row);
    }
    self.cursor.row = row;
    self.wrap_next = false;
}

pub fn cursorReport(self: anytype) struct { row_1: usize, col_1: usize } {
    const row_1 = if (self.origin_mode and self.cursor.row >= self.scroll_top)
        (self.cursor.row - self.scroll_top) + 1
    else
        self.cursor.row + 1;
    return .{ .row_1 = row_1, .col_1 = self.cursor.col + 1 };
}

pub fn newlineAction(self: anytype) @TypeOf(self.*).NewlineAction {
    if (self.cursor.row + 1 < @as(usize, self.grid.rows) and self.cursor.row != self.scroll_bottom) {
        self.cursor.row += 1;
        if (self.newline_mode) {
            self.cursor.col = self.leftBoundary();
        }
        self.wrap_next = false;
        return .moved;
    }
    if (self.cursor.row == self.scroll_bottom) {
        self.wrap_next = false;
        return .scroll_region;
    }
    self.wrap_next = false;
    return .scroll_full;
}

pub fn wrapNewlineAction(self: anytype) @TypeOf(self.*).NewlineAction {
    const left = self.leftBoundary();
    if (self.cursor.row + 1 < @as(usize, self.grid.rows) and self.cursor.row != self.scroll_bottom) {
        self.cursor.row += 1;
        self.cursor.col = left;
        self.wrap_next = false;
        return .moved;
    }
    if (self.cursor.row == self.scroll_bottom) {
        self.cursor.col = left;
        self.wrap_next = false;
        return .scroll_region;
    }
    self.cursor.col = left;
    self.wrap_next = false;
    return .scroll_full;
}

pub fn setScrollRegion(self: anytype, top: usize, bot: usize) void {
    self.scroll_top = top;
    self.scroll_bottom = bot;
    if (self.origin_mode) {
        self.cursor.row = top;
        self.cursor.col = self.leftBoundary();
    } else {
        self.cursor.row = 0;
        self.cursor.col = 0;
    }
    self.wrap_next = false;
}

pub fn setLeftRightMarginMode69(self: anytype, enabled: bool) void {
    self.left_right_margin_mode_69 = enabled;
    if (!enabled) {
        self.left_margin = 0;
        self.right_margin = if (self.grid.cols > 0) @as(usize, self.grid.cols - 1) else 0;
    }
    self.clampCursorToMargins();
}

pub fn setLeftRightMargins(self: anytype, left: usize, right: usize) void {
    if (self.grid.cols == 0) return;
    self.left_margin = @min(left, @as(usize, self.grid.cols - 1));
    self.right_margin = @min(right, @as(usize, self.grid.cols - 1));
    if (self.left_margin > self.right_margin) {
        self.left_margin = 0;
        self.right_margin = @as(usize, self.grid.cols - 1);
    }
    self.cursor.row = 0;
    self.cursor.col = self.leftBoundary();
    self.wrap_next = false;
}

pub fn leftBoundary(self: anytype) usize {
    if (self.left_right_margin_mode_69) return self.left_margin;
    return 0;
}

pub fn rightBoundary(self: anytype) usize {
    if (self.left_right_margin_mode_69) return self.right_margin;
    return if (self.grid.cols > 0) @as(usize, self.grid.cols - 1) else 0;
}

pub fn clampCursorToMargins(self: anytype) void {
    if (self.grid.cols == 0) {
        self.cursor.col = 0;
        return;
    }
    const left = self.leftBoundary();
    const right = self.rightBoundary();
    if (self.cursor.col < left) self.cursor.col = left;
    if (self.cursor.col > right) self.cursor.col = right;
}

pub fn writeRightBoundary(self: anytype) usize {
    return self.rightBoundary();
}
