const std = @import("std");
const types = @import("../types.zig");
const grid_mod = @import("grid.zig");
const tab_mod = @import("tabstops.zig");
const key_mod = @import("key_mode.zig");

const TerminalGrid = grid_mod.TerminalGrid;
const TabStops = tab_mod.TabStops;
const KeyModeStack = key_mod.KeyModeStack;

pub const Screen = struct {
    grid: TerminalGrid,
    cursor: types.CursorPos,
    cursor_style: types.CursorStyle,
    cursor_visible: bool,
    saved_cursor: SavedCursor,
    scroll_top: usize,
    scroll_bottom: usize,
    left_margin: usize,
    right_margin: usize,
    tabstops: TabStops,
    key_mode: KeyModeStack,
    current_attrs: types.CellAttrs,
    default_attrs: types.CellAttrs,
    wrap_next: bool,
    auto_wrap: bool,
    insert_mode: bool,
    origin_mode: bool,
    newline_mode: bool,
    local_echo_mode_12: bool,
    screen_reverse: bool,
    reverse_wrap: bool,
    grapheme_cluster_shaping_2027: bool,
    save_cursor_mode_1048: bool,
    left_right_margin_mode_69: bool,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16, default_attrs: types.CellAttrs) !Screen {
        const grid = try TerminalGrid.init(allocator, rows, cols, .{
            .codepoint = 0,
            .width = 1,
            .attrs = default_attrs,
        });
        const tabstops = try TabStops.init(allocator, cols);
        return .{
            .grid = grid,
            .cursor = .{ .row = 0, .col = 0 },
            .cursor_style = types.default_cursor_style,
            .cursor_visible = true,
            .saved_cursor = .{ .active = false, .cursor = .{ .row = 0, .col = 0 }, .attrs = default_attrs },
            .scroll_top = 0,
            .scroll_bottom = if (rows > 0) @as(usize, rows - 1) else 0,
            .left_margin = 0,
            .right_margin = if (cols > 0) @as(usize, cols - 1) else 0,
            .tabstops = tabstops,
            .key_mode = KeyModeStack.init(),
            .current_attrs = default_attrs,
            .default_attrs = default_attrs,
            .wrap_next = false,
            .auto_wrap = true,
            .insert_mode = false,
            .origin_mode = false,
            .newline_mode = false,
            .local_echo_mode_12 = false,
            .screen_reverse = false,
            .reverse_wrap = false,
            .grapheme_cluster_shaping_2027 = false,
            .save_cursor_mode_1048 = false,
            .left_right_margin_mode_69 = false,
        };
    }

    pub fn deinit(self: *Screen) void {
        self.grid.deinit();
        self.tabstops.deinit();
    }

    pub fn resize(self: *Screen, rows: u16, cols: u16) !void {
        const old_rows = self.grid.rows;
        const old_cols = self.grid.cols;
        const was_full_region = old_rows > 0 and self.scroll_top == 0 and self.scroll_bottom + 1 == @as(usize, old_rows);
        try self.grid.resize(rows, cols, .{
            .codepoint = 0,
            .width = 1,
            .attrs = self.default_attrs,
        });
        if (cols != old_cols) {
            try self.tabstops.resize(cols);
        }
        if (rows > 0) {
            if (self.scroll_top >= @as(usize, rows)) self.scroll_top = 0;
            if (self.scroll_bottom >= @as(usize, rows)) self.scroll_bottom = @as(usize, rows - 1);
            if (self.scroll_top > self.scroll_bottom) {
                self.scroll_top = 0;
                self.scroll_bottom = @as(usize, rows - 1);
            }
            if (was_full_region) {
                self.scroll_top = 0;
                self.scroll_bottom = @as(usize, rows - 1);
            }
        } else {
            self.scroll_top = 0;
            self.scroll_bottom = 0;
        }
        const max_row = if (rows > 0) @as(usize, rows - 1) else 0;
        const max_col = if (cols > 0) @as(usize, cols - 1) else 0;
        if (self.left_margin > max_col) self.left_margin = 0;
        if (self.right_margin > max_col) self.right_margin = max_col;
        if (self.left_margin > self.right_margin) {
            self.left_margin = 0;
            self.right_margin = max_col;
        }
        if (self.cursor.row > max_row) self.cursor.row = max_row;
        if (self.cursor.col > max_col) self.cursor.col = max_col;
        self.clampCursorToMargins();
    }

    pub fn resetState(self: *Screen) void {
        self.cursor = .{ .row = 0, .col = 0 };
        self.cursor_style = types.default_cursor_style;
        self.cursor_visible = true;
        self.saved_cursor = .{ .active = false, .cursor = .{ .row = 0, .col = 0 }, .attrs = self.default_attrs };
        self.scroll_top = 0;
        self.scroll_bottom = if (self.grid.rows > 0) @as(usize, self.grid.rows - 1) else 0;
        self.left_margin = 0;
        self.right_margin = if (self.grid.cols > 0) @as(usize, self.grid.cols - 1) else 0;
        self.key_mode = KeyModeStack.init();
        self.current_attrs = self.default_attrs;
        self.wrap_next = false;
        self.auto_wrap = true;
        self.insert_mode = false;
        self.origin_mode = false;
        self.newline_mode = false;
        self.local_echo_mode_12 = false;
        self.screen_reverse = false;
        self.reverse_wrap = false;
        self.grapheme_cluster_shaping_2027 = false;
        self.save_cursor_mode_1048 = false;
        self.left_right_margin_mode_69 = false;
        self.tabstops.reset();
    }

    pub fn blankCell(self: *const Screen) types.Cell {
        return .{
            .codepoint = 0,
            .width = 1,
            .attrs = self.current_attrs,
        };
    }

    pub fn defaultCell(self: *const Screen) types.Cell {
        return .{
            .codepoint = 0,
            .width = 1,
            .attrs = self.default_attrs,
        };
    }

    pub fn isFullScrollRegion(self: *const Screen) bool {
        const rows = @as(usize, self.grid.rows);
        if (rows == 0) return false;
        return self.scroll_top == 0 and self.scroll_bottom + 1 == rows;
    }

    pub fn setCursorStyle(self: *Screen, mode: i32) void {
        const style = switch (mode) {
            0, 1 => types.CursorStyle{ .shape = .block, .blink = true },
            2 => types.CursorStyle{ .shape = .block, .blink = false },
            3 => types.CursorStyle{ .shape = .underline, .blink = true },
            4 => types.CursorStyle{ .shape = .underline, .blink = false },
            5 => types.CursorStyle{ .shape = .bar, .blink = true },
            6 => types.CursorStyle{ .shape = .bar, .blink = false },
            else => self.cursor_style,
        };
        self.cursor_style = style;
    }

    pub fn setCursorBlink(self: *Screen, enabled: bool) void {
        self.cursor_style.blink = enabled;
    }

    pub fn saveCursor(self: *Screen) void {
        const slot = &self.saved_cursor;
        slot.active = true;
        slot.cursor = self.cursor;
        slot.attrs = self.current_attrs;
    }

    pub fn restoreCursor(self: *Screen) void {
        const slot = &self.saved_cursor;
        if (!slot.active) return;
        self.cursor = slot.cursor;
        self.current_attrs = slot.attrs;
    }

    pub fn keyModeStack(self: *Screen) *KeyModeStack {
        return &self.key_mode;
    }

    pub fn keyModeFlags(self: *const Screen) u32 {
        return self.key_mode.current();
    }

    pub fn keyModePush(self: *Screen, flags: u32) void {
        self.key_mode.push(flags);
    }

    pub fn keyModePop(self: *Screen, count: usize) void {
        self.key_mode.pop(count);
    }

    pub fn keyModeModify(self: *Screen, flags: u32, mode: u32) void {
        const current = self.key_mode.current();
        const updated = switch (mode) {
            2 => current | flags,
            3 => current & ~flags,
            else => flags,
        };
        self.key_mode.setCurrent(updated);
    }

    pub fn setAutowrap(self: *Screen, enabled: bool) void {
        self.auto_wrap = enabled;
    }

    pub fn setInsertMode(self: *Screen, enabled: bool) void {
        self.insert_mode = enabled;
    }

    pub fn setSaveCursorMode1048(self: *Screen, enabled: bool) void {
        self.save_cursor_mode_1048 = enabled;
    }

    pub fn setOriginMode(self: *Screen, enabled: bool) void {
        self.origin_mode = enabled;
        self.cursor.row = self.scroll_top;
        self.cursor.col = self.leftBoundary();
        self.wrap_next = false;
    }

    pub fn setNewlineMode(self: *Screen, enabled: bool) void {
        self.newline_mode = enabled;
    }

    pub fn setLocalEchoMode12(self: *Screen, enabled: bool) void {
        self.local_echo_mode_12 = enabled;
    }

    pub fn setGraphemeClusterShaping2027(self: *Screen, enabled: bool) void {
        self.grapheme_cluster_shaping_2027 = enabled;
    }

    pub fn setScreenReverse(self: *Screen, enabled: bool) void {
        if (self.screen_reverse == enabled) return;
        self.screen_reverse = enabled;
        self.grid.markDirtyAllWithReason(.screen_reverse_mode_toggle);
    }

    pub fn cellAtOr(self: *const Screen, row: usize, col: usize, default_cell: types.Cell) types.Cell {
        if (row >= @as(usize, self.grid.rows) or col >= @as(usize, self.grid.cols)) {
            return default_cell;
        }
        const idx = row * @as(usize, self.grid.cols) + col;
        return self.grid.cells.items[idx];
    }

    pub fn writeCodepoint(self: *Screen, cp: u32, attrs: types.CellAttrs) void {
        const rows = @as(usize, self.grid.rows);
        const cols = @as(usize, self.grid.cols);
        if (rows == 0 or cols == 0) return;
        if (self.cursor.row >= rows) return;
        if (self.cursor.col >= cols or self.cursor.row >= rows) return;
        const row = self.cursor.row;
        const col = self.cursor.col;
        const right = self.rightBoundary();
        if (col > right) return;
        const idx = row * cols + col;
        if (idx >= self.grid.cells.items.len) return;

        if (isCombiningMark(cp)) {
            var prev_col_opt: ?usize = null;
            var scan_col = col;
            while (scan_col > 0) {
                scan_col -= 1;
                const scan_idx = row * cols + scan_col;
                if (scan_idx >= self.grid.cells.items.len) break;
                const scan = self.grid.cells.items[scan_idx];
                if (scan.width == 0 and scan.x > 0) continue; // skip wide-cell continuations
                prev_col_opt = scan_col;
                break;
            }
            const prev_col = prev_col_opt orelse return;
            const prev_idx = row * cols + prev_col;
            var prev = self.grid.cells.items[prev_idx];
            if (prev.codepoint == 0) return;
            if (prev.combining_len < prev.combining.len) {
                prev.combining[prev.combining_len] = cp;
                prev.combining_len += 1;
                self.grid.cells.items[prev_idx] = prev;
                self.grid.markDirtyRange(row, row, prev_col, prev_col);
            } else if (self.grapheme_cluster_shaping_2027 and isGraphemeClusterPriorityMark(cp)) {
                prev.combining[prev.combining.len - 1] = cp;
                self.grid.cells.items[prev_idx] = prev;
                self.grid.markDirtyRange(row, row, prev_col, prev_col);
            }
            return;
        }

        const width: u8 = codepointCellWidth(cp);
        const write_width: u8 = if (width > 1 and col + 1 > right) 1 else width;

        // If overwriting a prior wide-cell root, clear its tail continuation.
        const existing = self.grid.cells.items[idx];
        if (existing.width > 1 and col + 1 < cols) {
            self.grid.cells.items[idx + 1] = self.blankCell();
        }

        // If writing into a continuation cell, clear the owning root first.
        if (existing.width == 0 and existing.x > 0 and col >= existing.x) {
            const root_col = col - existing.x;
            const root_idx = row * cols + root_col;
            if (root_idx < self.grid.cells.items.len) {
                const root = self.grid.cells.items[root_idx];
                if (root.width > 1) {
                    self.grid.cells.items[root_idx] = self.blankCell();
                    if (root_col + 1 < cols) {
                        self.grid.cells.items[root_idx + 1] = self.blankCell();
                    }
                }
            }
        }

        self.grid.cells.items[idx] = types.Cell{
            .codepoint = cp,
            .combining_len = 0,
            .combining = .{ 0, 0 },
            .width = write_width,
            .attrs = attrs,
        };
        if (write_width == 2 and col + 1 < cols) {
            self.grid.cells.items[idx + 1] = types.Cell{
                .codepoint = 0,
                .width = 0,
                .x = 1,
                .attrs = attrs,
            };
        }

        const advance: usize = write_width;
        if (self.cursor.col + advance > right) {
            if (self.auto_wrap) {
                self.wrap_next = true;
                self.grid.setRowWrapped(row, true);
            }
        } else {
            self.cursor.col += advance;
        }
        self.grid.markDirtyRange(row, row, col, @min(right, col + advance - 1));
    }

    fn isCombiningMark(codepoint: u32) bool {
        return (codepoint >= 0x0300 and codepoint <= 0x036F) or
            (codepoint >= 0x0483 and codepoint <= 0x0489) or
            (codepoint >= 0x0591 and codepoint <= 0x05BD) or
            codepoint == 0x05BF or
            (codepoint >= 0x05C1 and codepoint <= 0x05C2) or
            (codepoint >= 0x05C4 and codepoint <= 0x05C5) or
            codepoint == 0x05C7 or
            (codepoint >= 0x0610 and codepoint <= 0x061A) or
            (codepoint >= 0x064B and codepoint <= 0x065F) or
            codepoint == 0x0670 or
            (codepoint >= 0x06D6 and codepoint <= 0x06ED) or
            (codepoint >= 0x0711 and codepoint <= 0x0711) or
            (codepoint >= 0x0730 and codepoint <= 0x074A) or
            (codepoint >= 0x07A6 and codepoint <= 0x07B0) or
            (codepoint >= 0x07EB and codepoint <= 0x07F3) or
            (codepoint >= 0x0816 and codepoint <= 0x082D) or
            (codepoint >= 0x0859 and codepoint <= 0x085B) or
            (codepoint >= 0x08D3 and codepoint <= 0x0902) or
            codepoint == 0x093A or
            codepoint == 0x093C or
            (codepoint >= 0x0941 and codepoint <= 0x0948) or
            codepoint == 0x094D or
            (codepoint >= 0x0951 and codepoint <= 0x0957) or
            (codepoint >= 0x0962 and codepoint <= 0x0963) or
            (codepoint >= 0x1AB0 and codepoint <= 0x1AFF) or
            (codepoint >= 0x1DC0 and codepoint <= 0x1DFF) or
            (codepoint >= 0x20D0 and codepoint <= 0x20FF) or
            (codepoint >= 0xFE00 and codepoint <= 0xFE0F) or
            (codepoint >= 0xFE20 and codepoint <= 0xFE2F) or
            codepoint == 0x200C or codepoint == 0x200D or
            (codepoint >= 0xE0100 and codepoint <= 0xE01EF) or
            (codepoint >= 0x1F3FB and codepoint <= 0x1F3FF);
    }

    fn isGraphemeClusterPriorityMark(codepoint: u32) bool {
        return codepoint == 0x200D or // ZWJ
            codepoint == 0xFE0F or // VS16 emoji presentation
            (codepoint >= 0x1F3FB and codepoint <= 0x1F3FF); // emoji skin-tone modifiers
    }

    pub fn codepointCellWidth(codepoint: u32) u8 {
        // Conservative width-2 coverage for common East Asian wide/fullwidth glyphs
        // and emoji blocks. This is wcwidth-like (locale-neutral, no ambiguous-width=2).
        if ((codepoint >= 0x1100 and codepoint <= 0x115F) or
            codepoint == 0x2329 or codepoint == 0x232A or
            (codepoint >= 0x2E80 and codepoint <= 0xA4CF and codepoint != 0x303F) or
            (codepoint >= 0xAC00 and codepoint <= 0xD7A3) or
            (codepoint >= 0xF900 and codepoint <= 0xFAFF) or
            (codepoint >= 0xFE10 and codepoint <= 0xFE19) or
            (codepoint >= 0xFE30 and codepoint <= 0xFE6F) or
            (codepoint >= 0xFF00 and codepoint <= 0xFF60) or
            (codepoint >= 0xFFE0 and codepoint <= 0xFFE6) or
            (codepoint >= 0x1F300 and codepoint <= 0x1FAFF) or
            (codepoint >= 0x20000 and codepoint <= 0x3FFFD))
        {
            return 2;
        }
        return 1;
    }

    pub fn writeAsciiRun(self: *Screen, bytes: []const u8, attrs: types.CellAttrs, use_dec_special: bool) usize {
        const rows = @as(usize, self.grid.rows);
        const cols = @as(usize, self.grid.cols);
        if (rows == 0 or cols == 0) return 0;
        if (self.cursor.row >= rows) return 0;
        if (self.cursor.col >= cols or self.cursor.row >= rows) return 0;

        const row = self.cursor.row;
        const col = self.cursor.col;
        const right = self.rightBoundary();
        if (col > right) return 0;
        const remaining_cols = right - col + 1;
        const run_len = @min(remaining_cols, bytes.len);
        const row_start = row * cols + col;
        if (use_dec_special) {
            var j: usize = 0;
            while (j < run_len) {
                const b = bytes[j];
                var same_len: usize = 1;
                while (j + same_len < run_len and bytes[j + same_len] == b) : (same_len += 1) {}
                const cp = mapDecSpecial(b);
                const cell = types.Cell{
                    .codepoint = cp,
                    .combining_len = 0,
                    .combining = .{ 0, 0 },
                    .width = 1,
                    .attrs = attrs,
                };
                if (same_len >= 8) {
                    @memset(self.grid.cells.items[row_start + j .. row_start + j + same_len], cell);
                } else {
                    var k: usize = 0;
                    while (k < same_len) : (k += 1) {
                        self.grid.cells.items[row_start + j + k] = cell;
                    }
                }
                j += same_len;
            }
        } else {
            var j: usize = 0;
            while (j < run_len) {
                const b = bytes[j];
                var same_len: usize = 1;
                while (j + same_len < run_len and bytes[j + same_len] == b) : (same_len += 1) {}
                const cell = types.Cell{
                    .codepoint = b,
                    .combining_len = 0,
                    .combining = .{ 0, 0 },
                    .width = 1,
                    .attrs = attrs,
                };
                if (same_len >= 8) {
                    @memset(self.grid.cells.items[row_start + j .. row_start + j + same_len], cell);
                } else {
                    var k: usize = 0;
                    while (k < same_len) : (k += 1) {
                        self.grid.cells.items[row_start + j + k] = cell;
                    }
                }
                j += same_len;
            }
        }
        self.grid.markDirtyRange(row, row, col, col + run_len - 1);

        if (run_len == remaining_cols) {
            self.cursor.col = right;
            if (self.auto_wrap) {
                self.wrap_next = true;
                self.grid.setRowWrapped(row, true);
            }
        } else {
            self.cursor.col += run_len;
        }
        return run_len;
    }

    pub const WritePrep = enum {
        proceed,
        need_wrap,
        done,
    };

    pub fn prepareWrite(self: *Screen) WritePrep {
        const rows = @as(usize, self.grid.rows);
        const cols = @as(usize, self.grid.cols);
        if (rows == 0 or cols == 0) return .done;
        if (self.cursor.row >= rows) return .done;
        if (self.wrap_next) {
            self.wrap_next = false;
            if (self.auto_wrap) {
                self.grid.setRowWrapped(self.cursor.row, true);
                if (self.cursor.col == 0) {
                    const cols_local = @as(usize, self.grid.cols);
                    if (cols_local > 0) {
                        self.grid.markDirtyRange(self.cursor.row, self.cursor.row, 0, cols_local - 1);
                    }
                }
                return .need_wrap;
            }
        }
        if (self.cursor.col >= cols or self.cursor.row >= rows) return .done;
        return .proceed;
    }

    pub fn setCursor(self: *Screen, row: usize, col: usize) void {
        self.cursor = .{ .row = row, .col = col };
        self.clampCursorToMargins();
    }

    pub fn backspace(self: *Screen) void {
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

    pub fn tab(self: *Screen) void {
        if (self.grid.cols == 0) return;
        const max_col = self.rightBoundary();
        const next = self.tabstops.next(self.cursor.col, max_col);
        self.cursor.col = @min(next, max_col);
        self.wrap_next = false;
    }

    pub fn backTab(self: *Screen) void {
        if (self.grid.cols == 0) return;
        self.cursor.col = @max(self.leftBoundary(), self.tabstops.prev(self.cursor.col));
        self.wrap_next = false;
    }

    pub fn clearTabAtCursor(self: *Screen) void {
        self.tabstops.clearAt(self.cursor.col);
    }

    pub fn setTabAtCursor(self: *Screen) void {
        self.tabstops.setAt(self.cursor.col);
    }

    pub fn resetTabStops(self: *Screen) void {
        self.tabstops.reset();
    }

    pub fn clearAllTabs(self: *Screen) void {
        self.tabstops.clearAll();
    }

    pub fn carriageReturn(self: *Screen) void {
        self.cursor.col = self.leftBoundary();
        self.wrap_next = false;
    }

    pub fn cursorUp(self: *Screen, delta: usize) void {
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

    pub fn cursorDown(self: *Screen, delta: usize) void {
        if (self.origin_mode) {
            const max_row = @min(@as(usize, self.grid.rows - 1), self.scroll_bottom);
            self.cursor.row = @min(max_row, self.cursor.row + delta);
        } else {
            const max_row = @as(usize, self.grid.rows - 1);
            self.cursor.row = @min(max_row, self.cursor.row + delta);
        }
        self.wrap_next = false;
    }

    pub fn cursorForward(self: *Screen, delta: usize) void {
        const max_col = self.rightBoundary();
        self.cursor.col = @min(max_col, self.cursor.col + delta);
        self.wrap_next = false;
    }

    pub fn cursorBack(self: *Screen, delta: usize) void {
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

    pub fn setReverseWrap(self: *Screen, enabled: bool) void {
        self.reverse_wrap = enabled;
    }

    pub fn cursorNextLine(self: *Screen, delta: usize) void {
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

    pub fn cursorPrevLine(self: *Screen, delta: usize) void {
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

    pub fn cursorColAbsolute(self: *Screen, col_1: i32) void {
        const col = @min(@as(usize, self.grid.cols - 1), @as(usize, @intCast(col_1 - 1)));
        self.cursor.col = col;
        self.clampCursorToMargins();
        self.wrap_next = false;
    }

    pub fn cursorPosAbsolute(self: *Screen, row_1: i32, col_1: i32) void {
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

    pub fn cursorRowAbsolute(self: *Screen, row_1: i32) void {
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

    pub fn setCursorVisible(self: *Screen, visible: bool) void {
        self.cursor_visible = visible;
    }

    pub fn cursorReport(self: *const Screen) struct { row_1: usize, col_1: usize } {
        const row_1 = if (self.origin_mode and self.cursor.row >= self.scroll_top)
            (self.cursor.row - self.scroll_top) + 1
        else
            self.cursor.row + 1;
        return .{ .row_1 = row_1, .col_1 = self.cursor.col + 1 };
    }

    pub const NewlineAction = enum {
        moved,
        scroll_region,
        scroll_full,
    };

    pub fn newlineAction(self: *Screen) NewlineAction {
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

    pub fn wrapNewlineAction(self: *Screen) NewlineAction {
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

    pub fn setScrollRegion(self: *Screen, top: usize, bot: usize) void {
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

    pub fn setLeftRightMarginMode69(self: *Screen, enabled: bool) void {
        self.left_right_margin_mode_69 = enabled;
        if (!enabled) {
            self.left_margin = 0;
            self.right_margin = if (self.grid.cols > 0) @as(usize, self.grid.cols - 1) else 0;
        }
        self.clampCursorToMargins();
    }

    pub fn setLeftRightMargins(self: *Screen, left: usize, right: usize) void {
        if (self.grid.cols == 0) return;
        self.left_margin = @min(left, @as(usize, self.grid.cols - 1));
        self.right_margin = @min(right, @as(usize, self.grid.cols - 1));
        if (self.left_margin > self.right_margin) {
            self.left_margin = 0;
            self.right_margin = @as(usize, self.grid.cols - 1);
        }
        // xterm-compatible DECSLRM behavior homes cursor to row 1 at left margin.
        self.cursor.row = 0;
        self.cursor.col = self.leftBoundary();
        self.wrap_next = false;
    }

    fn leftBoundary(self: *const Screen) usize {
        if (self.left_right_margin_mode_69) return self.left_margin;
        return 0;
    }

    fn rightBoundary(self: *const Screen) usize {
        if (self.left_right_margin_mode_69) return self.right_margin;
        return if (self.grid.cols > 0) @as(usize, self.grid.cols - 1) else 0;
    }

    pub fn writeRightBoundary(self: *const Screen) usize {
        return self.rightBoundary();
    }

    fn clampCursorToMargins(self: *Screen) void {
        if (self.grid.cols == 0) {
            self.cursor.col = 0;
            return;
        }
        const left = self.leftBoundary();
        const right = self.rightBoundary();
        if (self.cursor.col < left) self.cursor.col = left;
        if (self.cursor.col > right) self.cursor.col = right;
    }

    pub fn cursorPos(self: *const Screen) types.CursorPos {
        return self.cursor;
    }

    pub fn rowCount(self: *const Screen) usize {
        return @as(usize, self.grid.rows);
    }

    pub fn colCount(self: *const Screen) usize {
        return @as(usize, self.grid.cols);
    }

    pub const SnapshotView = struct {
        rows: usize,
        cols: usize,
        cells: []const types.Cell,
        dirty_rows: []const bool,
        dirty_cols_start: []const u16,
        dirty_cols_end: []const u16,
        cursor: types.CursorPos,
        cursor_style: types.CursorStyle,
        cursor_visible: bool,
        dirty: grid_mod.Dirty,
        damage: grid_mod.Damage,
        full_dirty_reason: grid_mod.FullDirtyReason,
        full_dirty_seq: u64,
    };

    pub fn snapshotView(self: *const Screen) SnapshotView {
        return .{
            .rows = @as(usize, self.grid.rows),
            .cols = @as(usize, self.grid.cols),
            .cells = self.grid.cells.items,
            .dirty_rows = self.grid.dirty_rows.items,
            .dirty_cols_start = self.grid.dirty_cols_start.items,
            .dirty_cols_end = self.grid.dirty_cols_end.items,
            .cursor = self.cursor,
            .cursor_style = self.cursor_style,
            .cursor_visible = self.cursor_visible,
            .dirty = self.grid.dirty,
            .damage = self.grid.damage,
            .full_dirty_reason = self.grid.full_dirty_reason,
            .full_dirty_seq = self.grid.full_dirty_seq,
        };
    }

    pub fn markDirtyAll(self: *Screen) void {
        self.grid.markDirtyAllWithReason(.screen_mark_dirty_api);
    }

    pub fn markDirtyAllWithReason(self: *Screen, reason: grid_mod.FullDirtyReason) void {
        self.grid.markDirtyAllWithReason(reason);
    }

    pub fn clearDirty(self: *Screen) void {
        self.grid.clearDirty();
    }

    pub fn getDamage(self: *const Screen) ?struct {
        start_row: usize,
        end_row: usize,
        start_col: usize,
        end_col: usize,
    } {
        return switch (self.grid.dirty) {
            .none => null,
            else => .{
                .start_row = self.grid.damage.start_row,
                .end_row = self.grid.damage.end_row,
                .start_col = self.grid.damage.start_col,
                .end_col = self.grid.damage.end_col,
            },
        };
    }

    pub fn clear(self: *Screen) void {
        const default_cell = types.Cell{
            .codepoint = 0,
            .width = 1,
            .attrs = self.default_attrs,
        };
        for (self.grid.cells.items) |*cell| {
            cell.* = default_cell;
        }
        for (self.grid.wrap_flags.items) |*flag| {
            flag.* = false;
        }
        self.grid.markDirtyAllWithReason(.screen_clear);
    }

    pub fn eraseDisplay(self: *Screen, mode: i32, blank_cell: types.Cell) void {
        const rows = @as(usize, self.grid.rows);
        const cols = @as(usize, self.grid.cols);
        if (rows == 0 or cols == 0) return;
        const row = self.cursor.row;
        const col = self.cursor.col;
        const left = self.leftBoundary();
        const right = self.rightBoundary();

        switch (mode) {
            0 => { // cursor to end
                if (row >= rows or col >= cols) return;
                const start_col = if (col < left) left else col;
                if (start_col <= right) {
                    const row_start = row * cols;
                    for (self.grid.cells.items[row_start + start_col .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                    self.grid.markDirtyRange(row, row, start_col, right);
                }
                if (row + 1 < rows) {
                    var r = row + 1;
                    while (r < rows) : (r += 1) {
                        const row_start = r * cols;
                        for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                    }
                    self.grid.markDirtyRange(row + 1, rows - 1, left, right);
                }
                var r = row;
                while (r < rows) : (r += 1) {
                    self.grid.setRowWrapped(r, false);
                }
            },
            1 => { // start to cursor
                if (row >= rows or col >= cols) return;
                if (row > 0) {
                    var r: usize = 0;
                    while (r < row) : (r += 1) {
                        const row_start = r * cols;
                        for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                    }
                    self.grid.markDirtyRange(0, row - 1, left, right);
                }
                if (col >= left) {
                    const end_col = @min(col, right);
                    const row_start = row * cols;
                    for (self.grid.cells.items[row_start + left .. row_start + end_col + 1]) |*cell| cell.* = blank_cell;
                    self.grid.markDirtyRange(row, row, left, end_col);
                }
                var r: usize = 0;
                while (r <= row) : (r += 1) {
                    self.grid.setRowWrapped(r, false);
                }
            },
            2 => { // all
                if (left == 0 and right + 1 == cols) {
                    for (self.grid.cells.items) |*cell| cell.* = blank_cell;
                    self.grid.markDirtyAllWithReason(.erase_display_full);
                } else {
                    var r: usize = 0;
                    while (r < rows) : (r += 1) {
                        const row_start = r * cols;
                        for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                    }
                    self.grid.markDirtyRange(0, rows - 1, left, right);
                }
                for (self.grid.wrap_flags.items) |*flag| {
                    flag.* = false;
                }
            },
            3 => { // saved lines + all (treat as full clear)
                if (left == 0 and right + 1 == cols) {
                    for (self.grid.cells.items) |*cell| cell.* = blank_cell;
                    self.grid.markDirtyAllWithReason(.erase_display_full);
                } else {
                    var r: usize = 0;
                    while (r < rows) : (r += 1) {
                        const row_start = r * cols;
                        for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                    }
                    self.grid.markDirtyRange(0, rows - 1, left, right);
                }
                for (self.grid.wrap_flags.items) |*flag| {
                    flag.* = false;
                }
            },
            else => {},
        }
    }

    pub fn eraseLine(self: *Screen, mode: i32, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0 or self.grid.rows == 0) return;
        if (self.cursor.row >= @as(usize, self.grid.rows)) return;
        const left = self.leftBoundary();
        const right = self.rightBoundary();
        const row_start = self.cursor.row * cols;
        const col = self.cursor.col;
        if (col < left or col > right or col >= cols) return;
        switch (mode) {
            0 => { // cursor to end of line
                for (self.grid.cells.items[row_start + col .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                self.grid.markDirtyRange(self.cursor.row, self.cursor.row, col, right);
            },
            1 => { // start to cursor
                for (self.grid.cells.items[row_start + left .. row_start + col + 1]) |*cell| cell.* = blank_cell;
                self.grid.markDirtyRange(self.cursor.row, self.cursor.row, left, col);
            },
            2 => { // entire line
                for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                self.grid.markDirtyRange(self.cursor.row, self.cursor.row, left, right);
            },
            else => {},
        }
        self.grid.setRowWrapped(self.cursor.row, false);
    }

    pub fn insertChars(self: *Screen, count: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0) return;
        if (self.cursor.row >= @as(usize, self.grid.rows)) return;
        const left = self.leftBoundary();
        const right = self.rightBoundary();
        const col = self.cursor.col;
        if (col < left or col > right or col >= cols) return;
        const end_excl = right + 1;
        const n = @min(count, end_excl - col);
        if (n == 0) return;
        const row_start = self.cursor.row * cols;
        const line = self.grid.cells.items[row_start .. row_start + cols];
        if (end_excl - col > n) {
            std.mem.copyBackwards(types.Cell, line[col + n .. end_excl], line[col .. end_excl - n]);
        }
        for (line[col .. col + n]) |*cell| cell.* = blank_cell;
        self.grid.markDirtyRange(self.cursor.row, self.cursor.row, col, right);
    }

    pub fn deleteChars(self: *Screen, count: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0) return;
        if (self.cursor.row >= @as(usize, self.grid.rows)) return;
        const left = self.leftBoundary();
        const right = self.rightBoundary();
        const col = self.cursor.col;
        if (col < left or col > right or col >= cols) return;
        const end_excl = right + 1;
        const n = @min(count, end_excl - col);
        if (n == 0) return;
        const row_start = self.cursor.row * cols;
        const line = self.grid.cells.items[row_start .. row_start + cols];
        if (end_excl - col > n) {
            std.mem.copyForwards(types.Cell, line[col .. end_excl - n], line[col + n .. end_excl]);
        }
        for (line[end_excl - n .. end_excl]) |*cell| cell.* = blank_cell;
        self.grid.markDirtyRange(self.cursor.row, self.cursor.row, col, right);
    }

    pub fn eraseChars(self: *Screen, count: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0) return;
        if (self.cursor.row >= @as(usize, self.grid.rows)) return;
        const left = self.leftBoundary();
        const right = self.rightBoundary();
        const col = self.cursor.col;
        if (col < left or col > right or col >= cols) return;
        const end_excl = right + 1;
        const n = @min(count, end_excl - col);
        if (n == 0) return;
        const row_start = self.cursor.row * cols;
        const line = self.grid.cells.items[row_start .. row_start + cols];
        for (line[col .. col + n]) |*cell| cell.* = blank_cell;
        self.grid.markDirtyRange(self.cursor.row, self.cursor.row, col, col + n - 1);
    }

    pub fn insertLines(self: *Screen, count: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        const rows = @as(usize, self.grid.rows);
        if (rows == 0 or cols == 0) return;
        if (self.cursor.row < self.scroll_top or self.cursor.row > self.scroll_bottom) return;
        if (self.left_right_margin_mode_69 and (self.cursor.col < self.leftBoundary() or self.cursor.col > self.rightBoundary())) return;
        const n = @min(count, self.scroll_bottom - self.cursor.row + 1);
        if (self.left_right_margin_mode_69) {
            const left = self.leftBoundary();
            const right = self.rightBoundary();
            var row = self.scroll_bottom;
            while (true) {
                const row_start = row * cols;
                if (row >= self.cursor.row + n) {
                    const src_row = row - n;
                    const src_start = src_row * cols;
                    std.mem.copyForwards(
                        types.Cell,
                        self.grid.cells.items[row_start + left .. row_start + right + 1],
                        self.grid.cells.items[src_start + left .. src_start + right + 1],
                    );
                } else {
                    for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                }
                self.grid.setRowWrapped(row, false);
                if (row == self.cursor.row) break;
                row -= 1;
            }
            self.grid.markDirtyRange(self.cursor.row, self.scroll_bottom, left, right);
            return;
        }
        const region_end = (self.scroll_bottom + 1) * cols;
        const insert_at = self.cursor.row * cols;
        const move_len = region_end - insert_at - n * cols;
        if (move_len > 0) {
            std.mem.copyBackwards(types.Cell, self.grid.cells.items[insert_at + n * cols .. region_end], self.grid.cells.items[insert_at .. insert_at + move_len]);
        }
        for (self.grid.cells.items[insert_at .. insert_at + n * cols]) |*cell| cell.* = blank_cell;
        var row = self.scroll_bottom;
        while (row >= self.cursor.row + n) : (row -= 1) {
            self.grid.setRowWrapped(row, self.grid.rowWrapped(row - n));
            if (row == 0) break;
        }
        row = self.cursor.row;
        while (row < self.cursor.row + n and row <= self.scroll_bottom) : (row += 1) {
            self.grid.setRowWrapped(row, false);
        }
        self.grid.markDirtyRange(self.cursor.row, self.scroll_bottom, 0, cols - 1);
    }

    pub fn deleteLines(self: *Screen, count: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        const rows = @as(usize, self.grid.rows);
        if (rows == 0 or cols == 0) return;
        if (self.cursor.row < self.scroll_top or self.cursor.row > self.scroll_bottom) return;
        if (self.left_right_margin_mode_69 and (self.cursor.col < self.leftBoundary() or self.cursor.col > self.rightBoundary())) return;
        const n = @min(count, self.scroll_bottom - self.cursor.row + 1);
        if (self.left_right_margin_mode_69) {
            const left = self.leftBoundary();
            const right = self.rightBoundary();
            var row = self.cursor.row;
            while (row <= self.scroll_bottom) : (row += 1) {
                const row_start = row * cols;
                if (row + n <= self.scroll_bottom) {
                    const src_row = row + n;
                    const src_start = src_row * cols;
                    std.mem.copyForwards(
                        types.Cell,
                        self.grid.cells.items[row_start + left .. row_start + right + 1],
                        self.grid.cells.items[src_start + left .. src_start + right + 1],
                    );
                } else {
                    for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                }
                self.grid.setRowWrapped(row, false);
            }
            self.grid.markDirtyRange(self.cursor.row, self.scroll_bottom, left, right);
            return;
        }
        const region_end = (self.scroll_bottom + 1) * cols;
        const delete_at = self.cursor.row * cols;
        const move_len = region_end - delete_at - n * cols;
        if (move_len > 0) {
            std.mem.copyForwards(types.Cell, self.grid.cells.items[delete_at .. delete_at + move_len], self.grid.cells.items[delete_at + n * cols .. region_end]);
        }
        for (self.grid.cells.items[region_end - n * cols .. region_end]) |*cell| cell.* = blank_cell;
        var row = self.cursor.row;
        while (row + n <= self.scroll_bottom) : (row += 1) {
            self.grid.setRowWrapped(row, self.grid.rowWrapped(row + n));
        }
        row = self.scroll_bottom + 1 - n;
        while (row <= self.scroll_bottom) : (row += 1) {
            self.grid.setRowWrapped(row, false);
        }
        self.grid.markDirtyRange(self.cursor.row, self.scroll_bottom, 0, cols - 1);
    }

    pub fn updateDefaultColors(self: *Screen, old_attrs: types.CellAttrs, new_attrs: types.CellAttrs) void {
        self.default_attrs = new_attrs;

        if (colorsEqual(self.current_attrs.fg, old_attrs.fg)) self.current_attrs.fg = new_attrs.fg;
        if (colorsEqual(self.current_attrs.bg, old_attrs.bg)) self.current_attrs.bg = new_attrs.bg;
        if (colorsEqual(self.current_attrs.underline_color, old_attrs.underline_color)) self.current_attrs.underline_color = new_attrs.underline_color;

        if (colorsEqual(self.saved_cursor.attrs.fg, old_attrs.fg)) self.saved_cursor.attrs.fg = new_attrs.fg;
        if (colorsEqual(self.saved_cursor.attrs.bg, old_attrs.bg)) self.saved_cursor.attrs.bg = new_attrs.bg;
        if (colorsEqual(self.saved_cursor.attrs.underline_color, old_attrs.underline_color)) self.saved_cursor.attrs.underline_color = new_attrs.underline_color;

        for (self.grid.cells.items) |*cell| {
            if (colorsEqual(cell.attrs.fg, old_attrs.fg)) cell.attrs.fg = new_attrs.fg;
            if (colorsEqual(cell.attrs.bg, old_attrs.bg)) cell.attrs.bg = new_attrs.bg;
            if (colorsEqual(cell.attrs.underline_color, old_attrs.underline_color)) cell.attrs.underline_color = new_attrs.underline_color;
        }
        self.grid.markDirtyAllWithReason(.palette_default_changed);
    }

    pub fn updateAnsiColors(self: *Screen, old_colors: [16]types.Color, new_colors: [16]types.Color) void {
        self.current_attrs.fg = remapAnsiColor(self.current_attrs.fg, old_colors, new_colors);
        self.current_attrs.bg = remapAnsiColor(self.current_attrs.bg, old_colors, new_colors);
        self.current_attrs.underline_color = remapAnsiColor(self.current_attrs.underline_color, old_colors, new_colors);

        self.saved_cursor.attrs.fg = remapAnsiColor(self.saved_cursor.attrs.fg, old_colors, new_colors);
        self.saved_cursor.attrs.bg = remapAnsiColor(self.saved_cursor.attrs.bg, old_colors, new_colors);
        self.saved_cursor.attrs.underline_color = remapAnsiColor(self.saved_cursor.attrs.underline_color, old_colors, new_colors);

        for (self.grid.cells.items) |*cell| {
            cell.attrs.fg = remapAnsiColor(cell.attrs.fg, old_colors, new_colors);
            cell.attrs.bg = remapAnsiColor(cell.attrs.bg, old_colors, new_colors);
            cell.attrs.underline_color = remapAnsiColor(cell.attrs.underline_color, old_colors, new_colors);
        }
        self.grid.markDirtyAllWithReason(.palette_ansi_changed);
    }

    fn remapAnsiColor(color: types.Color, old_colors: [16]types.Color, new_colors: [16]types.Color) types.Color {
        for (0..16) |i| {
            if (colorsEqual(color, old_colors[i])) return new_colors[i];
        }
        return color;
    }

    fn colorsEqual(a: types.Color, b: types.Color) bool {
        return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
    }

    pub fn scrollRegionUpBy(self: *Screen, n: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0 or self.grid.rows == 0) return;
        if (n == 0) return;
        if (self.left_right_margin_mode_69) {
            const left = self.leftBoundary();
            const right = self.rightBoundary();
            var row = self.scroll_top;
            while (row <= self.scroll_bottom) : (row += 1) {
                const row_start = row * cols;
                if (row + n <= self.scroll_bottom) {
                    const src_row = row + n;
                    const src_start = src_row * cols;
                    std.mem.copyForwards(
                        types.Cell,
                        self.grid.cells.items[row_start + left .. row_start + right + 1],
                        self.grid.cells.items[src_start + left .. src_start + right + 1],
                    );
                } else {
                    for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                }
                self.grid.setRowWrapped(row, false);
            }
            self.grid.markDirtyRange(self.scroll_top, self.scroll_bottom, left, right);
            return;
        }
        const region_start = self.scroll_top * cols;
        const region_end = (self.scroll_bottom + 1) * cols;
        const move_len = region_end - region_start - n * cols;
        if (move_len > 0) {
            std.mem.copyForwards(types.Cell, self.grid.cells.items[region_start .. region_start + move_len], self.grid.cells.items[region_start + n * cols .. region_end]);
        }
        for (self.grid.cells.items[region_end - n * cols .. region_end]) |*cell| cell.* = blank_cell;
        const start_row = self.scroll_top;
        const end_row = self.scroll_bottom;
        if (start_row <= end_row and n > 0) {
            var row = start_row;
            while (row + n <= end_row) : (row += 1) {
                self.grid.setRowWrapped(row, self.grid.rowWrapped(row + n));
            }
            row = end_row + 1 - n;
            while (row <= end_row) : (row += 1) {
                self.grid.setRowWrapped(row, false);
            }
        }
        self.grid.markDirtyRange(self.scroll_top, self.scroll_bottom, 0, cols - 1);
    }

    pub fn scrollRegionUp(self: *Screen, count: usize, blank_cell: types.Cell) usize {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0 or self.grid.rows == 0) return 0;
        const n = @min(count, self.scroll_bottom - self.scroll_top + 1);
        if (n == 0) return 0;
        self.scrollRegionUpBy(n, blank_cell);
        return n;
    }

    pub fn scrollRegionDownBy(self: *Screen, n: usize, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0 or self.grid.rows == 0) return;
        if (n == 0) return;
        if (self.left_right_margin_mode_69) {
            const left = self.leftBoundary();
            const right = self.rightBoundary();
            var row = self.scroll_bottom;
            while (true) {
                const row_start = row * cols;
                if (row >= self.scroll_top + n) {
                    const src_row = row - n;
                    const src_start = src_row * cols;
                    std.mem.copyForwards(
                        types.Cell,
                        self.grid.cells.items[row_start + left .. row_start + right + 1],
                        self.grid.cells.items[src_start + left .. src_start + right + 1],
                    );
                } else {
                    for (self.grid.cells.items[row_start + left .. row_start + right + 1]) |*cell| cell.* = blank_cell;
                }
                self.grid.setRowWrapped(row, false);
                if (row == self.scroll_top) break;
                row -= 1;
            }
            self.grid.markDirtyRange(self.scroll_top, self.scroll_bottom, left, right);
            return;
        }
        const region_start = self.scroll_top * cols;
        const region_end = (self.scroll_bottom + 1) * cols;
        const move_len = region_end - region_start - n * cols;
        if (move_len > 0) {
            std.mem.copyBackwards(types.Cell, self.grid.cells.items[region_start + n * cols .. region_end], self.grid.cells.items[region_start .. region_start + move_len]);
        }
        for (self.grid.cells.items[region_start .. region_start + n * cols]) |*cell| cell.* = blank_cell;
        const start_row = self.scroll_top;
        const end_row = self.scroll_bottom;
        if (start_row <= end_row and n > 0) {
            var row = end_row;
            while (row >= start_row + n) : (row -= 1) {
                self.grid.setRowWrapped(row, self.grid.rowWrapped(row - n));
                if (row == 0) break;
            }
            row = start_row;
            while (row < start_row + n and row <= end_row) : (row += 1) {
                self.grid.setRowWrapped(row, false);
            }
        }
        self.grid.markDirtyRange(self.scroll_top, self.scroll_bottom, 0, cols - 1);
    }

    pub fn scrollRegionDown(self: *Screen, count: usize, blank_cell: types.Cell) usize {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0 or self.grid.rows == 0) return 0;
        const n = @min(count, self.scroll_bottom - self.scroll_top + 1);
        if (n == 0) return 0;
        self.scrollRegionDownBy(n, blank_cell);
        return n;
    }

    pub fn scrollUp(self: *Screen, blank_cell: types.Cell) void {
        const cols = @as(usize, self.grid.cols);
        const rows = @as(usize, self.grid.rows);
        if (rows == 0 or cols == 0) return;
        const total = rows * cols;
        const row_bytes = cols * @sizeOf(types.Cell);
        const src = @as([*]u8, @ptrCast(self.grid.cells.items.ptr));
        std.mem.copyForwards(u8, src[0 .. total * @sizeOf(types.Cell) - row_bytes], src[row_bytes .. total * @sizeOf(types.Cell)]);

        const row_start = (rows - 1) * cols;
        for (self.grid.cells.items[row_start .. row_start + cols]) |*cell| {
            cell.* = blank_cell;
        }
        if (rows > 1) {
            var row: usize = 0;
            while (row + 1 < rows) : (row += 1) {
                self.grid.setRowWrapped(row, self.grid.rowWrapped(row + 1));
            }
        }
        if (rows > 0) {
            self.grid.setRowWrapped(rows - 1, false);
        }
        self.cursor.row = rows - 1;
        self.cursor.col = 0;
        self.grid.markDirtyRange(0, rows - 1, 0, cols - 1);
    }
};

const SavedCursor = struct {
    active: bool,
    cursor: types.CursorPos,
    attrs: types.CellAttrs,
};

pub fn mapDecSpecial(codepoint: u32) u32 {
    return switch (codepoint) {
        0x60 => 0x25C6, // ◆
        0x61 => 0x2592, // ▒
        0x62 => 0x2409, // ␉
        0x63 => 0x240C, // ␌
        0x64 => 0x240D, // ␍
        0x65 => 0x240A, // ␊
        0x66 => 0x00B0, // °
        0x67 => 0x00B1, // ±
        0x68 => 0x2424, // ␤
        0x69 => 0x240B, // ␋
        0x6A => 0x2518, // ┘
        0x6B => 0x2510, // ┐
        0x6C => 0x250C, // ┌
        0x6D => 0x2514, // └
        0x6E => 0x253C, // ┼
        0x6F => 0x23BA, // ⎺
        0x70 => 0x23BB, // ⎻
        0x71 => 0x2500, // ─
        0x72 => 0x23BC, // ⎼
        0x73 => 0x23BD, // ⎽
        0x74 => 0x251C, // ├
        0x75 => 0x2524, // ┤
        0x76 => 0x2534, // ┴
        0x77 => 0x252C, // ┬
        0x78 => 0x2502, // │
        0x79 => 0x2264, // ≤
        0x7A => 0x2265, // ≥
        0x7B => 0x03C0, // π
        0x7C => 0x2260, // ≠
        0x7D => 0x00A3, // £
        0x7E => 0x00B7, // ·
        else => codepoint,
    };
}
pub fn setAutowrap(self: *Screen, enabled: bool) void {
    self.auto_wrap = enabled;
}
