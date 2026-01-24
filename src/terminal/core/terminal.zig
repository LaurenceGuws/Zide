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
const flate = std.compress.flate;
const posix = std.posix;
const Pty = pty_mod.Pty;
const PtySize = pty_mod.PtySize;
const Screen = screen_mod.Screen;
const Dirty = screen_mod.Dirty;
const Damage = screen_mod.Damage;
const KeyModeStack = screen_mod.KeyModeStack;
const builtin = @import("builtin");
const OscTerminator = parser_mod.OscTerminator;
const rl = @cImport({
    @cInclude("raylib.h");
});

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

const KittyKV = struct {
    key: u8,
    value: u32,
};

const KittyPartial = struct {
    id: u32,
    width: u32,
    height: u32,
    format: KittyImageFormat,
    data: std.ArrayList(u8),
    expected_size: u32,
    received: u32,
    compression: u8,
    quiet: u8,
    size_initialized: bool,
};

const KittyControl = struct {
    action: u8 = 't',
    quiet: u8 = 0,
    delete_action: u8 = 'a',
    format: u32 = 32,
    medium: u8 = 'd',
    compression: u8 = 0,
    width: u32 = 0,
    height: u32 = 0,
    size: u32 = 0,
    offset: u32 = 0,
    image_id: ?u32 = null,
    image_number: ?u32 = null,
    placement_id: ?u32 = null,
    cols: u32 = 0,
    rows: u32 = 0,
    x: u32 = 0,
    y: u32 = 0,
    x_offset: u32 = 0,
    y_offset: u32 = 0,
    z: i32 = 0,
    cursor_movement: u8 = 0,
    virtual: u32 = 0,
    parent_id: ?u32 = null,
    child_id: ?u32 = null,
    parent_x: i32 = 0,
    parent_y: i32 = 0,
    more: bool = false,
};

const KittyBuildError = error{
    InvalidData,
    BadPng,
};

const kitty_max_bytes: usize = 320 * 1024 * 1024;
const kitty_parent_max_depth: u8 = 10;

const KittyState = struct {
    images: std.ArrayList(KittyImage),
    placements: std.ArrayList(KittyPlacement),
    partials: std.AutoHashMap(u32, KittyPartial),
    next_id: u32,
    generation: u64,
    total_bytes: usize,
    scrollback_total: u64,
};

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
    kitty_primary: KittyState,
    kitty_alt: KittyState,
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
                .partials = std.AutoHashMap(u32, KittyPartial).init(allocator),
                .next_id = 1,
                .generation = 0,
                .total_bytes = 0,
                .scrollback_total = 0,
            },
            .kitty_alt = .{
                .images = .empty,
                .placements = .empty,
                .partials = std.AutoHashMap(u32, KittyPartial).init(allocator),
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

    fn activeScreenConst(self: *const TerminalSession) *const Screen {
        return if (self.active == .alt) &self.alt else &self.primary;
    }

    fn inactiveScreen(self: *TerminalSession) *Screen {
        return if (self.active == .alt) &self.primary else &self.alt;
    }

    fn kittyState(self: *TerminalSession) *KittyState {
        return if (self.active == .alt) &self.kitty_alt else &self.kitty_primary;
    }

    fn kittyStateConst(self: *const TerminalSession) *const KittyState {
        return if (self.active == .alt) &self.kitty_alt else &self.kitty_primary;
    }

    fn deinitKittyState(self: *TerminalSession, state: *KittyState) void {
        for (state.images.items) |image| {
            self.allocator.free(image.data);
        }
        state.images.deinit(self.allocator);
        state.placements.deinit(self.allocator);
        var partial_it = state.partials.iterator();
        while (partial_it.next()) |entry| {
            entry.value_ptr.data.deinit(self.allocator);
        }
        state.partials.deinit();
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
        self.deinitKittyState(&self.kitty_primary);
        self.deinitKittyState(&self.kitty_alt);
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
        const log = app_logger.logger("terminal.kitty");
        var control = KittyControl{};
        const kitty = self.kittyState();
        var raw_kv = std.ArrayList(KittyKV).empty;
        defer raw_kv.deinit(self.allocator);
        const data = parseKittyControl(self.allocator, payload, &control, &raw_kv);
        if (!validateKittyControl(control)) {
            if (log.enabled_file or log.enabled_console) {
                log.logf("kitty invalid command a={c} data_len={d}", .{ control.action, data.len });
            }
            return;
        }
        if (control.action == 'd') {
            self.deleteKittyByAction(control);
            self.writeKittyResponse(control, resolveKittyImageId(control) orelse 0, true, "OK");
            return;
        }

        if (control.action == 'p') {
            const image_id = resolveKittyImageId(control) orelse return;
            if (self.placeKittyImage(image_id, control)) |err_msg| {
                self.writeKittyResponse(control, image_id, false, err_msg);
                return;
            }
            self.writeKittyResponse(control, image_id, true, "OK");
            return;
        }

        if (control.action == 'q') {
            const image_id = resolveKittyImageId(control) orelse {
                self.writeKittyResponse(control, 0, false, "EINVAL");
                return;
            };
            if (control.more or control.offset != 0) {
                self.writeKittyResponse(control, image_id, false, "EINVAL");
                return;
            }
            const chunk = self.loadKittyPayload(&control, data) orelse {
                self.writeKittyResponse(control, image_id, false, "EINVAL");
                return;
            };
            if (kittyExpectedDataBytes(control)) |expected| {
                if (chunk.len < expected) {
                    var message = std.ArrayList(u8).empty;
                    defer message.deinit(self.allocator);
                    _ = message.writer(self.allocator).print(
                        "ENODATA:Insufficient image data: {d} < {d}",
                        .{ chunk.len, expected },
                    ) catch {
                        self.allocator.free(chunk);
                        return;
                    };
                    self.allocator.free(chunk);
                    self.writeKittyResponse(control, image_id, false, message.items);
                    return;
                }
            }
            const image = self.buildKittyImage(image_id, control, chunk) catch |err| {
                const message = switch (err) {
                    error.BadPng => "EBADPNG",
                    else => "EINVAL",
                };
                self.writeKittyResponse(control, image_id, false, message);
                return;
            };
            self.allocator.free(image.data);
            self.writeKittyResponse(control, image_id, true, "OK");
            return;
        }
        if (control.action != 't' and control.action != 'T') return;

        const image_id = resolveKittyImageId(control) orelse blk: {
            const id = kitty.next_id;
            kitty.next_id += 1;
            break :blk id;
        };

        const decoded = self.loadKittyPayload(&control, data) orelse {
            if (log.enabled_file or log.enabled_console) {
                log.logf("kitty decode failed len={d}", .{data.len});
            }
            self.writeKittyResponse(control, image_id, false, "EINVAL");
            return;
        };
        const final_data = self.accumulateKittyData(image_id, &control, decoded) orelse return;

        if (kittyExpectedDataBytes(control)) |expected| {
            if (final_data.len < expected) {
                var message = std.ArrayList(u8).empty;
                defer message.deinit(self.allocator);
                _ = message.writer(self.allocator).print(
                    "ENODATA:Insufficient image data: {d} < {d}",
                    .{ final_data.len, expected },
                ) catch {
                    self.allocator.free(final_data);
                    return;
                };
                self.allocator.free(final_data);
                self.writeKittyResponse(control, image_id, false, message.items);
                return;
            }
        }

        const image = self.buildKittyImage(image_id, control, final_data) catch |err| {
            if (log.enabled_file or log.enabled_console) {
                log.logf("kitty build failed id={d} format={d} data_len={d}", .{ image_id, control.format, final_data.len });
            }
            const message = switch (err) {
                error.BadPng => "EBADPNG",
                else => "EINVAL",
            };
            self.writeKittyResponse(control, image_id, false, message);
            return;
        };
        self.storeKittyImage(image);
        if (control.action == 'T') {
            if (self.placeKittyImage(image_id, control)) |err_msg| {
                self.writeKittyResponse(control, image_id, false, err_msg);
                return;
            }
        }
        self.writeKittyResponse(control, image_id, true, "OK");
    }

    fn parseKittyControl(
        allocator: std.mem.Allocator,
        payload: []const u8,
        control: *KittyControl,
        raw_kv: *std.ArrayList(KittyKV),
    ) []const u8 {
        var i: usize = 0;
        while (i < payload.len) {
            if (payload[i] == ';') {
                i += 1;
                break;
            }
            const key = payload[i];
            i += 1;
            if (i >= payload.len or payload[i] != '=') {
                while (i < payload.len and payload[i] != ',' and payload[i] != ';') : (i += 1) {}
                if (i < payload.len and payload[i] == ',') i += 1;
                if (i < payload.len and payload[i] == ';') {
                    i += 1;
                    break;
                }
                continue;
            }
            i += 1;
            const start_idx = i;
            while (i < payload.len and payload[i] != ',' and payload[i] != ';') : (i += 1) {}
            const value_slice = payload[start_idx..i];
            const parsed_unsigned = parseKittyValue(value_slice);
            const parsed_signed = parseKittySigned(value_slice);
            if (parsed_unsigned != null or parsed_signed != null) {
                const handled = switch (key) {
                    'a' => blk: {
                        if (parsed_unsigned) |value| control.action = @intCast(value);
                        break :blk true;
                    },
                    'q' => blk: {
                        if (parsed_unsigned) |value| control.quiet = @intCast(value);
                        break :blk true;
                    },
                    'd' => blk: {
                        if (parsed_unsigned) |value| control.delete_action = @intCast(value);
                        break :blk true;
                    },
                    'f' => blk: {
                        if (parsed_unsigned) |value| control.format = value;
                        break :blk true;
                    },
                    't' => blk: {
                        if (parsed_unsigned) |value| control.medium = @intCast(value);
                        break :blk true;
                    },
                    'o' => blk: {
                        if (parsed_unsigned) |value| control.compression = @intCast(value);
                        break :blk true;
                    },
                    's' => blk: {
                        if (parsed_unsigned) |value| control.width = value;
                        break :blk true;
                    },
                    'v' => blk: {
                        if (parsed_unsigned) |value| control.height = value;
                        break :blk true;
                    },
                    'S' => blk: {
                        if (parsed_unsigned) |value| control.size = value;
                        break :blk true;
                    },
                    'O' => blk: {
                        if (parsed_unsigned) |value| control.offset = value;
                        break :blk true;
                    },
                    'i' => blk: {
                        if (parsed_unsigned) |value| control.image_id = value;
                        break :blk true;
                    },
                    'I' => blk: {
                        if (parsed_unsigned) |value| control.image_number = value;
                        break :blk true;
                    },
                    'p' => blk: {
                        if (parsed_unsigned) |value| control.placement_id = value;
                        break :blk true;
                    },
                    'c' => blk: {
                        if (parsed_unsigned) |value| control.cols = value;
                        break :blk true;
                    },
                    'r' => blk: {
                        if (parsed_unsigned) |value| control.rows = value;
                        break :blk true;
                    },
                    'x' => blk: {
                        if (parsed_unsigned) |value| control.x = value;
                        break :blk true;
                    },
                    'y' => blk: {
                        if (parsed_unsigned) |value| control.y = value;
                        break :blk true;
                    },
                    'w' => blk: {
                        if (parsed_unsigned) |value| control.width = value;
                        break :blk true;
                    },
                    'h' => blk: {
                        if (parsed_unsigned) |value| control.height = value;
                        break :blk true;
                    },
                    'X' => blk: {
                        if (parsed_unsigned) |value| control.x_offset = value;
                        break :blk true;
                    },
                    'Y' => blk: {
                        if (parsed_unsigned) |value| control.y_offset = value;
                        break :blk true;
                    },
                    'z' => blk: {
                        if (parsed_signed) |value| control.z = value;
                        break :blk true;
                    },
                    'C' => blk: {
                        if (parsed_unsigned) |value| control.cursor_movement = @intCast(value);
                        break :blk true;
                    },
                    'U' => blk: {
                        if (parsed_unsigned) |value| control.virtual = value;
                        break :blk true;
                    },
                    'P' => blk: {
                        if (parsed_unsigned) |value| control.parent_id = value;
                        break :blk true;
                    },
                    'Q' => blk: {
                        if (parsed_unsigned) |value| control.child_id = value;
                        break :blk true;
                    },
                    'H' => blk: {
                        if (parsed_signed) |value| control.parent_x = value;
                        break :blk true;
                    },
                    'V' => blk: {
                        if (parsed_signed) |value| control.parent_y = value;
                        break :blk true;
                    },
                    'm' => blk: {
                        if (parsed_unsigned) |value| control.more = value != 0;
                        break :blk true;
                    },
                    else => false,
                };
                if (!handled) {
                    if (parsed_unsigned) |value| {
                        _ = raw_kv.append(allocator, .{ .key = key, .value = value }) catch {};
                    }
                }
            }
            if (i < payload.len and payload[i] == ',') {
                i += 1;
                continue;
            }
            if (i < payload.len and payload[i] == ';') {
                i += 1;
                break;
            }
        }
        return payload[i..];
    }

    fn parseKittyValue(text: []const u8) ?u32 {
        if (text.len == 0) return null;
        if (text.len == 1 and (text[0] < '0' or text[0] > '9')) {
            return @intCast(text[0]);
        }
        return std.fmt.parseUnsigned(u32, text, 10) catch null;
    }

    fn parseKittySigned(text: []const u8) ?i32 {
        if (text.len == 0) return null;
        return std.fmt.parseInt(i32, text, 10) catch null;
    }

    fn resolveKittyImageId(control: KittyControl) ?u32 {
        if (control.image_id) |id| return id;
        if (control.image_number) |id| return id;
        return null;
    }

    fn validateKittyControl(control: KittyControl) bool {
        switch (control.action) {
            't', 'T', 'p', 'd', 'q' => {},
            else => return false,
        }

        if (control.quiet > 2) return false;
        if (control.image_id != null and control.image_number != null) return false;

        if (control.action == 't' or control.action == 'T') {
            if (control.format != 0 and kittyFormatFor(control.format) == null) return false;
            if (control.medium != 'd' and control.medium != 'f' and control.medium != 't' and control.medium != 's') return false;
            if (control.compression != 0 and control.compression != 'z') return false;
        }

        if (control.action == 'p' or control.action == 'T') {
            if (control.image_id == null and control.image_number == null) return false;
            if (control.virtual != 0 and (control.parent_id != null or control.child_id != null or control.parent_x != 0 or control.parent_y != 0)) {
                return false;
            }
            if ((control.parent_id != null) != (control.child_id != null)) return false;
        }

        return true;
    }

    fn decodeBase64(self: *TerminalSession, data: []const u8) ?[]u8 {
        if (data.len == 0) {
            return self.allocator.alloc(u8, 0) catch return null;
        }
        const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(data) catch return null;
        var decoded = std.ArrayList(u8).empty;
        errdefer decoded.deinit(self.allocator);
        decoded.resize(self.allocator, decoded_len) catch return null;
        _ = std.base64.standard.Decoder.decode(decoded.items, data) catch return null;
        return decoded.toOwnedSlice(self.allocator) catch null;
    }

    fn loadKittyPayload(self: *TerminalSession, control: *KittyControl, data: []const u8) ?[]u8 {
        if (control.medium == 'd') {
            return self.decodeBase64(data);
        }
        if (control.more) return null;
        if (control.offset != 0) return null;

        const path_bytes = self.decodeBase64(data) orelse return null;
        defer self.allocator.free(path_bytes);
        if (std.mem.indexOfScalar(u8, path_bytes, 0) != null) return null;
        const path = path_bytes;
        return switch (control.medium) {
            'f' => self.readKittyFile(path, control.size, false),
            't' => self.readKittyFile(path, control.size, true),
            's' => self.readKittySharedMemory(path, control.size),
            else => null,
        };
    }

    fn readKittyFile(self: *TerminalSession, path: []const u8, size: u32, is_temporary: bool) ?[]u8 {
        if (is_temporary) {
            if (!std.mem.startsWith(u8, path, "/tmp/") and !std.mem.startsWith(u8, path, "/var/tmp/")) return null;
            if (std.mem.indexOf(u8, path, "tty-graphics-protocol") == null) return null;
        }
        var file = if (std.fs.path.isAbsolute(path))
            std.fs.openFileAbsolute(path, .{})
        else
            std.fs.cwd().openFile(path, .{});
        if (file) |*f| {
            defer f.close();
            defer if (is_temporary) {
                if (std.fs.path.isAbsolute(path)) {
                    _ = std.fs.deleteFileAbsolute(path) catch {};
                } else {
                    _ = std.fs.cwd().deleteFile(path) catch {};
                }
            };
            const stat = f.stat() catch return null;
            const total: usize = @intCast(stat.size);
            const read_len: usize = if (size > 0) @min(@as(usize, size), total) else total;
            if (read_len > kitty_max_bytes) return null;
            const out = self.allocator.alloc(u8, read_len) catch return null;
            const n = f.readAll(out) catch {
                self.allocator.free(out);
                return null;
            };
            if (n < read_len) {
                const trimmed = self.allocator.alloc(u8, n) catch {
                    self.allocator.free(out);
                    return null;
                };
                std.mem.copyForwards(u8, trimmed, out[0..n]);
                self.allocator.free(out);
                return trimmed;
            }
            return out;
        } else |_| {
            return null;
        }
    }

    fn readKittySharedMemory(self: *TerminalSession, name: []const u8, size: u32) ?[]u8 {
        if (!builtin.link_libc) return null;
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const name_z = std.fmt.bufPrintZ(&buf, "{s}", .{name}) catch return null;
        const fd = std.c.shm_open(name_z, @as(c_int, @bitCast(std.c.O{ .ACCMODE = .RDONLY })), 0);
        if (fd < 0) return null;
        defer _ = std.c.close(fd);
        defer _ = std.c.shm_unlink(name_z);
        const stat = posix.fstat(fd) catch return null;
        if (stat.size <= 0) return null;
        const total: usize = @intCast(stat.size);
        const read_len: usize = if (size > 0) @min(@as(usize, size), total) else total;
        if (read_len > kitty_max_bytes) return null;
        const map = posix.mmap(
            null,
            read_len,
            std.c.PROT.READ,
            std.c.MAP{ .TYPE = .SHARED },
            fd,
            0,
        ) catch return null;
        defer posix.munmap(map);
        const out = self.allocator.alloc(u8, read_len) catch return null;
        std.mem.copyForwards(u8, out, map[0..read_len]);
        return out;
    }

    fn accumulateKittyData(self: *TerminalSession, image_id: u32, control: *KittyControl, decoded: []u8) ?[]u8 {
        const kitty = self.kittyState();
        var chunk = decoded;
        var compression = control.compression;
        if (kitty.partials.getEntry(image_id)) |entry| {
            if (control.quiet == 0) {
                control.quiet = entry.value_ptr.quiet;
            } else {
                entry.value_ptr.quiet = control.quiet;
            }
            if (compression == 0) {
                compression = entry.value_ptr.compression;
            }
        }
        if (compression == 'z') {
            const inflated = self.inflateKittyData(chunk, control.size) orelse {
                self.allocator.free(chunk);
                return null;
            };
            self.allocator.free(chunk);
            chunk = inflated;
        } else if (compression != 0) {
            self.allocator.free(chunk);
            return null;
        }

        if (control.more) {
            const entry = kitty.partials.getOrPut(image_id) catch return null;
            if (!entry.found_existing) {
                const format = kittyFormatFor(control.format) orelse {
                    self.allocator.free(chunk);
                    return null;
                };
                entry.value_ptr.* = KittyPartial{
                    .id = image_id,
                    .width = control.width,
                    .height = control.height,
                    .format = format,
                    .data = .empty,
                    .expected_size = control.size,
                    .received = 0,
                    .compression = compression,
                    .quiet = control.quiet,
                    .size_initialized = false,
                };
            } else {
                if (control.quiet == 0) {
                    control.quiet = entry.value_ptr.quiet;
                } else {
                    entry.value_ptr.quiet = control.quiet;
                }
                if (entry.value_ptr.width == 0) entry.value_ptr.width = control.width;
                if (entry.value_ptr.height == 0) entry.value_ptr.height = control.height;
                if (entry.value_ptr.expected_size == 0) entry.value_ptr.expected_size = control.size;
            }
            if (!self.applyKittyChunk(entry.value_ptr, control, chunk)) {
                self.allocator.free(chunk);
                entry.value_ptr.data.deinit(self.allocator);
                _ = kitty.partials.remove(image_id);
                return null;
            }
            self.allocator.free(chunk);
            return null;
        }

        if (kitty.partials.getEntry(image_id)) |entry| {
            if (!self.applyKittyChunk(entry.value_ptr, control, chunk)) {
                self.allocator.free(chunk);
                entry.value_ptr.data.deinit(self.allocator);
                _ = kitty.partials.remove(image_id);
                return null;
            }
            self.allocator.free(chunk);
            if (entry.value_ptr.expected_size > 0 and entry.value_ptr.received != entry.value_ptr.expected_size) {
                entry.value_ptr.data.deinit(self.allocator);
                _ = kitty.partials.remove(image_id);
                return null;
            }
            const combined = entry.value_ptr.data.toOwnedSlice(self.allocator) catch return null;
            if (control.width == 0) control.width = entry.value_ptr.width;
            if (control.height == 0) control.height = entry.value_ptr.height;
            if (control.format == 0) {
                control.format = switch (entry.value_ptr.format) {
                    .png => 100,
                    .rgba => 32,
                };
            }
            entry.value_ptr.data.clearRetainingCapacity();
            _ = kitty.partials.remove(image_id);
            return combined;
        }

        if (control.size > 0) {
            if (control.size > kitty_max_bytes) {
                self.allocator.free(chunk);
                return null;
            }
            if (control.offset > 0) {
                self.allocator.free(chunk);
                return null;
            }
            if (chunk.len != control.size) {
                self.allocator.free(chunk);
                return null;
            }
        }
        if (chunk.len > kitty_max_bytes) {
            self.allocator.free(chunk);
            return null;
        }
        return chunk;
    }

    fn applyKittyChunk(self: *TerminalSession, partial: *KittyPartial, control: *KittyControl, chunk: []const u8) bool {
        const expected_size = if (partial.expected_size > 0) partial.expected_size else control.size;
        if (expected_size > 0 and expected_size > kitty_max_bytes) return false;
        if (expected_size > 0) {
            if (!partial.size_initialized) {
                partial.data.resize(self.allocator, expected_size) catch return false;
                @memset(partial.data.items, 0);
                partial.size_initialized = true;
            }
            const offset = control.offset;
            if (offset > expected_size) return false;
            const end = offset + @as(u32, @intCast(chunk.len));
            if (end > expected_size) return false;
            std.mem.copyForwards(u8, partial.data.items[offset..end], chunk);
            partial.received = @max(partial.received, end);
            return true;
        }

        if (control.offset > 0) return false;
        if (partial.data.items.len + chunk.len > kitty_max_bytes) return false;
        _ = partial.data.appendSlice(self.allocator, chunk) catch return false;
        partial.received = @intCast(partial.data.items.len);
        return true;
    }

    fn inflateKittyData(self: *TerminalSession, compressed: []const u8, expected_size: u32) ?[]u8 {
        var stream = std.io.fixedBufferStream(compressed);
        var reader_buf: [8192]u8 = undefined;
        var adapter = stream.reader().adaptToNewApi(&reader_buf);
        var window: [flate.max_window_len]u8 = undefined;
        var decompressor = flate.Decompress.init(&adapter.new_interface, .zlib, &window);
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator);
        const limit: usize = if (expected_size > 0) @intCast(expected_size) else kitty_max_bytes;
        var buf: [8192]u8 = undefined;
        while (true) {
            const n = decompressor.reader.readSliceShort(&buf) catch return null;
            if (n == 0) break;
            if (out.items.len + n > limit) return null;
            _ = out.appendSlice(self.allocator, buf[0..n]) catch return null;
        }
        if (expected_size > 0 and out.items.len != expected_size) return null;
        return out.toOwnedSlice(self.allocator) catch null;
    }

    fn kittyFormatFor(value: u32) ?KittyImageFormat {
        return switch (value) {
            24, 32 => .rgba,
            100 => .png,
            else => null,
        };
    }

    fn kittyExpectedDataBytes(control: KittyControl) ?usize {
        const format = kittyFormatFor(control.format) orelse return null;
        if (format != .rgba) return null;
        if (control.width == 0 or control.height == 0) return null;
        const total_px: usize = @as(usize, control.width) * @as(usize, control.height);
        return if (control.format == 24) total_px * 3 else total_px * 4;
    }

    fn findKittyImageById(images: []const KittyImage, image_id: u32) ?KittyImage {
        for (images) |image| {
            if (image.id == image_id) return image;
        }
        return null;
    }

    fn buildKittyImage(self: *TerminalSession, image_id: u32, control: KittyControl, data: []u8) KittyBuildError!KittyImage {
        const format = kittyFormatFor(control.format) orelse return error.InvalidData;
        switch (format) {
            .png => {
                const decoded = self.decodeKittyPng(data) catch |err| {
                    self.allocator.free(data);
                    return err;
                };
                self.allocator.free(data);
                return .{
                    .id = image_id,
                    .width = decoded.width,
                    .height = decoded.height,
                    .format = .rgba,
                    .data = decoded.data,
                    .version = 0,
                };
            },
            .rgba => {
                if (control.width == 0 or control.height == 0) {
                    self.allocator.free(data);
                    return error.InvalidData;
                }
                const total_px: usize = @as(usize, control.width) * @as(usize, control.height);
                if (control.format == 24) {
                    const expected = total_px * 3;
                    if (data.len < expected) {
                        self.allocator.free(data);
                        return error.InvalidData;
                    }
                    const expanded = self.expandRgbToRgba(data[0..expected], control.width, control.height) orelse {
                        self.allocator.free(data);
                        return error.InvalidData;
                    };
                    self.allocator.free(data);
                    return .{
                        .id = image_id,
                        .width = control.width,
                        .height = control.height,
                        .format = .rgba,
                        .data = expanded,
                        .version = 0,
                    };
                }
                const expected = total_px * 4;
                if (data.len < expected) {
                    self.allocator.free(data);
                    return error.InvalidData;
                }
                if (data.len != expected) {
                    const trimmed = self.allocator.alloc(u8, expected) catch {
                        self.allocator.free(data);
                        return error.InvalidData;
                    };
                    std.mem.copyForwards(u8, trimmed, data[0..expected]);
                    self.allocator.free(data);
                    return .{
                        .id = image_id,
                        .width = control.width,
                        .height = control.height,
                        .format = .rgba,
                        .data = trimmed,
                        .version = 0,
                    };
                }
                return .{
                    .id = image_id,
                    .width = control.width,
                    .height = control.height,
                    .format = .rgba,
                    .data = data,
                    .version = 0,
                };
            },
        }
    }

    fn expandRgbToRgba(self: *TerminalSession, rgb: []const u8, width: u32, height: u32) ?[]u8 {
        const total_px: usize = @as(usize, width) * @as(usize, height);
        const out_len = total_px * 4;
        var out = self.allocator.alloc(u8, out_len) catch return null;
        var src_idx: usize = 0;
        var dst_idx: usize = 0;
        while (src_idx + 2 < rgb.len and dst_idx + 3 < out.len) : (src_idx += 3) {
            out[dst_idx] = rgb[src_idx];
            out[dst_idx + 1] = rgb[src_idx + 1];
            out[dst_idx + 2] = rgb[src_idx + 2];
            out[dst_idx + 3] = 0xFF;
            dst_idx += 4;
        }
        return out;
    }

    fn decodeKittyPng(self: *TerminalSession, data: []const u8) KittyBuildError!struct { data: []u8, width: u32, height: u32 } {
        if (data.len == 0) return error.BadPng;
        var img = rl.LoadImageFromMemory(".png", @ptrCast(@constCast(data.ptr)), @intCast(data.len));
        if (img.data == null or img.width <= 0 or img.height <= 0) {
            if (img.data != null) rl.UnloadImage(img);
            return error.BadPng;
        }
        if (img.format != rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8) {
            rl.ImageFormat(&img, rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8);
            if (img.data == null or img.format != rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8) {
                if (img.data != null) rl.UnloadImage(img);
                return error.BadPng;
            }
        }
        const width: u32 = @intCast(img.width);
        const height: u32 = @intCast(img.height);
        const total_px: usize = @as(usize, width) * @as(usize, height);
        const expected_len = total_px * 4;
        if (expected_len > kitty_max_bytes) {
            rl.UnloadImage(img);
            return error.BadPng;
        }
        const out = self.allocator.alloc(u8, expected_len) catch {
            rl.UnloadImage(img);
            return error.InvalidData;
        };
        const src = @as([*]const u8, @ptrCast(img.data))[0..expected_len];
        std.mem.copyForwards(u8, out, src);
        rl.UnloadImage(img);
        return .{ .data = out, .width = width, .height = height };
    }

    fn kittyImageHasPlacement(self: *TerminalSession, image_id: u32) bool {
        const kitty = self.kittyStateConst();
        for (kitty.placements.items) |placement| {
            if (placement.image_id == image_id) return true;
        }
        return false;
    }

    fn kittyVisibleTop(self: *TerminalSession) u64 {
        if (self.isAltActive()) return 0;
        const kitty = self.kittyStateConst();
        const count = self.history.scrollbackCount();
        if (kitty.scrollback_total < count) return 0;
        return kitty.scrollback_total - count;
    }

    fn updateKittyPlacementsForScroll(self: *TerminalSession) void {
        const kitty = self.kittyState();
        if (kitty.placements.items.len == 0) return;
        const screen = self.activeScreenConst();
        const rows = @as(u64, screen.grid.rows);
        const top = self.kittyVisibleTop();
        const max_row = top + rows;
        var changed = false;
        var idx: usize = 0;
        while (idx < kitty.placements.items.len) {
            const placement = &kitty.placements.items[idx];
            if (placement.anchor_row < top or placement.anchor_row >= max_row) {
                _ = kitty.placements.swapRemove(idx);
                changed = true;
                continue;
            }
            const new_row: u64 = placement.anchor_row - top;
            if (placement.row != @as(u16, @intCast(new_row))) {
                placement.row = @as(u16, @intCast(new_row));
                changed = true;
            }
            idx += 1;
        }
        if (changed) {
            kitty.generation += 1;
            self.activeScreen().grid.markDirtyAll();
        }
    }

    fn shiftKittyPlacementsUp(self: *TerminalSession, top: usize, bottom: usize, count: usize) void {
        const kitty = self.kittyState();
        if (count == 0 or kitty.placements.items.len == 0) return;
        var changed = false;
        var idx: usize = 0;
        while (idx < kitty.placements.items.len) {
            const placement = &kitty.placements.items[idx];
            if (placement.row < top or placement.row > bottom) {
                idx += 1;
                continue;
            }
            if (placement.row < top + count) {
                _ = kitty.placements.swapRemove(idx);
                changed = true;
                continue;
            }
            placement.row = @intCast(placement.row - count);
            if (placement.anchor_row >= count) {
                placement.anchor_row -= count;
            }
            changed = true;
            idx += 1;
        }
        if (changed) {
            kitty.generation += 1;
            self.activeScreen().grid.markDirtyAll();
        }
    }

    fn shiftKittyPlacementsDown(self: *TerminalSession, top: usize, bottom: usize, count: usize) void {
        const kitty = self.kittyState();
        if (count == 0 or kitty.placements.items.len == 0) return;
        var changed = false;
        var idx: usize = 0;
        while (idx < kitty.placements.items.len) {
            const placement = &kitty.placements.items[idx];
            if (placement.row < top or placement.row > bottom) {
                idx += 1;
                continue;
            }
            if (placement.row + count > bottom) {
                _ = kitty.placements.swapRemove(idx);
                changed = true;
                continue;
            }
            placement.row = @intCast(placement.row + count);
            placement.anchor_row += count;
            changed = true;
            idx += 1;
        }
        if (changed) {
            kitty.generation += 1;
            self.activeScreen().grid.markDirtyAll();
        }
    }

    fn ensureKittyCapacity(self: *TerminalSession, additional: usize) bool {
        const kitty = self.kittyState();
        if (additional == 0) return true;
        while (kitty.total_bytes + additional > kitty_max_bytes) {
            if (!self.evictKittyImage(true)) {
                if (!self.evictKittyImage(false)) return false;
            }
        }
        return true;
    }

    fn evictKittyImage(self: *TerminalSession, prefer_unplaced: bool) bool {
        const kitty = self.kittyState();
        if (kitty.images.items.len == 0) return false;
        var best_idx: ?usize = null;
        var best_version: u64 = std.math.maxInt(u64);
        for (kitty.images.items, 0..) |image, idx| {
            if (prefer_unplaced and self.kittyImageHasPlacement(image.id)) continue;
            if (image.version < best_version) {
                best_version = image.version;
                best_idx = idx;
            }
        }
        if (best_idx == null) return false;
        const image = kitty.images.items[best_idx.?];
        self.allocator.free(image.data);
        kitty.total_bytes -= image.data.len;
        _ = kitty.images.swapRemove(best_idx.?);
        var p: usize = 0;
        while (p < kitty.placements.items.len) {
            if (kitty.placements.items[p].image_id == image.id) {
                _ = kitty.placements.swapRemove(p);
            } else {
                p += 1;
            }
        }
        if (kitty.partials.getEntry(image.id)) |entry| {
            entry.value_ptr.data.deinit(self.allocator);
            _ = kitty.partials.remove(image.id);
        }
        kitty.generation += 1;
        self.activeScreen().grid.markDirtyAll();
        return true;
    }

    fn storeKittyImage(self: *TerminalSession, image: KittyImage) void {
        const log = app_logger.logger("terminal.kitty");
        const kitty = self.kittyState();
        kitty.generation += 1;
        const version = kitty.generation;
        var idx: usize = 0;
        while (idx < kitty.images.items.len) : (idx += 1) {
            if (kitty.images.items[idx].id == image.id) {
                const old_len = kitty.images.items[idx].data.len;
                if (image.data.len > kitty_max_bytes) {
                    self.allocator.free(image.data);
                    return;
                }
                const extra = if (image.data.len > old_len) image.data.len - old_len else 0;
                if (!self.ensureKittyCapacity(extra)) {
                    self.allocator.free(image.data);
                    return;
                }
                self.allocator.free(kitty.images.items[idx].data);
                kitty.total_bytes -= old_len;
                kitty.images.items[idx] = image;
                kitty.images.items[idx].version = version;
                kitty.total_bytes += image.data.len;
                self.activeScreen().grid.markDirtyAll();
                if (log.enabled_file or log.enabled_console) {
                    log.logf("kitty image updated id={d} format={s} bytes={d}", .{ image.id, @tagName(image.format), image.data.len });
                }
                return;
            }
        }
        if (image.data.len > kitty_max_bytes) {
            self.allocator.free(image.data);
            return;
        }
        if (!self.ensureKittyCapacity(image.data.len)) {
            self.allocator.free(image.data);
            return;
        }
        var stored = image;
        stored.version = version;
        _ = kitty.images.append(self.allocator, stored) catch {};
        kitty.total_bytes += stored.data.len;
        self.activeScreen().grid.markDirtyAll();
        if (log.enabled_file or log.enabled_console) {
            log.logf("kitty image stored id={d} format={s} bytes={d}", .{ stored.id, @tagName(stored.format), stored.data.len });
        }
    }

    fn placeKittyImage(self: *TerminalSession, image_id: u32, control: KittyControl) ?[]const u8 {
        const log = app_logger.logger("terminal.kitty");
        const kitty = self.kittyState();
        const screen = self.activeScreen();
        if (screen.grid.rows == 0 or screen.grid.cols == 0) return "EINVAL";
        if (findKittyImageById(kitty.images.items, image_id) == null) return "ENOENT";
        const base_row = @min(@as(u16, @intCast(screen.cursor.row)), screen.grid.rows - 1);
        const base_col = @min(@as(u16, @intCast(screen.cursor.col)), screen.grid.cols - 1);
        var row = base_row;
        var col = base_col;
        var parent_image_id: u32 = 0;
        var parent_placement_id: u32 = 0;
        if (control.parent_id != null or control.child_id != null) {
            const parent_id = control.parent_id orelse return "ENOPARENT";
            const parent_pid = control.child_id orelse return "ENOPARENT";
            const placement_id = control.placement_id orelse 0;
            if (placement_id != 0 and parent_id == image_id and parent_pid == placement_id) return "EINVAL";
            parent_image_id = parent_id;
            parent_placement_id = parent_pid;
            const parent = self.findKittyPlacement(parent_id, parent_pid) orelse return "ENOPARENT";
            if (placement_id != 0) {
                const chain_check = self.kittyValidateParentChain(parent, image_id, placement_id);
                if (chain_check) |err_msg| return err_msg;
            } else {
                if (self.kittyParentChainTooDeep(parent)) return "ETOODEEP";
            }
            const offset_x: i32 = control.parent_x;
            const offset_y: i32 = control.parent_y;
            const parent_row: i32 = @intCast(parent.row);
            const parent_col: i32 = @intCast(parent.col);
            const new_row = parent_row + offset_y;
            const new_col = parent_col + offset_x;
            if (new_row < 0 or new_col < 0) return "EINVAL";
            row = @as(u16, @intCast(new_row));
            col = @as(u16, @intCast(new_col));
            if (row >= screen.grid.rows or col >= screen.grid.cols) return "EINVAL";
        }
        const visible_top = self.kittyVisibleTop();
        const placement = KittyPlacement{
            .image_id = image_id,
            .placement_id = control.placement_id orelse 0,
            .row = row,
            .col = col,
            .cols = @intCast(control.cols),
            .rows = @intCast(control.rows),
            .z = control.z,
            .anchor_row = visible_top + @as(u64, row),
            .is_virtual = control.virtual != 0,
            .parent_image_id = parent_image_id,
            .parent_placement_id = parent_placement_id,
            .offset_x = control.parent_x,
            .offset_y = control.parent_y,
        };
        _ = kitty.placements.append(self.allocator, placement) catch {};
        self.activeScreen().grid.markDirtyAll();
        if (log.enabled_file or log.enabled_console) {
            log.logf("kitty placed id={d} row={d} col={d} cols={d} rows={d}", .{ image_id, row, col, placement.cols, placement.rows });
        }

        if (control.cursor_movement != 1) {
            const cols = self.effectiveKittyColumns(control, image_id);
            const rows = self.effectiveKittyRows(control, image_id);
            if (rows > 0) {
                var moved: u32 = 0;
                while (moved < rows) : (moved += 1) {
                    self.newline();
                }
                screen.cursor.col = @min(@as(usize, col) + cols, @as(usize, screen.grid.cols - 1));
            } else if (cols > 0) {
                screen.cursor.col = @min(@as(usize, col) + cols, @as(usize, screen.grid.cols - 1));
            }
            screen.wrap_next = false;
        }
        return null;
    }

    fn kittyValidateParentChain(self: *TerminalSession, parent: KittyPlacement, image_id: u32, placement_id: u32) ?[]const u8 {
        var current = parent;
        var depth: u8 = 1;
        while (true) {
            if (depth > kitty_parent_max_depth) return "ETOODEEP";
            if (current.parent_image_id == 0 or current.parent_placement_id == 0) break;
            if (current.parent_image_id == image_id and current.parent_placement_id == placement_id) return "ECYCLE";
            const next = self.findKittyPlacement(current.parent_image_id, current.parent_placement_id) orelse break;
            current = next;
            depth += 1;
        }
        return null;
    }

    fn kittyParentChainTooDeep(self: *TerminalSession, parent: KittyPlacement) bool {
        var current = parent;
        var depth: u8 = 1;
        while (true) {
            if (depth > kitty_parent_max_depth) return true;
            if (current.parent_image_id == 0 or current.parent_placement_id == 0) break;
            const next = self.findKittyPlacement(current.parent_image_id, current.parent_placement_id) orelse break;
            current = next;
            depth += 1;
        }
        return false;
    }

    fn findKittyPlacement(self: *TerminalSession, image_id: u32, placement_id: u32) ?KittyPlacement {
        const kitty = self.kittyStateConst();
        for (kitty.placements.items) |placement| {
            if (placement.image_id == image_id and placement.placement_id == placement_id) return placement;
        }
        return null;
    }

    fn effectiveKittyColumns(self: *TerminalSession, control: KittyControl, image_id: u32) u32 {
        if (control.cols > 0) return control.cols;
        const cell_w = @as(u32, self.cell_width);
        const width_px = if (control.width > 0) control.width else blk: {
            const kitty = self.kittyStateConst();
            const image = findKittyImageById(kitty.images.items, image_id) orelse break :blk 0;
            break :blk image.width;
        };
        if (cell_w == 0 or width_px == 0) return 0;
        return std.math.divCeil(u32, width_px, cell_w) catch 0;
    }

    fn effectiveKittyRows(self: *TerminalSession, control: KittyControl, image_id: u32) u32 {
        if (control.rows > 0) return control.rows;
        const cell_h = @as(u32, self.cell_height);
        const height_px = if (control.height > 0) control.height else blk: {
            const kitty = self.kittyStateConst();
            const image = findKittyImageById(kitty.images.items, image_id) orelse break :blk 0;
            break :blk image.height;
        };
        if (cell_h == 0 or height_px == 0) return 0;
        if (height_px <= cell_h) return 0;
        return std.math.divCeil(u32, height_px, cell_h) catch 0;
    }

    fn deleteKittyImages(self: *TerminalSession, image_id: ?u32) void {
        const kitty = self.kittyState();
        if (image_id) |id| {
            var i: usize = 0;
            while (i < kitty.images.items.len) {
                if (kitty.images.items[i].id == id) {
                    kitty.total_bytes -= kitty.images.items[i].data.len;
                    self.allocator.free(kitty.images.items[i].data);
                    _ = kitty.images.swapRemove(i);
                } else {
                    i += 1;
                }
            }
            var p: usize = 0;
            while (p < kitty.placements.items.len) {
                if (kitty.placements.items[p].image_id == id or kitty.placements.items[p].parent_image_id == id) {
                    _ = kitty.placements.swapRemove(p);
                } else {
                    p += 1;
                }
            }
            if (kitty.partials.getEntry(id)) |entry| {
                entry.value_ptr.data.deinit(self.allocator);
                _ = kitty.partials.remove(id);
            }
        } else {
            self.clearKittyImages();
        }
        self.activeScreen().grid.markDirtyAll();
    }

    fn deleteKittyPlacements(
        self: *TerminalSession,
        ctx: anytype,
        predicate: *const fn (@TypeOf(ctx), *TerminalSession, KittyPlacement) bool,
    ) void {
        const kitty = self.kittyState();
        var idx: usize = 0;
        var changed = false;
        while (idx < kitty.placements.items.len) {
            if (predicate(ctx, self, kitty.placements.items[idx])) {
                _ = kitty.placements.swapRemove(idx);
                changed = true;
                continue;
            }
            idx += 1;
        }
        if (changed) {
            kitty.generation += 1;
            self.activeScreen().grid.markDirtyAll();
        }
    }

    fn deleteKittyByAction(self: *TerminalSession, control: KittyControl) void {
        const action = if (control.delete_action == 0) 'a' else control.delete_action;
        const id = resolveKittyImageId(control);
        const placement_id = control.placement_id orelse 0;
        const screen = self.activeScreenConst();
        const cursor_row = @as(u16, @intCast(screen.cursor.row));
        const cursor_col = @as(u16, @intCast(screen.cursor.col));
        const x = if (control.x > 0) control.x - 1 else 0;
        const y = if (control.y > 0) control.y - 1 else 0;
        const range_start = if (control.x > 0) control.x else 1;
        const range_end = if (control.y > 0) control.y else 0;
        const z = control.z;
        switch (action) {
            'a' => {
                const Ctx = struct {
                    fn pred(_: @This(), _: *TerminalSession, _: KittyPlacement) bool {
                        return true;
                    }
                };
                self.deleteKittyPlacements(Ctx{}, Ctx.pred);
            },
            'A' => {
                self.clearKittyImages();
            },
            'i', 'I' => {
                if (id == null) return;
                const target = id.?;
                if (action == 'I') {
                    self.deleteKittyImages(target);
                    return;
                }
                const Ctx = struct {
                    target_id: u32,
                    target_pid: u32,
                    fn pred(ctx: @This(), _: *TerminalSession, placement: KittyPlacement) bool {
                        if (placement.image_id != ctx.target_id) return false;
                        if (ctx.target_pid != 0 and placement.placement_id != ctx.target_pid) return false;
                        return true;
                    }
                };
                self.deleteKittyPlacements(Ctx{ .target_id = target, .target_pid = placement_id }, Ctx.pred);
            },
            'n', 'N' => {
                if (id == null) return;
                const target = id.?;
                if (action == 'N') {
                    self.deleteKittyImages(target);
                    return;
                }
                const Ctx = struct {
                    target_id: u32,
                    target_pid: u32,
                    fn pred(ctx: @This(), _: *TerminalSession, placement: KittyPlacement) bool {
                        if (placement.image_id != ctx.target_id) return false;
                        if (ctx.target_pid != 0 and placement.placement_id != ctx.target_pid) return false;
                        return true;
                    }
                };
                self.deleteKittyPlacements(Ctx{ .target_id = target, .target_pid = placement_id }, Ctx.pred);
            },
            'c', 'C' => {
                const delete_images = action == 'C';
                const Ctx = struct {
                    row: u16,
                    col: u16,
                    delete_images: bool,
                    fn pred(ctx: @This(), session: *TerminalSession, placement: KittyPlacement) bool {
                        if (!kittyPlacementIntersects(placement, ctx.row, ctx.col)) return false;
                        if (ctx.delete_images) {
                            session.deleteKittyImages(placement.image_id);
                            return false;
                        }
                        return true;
                    }
                };
                self.deleteKittyPlacements(Ctx{ .row = cursor_row, .col = cursor_col, .delete_images = delete_images }, Ctx.pred);
            },
            'p', 'P' => {
                const row = @as(u16, @intCast(y));
                const col = @as(u16, @intCast(x));
                const delete_images = action == 'P';
                const Ctx = struct {
                    row: u16,
                    col: u16,
                    delete_images: bool,
                    fn pred(ctx: @This(), session: *TerminalSession, placement: KittyPlacement) bool {
                        if (!kittyPlacementIntersects(placement, ctx.row, ctx.col)) return false;
                        if (ctx.delete_images) {
                            session.deleteKittyImages(placement.image_id);
                            return false;
                        }
                        return true;
                    }
                };
                self.deleteKittyPlacements(Ctx{ .row = row, .col = col, .delete_images = delete_images }, Ctx.pred);
            },
            'z', 'Z' => {
                const delete_images = action == 'Z';
                const Ctx = struct {
                    z: i32,
                    delete_images: bool,
                    fn pred(ctx: @This(), session: *TerminalSession, placement: KittyPlacement) bool {
                        if (placement.z != ctx.z) return false;
                        if (ctx.delete_images) {
                            session.deleteKittyImages(placement.image_id);
                            return false;
                        }
                        return true;
                    }
                };
                self.deleteKittyPlacements(Ctx{ .z = z, .delete_images = delete_images }, Ctx.pred);
            },
            'r', 'R' => {
                const end = if (range_end > 0) range_end else range_start;
                if (range_start > end) return;
                const delete_images = action == 'R';
                const Ctx = struct {
                    start_id: u32,
                    end_id: u32,
                    delete_images: bool,
                    fn pred(ctx: @This(), session: *TerminalSession, placement: KittyPlacement) bool {
                        if (placement.image_id < ctx.start_id or placement.image_id > ctx.end_id) return false;
                        if (ctx.delete_images) {
                            session.deleteKittyImages(placement.image_id);
                            return false;
                        }
                        return true;
                    }
                };
                self.deleteKittyPlacements(Ctx{ .start_id = range_start, .end_id = end, .delete_images = delete_images }, Ctx.pred);
            },
            'x', 'X' => {
                const col = @as(u16, @intCast(x));
                const delete_images = action == 'X';
                const Ctx = struct {
                    col: u16,
                    delete_images: bool,
                    fn pred(ctx: @This(), session: *TerminalSession, placement: KittyPlacement) bool {
                        if (!kittyPlacementIntersects(placement, placement.row, ctx.col)) return false;
                        if (ctx.delete_images) {
                            session.deleteKittyImages(placement.image_id);
                            return false;
                        }
                        return true;
                    }
                };
                self.deleteKittyPlacements(Ctx{ .col = col, .delete_images = delete_images }, Ctx.pred);
            },
            'y', 'Y' => {
                const row = @as(u16, @intCast(y));
                const delete_images = action == 'Y';
                const Ctx = struct {
                    row: u16,
                    delete_images: bool,
                    fn pred(ctx: @This(), session: *TerminalSession, placement: KittyPlacement) bool {
                        if (!kittyPlacementIntersects(placement, ctx.row, placement.col)) return false;
                        if (ctx.delete_images) {
                            session.deleteKittyImages(placement.image_id);
                            return false;
                        }
                        return true;
                    }
                };
                self.deleteKittyPlacements(Ctx{ .row = row, .delete_images = delete_images }, Ctx.pred);
            },
            else => {},
        }
    }

    fn kittyPlacementIntersects(placement: KittyPlacement, row: u16, col: u16) bool {
        const width = if (placement.cols > 0) placement.cols else 1;
        const height = if (placement.rows > 0) placement.rows else 1;
        const end_row: u16 = placement.row + height - 1;
        const end_col: u16 = placement.col + width - 1;
        return row >= placement.row and row <= end_row and col >= placement.col and col <= end_col;
    }

    fn writeKittyResponse(self: *TerminalSession, control: KittyControl, image_id: u32, ok: bool, message: []const u8) void {
        if (control.quiet == 2) return;
        if (control.quiet == 1 and ok) return;
        if (self.pty == null) return;
        var seq = std.ArrayList(u8).empty;
        defer seq.deinit(self.allocator);
        _ = seq.appendSlice(self.allocator, "\x1b_G") catch return;
        var needs_comma = false;
        if (image_id != 0) {
            _ = seq.writer(self.allocator).print("i={d}", .{image_id}) catch return;
            needs_comma = true;
        }
        if (control.image_number) |num| {
            if (needs_comma) _ = seq.append(self.allocator, ',') catch return;
            _ = seq.writer(self.allocator).print("I={d}", .{num}) catch return;
            needs_comma = true;
        }
        if (control.placement_id) |pid| {
            if (needs_comma) _ = seq.append(self.allocator, ',') catch return;
            _ = seq.writer(self.allocator).print("p={d}", .{pid}) catch return;
        }
        _ = seq.append(self.allocator, ';') catch return;
        _ = seq.appendSlice(self.allocator, message) catch return;
        _ = seq.appendSlice(self.allocator, "\x1b\\") catch return;
        if (self.pty) |*pty| {
            _ = pty.write(seq.items) catch {};
        }
    }

    fn clearKittyImages(self: *TerminalSession) void {
        const kitty = self.kittyState();
        for (kitty.images.items) |image| {
            self.allocator.free(image.data);
        }
        kitty.images.clearRetainingCapacity();
        kitty.placements.clearRetainingCapacity();
        var partial_it = kitty.partials.iterator();
        while (partial_it.next()) |entry| {
            entry.value_ptr.data.deinit(self.allocator);
        }
        kitty.partials.clearRetainingCapacity();
        kitty.total_bytes = 0;
        kitty.generation += 1;
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
        self.clearKittyImages();
    }

    pub fn eraseDisplay(self: *TerminalSession, mode: i32) void {
        const screen = self.activeScreen();
        const rows = @as(usize, screen.grid.rows);
        const cols = @as(usize, screen.grid.cols);
        if (rows == 0 or cols == 0) return;
        const blank_cell = self.blankCellForScreen(screen);
        const row = screen.cursor.row;
        const col = screen.cursor.col;
        if (row >= rows or col >= cols) return;

        switch (mode) {
            0 => { // cursor to end
                const start_idx = row * cols + col;
                for (screen.grid.cells.items[start_idx..]) |*cell| cell.* = blank_cell;
                screen.grid.markDirtyRange(row, row, col, cols - 1);
                if (row + 1 < rows) {
                    screen.grid.markDirtyRange(row + 1, rows - 1, 0, cols - 1);
                }
            },
            1 => { // start to cursor
                const end = row * cols + col + 1;
                for (screen.grid.cells.items[0..end]) |*cell| cell.* = blank_cell;
                if (row > 0) {
                    screen.grid.markDirtyRange(0, row - 1, 0, cols - 1);
                }
                screen.grid.markDirtyRange(row, row, 0, col);
            },
            2 => { // all
                for (screen.grid.cells.items) |*cell| cell.* = blank_cell;
                screen.grid.markDirtyAll();
            },
            else => {},
        }
    }

    pub fn eraseLine(self: *TerminalSession, mode: i32) void {
        const screen = self.activeScreen();
        const cols = @as(usize, screen.grid.cols);
        if (cols == 0 or screen.grid.rows == 0) return;
        const blank_cell = self.blankCellForScreen(screen);
        if (screen.cursor.row >= @as(usize, screen.grid.rows)) return;
        const row_start = screen.cursor.row * cols;
        const col = screen.cursor.col;
        if (col >= cols) return;
        switch (mode) {
            0 => { // cursor to end of line
                for (screen.grid.cells.items[row_start + col .. row_start + cols]) |*cell| cell.* = blank_cell;
                screen.grid.markDirtyRange(screen.cursor.row, screen.cursor.row, col, cols - 1);
            },
            1 => { // start to cursor
                for (screen.grid.cells.items[row_start .. row_start + col + 1]) |*cell| cell.* = blank_cell;
                screen.grid.markDirtyRange(screen.cursor.row, screen.cursor.row, 0, col);
            },
            2 => { // entire line
                for (screen.grid.cells.items[row_start .. row_start + cols]) |*cell| cell.* = blank_cell;
                screen.grid.markDirtyRange(screen.cursor.row, screen.cursor.row, 0, cols - 1);
            },
            else => {},
        }
    }

    pub fn insertChars(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const cols = @as(usize, screen.grid.cols);
        if (cols == 0) return;
        if (screen.cursor.row >= @as(usize, screen.grid.rows)) return;
        const col = screen.cursor.col;
        if (col >= cols) return;
        const n = @min(count, cols - col);
        const row_start = screen.cursor.row * cols;
        const line = screen.grid.cells.items[row_start .. row_start + cols];
        if (cols - col > n) {
            std.mem.copyBackwards(Cell, line[col + n ..], line[col .. cols - n]);
        }
        const blank_cell = self.blankCellForScreen(screen);
        for (line[col .. col + n]) |*cell| cell.* = blank_cell;
        screen.grid.markDirtyRange(screen.cursor.row, screen.cursor.row, col, cols - 1);
    }

    pub fn deleteChars(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const cols = @as(usize, screen.grid.cols);
        if (cols == 0) return;
        if (screen.cursor.row >= @as(usize, screen.grid.rows)) return;
        const col = screen.cursor.col;
        if (col >= cols) return;
        const n = @min(count, cols - col);
        const row_start = screen.cursor.row * cols;
        const line = screen.grid.cells.items[row_start .. row_start + cols];
        if (cols - col > n) {
            std.mem.copyForwards(Cell, line[col .. cols - n], line[col + n ..]);
        }
        const blank_cell = self.blankCellForScreen(screen);
        for (line[cols - n .. cols]) |*cell| cell.* = blank_cell;
        screen.grid.markDirtyRange(screen.cursor.row, screen.cursor.row, col, cols - 1);
    }

    pub fn eraseChars(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const cols = @as(usize, screen.grid.cols);
        if (cols == 0) return;
        if (screen.cursor.row >= @as(usize, screen.grid.rows)) return;
        const col = screen.cursor.col;
        if (col >= cols) return;
        const n = @min(count, cols - col);
        const row_start = screen.cursor.row * cols;
        const line = screen.grid.cells.items[row_start .. row_start + cols];
        const blank_cell = self.blankCellForScreen(screen);
        for (line[col .. col + n]) |*cell| cell.* = blank_cell;
        screen.grid.markDirtyRange(screen.cursor.row, screen.cursor.row, col, col + n - 1);
    }

    pub fn insertLines(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const cols = @as(usize, screen.grid.cols);
        const rows = @as(usize, screen.grid.rows);
        if (rows == 0 or cols == 0) return;
        if (screen.cursor.row < screen.scroll_top or screen.cursor.row > screen.scroll_bottom) return;
        const n = @min(count, screen.scroll_bottom - screen.cursor.row + 1);
        const blank_cell = self.blankCellForScreen(screen);
        const region_end = (screen.scroll_bottom + 1) * cols;
        const insert_at = screen.cursor.row * cols;
        const move_len = region_end - insert_at - n * cols;
        if (move_len > 0) {
            std.mem.copyBackwards(Cell, screen.grid.cells.items[insert_at + n * cols .. region_end], screen.grid.cells.items[insert_at .. insert_at + move_len]);
        }
        for (screen.grid.cells.items[insert_at .. insert_at + n * cols]) |*cell| cell.* = blank_cell;
        screen.grid.markDirtyRange(screen.cursor.row, screen.scroll_bottom, 0, cols - 1);
    }

    pub fn deleteLines(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const cols = @as(usize, screen.grid.cols);
        const rows = @as(usize, screen.grid.rows);
        if (rows == 0 or cols == 0) return;
        if (screen.cursor.row < screen.scroll_top or screen.cursor.row > screen.scroll_bottom) return;
        const n = @min(count, screen.scroll_bottom - screen.cursor.row + 1);
        const blank_cell = self.blankCellForScreen(screen);
        const region_end = (screen.scroll_bottom + 1) * cols;
        const delete_at = screen.cursor.row * cols;
        const move_len = region_end - delete_at - n * cols;
        if (move_len > 0) {
            std.mem.copyForwards(Cell, screen.grid.cells.items[delete_at .. delete_at + move_len], screen.grid.cells.items[delete_at + n * cols .. region_end]);
        }
        for (screen.grid.cells.items[region_end - n * cols .. region_end]) |*cell| cell.* = blank_cell;
        screen.grid.markDirtyRange(screen.cursor.row, screen.scroll_bottom, 0, cols - 1);
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
        const region_start = screen.scroll_top * cols;
        const region_end = (screen.scroll_bottom + 1) * cols;
        if (self.isFullScrollRegion()) {
            var row: usize = 0;
            while (row < n) : (row += 1) {
                self.pushScrollbackRow(screen.scroll_top + row);
            }
            self.updateKittyPlacementsForScroll();
        }
        const move_len = region_end - region_start - n * cols;
        if (move_len > 0) {
            std.mem.copyForwards(Cell, screen.grid.cells.items[region_start .. region_start + move_len], screen.grid.cells.items[region_start + n * cols .. region_end]);
        }
        for (screen.grid.cells.items[region_end - n * cols .. region_end]) |*cell| cell.* = blank_cell;
        screen.grid.markDirtyRange(screen.scroll_top, screen.scroll_bottom, 0, cols - 1);
        if (!self.isFullScrollRegion()) {
            self.shiftKittyPlacementsUp(screen.scroll_top, screen.scroll_bottom, n);
        }
    }

    pub fn scrollRegionDown(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const cols = @as(usize, screen.grid.cols);
        if (cols == 0 or screen.grid.rows == 0) return;
        const n = @min(count, screen.scroll_bottom - screen.scroll_top + 1);
        if (n == 0) return;
        const blank_cell = self.blankCellForScreen(screen);
        const region_start = screen.scroll_top * cols;
        const region_end = (screen.scroll_bottom + 1) * cols;
        const move_len = region_end - region_start - n * cols;
        if (move_len > 0) {
            std.mem.copyBackwards(Cell, screen.grid.cells.items[region_start + n * cols .. region_end], screen.grid.cells.items[region_start .. region_start + move_len]);
        }
        for (screen.grid.cells.items[region_start .. region_start + n * cols]) |*cell| cell.* = blank_cell;
        screen.grid.markDirtyRange(screen.scroll_top, screen.scroll_bottom, 0, cols - 1);
        self.shiftKittyPlacementsDown(screen.scroll_top, screen.scroll_bottom, n);
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

    fn newline(self: *TerminalSession) void {
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
            self.updateKittyPlacementsForScroll();
        }
        const total = rows * cols;
        const row_bytes = cols * @sizeOf(Cell);
        const src = @as([*]u8, @ptrCast(screen.grid.cells.items.ptr));
        std.mem.copyForwards(u8, src[0 .. total * @sizeOf(Cell) - row_bytes], src[row_bytes .. total * @sizeOf(Cell)]);

        const row_start = (rows - 1) * cols;
        const blank_cell = self.blankCellForScreen(screen);
        for (screen.grid.cells.items[row_start .. row_start + cols]) |*cell| {
            cell.* = blank_cell;
        }
        screen.cursor.row = rows - 1;
        screen.cursor.col = 0;
        screen.grid.markDirtyAll();
        if (!self.isFullScrollRegion()) {
            self.shiftKittyPlacementsUp(0, rows - 1, 1);
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
        self.clearKittyImages();
        if (clear) {
            self.clearGrid();
            self.activeScreen().cursor = .{ .row = 0, .col = 0 };
        }
        self.activeScreen().grid.markDirtyAll();
    }

    pub fn exitAltScreen(self: *TerminalSession, restore_cursor: bool) void {
        if (!self.isAltActive()) return;
        self.clearKittyImages();
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
        const kitty = self.kittyStateConst();
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
