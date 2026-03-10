const std = @import("std");
const types = @import("../types.zig");
const screen_mod = @import("screen.zig");

const Screen = screen_mod.Screen;

pub const WritePrep = enum {
    proceed,
    need_wrap,
    done,
};

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
            if (scan.width == 0 and scan.x > 0) continue;
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
    self.logDirtyRangeSemanticGaps("write_codepoint", row, row, col, @min(right, col + @max(@as(usize, write_width), 1) - 1));

    const existing = self.grid.cells.items[idx];
    if (existing.width > 1 and col + 1 < cols) {
        self.grid.cells.items[idx + 1] = self.blankCell();
    }

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
    return codepoint == 0x200D or
        codepoint == 0xFE0F or
        (codepoint >= 0x1F3FB and codepoint <= 0x1F3FF);
}

pub fn codepointCellWidth(codepoint: u32) u8 {
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
                    self.markDirtyRangeWithOrigin("prepare_write_wrap_mark", self.cursor.row, self.cursor.row, 0, cols_local - 1);
                }
            }
            return .need_wrap;
        }
    }
    if (self.cursor.col >= cols or self.cursor.row >= rows) return .done;
    return .proceed;
}

pub fn mapDecSpecial(codepoint: u32) u32 {
    return switch (codepoint) {
        0x60 => 0x25C6,
        0x61 => 0x2592,
        0x62 => 0x2409,
        0x63 => 0x240C,
        0x64 => 0x240D,
        0x65 => 0x240A,
        0x66 => 0x00B0,
        0x67 => 0x00B1,
        0x68 => 0x2424,
        0x69 => 0x240B,
        0x6A => 0x2518,
        0x6B => 0x2510,
        0x6C => 0x250C,
        0x6D => 0x2514,
        0x6E => 0x253C,
        0x6F => 0x23BA,
        0x70 => 0x23BB,
        0x71 => 0x2500,
        0x72 => 0x23BC,
        0x73 => 0x23BD,
        0x74 => 0x251C,
        0x75 => 0x2524,
        0x76 => 0x2534,
        0x77 => 0x252C,
        0x78 => 0x2502,
        0x79 => 0x2264,
        0x7A => 0x2265,
        0x7B => 0x03C0,
        0x7C => 0x2260,
        0x7D => 0x00A3,
        0x7E => 0x00B7,
        else => codepoint,
    };
}
