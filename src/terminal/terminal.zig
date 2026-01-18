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
    dirty_rows: []const bool,
    dirty_cols_start: []const u16,
    dirty_cols_end: []const u16,
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
    dirty_rows: std.ArrayList(bool),
    dirty_cols_start: std.ArrayList(u16),
    dirty_cols_end: std.ArrayList(u16),
    dirty: Dirty,
    damage: Damage,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !TerminalGrid {
        var cells = std.ArrayList(Cell).empty;
        var dirty_rows = std.ArrayList(bool).empty;
        var dirty_cols_start = std.ArrayList(u16).empty;
        var dirty_cols_end = std.ArrayList(u16).empty;
        const count = @as(usize, rows) * @as(usize, cols);
        try cells.resize(allocator, count);
        try dirty_rows.resize(allocator, rows);
        try dirty_cols_start.resize(allocator, rows);
        try dirty_cols_end.resize(allocator, rows);
        const default_cell = defaultCell();
        for (cells.items) |*cell| {
            cell.* = default_cell;
        }
        for (dirty_rows.items) |*row_dirty| {
            row_dirty.* = true;
        }
        for (dirty_cols_start.items, dirty_cols_end.items) |*col_start, *col_end| {
            col_start.* = 0;
            col_end.* = if (cols > 0) cols - 1 else 0;
        }
        return .{
            .allocator = allocator,
            .rows = rows,
            .cols = cols,
            .cells = cells,
            .dirty_rows = dirty_rows,
            .dirty_cols_start = dirty_cols_start,
            .dirty_cols_end = dirty_cols_end,
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
        self.dirty_rows.deinit(self.allocator);
        self.dirty_cols_start.deinit(self.allocator);
        self.dirty_cols_end.deinit(self.allocator);
    }

    pub fn resize(self: *TerminalGrid, rows: u16, cols: u16) !void {
        if (self.rows == rows and self.cols == cols) return;
        const old_rows = self.rows;
        const old_cols = self.cols;
        const old_cells = self.cells;

        var new_cells = std.ArrayList(Cell).empty;
        var new_dirty_rows = std.ArrayList(bool).empty;
        var new_dirty_cols_start = std.ArrayList(u16).empty;
        var new_dirty_cols_end = std.ArrayList(u16).empty;
        const count = @as(usize, rows) * @as(usize, cols);
        try new_cells.resize(self.allocator, count);
        try new_dirty_rows.resize(self.allocator, rows);
        try new_dirty_cols_start.resize(self.allocator, rows);
        try new_dirty_cols_end.resize(self.allocator, rows);

        const default_cell = defaultCell();
        for (new_cells.items) |*cell| {
            cell.* = default_cell;
        }

        const copy_rows = @min(@as(usize, old_rows), @as(usize, rows));
        const copy_cols = @min(@as(usize, old_cols), @as(usize, cols));
        if (copy_rows > 0 and copy_cols > 0 and old_cells.items.len > 0) {
            var row: usize = 0;
            while (row < copy_rows) : (row += 1) {
                const old_start = row * @as(usize, old_cols);
                const new_start = row * @as(usize, cols);
                std.mem.copyForwards(
                    Cell,
                    new_cells.items[new_start .. new_start + copy_cols],
                    old_cells.items[old_start .. old_start + copy_cols],
                );
            }
        }

        for (new_dirty_rows.items) |*row_dirty| {
            row_dirty.* = true;
        }
        for (new_dirty_cols_start.items, new_dirty_cols_end.items) |*col_start, *col_end| {
            col_start.* = 0;
            col_end.* = if (cols > 0) cols - 1 else 0;
        }

        self.cells.deinit(self.allocator);
        self.dirty_rows.deinit(self.allocator);
        self.dirty_cols_start.deinit(self.allocator);
        self.dirty_cols_end.deinit(self.allocator);
        self.cells = new_cells;
        self.dirty_rows = new_dirty_rows;
        self.dirty_cols_start = new_dirty_cols_start;
        self.dirty_cols_end = new_dirty_cols_end;
        self.rows = rows;
        self.cols = cols;
        self.markDirtyAll();
    }

    fn setAllDirtyRows(self: *TerminalGrid, value: bool) void {
        for (self.dirty_rows.items) |*row_dirty| {
            row_dirty.* = value;
        }
    }

    fn setAllDirtyCols(self: *TerminalGrid, start: u16, end: u16) void {
        for (self.dirty_cols_start.items, self.dirty_cols_end.items) |*col_start, *col_end| {
            col_start.* = start;
            col_end.* = end;
        }
    }

    pub fn markDirtyRange(self: *TerminalGrid, start_row: usize, end_row: usize, start_col: usize, end_col: usize) void {
        if (self.rows == 0 or self.cols == 0) return;
        const max_row = @as(usize, self.rows - 1);
        const max_col = @as(usize, self.cols - 1);
        const row_start = @min(start_row, max_row);
        const row_end = @min(end_row, max_row);
        const col_start = @min(start_col, max_col);
        const col_end = @min(end_col, max_col);
        if (row_start > row_end or col_start > col_end) return;

        if (self.dirty != .full) {
            if (self.dirty == .none) {
                self.dirty = .partial;
                self.damage = .{
                    .start_row = row_start,
                    .end_row = row_end,
                    .start_col = col_start,
                    .end_col = col_end,
                };
            } else {
                self.damage.start_row = @min(self.damage.start_row, row_start);
                self.damage.end_row = @max(self.damage.end_row, row_end);
                self.damage.start_col = @min(self.damage.start_col, col_start);
                self.damage.end_col = @max(self.damage.end_col, col_end);
            }
        }

        for (row_start..row_end + 1) |row| {
            self.dirty_rows.items[row] = true;
            const col_start_u16: u16 = @intCast(col_start);
            const col_end_u16: u16 = @intCast(col_end);
            if (self.dirty_cols_start.items[row] > col_start_u16) {
                self.dirty_cols_start.items[row] = col_start_u16;
            }
            if (self.dirty_cols_end.items[row] < col_end_u16) {
                self.dirty_cols_end.items[row] = col_end_u16;
            }
        }
    }

    pub fn markDirtyAll(self: *TerminalGrid) void {
        self.dirty = .full;
        self.damage = .{
            .start_row = 0,
            .end_row = if (self.rows > 0) @as(usize, self.rows - 1) else 0,
            .start_col = 0,
            .end_col = if (self.cols > 0) @as(usize, self.cols - 1) else 0,
        };
        self.setAllDirtyRows(true);
        if (self.cols > 0) {
            self.setAllDirtyCols(0, self.cols - 1);
        } else {
            self.setAllDirtyCols(0, 0);
        }
    }

    pub fn clearDirty(self: *TerminalGrid) void {
        self.dirty = .none;
        self.setAllDirtyRows(false);
        const invalid_start = self.cols;
        for (self.dirty_cols_start.items, self.dirty_cols_end.items) |*col_start, *col_end| {
            col_start.* = invalid_start;
            col_end.* = 0;
        }
        self.damage = .{
            .start_row = 0,
            .end_row = 0,
            .start_col = 0,
            .end_col = 0,
        };
    }
};

/// Minimal terminal stub so the UI panel stays wired while backend is removed.
pub const TerminalSession = struct {
    allocator: std.mem.Allocator,
    title: []const u8,
    title_buffer: std.ArrayList(u8),
    pty: ?Pty,
    grid: TerminalGrid,
    scrollback: Scrollback,
    cursor: CursorPos,
    alt_cursor: CursorPos,
    scrollback_offset: usize,
    saved_scrollback_offset: usize,
    selection: TerminalSelection,
    bracketed_paste: bool,
    cell_width: u16,
    cell_height: u16,
    stream: stream_mod.Stream,
    esc_state: EscState,
    csi: csi_mod.CsiParser,
    osc_state: OscState,
    osc_buffer: std.ArrayList(u8),
    osc_clipboard: std.ArrayList(u8),
    osc_clipboard_pending: bool,
    osc_hyperlink: std.ArrayList(u8),
    osc_hyperlink_active: bool,
    current_attrs: CellAttrs,
    scroll_top: usize,
    scroll_bottom: usize,
    alt_scroll_top: usize,
    alt_scroll_bottom: usize,
    alt_grid: ?TerminalGrid,
    alt_active: bool,
    saved_cursor_main: SavedCursor,
    saved_cursor_alt: SavedCursor,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*TerminalSession {
        const session = try allocator.create(TerminalSession);
        const grid = try TerminalGrid.init(allocator, rows, cols);
        const scrollback = try Scrollback.init(allocator, default_scrollback_rows, cols);
        const log = app_logger.logger("terminal.core");
        log.logf("terminal init rows={d} cols={d} scrollback_max={d}", .{ rows, cols, default_scrollback_rows });
        log.logStdout("terminal init rows={d} cols={d}", .{ rows, cols });
        session.* = .{
            .allocator = allocator,
            .title = "Terminal",
            .title_buffer = .empty,
            .pty = null,
            .grid = grid,
            .scrollback = scrollback,
            .cursor = .{ .row = 0, .col = 0 },
            .alt_cursor = .{ .row = 0, .col = 0 },
            .scrollback_offset = 0,
            .saved_scrollback_offset = 0,
            .selection = .{
                .active = false,
                .selecting = false,
                .start = .{ .row = 0, .col = 0 },
                .end = .{ .row = 0, .col = 0 },
            },
            .bracketed_paste = false,
            .cell_width = 0,
            .cell_height = 0,
            .stream = .{},
            .esc_state = .ground,
            .csi = .{},
            .osc_state = .idle,
            .osc_buffer = .empty,
            .osc_clipboard = .empty,
            .osc_clipboard_pending = false,
            .osc_hyperlink = .empty,
            .osc_hyperlink_active = false,
            .current_attrs = defaultCell().attrs,
            .scroll_top = 0,
            .scroll_bottom = if (rows > 0) @as(usize, rows - 1) else 0,
            .alt_scroll_top = 0,
            .alt_scroll_bottom = if (rows > 0) @as(usize, rows - 1) else 0,
            .alt_grid = null,
            .alt_active = false,
            .saved_cursor_main = .{ .active = false, .cursor = .{ .row = 0, .col = 0 }, .attrs = defaultCell().attrs },
            .saved_cursor_alt = .{ .active = false, .cursor = .{ .row = 0, .col = 0 }, .attrs = defaultCell().attrs },
        };
        return session;
    }

    pub fn deinit(self: *TerminalSession) void {
        if (self.pty) |*pty| {
            pty.deinit();
        }
        self.scrollback.deinit();
        self.grid.deinit();
        if (self.alt_grid) |*grid| {
            grid.deinit();
        }
        self.osc_buffer.deinit(self.allocator);
        self.osc_clipboard.deinit(self.allocator);
        self.osc_hyperlink.deinit(self.allocator);
        self.title_buffer.deinit(self.allocator);
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
            var had_data = false;
            while (true) {
                const n = try pty.read(&buf);
                if (n == null or n.? == 0) break;
                had_data = true;
                for (buf[0..n.?]) |b| {
                    self.handleByte(b);
                }
            }
            if (had_data) {
                self.clearSelection();
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

    pub fn sendText(self: *TerminalSession, text: []const u8) !void {
        if (text.len == 0) return;
        if (self.pty) |*pty| {
            _ = try pty.write(text);
        }
    }

    pub fn resize(self: *TerminalSession, rows: u16, cols: u16) !void {
        const old_rows = self.grid.rows;
        const old_cols = self.grid.cols;
        try self.grid.resize(rows, cols);
        if (cols != old_cols) {
            try self.scrollback.resizePreserve(cols, defaultCell());
        }
        if (self.alt_grid) |*grid| {
            try grid.resize(rows, cols);
        }
        const was_full_region = old_rows > 0 and self.scroll_top == 0 and self.scroll_bottom + 1 == @as(usize, old_rows);
        const log = app_logger.logger("terminal.core");
        log.logf("terminal resize rows={d} cols={d} scrollback_cols={d}", .{ rows, cols, self.grid.cols });
        log.logStdout("terminal resize rows={d} cols={d}", .{ rows, cols });
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
            if (self.alt_scroll_top >= @as(usize, rows)) self.alt_scroll_top = 0;
            if (self.alt_scroll_bottom >= @as(usize, rows)) self.alt_scroll_bottom = @as(usize, rows - 1);
            if (self.alt_scroll_top > self.alt_scroll_bottom) {
                self.alt_scroll_top = 0;
                self.alt_scroll_bottom = @as(usize, rows - 1);
            }
        } else {
            self.scroll_top = 0;
            self.scroll_bottom = 0;
            self.alt_scroll_top = 0;
            self.alt_scroll_bottom = 0;
        }
        const max_row = if (rows > 0) @as(usize, rows - 1) else 0;
        const max_col = if (cols > 0) @as(usize, cols - 1) else 0;
        if (self.cursor.row > max_row) self.cursor.row = max_row;
        if (self.cursor.col > max_col) self.cursor.col = max_col;
        self.clearSelection();
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
                self.osc_state = .idle;
            },
            else => {},
        }
    }

    fn handleByte(self: *TerminalSession, byte: u8) void {
        if (self.osc_state != .idle) {
            self.handleOscByte(byte);
            return;
        }
        switch (self.esc_state) {
            .ground => {
                if (byte == 0x1B) {
                    self.esc_state = .esc;
                    self.stream.reset();
                    self.csi.reset();
                    self.osc_state = .idle;
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
                } else if (byte == ']') {
                    self.esc_state = .ground;
                    self.osc_state = .osc;
                    self.osc_buffer.clearRetainingCapacity();
                    return;
                } else if (byte == 'c') {
                    self.resetState();
                    self.esc_state = .ground;
                } else if (byte == '7') {
                    self.saveCursor();
                    self.esc_state = .ground;
                } else if (byte == '8') {
                    self.restoreCursor();
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

    fn handleOscByte(self: *TerminalSession, byte: u8) void {
        switch (self.osc_state) {
            .idle => return,
            .osc => {
                if (byte == 0x07) { // BEL
                    self.finishOsc();
                    return;
                }
                if (byte == 0x1B) { // ESC
                    self.osc_state = .osc_esc;
                    return;
                }
                if (self.osc_buffer.items.len < 4096) {
                    _ = self.osc_buffer.append(self.allocator, byte) catch {};
                }
            },
            .osc_esc => {
                if (byte == '\\') { // ST
                    self.finishOsc();
                    return;
                }
                // Treat stray ESC as ignored and continue.
                self.osc_state = .osc;
                if (self.osc_buffer.items.len < 4096) {
                    _ = self.osc_buffer.append(self.allocator, byte) catch {};
                }
            },
        }
    }

    fn finishOsc(self: *TerminalSession) void {
        self.parseOsc(self.osc_buffer.items);
        self.osc_buffer.clearRetainingCapacity();
        self.osc_state = .idle;
    }

    fn parseOsc(self: *TerminalSession, payload: []const u8) void {
        var i: usize = 0;
        var code: usize = 0;
        var has_code = false;
        while (i < payload.len) : (i += 1) {
            const b = payload[i];
            if (b == ';') {
                has_code = true;
                i += 1;
                break;
            }
            if (b < '0' or b > '9') {
                return;
            }
            code = code * 10 + @as(usize, b - '0');
            has_code = true;
        }
        if (!has_code or i > payload.len) return;
        const text = payload[i..];
        switch (code) {
            0, 2 => {
                self.setTitle(text);
            },
            8 => {
                self.parseOscHyperlink(text);
            },
            52 => {
                self.parseOscClipboard(text);
            },
            else => {},
        }
    }

    fn setTitle(self: *TerminalSession, text: []const u8) void {
        self.title_buffer.clearRetainingCapacity();
        const max_len: usize = 256;
        const slice = if (text.len > max_len) text[0..max_len] else text;
        _ = self.title_buffer.appendSlice(self.allocator, slice) catch return;
        self.title = self.title_buffer.items;
    }

    fn parseOscHyperlink(self: *TerminalSession, text: []const u8) void {
        const split = std.mem.indexOfScalar(u8, text, ';') orelse return;
        const uri = text[split + 1 ..];
        self.osc_hyperlink.clearRetainingCapacity();
        if (uri.len == 0) {
            self.osc_hyperlink_active = false;
            return;
        }
        _ = self.osc_hyperlink.appendSlice(self.allocator, uri) catch return;
        self.osc_hyperlink_active = true;
    }

    fn parseOscClipboard(self: *TerminalSession, text: []const u8) void {
        const split = std.mem.indexOfScalar(u8, text, ';') orelse return;
        const selection = text[0..split];
        const payload = text[split + 1 ..];
        if (payload.len == 0 or std.mem.eql(u8, payload, "?")) return;
        if (!std.mem.containsAtLeast(u8, selection, 1, "c") and !std.mem.containsAtLeast(u8, selection, 1, "0")) {
            return;
        }

        const max_bytes: usize = 1024 * 1024;
        if (payload.len > max_bytes * 2) return;

        var decoded = std.ArrayList(u8).empty;
        defer decoded.deinit(self.allocator);

        const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(payload) catch return;
        if (decoded_len > max_bytes) return;
        decoded.resize(self.allocator, decoded_len) catch return;
        _ = std.base64.standard.Decoder.decode(decoded.items, payload) catch return;

        self.osc_clipboard.clearRetainingCapacity();
        _ = self.osc_clipboard.appendSlice(self.allocator, decoded.items) catch return;
        _ = self.osc_clipboard.append(self.allocator, 0) catch return;
        self.osc_clipboard_pending = true;
    }

    fn handleCsi(self: *TerminalSession, action: csi_mod.CsiAction) void {
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
            's' => { // SCP
                if (!action.private) {
                    self.saveCursor();
                }
            },
            'u' => { // RCP
                if (!action.private) {
                    self.restoreCursor();
                }
            },
            'm' => { // SGR
                self.applySgr(action);
            },
            'h' => { // SM
                if (action.private) {
                    const param_len: u8 = if (count == 0 and p[0] == 0) 0 else count + 1;
                    var idx: u8 = 0;
                    while (idx < param_len and idx < p.len) : (idx += 1) {
                        const mode = p[idx];
                        switch (mode) {
                            47 => self.enterAltScreen(false, false),
                            1047 => self.enterAltScreen(true, false),
                            1048 => self.saveCursor(),
                            1049 => self.enterAltScreen(true, true),
                            2004 => self.bracketed_paste = true,
                            else => {},
                        }
                    }
                    return;
                }
                if (action.private) return;
            },
            'l' => { // RM
                if (action.private) {
                    const param_len: u8 = if (count == 0 and p[0] == 0) 0 else count + 1;
                    var idx: u8 = 0;
                    while (idx < param_len and idx < p.len) : (idx += 1) {
                        const mode = p[idx];
                        switch (mode) {
                            47 => self.exitAltScreen(false),
                            1047 => self.exitAltScreen(false),
                            1048 => self.restoreCursor(),
                            1049 => self.exitAltScreen(true),
                            2004 => self.bracketed_paste = false,
                            else => {},
                        }
                    }
                    return;
                }
                if (action.private) return;
            },
            else => {},
        }
    }

    fn resetState(self: *TerminalSession) void {
        self.cursor = .{ .row = 0, .col = 0 };
        self.current_attrs = defaultCell().attrs;
        self.scroll_top = 0;
        self.scroll_bottom = if (self.grid.rows > 0) @as(usize, self.grid.rows - 1) else 0;
        self.alt_scroll_top = 0;
        self.alt_scroll_bottom = if (self.grid.rows > 0) @as(usize, self.grid.rows - 1) else 0;
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
                self.grid.markDirtyRange(row, row, col, cols - 1);
                if (row + 1 < rows) {
                    self.grid.markDirtyRange(row + 1, rows - 1, 0, cols - 1);
                }
            },
            1 => { // start to cursor
                const end = row * cols + col + 1;
                for (self.grid.cells.items[0..end]) |*cell| cell.* = default_cell;
                if (row > 0) {
                    self.grid.markDirtyRange(0, row - 1, 0, cols - 1);
                }
                self.grid.markDirtyRange(row, row, 0, col);
            },
            2 => { // all
                for (self.grid.cells.items) |*cell| cell.* = default_cell;
                self.grid.markDirtyAll();
            },
            else => {},
        }
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
                self.grid.markDirtyRange(self.cursor.row, self.cursor.row, col, cols - 1);
            },
            1 => { // start to cursor
                for (self.grid.cells.items[row_start .. row_start + col + 1]) |*cell| cell.* = default_cell;
                self.grid.markDirtyRange(self.cursor.row, self.cursor.row, 0, col);
            },
            2 => { // entire line
                for (self.grid.cells.items[row_start .. row_start + cols]) |*cell| cell.* = default_cell;
                self.grid.markDirtyRange(self.cursor.row, self.cursor.row, 0, cols - 1);
            },
            else => {},
        }
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
        self.grid.markDirtyRange(self.cursor.row, self.cursor.row, col, cols - 1);
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
        self.grid.markDirtyRange(self.cursor.row, self.cursor.row, col, cols - 1);
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
        self.grid.markDirtyRange(self.cursor.row, self.scroll_bottom, 0, cols - 1);
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
        self.grid.markDirtyRange(self.cursor.row, self.scroll_bottom, 0, cols - 1);
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
        if (self.alt_active) return;
        const row_start = row * cols;
        self.scrollback.pushRow(self.grid.cells.items[row_start .. row_start + cols]);
        const log = app_logger.logger("terminal.core");
        log.logf("scrollback push row={d} total={d}", .{ row, self.scrollback.count() });
        log.logStdout("scrollback push total={d}", .{self.scrollback.count()});
    }

    fn scrollRegionUp(self: *TerminalSession, count: usize) void {
        const log = app_logger.logger("terminal.core");
        log.logf("scroll region up count={d} top={d} bottom={d}", .{ count, self.scroll_top, self.scroll_bottom });
        log.logStdout("scroll region up count={d}", .{count});
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
        self.grid.markDirtyRange(self.scroll_top, self.scroll_bottom, 0, cols - 1);
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
        self.grid.markDirtyRange(self.scroll_top, self.scroll_bottom, 0, cols - 1);
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
        self.grid.markDirtyRange(row, row, col, col);
    }

    fn newline(self: *TerminalSession) void {
        if (self.cursor.row + 1 < @as(usize, self.grid.rows) and self.cursor.row != self.scroll_bottom) {
            self.cursor.row += 1;
            self.cursor.col = 0;
            return;
        }
        if (self.cursor.row == self.scroll_bottom) {
            self.scrollRegionUp(1);
            return;
        }
        self.scrollUp();
    }

    fn scrollUp(self: *TerminalSession) void {
        const log = app_logger.logger("terminal.core");
        log.logf("scroll up rows={d} cols={d}", .{ self.grid.rows, self.grid.cols });
        log.logStdout("scroll up rows={d} cols={d}", .{ self.grid.rows, self.grid.cols });
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
        if (self.alt_active) return 0;
        return self.scrollback.count();
    }

    pub fn scrollbackRow(self: *TerminalSession, index: usize) ?[]const Cell {
        if (self.alt_active) return null;
        return self.scrollback.rowSlice(index);
    }

    pub fn scrollOffset(self: *TerminalSession) usize {
        if (self.alt_active) return 0;
        return self.scrollback_offset;
    }

    pub fn setScrollOffset(self: *TerminalSession, offset: usize) void {
        if (self.alt_active) {
            self.scrollback_offset = 0;
            return;
        }
        const max_offset = self.maxScrollOffset();
        self.scrollback_offset = @min(offset, max_offset);
        self.grid.markDirtyAll();
        const log = app_logger.logger("terminal.core");
        log.logf("set scroll offset={d} max={d}", .{ self.scrollback_offset, max_offset });
        log.logStdout("set scroll offset={d} max={d}", .{ self.scrollback_offset, max_offset });
    }

    pub fn scrollBy(self: *TerminalSession, delta: isize) void {
        if (self.alt_active) return;
        if (delta == 0) return;
        const max_offset = self.maxScrollOffset();
        var offset: isize = @intCast(self.scrollback_offset);
        offset += delta;
        if (offset < 0) offset = 0;
        const max_i: isize = @intCast(max_offset);
        if (offset > max_i) offset = max_i;
        self.scrollback_offset = @intCast(offset);
        self.grid.markDirtyAll();
        const log = app_logger.logger("terminal.core");
        log.logf("scroll by delta={d} offset={d} max={d}", .{ delta, self.scrollback_offset, max_offset });
        log.logStdout("scroll by delta={d} offset={d} max={d}", .{ delta, self.scrollback_offset, max_offset });
    }

    fn maxScrollOffset(self: *TerminalSession) usize {
        if (self.alt_active) return 0;
        const rows = @as(usize, self.grid.rows);
        const total = self.scrollback.count() + rows;
        return if (total > rows) total - rows else 0;
    }

    fn saveCursor(self: *TerminalSession) void {
        const slot = if (self.alt_active) &self.saved_cursor_alt else &self.saved_cursor_main;
        slot.active = true;
        slot.cursor = self.cursor;
        slot.attrs = self.current_attrs;
    }

    fn restoreCursor(self: *TerminalSession) void {
        const slot = if (self.alt_active) &self.saved_cursor_alt else &self.saved_cursor_main;
        if (!slot.active) return;
        self.cursor = slot.cursor;
        self.current_attrs = slot.attrs;
    }

    fn clearGrid(self: *TerminalSession) void {
        const default_cell = defaultCell();
        for (self.grid.cells.items) |*cell| {
            cell.* = default_cell;
        }
        self.grid.markDirtyAll();
    }

    fn enterAltScreen(self: *TerminalSession, clear: bool, save_cursor: bool) void {
        if (self.alt_active) return;
        if (save_cursor) {
            self.saveCursor();
        }
        if (self.alt_grid == null) {
            self.alt_grid = TerminalGrid.init(self.allocator, self.grid.rows, self.grid.cols) catch return;
        }
        if (self.alt_grid) |*grid| {
            std.mem.swap(TerminalGrid, &self.grid, grid);
        }
        std.mem.swap(CursorPos, &self.cursor, &self.alt_cursor);
        std.mem.swap(usize, &self.scroll_top, &self.alt_scroll_top);
        std.mem.swap(usize, &self.scroll_bottom, &self.alt_scroll_bottom);
        self.alt_active = true;
        self.saved_scrollback_offset = self.scrollback_offset;
        self.scrollback_offset = 0;
        self.clearSelection();
        if (clear) {
            self.clearGrid();
            self.cursor = .{ .row = 0, .col = 0 };
        }
    }

    fn exitAltScreen(self: *TerminalSession, restore_cursor: bool) void {
        if (!self.alt_active) return;
        if (self.alt_grid) |*grid| {
            std.mem.swap(TerminalGrid, &self.grid, grid);
        }
        std.mem.swap(CursorPos, &self.cursor, &self.alt_cursor);
        std.mem.swap(usize, &self.scroll_top, &self.alt_scroll_top);
        std.mem.swap(usize, &self.scroll_bottom, &self.alt_scroll_bottom);
        self.alt_active = false;
        self.scrollback_offset = self.saved_scrollback_offset;
        self.clearSelection();
        if (restore_cursor) {
            self.restoreCursor();
        }
        self.grid.markDirtyAll();
    }

    pub fn snapshot(self: *TerminalSession) TerminalSnapshot {
        return TerminalSnapshot{
            .rows = @as(usize, self.grid.rows),
            .cols = @as(usize, self.grid.cols),
            .cells = self.grid.cells.items,
            .dirty_rows = self.grid.dirty_rows.items,
            .dirty_cols_start = self.grid.dirty_cols_start.items,
            .dirty_cols_end = self.grid.dirty_cols_end.items,
            .cursor = self.cursor,
            .dirty = self.grid.dirty,
            .damage = self.grid.damage,
        };
    }

    pub fn takeOscClipboard(self: *TerminalSession) ?[]const u8 {
        if (!self.osc_clipboard_pending) return null;
        self.osc_clipboard_pending = false;
        return self.osc_clipboard.items;
    }

    pub fn clearDirty(self: *TerminalSession) void {
        self.grid.clearDirty();
    }

    pub fn clearSelection(self: *TerminalSession) void {
        self.selection.active = false;
        self.selection.selecting = false;
    }

    pub fn startSelection(self: *TerminalSession, row: usize, col: usize) void {
        self.selection.active = true;
        self.selection.selecting = true;
        self.selection.start = .{ .row = row, .col = col };
        self.selection.end = .{ .row = row, .col = col };
    }

    pub fn updateSelection(self: *TerminalSession, row: usize, col: usize) void {
        if (!self.selection.active) return;
        self.selection.end = .{ .row = row, .col = col };
    }

    pub fn finishSelection(self: *TerminalSession) void {
        if (!self.selection.active) return;
        self.selection.selecting = false;
    }

    pub fn selectionState(self: *TerminalSession) ?TerminalSelection {
        if (!self.selection.active) return null;
        return self.selection;
    }

    pub fn bracketedPasteEnabled(self: *TerminalSession) bool {
        return self.bracketed_paste;
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

pub const SelectionPos = struct {
    row: usize,
    col: usize,
};

pub const TerminalSelection = struct {
    active: bool,
    selecting: bool,
    start: SelectionPos,
    end: SelectionPos,
};

const SavedCursor = struct {
    active: bool,
    cursor: CursorPos,
    attrs: CellAttrs,
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

const OscState = enum {
    idle,
    osc,
    osc_esc,
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
