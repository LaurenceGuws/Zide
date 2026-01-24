const std = @import("std");
const pty_mod = @import("../io/pty.zig");
const input_mod = @import("../input/input.zig");
const history_mod = @import("../model/history.zig");
const csi_mod = @import("../parser/csi.zig");
const parser_mod = @import("../parser/parser.zig");
const protocol_csi = @import("../protocol/csi.zig");
const protocol_dcs_apc = @import("../protocol/dcs_apc.zig");
const protocol_osc = @import("../protocol/osc.zig");
const screen_mod = @import("../model/screen.zig");
const snapshot_mod = @import("snapshot.zig");
const types = @import("../model/types.zig");
const app_logger = @import("../../app_logger.zig");
const kitty_mod = @import("../kitty/graphics.zig");
const Pty = pty_mod.Pty;
const PtySize = pty_mod.PtySize;
const Screen = screen_mod.Screen;
const Dirty = screen_mod.Dirty;
const Damage = screen_mod.Damage;
const KeyModeStack = screen_mod.KeyModeStack;
const builtin = @import("builtin");
const OscTerminator = parser_mod.OscTerminator;

const dynamic_color_count: usize = 10;

const SemanticPromptKind = enum {
    primary,
    continuation,
    secondary,
    right,
};

const SemanticPromptState = struct {
    prompt_active: bool = false,
    input_active: bool = false,
    output_active: bool = false,
    kind: SemanticPromptKind = .primary,
    redraw: bool = true,
    special_key: bool = false,
    click_events: bool = false,
    exit_code: ?u8 = null,
};

pub const KittyImageFormat = snapshot_mod.KittyImageFormat;
pub const KittyImage = snapshot_mod.KittyImage;
pub const KittyPlacement = snapshot_mod.KittyPlacement;

fn buildDefaultPalette() [256]types.Color {
    var palette: [256]types.Color = undefined;
    var idx: usize = 0;
    while (idx < palette.len) : (idx += 1) {
        palette[idx] = types.indexToRgb(@intCast(idx));
    }
    return palette;
}

fn logCsiSequences(log: app_logger.Logger, buf: []const u8) void {
    if (!(log.enabled_file or log.enabled_console)) return;
    var i: usize = 0;
    while (i + 1 < buf.len) : (i += 1) {
        if (buf[i] != 0x1b or buf[i + 1] != '[') continue;
        const start = i;
        i += 2;
        while (i < buf.len) : (i += 1) {
            const b = buf[i];
            if (b >= 0x40 and b <= 0x7E) {
                if (b == 'm') {
                    const seq = buf[start .. i + 1];
                    var hex_buf: [256]u8 = undefined;
                    var out: []u8 = hex_buf[0..0];
                    for (seq) |sb| {
                        if (out.len + 3 > hex_buf.len) break;
                        const pos = out.len;
                        _ = std.fmt.bufPrint(hex_buf[pos..], "{x:0>2} ", .{sb}) catch break;
                        out = hex_buf[0 .. pos + 3];
                    }
                    log.logf("csi raw len={d} hex={s}", .{ seq.len, out });
                }
                break;
            }
        }
    }
}

pub const TerminalSnapshot = snapshot_mod.TerminalSnapshot;
pub const DebugSnapshot = snapshot_mod.DebugSnapshot;

pub fn debugSnapshot(self: *TerminalSession) DebugSnapshot {
    if (!debugAccessAllowed()) @panic("debugSnapshot is test-only");
    return .{
        .title = self.title,
        .cwd = self.cwd,
        .osc_clipboard = self.osc_clipboard.items,
        .osc_clipboard_pending = self.osc_clipboard_pending,
        .hyperlinks = self.hyperlink_table.items,
        .scrollback_count = self.history.scrollbackCount(),
        .scrollback_offset = self.history.scrollOffset(),
        .selection = self.selectionState(),
        .base_default_attrs = self.base_default_attrs,
    };
}

pub fn debugScrollbackRow(self: *TerminalSession, index: usize) ?[]const Cell {
    if (!debugAccessAllowed()) @panic("debugScrollbackRow is test-only");
    return self.history.scrollbackRow(index);
}

pub fn debugSetCursor(self: *TerminalSession, row: usize, col: usize) void {
    if (!debugAccessAllowed()) @panic("debugSetCursor is test-only");
    const screen = self.activeScreen();
    screen.cursor = .{ .row = row, .col = col };
}

pub fn debugFeedBytes(self: *TerminalSession, bytes: []const u8) void {
    if (!debugAccessAllowed()) @panic("debugFeedBytes is test-only");
    self.parser.handleSlice(self, bytes);
}

fn debugAccessAllowed() bool {
    if (builtin.is_test) return true;
    const root = @import("root");
    return @hasDecl(root, "terminal_replay_enabled") and root.terminal_replay_enabled;
}

const ActiveScreen = enum {
    primary,
    alt,
};

/// Minimal terminal stub so the UI panel stays wired while backend is removed.
pub const TerminalSession = struct {
    allocator: std.mem.Allocator,
    title: []const u8,
    title_buffer: std.ArrayList(u8),
    pty: ?Pty,
    primary: Screen,
    alt: Screen,
    active: ActiveScreen,
    history: history_mod.TerminalHistory,
    bracketed_paste: bool,
    app_cursor_keys: bool,
    app_keypad: bool,
    input: input_mod.InputState,
    cell_width: u16,
    cell_height: u16,
    parser: parser_mod.Parser,
    osc_clipboard: std.ArrayList(u8),
    osc_clipboard_pending: bool,
    osc_hyperlink: std.ArrayList(u8),
    osc_hyperlink_active: bool,
    hyperlink_table: std.ArrayList(Hyperlink),
    current_hyperlink_id: u32,
    cwd: []const u8,
    cwd_buffer: std.ArrayList(u8),
    semantic_prompt: SemanticPromptState,
    semantic_prompt_aid: std.ArrayList(u8),
    semantic_cmdline: std.ArrayList(u8),
    semantic_cmdline_valid: bool,
    user_vars: std.StringHashMap([]u8),
    kitty_primary: kitty_mod.KittyState,
    kitty_alt: kitty_mod.KittyState,
    base_default_attrs: types.CellAttrs,
    palette_default: [256]types.Color,
    palette_current: [256]types.Color,
    dynamic_colors: [dynamic_color_count]?types.Color,
    read_thread: ?std.Thread,
    read_thread_running: std.atomic.Value(bool),
    state_mutex: std.Thread.Mutex,
    output_pending: std.atomic.Value(bool),
    output_generation: std.atomic.Value(u64),
    alt_exit_pending: std.atomic.Value(bool),
    alt_exit_time_ms: std.atomic.Value(i64),
    view_cells: std.ArrayList(Cell),
    view_dirty_rows: std.ArrayList(bool),
    view_dirty_cols_start: std.ArrayList(u16),
    view_dirty_cols_end: std.ArrayList(u16),
    alt_last_active: bool,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*TerminalSession {
        const session = try allocator.create(TerminalSession);
        const default_attrs = types.defaultCell().attrs;
        const primary = try Screen.init(allocator, rows, cols, default_attrs);
        const alt = try Screen.init(allocator, rows, cols, default_attrs);
        const history = try history_mod.TerminalHistory.init(allocator, default_scrollback_rows, cols);
        const log = app_logger.logger("terminal.core");
        log.logf("terminal init rows={d} cols={d} scrollback_max={d}", .{ rows, cols, default_scrollback_rows });
        log.logStdout("terminal init rows={d} cols={d}", .{ rows, cols });
        const palette_default = buildDefaultPalette();
        session.* = .{
            .allocator = allocator,
            .title = "Terminal",
            .title_buffer = .empty,
            .pty = null,
            .primary = primary,
            .alt = alt,
            .active = .primary,
            .history = history,
            .bracketed_paste = false,
            .app_cursor_keys = false,
            .app_keypad = false,
            .input = input_mod.InputState.init(),
            .cell_width = 0,
            .cell_height = 0,
            .parser = parser_mod.Parser.init(allocator),
            .osc_clipboard = .empty,
            .osc_clipboard_pending = false,
            .osc_hyperlink = .empty,
            .osc_hyperlink_active = false,
            .hyperlink_table = .empty,
            .current_hyperlink_id = 0,
            .cwd = "",
            .cwd_buffer = .empty,
            .semantic_prompt = .{},
            .semantic_prompt_aid = .empty,
            .semantic_cmdline = .empty,
            .semantic_cmdline_valid = false,
            .user_vars = std.StringHashMap([]u8).init(allocator),
            .kitty_primary = .{
                .images = .empty,
                .placements = .empty,
                .partials = std.AutoHashMap(u32, kitty_mod.KittyPartial).init(allocator),
                .next_id = 1,
                .generation = 0,
                .total_bytes = 0,
                .scrollback_total = 0,
            },
            .kitty_alt = .{
                .images = .empty,
                .placements = .empty,
                .partials = std.AutoHashMap(u32, kitty_mod.KittyPartial).init(allocator),
                .next_id = 1,
                .generation = 0,
                .total_bytes = 0,
                .scrollback_total = 0,
            },
            .base_default_attrs = default_attrs,
            .palette_default = palette_default,
            .palette_current = palette_default,
            .dynamic_colors = [_]?types.Color{null} ** dynamic_color_count,
            .read_thread = null,
            .read_thread_running = std.atomic.Value(bool).init(false),
            .state_mutex = .{},
            .output_pending = std.atomic.Value(bool).init(false),
            .output_generation = std.atomic.Value(u64).init(0),
            .alt_exit_pending = std.atomic.Value(bool).init(false),
            .alt_exit_time_ms = std.atomic.Value(i64).init(-1),
            .view_cells = .empty,
            .view_dirty_rows = .empty,
            .view_dirty_cols_start = .empty,
            .view_dirty_cols_end = .empty,
            .alt_last_active = false,
        };
        return session;
    }

    pub fn activeScreen(self: *TerminalSession) *Screen {
        return if (self.active == .alt) &self.alt else &self.primary;
    }

    pub fn activeScreenConst(self: *const TerminalSession) *const Screen {
        return if (self.active == .alt) &self.alt else &self.primary;
    }

    fn inactiveScreen(self: *TerminalSession) *Screen {
        return if (self.active == .alt) &self.primary else &self.alt;
    }

    fn isAltActive(self: *const TerminalSession) bool {
        return self.active == .alt;
    }

    fn defaultCell(self: *const TerminalSession) Cell {
        return .{
            .codepoint = 0,
            .width = 1,
            .attrs = self.primary.default_attrs,
        };
    }

    fn blankCellForScreen(self: *const TerminalSession, screen: *const Screen) Cell {
        _ = self;
        return .{
            .codepoint = 0,
            .width = 1,
            .attrs = screen.current_attrs,
        };
    }

    pub fn setDefaultColors(self: *TerminalSession, fg: types.Color, bg: types.Color) void {
        const old_attrs = self.primary.default_attrs;
        var new_attrs = types.defaultCell().attrs;
        new_attrs.fg = fg;
        new_attrs.bg = bg;
        new_attrs.underline_color = fg;

        self.primary.updateDefaultColors(old_attrs, new_attrs);
        self.alt.updateDefaultColors(old_attrs, new_attrs);
        self.history.updateDefaultColors(old_attrs.fg, old_attrs.bg, new_attrs.fg, new_attrs.bg);
    }

    pub fn deinit(self: *TerminalSession) void {
        if (self.read_thread) |thread| {
            self.read_thread_running.store(false, .release);
            thread.join();
            self.read_thread = null;
        }
        if (self.pty) |*pty| {
            pty.deinit();
        }
        self.view_cells.deinit(self.allocator);
        self.view_dirty_rows.deinit(self.allocator);
        self.view_dirty_cols_start.deinit(self.allocator);
        self.view_dirty_cols_end.deinit(self.allocator);
        self.history.deinit();
        self.primary.deinit();
        self.alt.deinit();
        self.parser.deinit();
        self.osc_clipboard.deinit(self.allocator);
        self.osc_hyperlink.deinit(self.allocator);
        self.cwd_buffer.deinit(self.allocator);
        self.semantic_prompt_aid.deinit(self.allocator);
        self.semantic_cmdline.deinit(self.allocator);
        var user_it = self.user_vars.iterator();
        while (user_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.user_vars.deinit();
        kitty_mod.deinitKittyState(self, &self.kitty_primary);
        kitty_mod.deinitKittyState(self, &self.kitty_alt);
        for (self.hyperlink_table.items) |link| {
            self.allocator.free(link.uri);
        }
        self.hyperlink_table.deinit(self.allocator);
        self.title_buffer.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn start(self: *TerminalSession, shell: ?[:0]const u8) !void {
        const size = PtySize{
            .rows = self.primary.grid.rows,
            .cols = self.primary.grid.cols,
            .cell_width = self.cell_width,
            .cell_height = self.cell_height,
        };
        const pty = try Pty.init(self.allocator, size, shell);
        self.pty = pty;
        if (builtin.os.tag == .linux or builtin.os.tag == .macos) {
            self.read_thread_running.store(true, .release);
            self.read_thread = try std.Thread.spawn(.{}, readThreadMain, .{self});
        }
    }

    pub fn poll(self: *TerminalSession) !void {
        if (self.read_thread != null) {
            if (self.output_pending.swap(false, .acq_rel)) {
                self.state_mutex.lock();
                self.clearSelection();
                self.state_mutex.unlock();
            }
            return;
        }

        if (self.pty) |*pty| {
            var buf: [262144]u8 = undefined;
            var had_data = false;
            var processed: usize = 0;
            const max_bytes_per_poll: usize = 256 * 1024;
            const start_ms = std.time.milliTimestamp();
            const io_log = app_logger.logger("terminal.io");
            while (true) {
                const n = try pty.read(&buf);
                if (n == null or n.? == 0) break;
                had_data = true;
                processed += n.?;
                logCsiSequences(io_log, buf[0..n.?]);
                self.parser.handleSlice(self, buf[0..n.?]);
                _ = self.output_generation.fetchAdd(1, .acq_rel);
                if (processed >= max_bytes_per_poll) break;
            }
            if (had_data) {
                self.clearSelection();
            }
            if (processed > 0 and self.alt_exit_pending.swap(false, .acq_rel)) {
                const elapsed_ms = @as(f64, @floatFromInt(std.time.milliTimestamp() - start_ms));
                io_log.logf("alt_exit_io_ms={d:.2} bytes={d}", .{ elapsed_ms, processed });
            }
        }
    }

    pub fn hasData(self: *TerminalSession) bool {
        if (self.read_thread != null) {
            return self.output_pending.load(.acquire);
        }
        if (self.pty) |*pty| {
            return pty.hasData();
        }
        return false;
    }


    pub fn lock(self: *TerminalSession) void {
        self.state_mutex.lock();
    }

    pub fn unlock(self: *TerminalSession) void {
        self.state_mutex.unlock();
    }

    pub fn currentGeneration(self: *TerminalSession) u64 {
        return self.output_generation.load(.acquire);
    }

    pub fn sendKey(self: *TerminalSession, key: Key, mod: Modifier) !void {
        if (self.pty) |*pty| {
            if (self.app_cursor_keys and mod == types.VTERM_MOD_NONE) {
                const seq = switch (key) {
                    VTERM_KEY_UP => "\x1bOA",
                    VTERM_KEY_DOWN => "\x1bOB",
                    VTERM_KEY_RIGHT => "\x1bOC",
                    VTERM_KEY_LEFT => "\x1bOD",
                    VTERM_KEY_HOME => "\x1bOH",
                    VTERM_KEY_END => "\x1bOF",
                    else => "",
                };
                if (seq.len > 0) {
                    _ = try pty.write(seq);
                    return;
                }
            }
            _ = try input_mod.sendKey(pty, key, mod, self.keyModeFlags());
        }
    }

    pub fn sendKeypad(self: *TerminalSession, key: input_mod.KeypadKey, mod: Modifier) !void {
        if (self.pty) |*pty| {
            _ = try input_mod.sendKeypad(pty, key, mod, self.app_keypad, self.keyModeFlags());
        }
    }

    pub fn appKeypadEnabled(self: *const TerminalSession) bool {
        return self.app_keypad;
    }

    pub fn sendChar(self: *TerminalSession, char: u32, mod: Modifier) !void {
        if (self.pty) |*pty| {
            _ = try input_mod.sendChar(pty, char, mod, self.keyModeFlags());
        }
    }

    pub fn reportMouseEvent(self: *TerminalSession, event: MouseEvent) !bool {
        if (self.pty == null) return false;
        const screen = self.activeScreen();
        if (self.pty) |*pty| {
            return self.input.reportMouseEvent(pty, event, screen.grid.rows, screen.grid.cols);
        }
        return false;
    }

    pub fn sendText(self: *TerminalSession, text: []const u8) !void {
        if (text.len == 0) return;
        if (self.pty) |*pty| {
            try input_mod.sendText(pty, text);
        }
    }

    pub fn resize(self: *TerminalSession, rows: u16, cols: u16) !void {
        const old_cols = self.primary.grid.cols;
        try self.primary.resize(rows, cols);
        try self.alt.resize(rows, cols);
        if (cols != old_cols) {
            try self.history.resizePreserve(cols, self.defaultCell());
        }
        const log = app_logger.logger("terminal.core");
        log.logf("terminal resize rows={d} cols={d} scrollback_cols={d}", .{ rows, cols, self.primary.grid.cols });
        log.logStdout("terminal resize rows={d} cols={d}", .{ rows, cols });
        if (self.isAltActive()) {
            const max_offset = self.history.maxScrollOffset(self.primary.grid.rows);
            if (self.history.saved_scrollback_offset > max_offset) {
                self.history.saved_scrollback_offset = max_offset;
            }
            self.history.scrollback_offset = 0;
        } else {
            self.setScrollOffset(self.history.scrollback_offset);
        }
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

    pub fn handleControl(self: *TerminalSession, byte: u8) void {
        const screen = self.activeScreen();
        switch (byte) {
            0x08 => { // BS
                if (screen.cursor.col > 0) screen.cursor.col -= 1;
                screen.wrap_next = false;
            },
            0x09 => { // TAB (every 8 columns)
                if (screen.grid.cols == 0) return;
                const max_col = @as(usize, screen.grid.cols - 1);
                const next = screen.tabstops.next(screen.cursor.col, max_col);
                screen.cursor.col = @min(next, max_col);
                screen.wrap_next = false;
            },
            0x0A => { // LF
                self.newline();
            },
            0x0D => { // CR
                screen.cursor.col = 0;
                screen.wrap_next = false;
            },
            0x0E => { // SO (Shift Out) -> G1
                self.parser.gl_charset = self.parser.g1_charset;
            },
            0x0F => { // SI (Shift In) -> G0
                self.parser.gl_charset = self.parser.g0_charset;
            },
            0x1B => { // ESC
                self.parser.esc_state = .esc;
                self.parser.stream.reset();
                self.parser.csi.reset();
                self.parser.osc_state = .idle;
                self.parser.apc_state = .idle;
                self.parser.dcs_state = .idle;
            },
            else => {},
        }
    }

    pub fn parseDcs(self: *TerminalSession, payload: []const u8) void {
        protocol_dcs_apc.parseDcs(self, payload);
    }

    pub fn parseApc(self: *TerminalSession, payload: []const u8) void {
        protocol_dcs_apc.parseApc(self, payload);
    }

    pub fn parseOsc(self: *TerminalSession, payload: []const u8, terminator: OscTerminator) void {
        protocol_osc.parseOsc(self, payload, terminator);
    }
    pub fn appendHyperlink(self: *TerminalSession, uri: []const u8) ?u32 {
        if (uri.len == 0) return 0;
        if (self.hyperlink_table.items.len >= max_hyperlinks) {
            for (self.hyperlink_table.items) |link| {
                self.allocator.free(link.uri);
            }
            self.hyperlink_table.clearRetainingCapacity();
        }
        const duped = self.allocator.dupe(u8, uri) catch return null;
        _ = self.hyperlink_table.append(self.allocator, .{ .uri = duped }) catch {
            self.allocator.free(duped);
            return null;
        };
        return @intCast(self.hyperlink_table.items.len);
    }

    pub fn parseKittyGraphics(self: *TerminalSession, payload: []const u8) void {
        kitty_mod.parseKittyGraphics(self, payload);
    }

    pub fn handleCsi(self: *TerminalSession, action: csi_mod.CsiAction) void {
        protocol_csi.handleCsi(self, action);
    }

    pub fn resetState(self: *TerminalSession) void {
        self.parser.reset();
        self.primary.resetState();
        self.alt.resetState();
        self.input.resetMouse();
        self.current_hyperlink_id = 0;
        self.app_keypad = false;
        self.primary.clear();
        self.alt.clear();
        kitty_mod.clearKittyImages(self);
    }

    pub fn eraseDisplay(self: *TerminalSession, mode: i32) void {
        const screen = self.activeScreen();
        const blank_cell = self.blankCellForScreen(screen);
        screen.eraseDisplay(mode, blank_cell);
    }

    pub fn eraseLine(self: *TerminalSession, mode: i32) void {
        const screen = self.activeScreen();
        const blank_cell = self.blankCellForScreen(screen);
        screen.eraseLine(mode, blank_cell);
    }

    pub fn insertChars(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = self.blankCellForScreen(screen);
        screen.insertChars(count, blank_cell);
    }

    pub fn deleteChars(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = self.blankCellForScreen(screen);
        screen.deleteChars(count, blank_cell);
    }

    pub fn eraseChars(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = self.blankCellForScreen(screen);
        screen.eraseChars(count, blank_cell);
    }

    pub fn insertLines(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = self.blankCellForScreen(screen);
        screen.insertLines(count, blank_cell);
    }

    pub fn deleteLines(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = self.blankCellForScreen(screen);
        screen.deleteLines(count, blank_cell);
    }

    fn isFullScrollRegion(self: *TerminalSession) bool {
        const screen = self.activeScreenConst();
        const rows = @as(usize, screen.grid.rows);
        if (rows == 0) return false;
        return screen.scroll_top == 0 and screen.scroll_bottom + 1 == rows;
    }

    fn pushScrollbackRow(self: *TerminalSession, row: usize) void {
        if (self.isAltActive()) return;
        const screen = &self.primary;
        const cols = @as(usize, screen.grid.cols);
        if (cols == 0 or screen.grid.rows == 0) return;
        if (row >= @as(usize, screen.grid.rows)) return;
        const row_start = row * cols;
        self.history.pushRow(screen.grid.cells.items[row_start .. row_start + cols]);
        self.kitty_primary.scrollback_total += 1;
        const log = app_logger.logger("terminal.core");
        log.logf("scrollback push row={d} total={d}", .{ row, self.history.scrollbackCount() });
        log.logStdout("scrollback push total={d}", .{self.history.scrollbackCount()});
    }

    pub fn scrollRegionUp(self: *TerminalSession, count: usize) void {
        const log = app_logger.logger("terminal.core");
        const screen = self.activeScreen();
        log.logf("scroll region up count={d} top={d} bottom={d}", .{ count, screen.scroll_top, screen.scroll_bottom });
        log.logStdout("scroll region up count={d}", .{count});
        const cols = @as(usize, screen.grid.cols);
        if (cols == 0 or screen.grid.rows == 0) return;
        const n = @min(count, screen.scroll_bottom - screen.scroll_top + 1);
        if (n == 0) return;
        const blank_cell = self.blankCellForScreen(screen);
        if (self.isFullScrollRegion()) {
            var row: usize = 0;
            while (row < n) : (row += 1) {
                self.pushScrollbackRow(screen.scroll_top + row);
            }
            kitty_mod.updateKittyPlacementsForScroll(self);
        }
        screen.scrollRegionUpBy(n, blank_cell);
        if (!self.isFullScrollRegion()) {
            kitty_mod.shiftKittyPlacementsUp(self, screen.scroll_top, screen.scroll_bottom, n);
        }
    }

    pub fn scrollRegionDown(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const cols = @as(usize, screen.grid.cols);
        if (cols == 0 or screen.grid.rows == 0) return;
        const n = @min(count, screen.scroll_bottom - screen.scroll_top + 1);
        if (n == 0) return;
        const blank_cell = self.blankCellForScreen(screen);
        screen.scrollRegionDownBy(n, blank_cell);
        kitty_mod.shiftKittyPlacementsDown(self, screen.scroll_top, screen.scroll_bottom, n);
    }

    fn applySgr(self: *TerminalSession, action: csi_mod.CsiAction) void {
        protocol_csi.applySgr(self, action);
    }

    pub fn paletteColor(self: *const TerminalSession, idx: u8) types.Color {
        return self.palette_current[idx];
    }

    pub fn handleCodepoint(self: *TerminalSession, codepoint: u32) void {
        if (codepoint == 0) return;
        if (codepoint > 0x10FFFF or (codepoint >= 0xD800 and codepoint <= 0xDFFF)) return;

        var cp = codepoint;
        if (self.parser.gl_charset == .dec_special) {
            cp = mapDecSpecial(codepoint);
        }

        const screen = self.activeScreen();
        const rows = @as(usize, screen.grid.rows);
        const cols = @as(usize, screen.grid.cols);
        if (rows == 0 or cols == 0) return;
        if (screen.cursor.row >= rows) return;
        if (screen.wrap_next) {
            self.newline();
            screen.wrap_next = false;
        }
        if (screen.cursor.col >= cols or screen.cursor.row >= rows) return;

        const row = screen.cursor.row;
        const col = screen.cursor.col;
        const idx = row * cols + col;
        if (idx >= screen.grid.cells.items.len) return;
        var attrs = screen.current_attrs;
        if (self.osc_hyperlink_active and self.current_hyperlink_id > 0) {
            attrs.link_id = self.current_hyperlink_id;
            attrs.underline = true;
        } else {
            attrs.link_id = 0;
        }
        screen.grid.cells.items[idx] = Cell{
            .codepoint = cp,
            .width = 1,
            .attrs = attrs,
        };

        if (screen.cursor.col + 1 >= cols) {
            screen.wrap_next = true;
        } else {
            screen.cursor.col += 1;
        }
        screen.grid.markDirtyRange(row, row, col, col);
    }

    pub fn handleAsciiSlice(self: *TerminalSession, bytes: []const u8) void {
        if (bytes.len == 0) return;
        const screen = self.activeScreen();
        const rows = @as(usize, screen.grid.rows);
        const cols = @as(usize, screen.grid.cols);
        if (rows == 0 or cols == 0) return;
        if (screen.cursor.row >= rows) return;

        var attrs = screen.current_attrs;
        if (self.osc_hyperlink_active and self.current_hyperlink_id > 0) {
            attrs.link_id = self.current_hyperlink_id;
            attrs.underline = true;
        } else {
            attrs.link_id = 0;
        }
        const use_dec_special = self.parser.gl_charset == .dec_special;

        var i: usize = 0;
        while (i < bytes.len) {
            if (screen.wrap_next) {
                self.newline();
                screen.wrap_next = false;
                if (screen.cursor.row >= rows) break;
            }
            if (screen.cursor.col >= cols or screen.cursor.row >= rows) break;

            const row = screen.cursor.row;
            const col = screen.cursor.col;
            const remaining_cols = cols - col;
            const run_len = @min(remaining_cols, bytes.len - i);
            const row_start = row * cols + col;
            if (use_dec_special) {
                var j: usize = 0;
                while (j < run_len) {
                    const b = bytes[i + j];
                    var same_len: usize = 1;
                    while (j + same_len < run_len and bytes[i + j + same_len] == b) : (same_len += 1) {}
                    const cp = mapDecSpecial(b);
                    const cell = Cell{
                        .codepoint = cp,
                        .width = 1,
                        .attrs = attrs,
                    };
                    if (same_len >= 8) {
                        @memset(screen.grid.cells.items[row_start + j .. row_start + j + same_len], cell);
                    } else {
                        var k: usize = 0;
                        while (k < same_len) : (k += 1) {
                            screen.grid.cells.items[row_start + j + k] = cell;
                        }
                    }
                    j += same_len;
                }
            } else {
                var j: usize = 0;
                while (j < run_len) {
                    const b = bytes[i + j];
                    var same_len: usize = 1;
                    while (j + same_len < run_len and bytes[i + j + same_len] == b) : (same_len += 1) {}
                    const cell = Cell{
                        .codepoint = b,
                        .width = 1,
                        .attrs = attrs,
                    };
                    if (same_len >= 8) {
                        @memset(screen.grid.cells.items[row_start + j .. row_start + j + same_len], cell);
                    } else {
                        var k: usize = 0;
                        while (k < same_len) : (k += 1) {
                            screen.grid.cells.items[row_start + j + k] = cell;
                        }
                    }
                    j += same_len;
                }
            }
            screen.grid.markDirtyRange(row, row, col, col + run_len - 1);

            if (run_len == remaining_cols) {
                screen.wrap_next = true;
            } else {
                screen.cursor.col += run_len;
            }
            i += run_len;
        }
    }

    fn mapDecSpecial(codepoint: u32) u32 {
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

    pub fn newline(self: *TerminalSession) void {
        const screen = self.activeScreen();
        if (screen.cursor.row + 1 < @as(usize, screen.grid.rows) and screen.cursor.row != screen.scroll_bottom) {
            screen.cursor.row += 1;
            screen.cursor.col = 0;
            screen.wrap_next = false;
            return;
        }
        if (screen.cursor.row == screen.scroll_bottom) {
            self.scrollRegionUp(1);
            screen.wrap_next = false;
            return;
        }
        self.scrollUp();
        screen.wrap_next = false;
    }

    fn scrollUp(self: *TerminalSession) void {
        const log = app_logger.logger("terminal.core");
        const screen = self.activeScreen();
        log.logf("scroll up rows={d} cols={d}", .{ screen.grid.rows, screen.grid.cols });
        log.logStdout("scroll up rows={d} cols={d}", .{ screen.grid.rows, screen.grid.cols });
        const cols = @as(usize, screen.grid.cols);
        const rows = @as(usize, screen.grid.rows);
        if (rows == 0 or cols == 0) return;

        if (self.isFullScrollRegion()) {
            self.pushScrollbackRow(0);
            kitty_mod.updateKittyPlacementsForScroll(self);
        }
        const blank_cell = self.blankCellForScreen(screen);
        screen.scrollUp(blank_cell);
        if (!self.isFullScrollRegion()) {
            kitty_mod.shiftKittyPlacementsUp(self, 0, rows - 1, 1);
        }
    }

    pub fn getCell(self: *TerminalSession, row: usize, col: usize) Cell {
        const screen = self.activeScreenConst();
        if (row >= @as(usize, screen.grid.rows) or col >= @as(usize, screen.grid.cols)) {
            return self.defaultCell();
        }
        const idx = row * @as(usize, screen.grid.cols) + col;
        return screen.grid.cells.items[idx];
    }

    pub fn getCursorPos(self: *TerminalSession) CursorPos {
        return self.activeScreenConst().cursor;
    }

    pub fn gridRows(self: *TerminalSession) usize {
        return @as(usize, self.activeScreenConst().grid.rows);
    }

    pub fn gridCols(self: *TerminalSession) usize {
        return @as(usize, self.activeScreenConst().grid.cols);
    }

    pub fn scrollbackCount(self: *TerminalSession) usize {
        if (self.isAltActive()) return 0;
        return self.history.scrollbackCount();
    }

    pub fn scrollbackRow(self: *TerminalSession, index: usize) ?[]const Cell {
        if (self.isAltActive()) return null;
        return self.history.scrollbackRow(index);
    }

    pub fn scrollOffset(self: *TerminalSession) usize {
        if (self.isAltActive()) return 0;
        return self.history.scrollOffset();
    }

    pub fn setScrollOffset(self: *TerminalSession, offset: usize) void {
        if (self.isAltActive()) {
            self.history.scrollback_offset = 0;
            return;
        }
        self.history.setScrollOffset(self.primary.grid.rows, offset);
        self.primary.grid.markDirtyAll();
        const log = app_logger.logger("terminal.core");
        const max_offset = self.history.maxScrollOffset(self.primary.grid.rows);
        log.logf("set scroll offset={d} max={d}", .{ self.history.scrollOffset(), max_offset });
        log.logStdout("set scroll offset={d} max={d}", .{ self.history.scrollOffset(), max_offset });
    }

    pub fn scrollBy(self: *TerminalSession, delta: isize) void {
        if (self.isAltActive()) return;
        if (delta == 0) return;
        self.history.scrollBy(self.primary.grid.rows, delta);
        self.primary.grid.markDirtyAll();
        const log = app_logger.logger("terminal.core");
        const max_offset = self.history.maxScrollOffset(self.primary.grid.rows);
        log.logf("scroll by delta={d} offset={d} max={d}", .{ delta, self.history.scrollOffset(), max_offset });
        log.logStdout("scroll by delta={d} offset={d} max={d}", .{ delta, self.history.scrollOffset(), max_offset });
    }

    fn keyModeStack(self: *TerminalSession) *KeyModeStack {
        return &self.activeScreen().key_mode;
    }

    fn keyModeFlags(self: *TerminalSession) u32 {
        return self.keyModeStack().current();
    }

    pub fn keyModePush(self: *TerminalSession, flags: u32) void {
        self.keyModeStack().push(flags);
    }

    pub fn keyModePop(self: *TerminalSession, count: usize) void {
        self.keyModeStack().pop(count);
    }

    pub fn keyModeModify(self: *TerminalSession, flags: u32, mode: u32) void {
        const stack = self.keyModeStack();
        const current = stack.current();
        const updated = switch (mode) {
            2 => current | flags,
            3 => current & ~flags,
            else => flags,
        };
        stack.setCurrent(updated);
    }

    pub fn keyModeQuery(self: *TerminalSession) void {
        const flags = self.keyModeFlags();
        if (self.pty) |*pty| {
            var buf: [32]u8 = undefined;
            const seq = std.fmt.bufPrint(&buf, "\x1b[?{d}u", .{flags}) catch return;
            _ = pty.write(seq) catch {};
        }
    }

    pub fn setCursorStyle(self: *TerminalSession, mode: i32) void {
        const screen = self.activeScreen();
        const style = switch (mode) {
            0, 1 => types.CursorStyle{ .shape = .block, .blink = true },
            2 => types.CursorStyle{ .shape = .block, .blink = false },
            3 => types.CursorStyle{ .shape = .underline, .blink = true },
            4 => types.CursorStyle{ .shape = .underline, .blink = false },
            5 => types.CursorStyle{ .shape = .bar, .blink = true },
            6 => types.CursorStyle{ .shape = .bar, .blink = false },
            else => screen.cursor_style,
        };
        screen.cursor_style = style;
    }

    pub fn saveCursor(self: *TerminalSession) void {
        const screen = self.activeScreen();
        const slot = &screen.saved_cursor;
        slot.active = true;
        slot.cursor = screen.cursor;
        slot.attrs = screen.current_attrs;
    }

    pub fn setKeypadMode(self: *TerminalSession, enabled: bool) void {
        self.app_keypad = enabled;
    }

    pub fn restoreCursor(self: *TerminalSession) void {
        const screen = self.activeScreen();
        const slot = &screen.saved_cursor;
        if (!slot.active) return;
        screen.cursor = slot.cursor;
        screen.current_attrs = slot.attrs;
    }

    fn clearGrid(self: *TerminalSession) void {
        const screen = self.activeScreen();
        screen.clear();
    }

    pub fn enterAltScreen(self: *TerminalSession, clear: bool, save_cursor: bool) void {
        if (self.isAltActive()) return;
        if (save_cursor) {
            self.saveCursor();
        }
        self.history.saveScrollOffset();
        self.clearSelection();
        self.active = .alt;
        kitty_mod.clearKittyImages(self);
        if (clear) {
            self.clearGrid();
            self.activeScreen().cursor = .{ .row = 0, .col = 0 };
        }
        self.activeScreen().grid.markDirtyAll();
    }

    pub fn exitAltScreen(self: *TerminalSession, restore_cursor: bool) void {
        if (!self.isAltActive()) return;
        kitty_mod.clearKittyImages(self);
        self.active = .primary;
        self.alt_exit_pending.store(true, .release);
        self.alt_exit_time_ms.store(std.time.milliTimestamp(), .release);
        self.history.restoreScrollOffset(self.primary.grid.rows);
        self.clearSelection();
        if (restore_cursor) {
            self.restoreCursor();
        }
        self.activeScreen().grid.markDirtyAll();
    }

    pub fn snapshot(self: *TerminalSession) TerminalSnapshot {
        const screen = self.activeScreenConst();
        const alt_active = self.isAltActive();
        const kitty = kitty_mod.kittyStateConst(self);
        return TerminalSnapshot{
            .rows = @as(usize, screen.grid.rows),
            .cols = @as(usize, screen.grid.cols),
            .cells = screen.grid.cells.items,
            .dirty_rows = screen.grid.dirty_rows.items,
            .dirty_cols_start = screen.grid.dirty_cols_start.items,
            .dirty_cols_end = screen.grid.dirty_cols_end.items,
            .cursor = screen.cursor,
            .cursor_style = screen.cursor_style,
            .cursor_visible = screen.cursor_visible,
            .dirty = screen.grid.dirty,
            .damage = screen.grid.damage,
            .alt_active = alt_active,
            .generation = self.output_generation.load(.acquire),
            .kitty_images = kitty.images.items,
            .kitty_placements = kitty.placements.items,
            .kitty_generation = kitty.generation,
        };
    }

    pub fn takeOscClipboard(self: *TerminalSession) ?[]const u8 {
        if (!self.osc_clipboard_pending) return null;
        self.osc_clipboard_pending = false;
        return self.osc_clipboard.items;
    }

    pub fn hyperlinkUri(self: *const TerminalSession, link_id: u32) ?[]const u8 {
        if (link_id == 0) return null;
        const idx = link_id - 1;
        if (idx >= self.hyperlink_table.items.len) return null;
        return self.hyperlink_table.items[idx].uri;
    }

    pub fn currentCwd(self: *const TerminalSession) []const u8 {
        return self.cwd;
    }

    pub fn clearDirty(self: *TerminalSession) void {
        self.activeScreen().grid.clearDirty();
    }

    pub fn clearSelection(self: *TerminalSession) void {
        self.history.clearSelection();
    }

    pub fn startSelection(self: *TerminalSession, row: usize, col: usize) void {
        if (self.isAltActive()) return;
        self.history.startSelection(row, col);
    }

    pub fn updateSelection(self: *TerminalSession, row: usize, col: usize) void {
        if (self.isAltActive()) return;
        self.history.updateSelection(row, col);
    }

    pub fn finishSelection(self: *TerminalSession) void {
        if (self.isAltActive()) return;
        self.history.finishSelection();
    }

    pub fn selectionState(self: *TerminalSession) ?TerminalSelection {
        if (self.isAltActive()) return null;
        return self.history.selectionState();
    }

    pub fn bracketedPasteEnabled(self: *TerminalSession) bool {
        return self.bracketed_paste;
    }

    pub fn mouseReportingEnabled(self: *TerminalSession) bool {
        return self.input.mouseTrackingActive();
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
        const screen = self.activeScreenConst();
        return switch (screen.grid.dirty) {
            .none => null,
            else => .{
                .start_row = screen.grid.damage.start_row,
                .end_row = screen.grid.damage.end_row,
                .start_col = screen.grid.damage.start_col,
                .end_col = screen.grid.damage.end_col,
            },
        };
    }

    pub fn markDirty(self: *TerminalSession) void {
        self.activeScreen().grid.markDirtyAll();
    }
};

fn readThreadMain(session: *TerminalSession) void {
    const max_read: usize = 64 * 1024;
    var buf: [max_read]u8 = undefined;

    while (session.read_thread_running.load(.acquire)) {
        if (session.pty) |*pty| {
            if (!pty.waitForData(50)) {
                continue;
            }
            var processed: usize = 0;
            const start_ms = std.time.milliTimestamp();
            const io_log = app_logger.logger("terminal.io");
            while (session.read_thread_running.load(.acquire)) {
                const n = pty.read(&buf) catch break;
                if (n == null or n.? == 0) break;
                processed += n.?;
                logCsiSequences(io_log, buf[0..n.?]);
                session.state_mutex.lock();
                session.parser.handleSlice(session, buf[0..n.?]);
                session.state_mutex.unlock();
                session.output_pending.store(true, .release);
                _ = session.output_generation.fetchAdd(1, .acq_rel);
            }
            if (processed > 0 and session.alt_exit_pending.swap(false, .acq_rel)) {
                const elapsed_ms = @as(f64, @floatFromInt(std.time.milliTimestamp() - start_ms));
                io_log.logf("alt_exit_io_ms={d:.2} bytes={d}", .{ elapsed_ms, processed });
            }
        } else {
            break;
        }
    }
}

pub const Hyperlink = snapshot_mod.Hyperlink;

pub const VTERM_KEY_NONE = types.VTERM_KEY_NONE;
pub const VTERM_KEY_ENTER = types.VTERM_KEY_ENTER;
pub const VTERM_KEY_TAB = types.VTERM_KEY_TAB;
pub const VTERM_KEY_BACKSPACE = types.VTERM_KEY_BACKSPACE;
pub const VTERM_KEY_ESCAPE = types.VTERM_KEY_ESCAPE;
pub const VTERM_KEY_UP = types.VTERM_KEY_UP;
pub const VTERM_KEY_DOWN = types.VTERM_KEY_DOWN;
pub const VTERM_KEY_LEFT = types.VTERM_KEY_LEFT;
pub const VTERM_KEY_RIGHT = types.VTERM_KEY_RIGHT;
pub const VTERM_KEY_INS = types.VTERM_KEY_INS;
pub const VTERM_KEY_DEL = types.VTERM_KEY_DEL;
pub const VTERM_KEY_HOME = types.VTERM_KEY_HOME;
pub const VTERM_KEY_END = types.VTERM_KEY_END;
pub const VTERM_KEY_PAGEUP = types.VTERM_KEY_PAGEUP;
pub const VTERM_KEY_PAGEDOWN = types.VTERM_KEY_PAGEDOWN;
pub const KeypadKey = input_mod.KeypadKey;

pub const VTERM_MOD_NONE = types.VTERM_MOD_NONE;
pub const VTERM_MOD_SHIFT = types.VTERM_MOD_SHIFT;
pub const VTERM_MOD_ALT = types.VTERM_MOD_ALT;
pub const VTERM_MOD_CTRL = types.VTERM_MOD_CTRL;

const default_scrollback_rows: usize = 1000;
const key_mode_disambiguate: u32 = 1;
const key_mode_report_all_keys: u32 = 8;
const mouse_button_left_mask: u8 = 1;
const mouse_button_middle_mask: u8 = 2;
const mouse_button_right_mask: u8 = 4;
const max_hyperlinks: usize = 2048;

pub const CursorPos = types.CursorPos;
pub const SelectionPos = types.SelectionPos;
pub const TerminalSelection = types.TerminalSelection;
pub const Cell = types.Cell;
pub const CellAttrs = types.CellAttrs;
pub const Color = types.Color;
pub const Key = types.Key;
pub const Modifier = types.Modifier;
pub const MouseButton = types.MouseButton;
pub const MouseEventKind = types.MouseEventKind;
pub const MouseEvent = types.MouseEvent;
