const std = @import("std");
const pty_mod = @import("pty.zig");
const stream_mod = @import("stream.zig");
const csi_mod = @import("csi.zig");
const scrollback_mod = @import("scrollback.zig");
const app_logger = @import("../app_logger.zig");
const Pty = pty_mod.Pty;
const PtySize = pty_mod.PtySize;

pub const TerminalSnapshot = struct {
    rows: usize,
    cols: usize,
    cells: []const Cell,
    cursor: CursorPos,
    dirty: Dirty,
    damage: Damage,

    pub fn rowSlice(self: *const TerminalSnapshot, row: usize) []const Cell {
        const start = row * self.cols;
        return self.cells[start .. start + self.cols];
    }

    pub fn cellAt(self: *const TerminalSnapshot, row: usize, col: usize) Cell {
        return self.cells[row * self.cols + col];
    }
};

pub const Damage = struct {
    start_row: usize,
    end_row: usize,
    start_col: usize,
    end_col: usize,
};

pub const Dirty = enum {
    none,
    partial,
    full,
};

const TerminalGrid = struct {
    allocator: std.mem.Allocator,
    rows: u16,
    cols: u16,
    cells: std.ArrayList(Cell),
    dirty: Dirty,
    damage: Damage,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !TerminalGrid {
        var cells = std.ArrayList(Cell).empty;
        const count = @as(usize, rows) * @as(usize, cols);
        try cells.resize(allocator, count);
        const default_cell = defaultCell();
        for (cells.items) |*cell| {
            cell.* = default_cell;
        }
        return .{
            .allocator = allocator,
            .rows = rows,
            .cols = cols,
            .cells = cells,
            .dirty = .full,
            .damage = .{
                .start_row = 0,
                .end_row = if (rows > 0) @as(usize, rows - 1) else 0,
                .start_col = 0,
                .end_col = if (cols > 0) @as(usize, cols - 1) else 0,
            },
        };
    }

    pub fn deinit(self: *TerminalGrid) void {
        self.cells.deinit(self.allocator);
    }

    pub fn resize(self: *TerminalGrid, rows: u16, cols: u16) !void {
        if (self.rows == rows and self.cols == cols) return;
        self.rows = rows;
        self.cols = cols;
        const count = @as(usize, rows) * @as(usize, cols);
        try self.cells.resize(self.allocator, count);
        const default_cell = defaultCell();
        for (self.cells.items) |*cell| {
            cell.* = default_cell;
        }
        self.markDirtyAll();
    }

    pub fn markDirtyAll(self: *TerminalGrid) void {
        self.dirty = .full;
        self.damage = .{
            .start_row = 0,
            .end_row = if (self.rows > 0) @as(usize, self.rows - 1) else 0,
            .start_col = 0,
            .end_col = if (self.cols > 0) @as(usize, self.cols - 1) else 0,
        };
    }

    pub fn clearDirty(self: *TerminalGrid) void {
        self.dirty = .none;
    }
};

/// Minimal terminal stub so the UI panel stays wired while backend is removed.
pub const TerminalSession = struct {
    allocator: std.mem.Allocator,
    title: []const u8,
    pty: ?Pty,
    grid: TerminalGrid,
    scrollback: Scrollback,
    cursor: CursorPos,
    scrollback_offset: usize,
    cell_width: u16,
    cell_height: u16,
    stream: stream_mod.Stream,
    esc_state: EscState,
    csi: csi_mod.CsiParser,
    current_attrs: CellAttrs,
    scroll_top: usize,
    scroll_bottom: usize,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*TerminalSession {
        const session = try allocator.create(TerminalSession);
        const grid = try TerminalGrid.init(allocator, rows, cols);
        const scrollback = try Scrollback.init(allocator, default_scrollback_rows, cols);
        app_logger.logf("terminal init rows={d} cols={d} scrollback_max={d}", .{ rows, cols, default_scrollback_rows });
        app_logger.logStdout("terminal init rows={d} cols={d}", .{ rows, cols });
        session.* = .{
            .allocator = allocator,
            .title = "Terminal",
            .pty = null,
            .grid = grid,
            .scrollback = scrollback,
            .cursor = .{ .row = 0, .col = 0 },
            .scrollback_offset = 0,
            .cell_width = 0,
            .cell_height = 0,
            .stream = .{},
            .esc_state = .ground,
            .csi = .{},
            .current_attrs = defaultCell().attrs,
            .scroll_top = 0,
            .scroll_bottom = if (rows > 0) @as(usize, rows - 1) else 0,
        };
        return session;
    }

    pub fn deinit(self: *TerminalSession) void {
        if (self.pty) |*pty| {
            pty.deinit();
        }
        self.scrollback.deinit();
        self.grid.deinit();
        self.allocator.destroy(self);
    }

    pub fn start(self: *TerminalSession, shell: ?[:0]const u8) !void {
        const size = PtySize{
            .rows = self.grid.rows,
            .cols = self.grid.cols,
            .cell_width = self.cell_width,
            .cell_height = self.cell_height,
        };
        const pty = try Pty.init(self.allocator, size, shell);
        self.pty = pty;
    }

    pub fn poll(self: *TerminalSession) !void {
        if (self.pty) |*pty| {
            var buf: [4096]u8 = undefined;
            while (true) {
                const n = try pty.read(&buf);
                if (n == null or n.? == 0) break;
                for (buf[0..n.?]) |b| {
                    self.handleByte(b);
                }
            }
        }
    }

    pub fn hasData(self: *TerminalSession) bool {
        if (self.pty) |*pty| {
            return pty.hasData();
        }
        return false;
    }

    pub fn sendKey(self: *TerminalSession, key: Key, mod: Modifier) !void {
        _ = mod;
        if (self.pty) |*pty| {
            const seq = switch (key) {
                VTERM_KEY_ENTER => "\r",
                VTERM_KEY_TAB => "\t",
                VTERM_KEY_BACKSPACE => "\x7f",
                VTERM_KEY_ESCAPE => "\x1b",
                VTERM_KEY_UP => "\x1b[A",
                VTERM_KEY_DOWN => "\x1b[B",
                VTERM_KEY_RIGHT => "\x1b[C",
                VTERM_KEY_LEFT => "\x1b[D",
                VTERM_KEY_HOME => "\x1b[H",
                VTERM_KEY_END => "\x1b[F",
                VTERM_KEY_PAGEUP => "\x1b[5~",
                VTERM_KEY_PAGEDOWN => "\x1b[6~",
                VTERM_KEY_INS => "\x1b[2~",
                VTERM_KEY_DEL => "\x1b[3~",
                else => "",
            };
            if (seq.len > 0) {
                _ = try pty.write(seq);
            }
        }
    }

    pub fn sendChar(self: *TerminalSession, char: u32, mod: Modifier) !void {
        _ = mod;
        if (self.pty) |*pty| {
            if (char > 0x10FFFF or (char >= 0xD800 and char <= 0xDFFF)) return;
            var buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(@intCast(char), &buf) catch return;
            _ = try pty.write(buf[0..len]);
        }
    }

    pub fn resize(self: *TerminalSession, rows: u16, cols: u16) !void {
        const old_rows = self.grid.rows;
        const old_cols = self.grid.cols;
        try self.grid.resize(rows, cols);
        if (cols != old_cols) {
            try self.scrollback.resize(cols);
        }
        const was_full_region = old_rows > 0 and self.scroll_top == 0 and self.scroll_bottom + 1 == @as(usize, old_rows);
        app_logger.logf("terminal resize rows={d} cols={d} scrollback_cols={d}", .{ rows, cols, self.grid.cols });
        app_logger.logStdout("terminal resize rows={d} cols={d}", .{ rows, cols });
        self.setScrollOffset(self.scrollback_offset);
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
        if (self.cursor.row > max_row) self.cursor.row = max_row;
        if (self.cursor.col > max_col) self.cursor.col = max_col;
        if (self.pty) |*pty| {
            const size = PtySize{
                .rows = rows,
                .cols = cols,
                .cell_width = self.cell_width,
                .cell_height = self.cell_height,
            };
            try pty.resize(size);
        }
    }

    pub fn setCellSize(self: *TerminalSession, cell_width: u16, cell_height: u16) void {
        self.cell_width = cell_width;
        self.cell_height = cell_height;
    }

    fn handleControl(self: *TerminalSession, byte: u8) void {
        switch (byte) {
            0x08 => { // BS
                if (self.cursor.col > 0) self.cursor.col -= 1;
            },
            0x09 => { // TAB (every 8 columns)
                const next = (self.cursor.col + 8) & ~@as(usize, 7);
                self.cursor.col = @min(next, @as(usize, self.grid.cols - 1));
            },
            0x0A => { // LF
                self.newline();
            },
            0x0D => { // CR
                self.cursor.col = 0;
            },
            0x1B => { // ESC
                self.esc_state = .esc;
                self.stream.reset();
                self.csi.reset();
            },
            else => {},
        }
    }

    fn handleByte(self: *TerminalSession, byte: u8) void {
        switch (self.esc_state) {
            .ground => {
                if (byte == 0x1B) {
                    self.esc_state = .esc;
                    self.stream.reset();
                    self.csi.reset();
                    return;
                }
                if (self.stream.feed(byte)) |event| {
                    switch (event) {
                        .codepoint => |cp| self.handleCodepoint(@intCast(cp)),
                        .control => |c| self.handleControl(c),
                        .invalid => self.handleCodepoint(0xFFFD),
                    }
                }
            },
            .esc => {
                if (byte == '[') {
                    self.esc_state = .csi;
                    self.csi.reset();
                } else if (byte == 'c') {
                    self.resetState();
                    self.esc_state = .ground;
                } else {
                    self.esc_state = .ground;
                }
            },
            .csi => {
                if (self.csi.feed(byte)) |action| {
                    self.handleCsi(action);
                    self.esc_state = .ground;
                }
            },
        }
    }

    fn handleCsi(self: *TerminalSession, action: csi_mod.CsiAction) void {
        if (action.private) return;
        const p = action.params;
        const count = action.count;
        const get = struct {
            fn at(params: [8]i32, idx: u8, default: i32) i32 {
                return if (idx < 8) params[idx] else default;
            }
        }.at;

        switch (action.final) {
            'A' => { // CUU
                const n = @max(1, get(p, 0, 1));
                const delta: usize = @intCast(n);
                self.cursor.row = if (self.cursor.row > delta) self.cursor.row - delta else 0;
            },
            'B' => { // CUD
                const n = @max(1, get(p, 0, 1));
                const delta: usize = @intCast(n);
                const max_row = @as(usize, self.grid.rows - 1);
                self.cursor.row = @min(max_row, self.cursor.row + delta);
            },
            'C' => { // CUF
                const n = @max(1, get(p, 0, 1));
                const delta: usize = @intCast(n);
                const max_col = @as(usize, self.grid.cols - 1);
                self.cursor.col = @min(max_col, self.cursor.col + delta);
            },
            'D' => { // CUB
                const n = @max(1, get(p, 0, 1));
                const delta: usize = @intCast(n);
                self.cursor.col = if (self.cursor.col > delta) self.cursor.col - delta else 0;
            },
            'E' => { // CNL
                const n = @max(1, get(p, 0, 1));
                const delta: usize = @intCast(n);
                const max_row = @as(usize, self.grid.rows - 1);
                self.cursor.row = @min(max_row, self.cursor.row + delta);
                self.cursor.col = 0;
            },
            'F' => { // CPL
                const n = @max(1, get(p, 0, 1));
                const delta: usize = @intCast(n);
                self.cursor.row = if (self.cursor.row > delta) self.cursor.row - delta else 0;
                self.cursor.col = 0;
            },
            'G' => { // CHA
                const col_1 = @max(1, get(p, 0, 1));
                const col = @min(@as(usize, self.grid.cols - 1), @as(usize, @intCast(col_1 - 1)));
                self.cursor.col = col;
            },
            'H', 'f' => { // CUP
                const row_1 = @max(1, get(p, 0, 1));
                const col_1 = @max(1, get(p, 1, 1));
                const row = @min(@as(usize, self.grid.rows - 1), @as(usize, @intCast(row_1 - 1)));
                const col = @min(@as(usize, self.grid.cols - 1), @as(usize, @intCast(col_1 - 1)));
                self.cursor.row = row;
                self.cursor.col = col;
            },
            'd' => { // VPA
                const row_1 = @max(1, get(p, 0, 1));
                const row = @min(@as(usize, self.grid.rows - 1), @as(usize, @intCast(row_1 - 1)));
                self.cursor.row = row;
            },
            'J' => { // ED
                const mode = if (count > 0) p[0] else 0;
                self.eraseDisplay(mode);
            },
            'K' => { // EL
                const mode = if (count > 0) p[0] else 0;
                self.eraseLine(mode);
            },
            '@' => { // ICH
                const n = @max(1, get(p, 0, 1));
                self.insertChars(@intCast(n));
            },
            'P' => { // DCH
                const n = @max(1, get(p, 0, 1));
                self.deleteChars(@intCast(n));
            },
            'L' => { // IL
                const n = @max(1, get(p, 0, 1));
                self.insertLines(@intCast(n));
            },
            'M' => { // DL
                const n = @max(1, get(p, 0, 1));
                self.deleteLines(@intCast(n));
            },
            'S' => { // SU
                const n = @max(1, get(p, 0, 1));
                self.scrollRegionUp(@intCast(n));
            },
            'T' => { // SD
                const n = @max(1, get(p, 0, 1));
                self.scrollRegionDown(@intCast(n));
            },
            'r' => { // DECSTBM
                const top_1 = if (count > 0 and p[0] > 0) p[0] else 1;
                const bot_1 = if (count > 1 and p[1] > 0) p[1] else @as(i32, @intCast(self.grid.rows));
                const top = @min(@as(usize, self.grid.rows - 1), @as(usize, @intCast(@max(1, top_1) - 1)));
                const bot = @min(@as(usize, self.grid.rows - 1), @as(usize, @intCast(@max(1, bot_1) - 1)));
                if (top <= bot) {
                    self.scroll_top = top;
                    self.scroll_bottom = bot;
                    self.cursor.row = top;
                    self.cursor.col = 0;
                }
            },
            'm' => { // SGR
                self.applySgr(action);
            },
            else => {},
        }
    }

    fn resetState(self: *TerminalSession) void {
        self.cursor = .{ .row = 0, .col = 0 };
        self.current_attrs = defaultCell().attrs;
        self.scroll_top = 0;
        self.scroll_bottom = if (self.grid.rows > 0) @as(usize, self.grid.rows - 1) else 0;
        const default_cell = defaultCell();
        for (self.grid.cells.items) |*cell| {
            cell.* = default_cell;
        }
        self.grid.markDirtyAll();
    }

    fn eraseDisplay(self: *TerminalSession, mode: i32) void {
        const rows = @as(usize, self.grid.rows);
        const cols = @as(usize, self.grid.cols);
        if (rows == 0 or cols == 0) return;
        const default_cell = defaultCell();
        const row = self.cursor.row;
        const col = self.cursor.col;
        if (row >= rows or col >= cols) return;

        switch (mode) {
            0 => { // cursor to end
                const start_idx = row * cols + col;
                for (self.grid.cells.items[start_idx..]) |*cell| cell.* = default_cell;
            },
            1 => { // start to cursor
                const end = row * cols + col + 1;
                for (self.grid.cells.items[0..end]) |*cell| cell.* = default_cell;
            },
            2 => { // all
                for (self.grid.cells.items) |*cell| cell.* = default_cell;
            },
            else => {},
        }
        self.grid.markDirtyAll();
    }

    fn eraseLine(self: *TerminalSession, mode: i32) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0 or self.grid.rows == 0) return;
        const default_cell = defaultCell();
        if (self.cursor.row >= @as(usize, self.grid.rows)) return;
        const row_start = self.cursor.row * cols;
        const col = self.cursor.col;
        if (col >= cols) return;
        switch (mode) {
            0 => { // cursor to end of line
                for (self.grid.cells.items[row_start + col .. row_start + cols]) |*cell| cell.* = default_cell;
            },
            1 => { // start to cursor
                for (self.grid.cells.items[row_start .. row_start + col + 1]) |*cell| cell.* = default_cell;
            },
            2 => { // entire line
                for (self.grid.cells.items[row_start .. row_start + cols]) |*cell| cell.* = default_cell;
            },
            else => {},
        }
        self.grid.markDirtyAll();
    }

    fn insertChars(self: *TerminalSession, count: usize) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0) return;
        if (self.cursor.row >= @as(usize, self.grid.rows)) return;
        const col = self.cursor.col;
        if (col >= cols) return;
        const n = @min(count, cols - col);
        const row_start = self.cursor.row * cols;
        const line = self.grid.cells.items[row_start .. row_start + cols];
        if (cols - col > n) {
            std.mem.copyBackwards(Cell, line[col + n ..], line[col .. cols - n]);
        }
        const default_cell = defaultCell();
        for (line[col .. col + n]) |*cell| cell.* = default_cell;
        self.grid.markDirtyAll();
    }

    fn deleteChars(self: *TerminalSession, count: usize) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0) return;
        if (self.cursor.row >= @as(usize, self.grid.rows)) return;
        const col = self.cursor.col;
        if (col >= cols) return;
        const n = @min(count, cols - col);
        const row_start = self.cursor.row * cols;
        const line = self.grid.cells.items[row_start .. row_start + cols];
        if (cols - col > n) {
            std.mem.copyForwards(Cell, line[col .. cols - n], line[col + n ..]);
        }
        const default_cell = defaultCell();
        for (line[cols - n .. cols]) |*cell| cell.* = default_cell;
        self.grid.markDirtyAll();
    }

    fn insertLines(self: *TerminalSession, count: usize) void {
        const cols = @as(usize, self.grid.cols);
        const rows = @as(usize, self.grid.rows);
        if (rows == 0 or cols == 0) return;
        if (self.cursor.row < self.scroll_top or self.cursor.row > self.scroll_bottom) return;
        const n = @min(count, self.scroll_bottom - self.cursor.row + 1);
        const default_cell = defaultCell();
        const region_end = (self.scroll_bottom + 1) * cols;
        const insert_at = self.cursor.row * cols;
        const move_len = region_end - insert_at - n * cols;
        if (move_len > 0) {
            std.mem.copyBackwards(Cell, self.grid.cells.items[insert_at + n * cols .. region_end], self.grid.cells.items[insert_at .. insert_at + move_len]);
        }
        for (self.grid.cells.items[insert_at .. insert_at + n * cols]) |*cell| cell.* = default_cell;
        self.grid.markDirtyAll();
    }

    fn deleteLines(self: *TerminalSession, count: usize) void {
        const cols = @as(usize, self.grid.cols);
        const rows = @as(usize, self.grid.rows);
        if (rows == 0 or cols == 0) return;
        if (self.cursor.row < self.scroll_top or self.cursor.row > self.scroll_bottom) return;
        const n = @min(count, self.scroll_bottom - self.cursor.row + 1);
        const default_cell = defaultCell();
        const region_end = (self.scroll_bottom + 1) * cols;
        const delete_at = self.cursor.row * cols;
        const move_len = region_end - delete_at - n * cols;
        if (move_len > 0) {
            std.mem.copyForwards(Cell, self.grid.cells.items[delete_at .. delete_at + move_len], self.grid.cells.items[delete_at + n * cols .. region_end]);
        }
        for (self.grid.cells.items[region_end - n * cols .. region_end]) |*cell| cell.* = default_cell;
        self.grid.markDirtyAll();
    }

    fn isFullScrollRegion(self: *TerminalSession) bool {
        const rows = @as(usize, self.grid.rows);
        if (rows == 0) return false;
        return self.scroll_top == 0 and self.scroll_bottom + 1 == rows;
    }

    fn pushScrollbackRow(self: *TerminalSession, row: usize) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0 or self.grid.rows == 0) return;
        if (row >= @as(usize, self.grid.rows)) return;
        const row_start = row * cols;
        self.scrollback.pushRow(self.grid.cells.items[row_start .. row_start + cols]);
        app_logger.logf("scrollback push row={d} total={d}", .{ row, self.scrollback.count() });
        app_logger.logStdout("scrollback push total={d}", .{self.scrollback.count()});
    }

    fn scrollRegionUp(self: *TerminalSession, count: usize) void {
        app_logger.logf("scroll region up count={d} top={d} bottom={d}", .{ count, self.scroll_top, self.scroll_bottom });
        app_logger.logStdout("scroll region up count={d}", .{count});
        const cols = @as(usize, self.grid.cols);
        if (cols == 0 or self.grid.rows == 0) return;
        const n = @min(count, self.scroll_bottom - self.scroll_top + 1);
        if (n == 0) return;
        const default_cell = defaultCell();
        const region_start = self.scroll_top * cols;
        const region_end = (self.scroll_bottom + 1) * cols;
        if (self.isFullScrollRegion()) {
            var row: usize = 0;
            while (row < n) : (row += 1) {
                self.pushScrollbackRow(self.scroll_top + row);
            }
        }
        const move_len = region_end - region_start - n * cols;
        if (move_len > 0) {
            std.mem.copyForwards(Cell, self.grid.cells.items[region_start .. region_start + move_len], self.grid.cells.items[region_start + n * cols .. region_end]);
        }
        for (self.grid.cells.items[region_end - n * cols .. region_end]) |*cell| cell.* = default_cell;
        self.grid.markDirtyAll();
    }

    fn scrollRegionDown(self: *TerminalSession, count: usize) void {
        const cols = @as(usize, self.grid.cols);
        if (cols == 0 or self.grid.rows == 0) return;
        const n = @min(count, self.scroll_bottom - self.scroll_top + 1);
        if (n == 0) return;
        const default_cell = defaultCell();
        const region_start = self.scroll_top * cols;
        const region_end = (self.scroll_bottom + 1) * cols;
        const move_len = region_end - region_start - n * cols;
        if (move_len > 0) {
            std.mem.copyBackwards(Cell, self.grid.cells.items[region_start + n * cols .. region_end], self.grid.cells.items[region_start .. region_start + move_len]);
        }
        for (self.grid.cells.items[region_start .. region_start + n * cols]) |*cell| cell.* = default_cell;
        self.grid.markDirtyAll();
    }

    fn applySgr(self: *TerminalSession, action: csi_mod.CsiAction) void {
        const params = action.params;
        const n_params: usize = if (action.count == 0 and params[0] == 0) 1 else @as(usize, action.count + 1);
        var i: usize = 0;
        while (i < n_params) {
            const p = params[i];
            if (p == 38 or p == 48) {
                if (i + 1 < n_params) {
                    const mode = params[i + 1];
                    if (mode == 5 and i + 2 < n_params) {
                        const idx = clampColorIndex(params[i + 2]);
                        const color = indexToRgb(idx);
                        if (p == 38) {
                            self.current_attrs.fg = color;
                        } else {
                            self.current_attrs.bg = color;
                        }
                        i += 3;
                        continue;
                    }
                    if (mode == 2 and i + 4 < n_params) {
                        const r = clampColorIndex(params[i + 2]);
                        const g = clampColorIndex(params[i + 3]);
                        const b = clampColorIndex(params[i + 4]);
                        const color = Color{ .r = r, .g = g, .b = b };
                        if (p == 38) {
                            self.current_attrs.fg = color;
                        } else {
                            self.current_attrs.bg = color;
                        }
                        i += 5;
                        continue;
                    }
                }
                i += 1;
                continue;
            }
            switch (p) {
                0 => { // reset
                    self.current_attrs = defaultCell().attrs;
                },
                1 => { // bold
                    self.current_attrs.bold = true;
                },
                22 => { // normal intensity
                    self.current_attrs.bold = false;
                },
                7 => { // reverse
                    self.current_attrs.reverse = true;
                },
                27 => { // reverse off
                    self.current_attrs.reverse = false;
                },
                39 => { // default fg
                    self.current_attrs.fg = defaultCell().attrs.fg;
                },
                49 => { // default bg
                    self.current_attrs.bg = defaultCell().attrs.bg;
                },
                30...37 => {
                    self.current_attrs.fg = ansiColors[@intCast(p - 30)];
                },
                40...47 => {
                    self.current_attrs.bg = ansiColors[@intCast(p - 40)];
                },
                90...97 => {
                    self.current_attrs.fg = ansiBrightColors[@intCast(p - 90)];
                },
                100...107 => {
                    self.current_attrs.bg = ansiBrightColors[@intCast(p - 100)];
                },
                else => {},
            }
            i += 1;
        }
    }

    fn handleCodepoint(self: *TerminalSession, codepoint: u32) void {
        if (codepoint == 0) return;
        if (codepoint > 0x10FFFF or (codepoint >= 0xD800 and codepoint <= 0xDFFF)) return;

        const rows = @as(usize, self.grid.rows);
        const cols = @as(usize, self.grid.cols);
        if (rows == 0 or cols == 0) return;
        if (self.cursor.row >= rows) return;
        if (self.cursor.col >= cols) {
            self.newline();
            if (self.cursor.col >= cols or self.cursor.row >= rows) return;
        }

        const row = self.cursor.row;
        const col = self.cursor.col;
        const idx = row * cols + col;
        if (idx >= self.grid.cells.items.len) return;
        self.grid.cells.items[idx] = Cell{
            .codepoint = codepoint,
            .width = 1,
            .attrs = self.current_attrs,
        };

        self.cursor.col += 1;
        if (self.cursor.col >= cols) {
            self.newline();
        }
        self.grid.markDirtyAll();
    }

    fn newline(self: *TerminalSession) void {
        if (self.cursor.row + 1 < @as(usize, self.grid.rows)) {
            self.cursor.row += 1;
            self.cursor.col = 0;
            return;
        }
        self.scrollUp();
    }

    fn scrollUp(self: *TerminalSession) void {
        app_logger.logf("scroll up rows={d} cols={d}", .{ self.grid.rows, self.grid.cols });
        app_logger.logStdout("scroll up rows={d} cols={d}", .{ self.grid.rows, self.grid.cols });
        const cols = @as(usize, self.grid.cols);
        const rows = @as(usize, self.grid.rows);
        if (rows == 0 or cols == 0) return;

        if (self.isFullScrollRegion()) {
            self.pushScrollbackRow(0);
        }
        const total = rows * cols;
        const row_bytes = cols * @sizeOf(Cell);
        const src = @as([*]u8, @ptrCast(self.grid.cells.items.ptr));
        std.mem.copyForwards(u8, src[0 .. total * @sizeOf(Cell) - row_bytes], src[row_bytes .. total * @sizeOf(Cell)]);

        const row_start = (rows - 1) * cols;
        const default_cell = defaultCell();
        for (self.grid.cells.items[row_start .. row_start + cols]) |*cell| {
            cell.* = default_cell;
        }
        self.cursor.row = rows - 1;
        self.cursor.col = 0;
        self.grid.markDirtyAll();
    }

    pub fn getCell(self: *TerminalSession, row: usize, col: usize) Cell {
        if (row >= @as(usize, self.grid.rows) or col >= @as(usize, self.grid.cols)) {
            return defaultCell();
        }
        const idx = row * @as(usize, self.grid.cols) + col;
        return self.grid.cells.items[idx];
    }

    pub fn getCursorPos(self: *TerminalSession) CursorPos {
        return self.cursor;
    }

    pub fn gridRows(self: *TerminalSession) usize {
        return @as(usize, self.grid.rows);
    }

    pub fn gridCols(self: *TerminalSession) usize {
        return @as(usize, self.grid.cols);
    }

    pub fn scrollbackCount(self: *TerminalSession) usize {
        return self.scrollback.count();
    }

    pub fn scrollbackRow(self: *TerminalSession, index: usize) ?[]const Cell {
        return self.scrollback.rowSlice(index);
    }

    pub fn scrollOffset(self: *TerminalSession) usize {
        return self.scrollback_offset;
    }

    pub fn setScrollOffset(self: *TerminalSession, offset: usize) void {
        const max_offset = self.maxScrollOffset();
        self.scrollback_offset = @min(offset, max_offset);
        app_logger.logf("set scroll offset={d} max={d}", .{ self.scrollback_offset, max_offset });
        app_logger.logStdout("set scroll offset={d} max={d}", .{ self.scrollback_offset, max_offset });
    }

    pub fn scrollBy(self: *TerminalSession, delta: isize) void {
        if (delta == 0) return;
        const max_offset = self.maxScrollOffset();
        var offset: isize = @intCast(self.scrollback_offset);
        offset += delta;
        if (offset < 0) offset = 0;
        const max_i: isize = @intCast(max_offset);
        if (offset > max_i) offset = max_i;
        self.scrollback_offset = @intCast(offset);
        app_logger.logf("scroll by delta={d} offset={d} max={d}", .{ delta, self.scrollback_offset, max_offset });
        app_logger.logStdout("scroll by delta={d} offset={d} max={d}", .{ delta, self.scrollback_offset, max_offset });
    }

    fn maxScrollOffset(self: *TerminalSession) usize {
        const rows = @as(usize, self.grid.rows);
        const total = self.scrollback.count() + rows;
        return if (total > rows) total - rows else 0;
    }

    pub fn snapshot(self: *TerminalSession) TerminalSnapshot {
        const snap = TerminalSnapshot{
            .rows = @as(usize, self.grid.rows),
            .cols = @as(usize, self.grid.cols),
            .cells = self.grid.cells.items,
            .cursor = self.cursor,
            .dirty = self.grid.dirty,
            .damage = self.grid.damage,
        };
        self.grid.clearDirty();
        return snap;
    }

    pub fn isAlive(self: *TerminalSession) bool {
        _ = self;
        return false;
    }

    pub fn getDamage(self: *TerminalSession) ?struct {
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

    pub fn markDirty(self: *TerminalSession) void {
        self.grid.markDirtyAll();
    }
};

pub const CursorPos = struct {
    row: usize,
    col: usize,
};

pub const Cell = struct {
    codepoint: u32,
    width: u8,
    attrs: CellAttrs,
};

const Scrollback = scrollback_mod.Scrollback(Cell);

pub const CellAttrs = struct {
    fg: Color,
    bg: Color,
    bold: bool,
    reverse: bool,
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const Key = u32;
pub const Modifier = u8;

pub const VTERM_KEY_NONE: Key = 0;
pub const VTERM_KEY_ENTER: Key = 1;
pub const VTERM_KEY_TAB: Key = 2;
pub const VTERM_KEY_BACKSPACE: Key = 3;
pub const VTERM_KEY_ESCAPE: Key = 4;
pub const VTERM_KEY_UP: Key = 5;
pub const VTERM_KEY_DOWN: Key = 6;
pub const VTERM_KEY_LEFT: Key = 7;
pub const VTERM_KEY_RIGHT: Key = 8;
pub const VTERM_KEY_INS: Key = 9;
pub const VTERM_KEY_DEL: Key = 10;
pub const VTERM_KEY_HOME: Key = 11;
pub const VTERM_KEY_END: Key = 12;
pub const VTERM_KEY_PAGEUP: Key = 13;
pub const VTERM_KEY_PAGEDOWN: Key = 14;

pub const VTERM_MOD_NONE: Modifier = 0;
pub const VTERM_MOD_SHIFT: Modifier = 1;
pub const VTERM_MOD_ALT: Modifier = 2;
pub const VTERM_MOD_CTRL: Modifier = 4;

const EscState = enum {
    ground,
    esc,
    csi,
};

fn defaultCell() Cell {
    return Cell{
        .codepoint = 0,
        .width = 1,
        .attrs = CellAttrs{
            .fg = default_fg,
            .bg = default_bg,
            .bold = false,
            .reverse = false,
        },
    };
}

const default_fg = Color{ .r = 220, .g = 220, .b = 220 };
const default_bg = Color{ .r = 24, .g = 25, .b = 33 };
const default_scrollback_rows: usize = 1000;

const ansiColors = [_]Color{
    .{ .r = 0, .g = 0, .b = 0 }, // black
    .{ .r = 205, .g = 49, .b = 49 }, // red
    .{ .r = 13, .g = 188, .b = 121 }, // green
    .{ .r = 229, .g = 229, .b = 16 }, // yellow
    .{ .r = 36, .g = 114, .b = 200 }, // blue
    .{ .r = 188, .g = 63, .b = 188 }, // magenta
    .{ .r = 17, .g = 168, .b = 205 }, // cyan
    .{ .r = 229, .g = 229, .b = 229 }, // white
};

const ansiBrightColors = [_]Color{
    .{ .r = 102, .g = 102, .b = 102 }, // bright black
    .{ .r = 241, .g = 76, .b = 76 }, // bright red
    .{ .r = 35, .g = 209, .b = 139 }, // bright green
    .{ .r = 245, .g = 245, .b = 67 }, // bright yellow
    .{ .r = 59, .g = 142, .b = 234 }, // bright blue
    .{ .r = 214, .g = 112, .b = 214 }, // bright magenta
    .{ .r = 41, .g = 184, .b = 219 }, // bright cyan
    .{ .r = 255, .g = 255, .b = 255 }, // bright white
};

fn clampColorIndex(value: i32) u8 {
    if (value <= 0) return 0;
    if (value >= 255) return 255;
    return @intCast(value);
}

fn indexToRgb(idx: u8) Color {
    if (idx < 8) return ansiColors[idx];
    if (idx < 16) return ansiBrightColors[idx - 8];

    if (idx < 232) {
        const color_idx = idx - 16;
        const r_idx = color_idx / 36;
        const g_idx = (color_idx % 36) / 6;
        const b_idx = color_idx % 6;
        return .{
            .r = if (r_idx == 0) 0 else @as(u8, @intCast(55 + r_idx * 40)),
            .g = if (g_idx == 0) 0 else @as(u8, @intCast(55 + g_idx * 40)),
            .b = if (b_idx == 0) 0 else @as(u8, @intCast(55 + b_idx * 40)),
        };
    }

    const gray = @as(u8, @intCast(8 + (idx - 232) * 10));
    return .{ .r = gray, .g = gray, .b = gray };
}
