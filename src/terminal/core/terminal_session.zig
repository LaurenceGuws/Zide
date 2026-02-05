const std = @import("std");
const pty_mod = @import("../io/pty.zig");
const input_mod = @import("../input/input.zig");
const history_mod = @import("../model/history.zig");
const csi_mod = @import("../parser/csi.zig");
const parser_mod = @import("../parser/parser.zig");
const protocol_csi = @import("../protocol/csi.zig");
const screen_mod = @import("../model/screen.zig");
const render_cache_mod = @import("render_cache.zig");
const snapshot_mod = @import("snapshot.zig");
const types = @import("../model/types.zig");
const app_logger = @import("../../app_logger.zig");
const kitty_mod = @import("../kitty/graphics.zig");
const semantic_prompt_mod = @import("semantic_prompt.zig");
const palette_mod = @import("palette.zig");
const pty_io = @import("pty_io.zig");
const view_cache = @import("view_cache.zig");
const resize_reflow = @import("resize_reflow.zig");
const selection_mod = @import("selection.zig");
const scrolling_mod = @import("scrolling.zig");
const control_handlers = @import("control_handlers.zig");
const parser_hooks = @import("parser_hooks.zig");
const input_modes = @import("input_modes.zig");
const hyperlink_table = @import("hyperlink_table.zig");
const Pty = pty_mod.Pty;
const PtySize = pty_mod.PtySize;
const Screen = screen_mod.Screen;
const Dirty = screen_mod.Dirty;
const Damage = screen_mod.Damage;
const builtin = @import("builtin");
const OscTerminator = parser_mod.OscTerminator;
const Charset = parser_mod.Charset;
const CharsetTarget = parser_mod.CharsetTarget;

const dynamic_color_count: usize = 10;

const SemanticPromptKind = semantic_prompt_mod.SemanticPromptKind;
const SemanticPromptState = semantic_prompt_mod.SemanticPromptState;

const SavedCharsetState = struct {
    active: bool = false,
    g0: Charset = .ascii,
    g1: Charset = .ascii,
    gl: Charset = .ascii,
    target: CharsetTarget = .g0,
};

pub const KittyImageFormat = snapshot_mod.KittyImageFormat;
pub const KittyImage = snapshot_mod.KittyImage;
pub const KittyPlacement = snapshot_mod.KittyPlacement;

const RenderCache = render_cache_mod.RenderCache;

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
    self.activeScreen().setCursor(row, col);
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
    input_snapshot: InputSnapshot,
    pty_write_mutex: std.Thread.Mutex,
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
    parse_thread: ?std.Thread,
    parse_thread_running: std.atomic.Value(bool),
    state_mutex: std.Thread.Mutex,
    io_mutex: std.Thread.Mutex,
    io_wait_cond: std.Thread.Condition,
    io_buffer: std.ArrayList(u8),
    io_read_offset: usize,
    sync_updates_active: bool,
    column_mode_132: bool,
    output_pending: std.atomic.Value(bool),
    output_generation: std.atomic.Value(u64),
    input_pressure: std.atomic.Value(bool),
    alt_exit_pending: std.atomic.Value(bool),
    alt_exit_time_ms: std.atomic.Value(i64),
    last_parse_log_ms: i64,
    render_caches: [2]RenderCache,
    render_cache_index: std.atomic.Value(u8),
    view_cache_pending: std.atomic.Value(bool),
    view_cache_request_offset: std.atomic.Value(u64),
    alt_last_active: bool,
    clear_generation: std.atomic.Value(u64),
    force_full_damage: std.atomic.Value(bool),
    saved_charset: SavedCharsetState,
    child_exited: std.atomic.Value(bool),
    child_exit_code: std.atomic.Value(i32),

    pub const InitOptions = struct {
        scrollback_rows: ?usize = null,
        cursor_style: ?types.CursorStyle = null,
    };

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*TerminalSession {
        return initWithOptions(allocator, rows, cols, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, rows: u16, cols: u16, options: InitOptions) !*TerminalSession {
        const session = try allocator.create(TerminalSession);
        const default_attrs = types.defaultCell().attrs;
        var primary = try Screen.init(allocator, rows, cols, default_attrs);
        var alt = try Screen.init(allocator, rows, cols, default_attrs);
        if (options.cursor_style) |cursor_style| {
            primary.cursor_style = cursor_style;
            alt.cursor_style = cursor_style;
        }
        const scrollback_rows = options.scrollback_rows orelse default_scrollback_rows;
        const history = try history_mod.TerminalHistory.init(allocator, scrollback_rows, cols);
        const log = app_logger.logger("terminal.core");
        log.logf("terminal init rows={d} cols={d} scrollback_max={d}", .{ rows, cols, scrollback_rows });
        log.logStdout("terminal init rows={d} cols={d}", .{ rows, cols });
        const palette_default = palette_mod.buildDefaultPalette();
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
            .input_snapshot = InputSnapshot.init(),
            .pty_write_mutex = .{},
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
                .loading_image_id = null,
                .generation = 0,
                .total_bytes = 0,
                .scrollback_total = 0,
            },
            .kitty_alt = .{
                .images = .empty,
                .placements = .empty,
                .partials = std.AutoHashMap(u32, kitty_mod.KittyPartial).init(allocator),
                .next_id = 1,
                .loading_image_id = null,
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
            .parse_thread = null,
            .parse_thread_running = std.atomic.Value(bool).init(false),
            .state_mutex = .{},
            .io_mutex = .{},
            .io_wait_cond = .{},
            .io_buffer = .empty,
            .io_read_offset = 0,
            .sync_updates_active = false,
            .column_mode_132 = false,
            .output_pending = std.atomic.Value(bool).init(false),
            .output_generation = std.atomic.Value(u64).init(0),
            .input_pressure = std.atomic.Value(bool).init(false),
            .alt_exit_pending = std.atomic.Value(bool).init(false),
            .alt_exit_time_ms = std.atomic.Value(i64).init(-1),
            .last_parse_log_ms = 0,
            .render_caches = .{ RenderCache.init(), RenderCache.init() },
            .render_cache_index = std.atomic.Value(u8).init(0),
            .view_cache_pending = std.atomic.Value(bool).init(false),
            .view_cache_request_offset = std.atomic.Value(u64).init(0),
            .alt_last_active = false,
            .clear_generation = std.atomic.Value(u64).init(0),
            .force_full_damage = std.atomic.Value(bool).init(false),
            .saved_charset = .{},
            .child_exited = std.atomic.Value(bool).init(false),
            .child_exit_code = std.atomic.Value(i32).init(-1),
        };
        session.updateInputSnapshot();
        return session;
    }

    pub fn activeScreen(self: *TerminalSession) *Screen {
        return if (self.active == .alt) &self.alt else &self.primary;
    }

    pub fn activeScreenConst(self: *const TerminalSession) *const Screen {
        return if (self.active == .alt) &self.alt else &self.primary;
    }

    pub fn setInputPressure(self: *TerminalSession, value: bool) void {
        self.input_pressure.store(value, .release);
    }

    pub fn updateInputSnapshot(self: *TerminalSession) void {
        self.input_snapshot.app_cursor_keys.store(self.app_cursor_keys, .release);
        self.input_snapshot.app_keypad.store(self.app_keypad, .release);
        self.input_snapshot.key_mode_flags.store(self.keyModeFlags(), .release);
        self.input_snapshot.mouse_mode_x10.store(self.input.mouse_mode_x10, .release);
        self.input_snapshot.mouse_mode_button.store(self.input.mouse_mode_button, .release);
        self.input_snapshot.mouse_mode_any.store(self.input.mouse_mode_any, .release);
        self.input_snapshot.mouse_mode_sgr.store(self.input.mouse_mode_sgr, .release);
    }

    fn hashRow(cells: []const Cell) u64 {
        var h: u64 = 1469598103934665603;
        const prime: u64 = 1099511628211;
        for (cells) |cell| {
            h = (h ^ @as(u64, cell.codepoint)) *% prime;
            h = (h ^ @as(u64, cell.width)) *% prime;
            const attrs = cell.attrs;
            h = (h ^ @as(u64, attrs.fg.r)) *% prime;
            h = (h ^ @as(u64, attrs.fg.g)) *% prime;
            h = (h ^ @as(u64, attrs.fg.b)) *% prime;
            h = (h ^ @as(u64, attrs.fg.a)) *% prime;
            h = (h ^ @as(u64, attrs.bg.r)) *% prime;
            h = (h ^ @as(u64, attrs.bg.g)) *% prime;
            h = (h ^ @as(u64, attrs.bg.b)) *% prime;
            h = (h ^ @as(u64, attrs.bg.a)) *% prime;
            h = (h ^ @as(u64, attrs.underline_color.r)) *% prime;
            h = (h ^ @as(u64, attrs.underline_color.g)) *% prime;
            h = (h ^ @as(u64, attrs.underline_color.b)) *% prime;
            h = (h ^ @as(u64, attrs.underline_color.a)) *% prime;
            h = (h ^ @as(u64, @intFromBool(attrs.bold))) *% prime;
            h = (h ^ @as(u64, @intFromBool(attrs.blink))) *% prime;
            h = (h ^ @as(u64, @intFromBool(attrs.blink_fast))) *% prime;
            h = (h ^ @as(u64, @intFromBool(attrs.reverse))) *% prime;
            h = (h ^ @as(u64, @intFromBool(attrs.underline))) *% prime;
            h = (h ^ @as(u64, attrs.link_id)) *% prime;
        }
        return h;
    }

    fn updateViewCacheNoLock(self: *TerminalSession, generation: u64, scroll_offset: usize) void {
        view_cache.updateViewCacheNoLock(self, generation, scroll_offset);
    }

    fn inactiveScreen(self: *TerminalSession) *Screen {
        return if (self.active == .alt) &self.primary else &self.alt;
    }

    fn isAltActive(self: *const TerminalSession) bool {
        return self.active == .alt;
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
        if (self.parse_thread) |thread| {
            self.parse_thread_running.store(false, .release);
            self.io_wait_cond.signal();
            thread.join();
            self.parse_thread = null;
        }
        if (self.pty) |*pty| {
            pty.deinit();
        }
        self.render_caches[0].deinit(self.allocator);
        self.render_caches[1].deinit(self.allocator);
        self.io_buffer.deinit(self.allocator);
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
        try pty_io.start(self, shell);
    }

    pub fn poll(self: *TerminalSession) !void {
        self.maybeUpdateChildExit();
        return pty_io.poll(self);
    }

    pub fn childExitCode(self: *TerminalSession) ?i32 {
        if (!self.child_exited.load(.acquire)) return null;
        return self.child_exit_code.load(.acquire);
    }

    fn maybeUpdateChildExit(self: *TerminalSession) void {
        if (self.child_exited.load(.acquire)) return;
        if (self.pty) |*pty| {
            if (pty.pollExit() catch null) |code| {
                self.child_exit_code.store(code, .release);
                self.child_exited.store(true, .release);

                const log = app_logger.logger("terminal.pty");
                if (log.enabled_file or log.enabled_console) {
                    log.logf("pty child exited code={d}", .{code});
                }
            }
        }
    }

    pub fn hasData(self: *TerminalSession) bool {
        if (self.read_thread != null) {
            if (self.parse_thread != null) {
                return self.output_pending.load(.acquire);
            }
            if (self.output_pending.load(.acquire)) return true;
            var pending = false;
            self.io_mutex.lock();
            if (self.io_buffer.items.len > self.io_read_offset) {
                pending = true;
            }
            self.io_mutex.unlock();
            return pending;
        }
        if (self.pty) |*pty| {
            return pty.hasData();
        }
        return false;
    }

    pub fn lock(self: *TerminalSession) void {
        self.state_mutex.lock();
    }

    pub fn tryLock(self: *TerminalSession) bool {
        return self.state_mutex.tryLock();
    }

    pub fn unlock(self: *TerminalSession) void {
        self.state_mutex.unlock();
    }

    pub fn currentGeneration(self: *TerminalSession) u64 {
        return self.output_generation.load(.acquire);
    }

    pub fn sendKey(self: *TerminalSession, key: Key, mod: Modifier) !void {
        try self.sendKeyAction(key, mod, input_mod.KeyAction.press);
    }

    pub fn sendKeyAction(self: *TerminalSession, key: Key, mod: Modifier, action: input_mod.KeyAction) !void {
        const log = app_logger.logger("terminal.input");
        const input_snapshot = self.input_snapshot;
        const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
        const app_cursor = input_snapshot.app_cursor_keys.load(.acquire);
        if (log.enabled_file or log.enabled_console) {
            log.logf("sendKey key={s} code={d} mod=0x{x} action={s} app_cursor={any} key_mode=0x{x}", .{
                keyName(key),
                key,
                mod,
                @tagName(action),
                app_cursor,
                key_mode_flags,
            });
        }
        if (self.pty) |*pty| {
            self.pty_write_mutex.lock();
            defer self.pty_write_mutex.unlock();
            if (key_mode_flags == 0 and app_cursor and mod == types.VTERM_MOD_NONE and action == .press) {
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
            _ = try input_mod.sendKeyAction(pty, key, mod, key_mode_flags, action);
        }
    }

    pub fn sendKeypad(self: *TerminalSession, key: input_mod.KeypadKey, mod: Modifier) !void {
        try self.sendKeypadAction(key, mod, input_mod.KeyAction.press);
    }

    pub fn sendKeypadAction(self: *TerminalSession, key: input_mod.KeypadKey, mod: Modifier, action: input_mod.KeyAction) !void {
        const log = app_logger.logger("terminal.input");
        const input_snapshot = self.input_snapshot;
        const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
        const app_keypad = input_snapshot.app_keypad.load(.acquire);
        if (log.enabled_file or log.enabled_console) {
            log.logf("sendKeypad key={s} mod=0x{x} action={s} app_keypad={any} key_mode=0x{x}", .{
                keypadKeyName(key),
                mod,
                @tagName(action),
                app_keypad,
                key_mode_flags,
            });
        }
        if (self.pty) |*pty| {
            self.pty_write_mutex.lock();
            defer self.pty_write_mutex.unlock();
            if (action == .press) {
                _ = try input_mod.sendKeypad(pty, key, mod, app_keypad, key_mode_flags);
            }
        }
    }

    pub fn appKeypadEnabled(self: *const TerminalSession) bool {
        return input_modes.appKeypadEnabled(self);
    }

    pub fn sendChar(self: *TerminalSession, char: u32, mod: Modifier) !void {
        try self.sendCharAction(char, mod, input_mod.KeyAction.press);
    }

    pub fn sendCharAction(self: *TerminalSession, char: u32, mod: Modifier, action: input_mod.KeyAction) !void {
        const log = app_logger.logger("terminal.input");
        const input_snapshot = self.input_snapshot;
        const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
        if (log.enabled_file or log.enabled_console) {
            log.logf("sendChar cp={d} mod=0x{x} action={s} key_mode=0x{x}", .{
                char,
                mod,
                @tagName(action),
                key_mode_flags,
            });
        }
        if (self.pty) |*pty| {
            self.pty_write_mutex.lock();
            defer self.pty_write_mutex.unlock();
            _ = try input_mod.sendCharAction(pty, char, mod, key_mode_flags, action);
        }
    }

    pub fn reportMouseEvent(self: *TerminalSession, event: MouseEvent) !bool {
        if (self.pty == null) return false;
        const screen = self.activeScreen();
        if (self.pty) |*pty| {
            self.pty_write_mutex.lock();
            defer self.pty_write_mutex.unlock();
            return self.input.reportMouseEvent(pty, event, screen.grid.rows, screen.grid.cols);
        }
        return false;
    }

    pub fn sendText(self: *TerminalSession, text: []const u8) !void {
        if (text.len == 0) return;
        const log = app_logger.logger("terminal.input");
        if (log.enabled_file or log.enabled_console) {
            log.logf("sendText len={d}", .{text.len});
        }
        if (self.pty) |*pty| {
            self.pty_write_mutex.lock();
            defer self.pty_write_mutex.unlock();
            try input_mod.sendText(pty, text);
        }
    }

    pub fn resize(self: *TerminalSession, rows: u16, cols: u16) !void {
        try resize_reflow.resize(self, rows, cols);
    }

    pub fn setColumnMode132(self: *TerminalSession, enabled: bool) void {
        if (self.column_mode_132 == enabled) return;
        self.column_mode_132 = enabled;
        if (!enabled) return;
        self.primary.clear();
        self.alt.clear();
        self.primary.setCursor(0, 0);
        self.alt.setCursor(0, 0);
        _ = self.clear_generation.fetchAdd(1, .acq_rel);
        self.force_full_damage.store(true, .release);
    }

    pub fn setCellSize(self: *TerminalSession, cell_width: u16, cell_height: u16) void {
        self.cell_width = cell_width;
        self.cell_height = cell_height;
    }

    pub fn handleControl(self: *TerminalSession, byte: u8) void {
        control_handlers.handleControl(self, byte);
    }

    pub fn parseDcs(self: *TerminalSession, payload: []const u8) void {
        parser_hooks.parseDcs(self, payload);
    }

    pub fn parseApc(self: *TerminalSession, payload: []const u8) void {
        parser_hooks.parseApc(self, payload);
    }

    pub fn parseOsc(self: *TerminalSession, payload: []const u8, terminator: OscTerminator) void {
        parser_hooks.parseOsc(self, payload, terminator);
    }
    pub fn appendHyperlink(self: *TerminalSession, uri: []const u8) ?u32 {
        return hyperlink_table.appendHyperlink(self, uri, max_hyperlinks);
    }

    pub fn parseKittyGraphics(self: *TerminalSession, payload: []const u8) void {
        parser_hooks.parseKittyGraphics(self, payload);
    }

    pub fn handleCsi(self: *TerminalSession, action: csi_mod.CsiAction) void {
        parser_hooks.handleCsi(self, action);
    }

    pub fn resetState(self: *TerminalSession) void {
        self.parser.reset();
        self.saved_charset = .{};
        self.primary.resetState();
        self.alt.resetState();
        self.input.resetMouse();
        self.current_hyperlink_id = 0;
        self.app_keypad = false;
        self.primary.clear();
        self.alt.clear();
        kitty_mod.clearKittyImages(self);
        _ = self.clear_generation.fetchAdd(1, .acq_rel);
    }

    pub fn reverseIndex(self: *TerminalSession) void {
        control_handlers.reverseIndex(self);
    }

    pub fn eraseDisplay(self: *TerminalSession, mode: i32) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.eraseDisplay(mode, blank_cell);
        self.force_full_damage.store(true, .release);
        if (mode == 2 or mode == 3) {
            self.clearSelection();
            _ = self.clear_generation.fetchAdd(1, .acq_rel);
        }
    }

    pub fn eraseLine(self: *TerminalSession, mode: i32) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.eraseLine(mode, blank_cell);
        self.force_full_damage.store(true, .release);
    }

    pub fn insertChars(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.insertChars(count, blank_cell);
    }

    pub fn deleteChars(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.deleteChars(count, blank_cell);
    }

    pub fn eraseChars(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.eraseChars(count, blank_cell);
    }

    pub fn insertLines(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.insertLines(count, blank_cell);
    }

    pub fn deleteLines(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.deleteLines(count, blank_cell);
    }

    pub fn scrollRegionUp(self: *TerminalSession, count: usize) void {
        scrolling_mod.scrollRegionUp(self, count);
    }

    pub fn scrollRegionDown(self: *TerminalSession, count: usize) void {
        scrolling_mod.scrollRegionDown(self, count);
    }

    fn applySgr(self: *TerminalSession, action: csi_mod.CsiAction) void {
        protocol_csi.applySgr(self, action);
    }

    pub fn paletteColor(self: *const TerminalSession, idx: u8) types.Color {
        return self.palette_current[idx];
    }

    pub fn handleCodepoint(self: *TerminalSession, codepoint: u32) void {
        parser_hooks.handleCodepoint(self, codepoint);
    }

    pub fn handleAsciiSlice(self: *TerminalSession, bytes: []const u8) void {
        parser_hooks.handleAsciiSlice(self, bytes);
    }

    pub fn newline(self: *TerminalSession) void {
        control_handlers.newline(self);
    }

    pub fn wrapNewline(self: *TerminalSession) void {
        control_handlers.wrapNewline(self);
    }

    fn scrollUp(self: *TerminalSession) void {
        scrolling_mod.scrollUp(self);
    }

    pub fn getCell(self: *TerminalSession, row: usize, col: usize) Cell {
        const screen = self.activeScreenConst();
        return screen.cellAtOr(row, col, self.primary.defaultCell());
    }

    pub fn getCursorPos(self: *TerminalSession) CursorPos {
        return self.activeScreenConst().cursorPos();
    }

    pub fn gridRows(self: *TerminalSession) usize {
        return self.activeScreenConst().rowCount();
    }

    pub fn gridCols(self: *TerminalSession) usize {
        return self.activeScreenConst().colCount();
    }

    pub fn scrollbackCount(self: *TerminalSession) usize {
        if (self.isAltActive()) return 0;
        self.history.ensureViewCache(self.primary.grid.cols, self.primary.defaultCell());
        return self.history.scrollbackCount();
    }

    pub fn scrollbackRow(self: *TerminalSession, index: usize) ?[]const Cell {
        if (self.isAltActive()) return null;
        self.history.ensureViewCache(self.primary.grid.cols, self.primary.defaultCell());
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
        self.history.ensureViewCache(self.primary.grid.cols, self.primary.defaultCell());
        self.history.setScrollOffset(self.primary.grid.rows, offset);
        self.primary.markDirtyAll();
        self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
        self.view_cache_pending.store(true, .release);
        self.io_wait_cond.signal();
        self.updateViewCacheForScroll();
        const log = app_logger.logger("terminal.core");
        const max_offset = self.history.maxScrollOffset(self.primary.grid.rows);
        log.logf("set scroll offset={d} max={d}", .{ self.history.scrollOffset(), max_offset });
        log.logStdout("set scroll offset={d} max={d}", .{ self.history.scrollOffset(), max_offset });
    }

    pub fn scrollBy(self: *TerminalSession, delta: isize) void {
        if (self.isAltActive()) return;
        if (delta == 0) return;
        self.history.ensureViewCache(self.primary.grid.cols, self.primary.defaultCell());
        self.history.scrollBy(self.primary.grid.rows, delta);
        self.primary.markDirtyAll();
        self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
        self.view_cache_pending.store(true, .release);
        self.io_wait_cond.signal();
        self.updateViewCacheForScroll();
        const log = app_logger.logger("terminal.core");
        const max_offset = self.history.maxScrollOffset(self.primary.grid.rows);
        log.logf("scroll by delta={d} offset={d} max={d}", .{ delta, self.history.scrollOffset(), max_offset });
        log.logStdout("scroll by delta={d} offset={d} max={d}", .{ delta, self.history.scrollOffset(), max_offset });
    }

    pub fn updateViewCacheForScroll(self: *TerminalSession) void {
        view_cache.updateViewCacheForScroll(self);
    }

    pub fn updateViewCacheForScrollLocked(self: *TerminalSession) void {
        view_cache.updateViewCacheForScrollLocked(self);
    }

    fn keyModeFlags(self: *TerminalSession) u32 {
        return input_modes.keyModeFlags(self);
    }

    pub fn keyModeFlagsValue(self: *TerminalSession) u32 {
        return self.keyModeFlags();
    }

    pub fn keyModePush(self: *TerminalSession, flags: u32) void {
        input_modes.keyModePush(self, flags);
    }

    pub fn keyModePop(self: *TerminalSession, count: usize) void {
        input_modes.keyModePop(self, count);
    }

    pub fn keyModeModify(self: *TerminalSession, flags: u32, mode: u32) void {
        input_modes.keyModeModify(self, flags, mode);
    }

    pub fn keyModeQuery(self: *TerminalSession) void {
        input_modes.keyModeQuery(self);
    }

    pub fn setCursorStyle(self: *TerminalSession, mode: i32) void {
        self.activeScreen().setCursorStyle(mode);
    }

    pub fn saveCursor(self: *TerminalSession) void {
        self.activeScreen().saveCursor();
        self.saved_charset = .{
            .active = true,
            .g0 = self.parser.g0_charset,
            .g1 = self.parser.g1_charset,
            .gl = self.parser.gl_charset,
            .target = self.parser.charset_target,
        };
    }

    pub fn setKeypadMode(self: *TerminalSession, enabled: bool) void {
        input_modes.setKeypadMode(self, enabled);
    }

    pub fn restoreCursor(self: *TerminalSession) void {
        self.activeScreen().restoreCursor();
        if (!self.saved_charset.active) return;
        self.parser.g0_charset = self.saved_charset.g0;
        self.parser.g1_charset = self.saved_charset.g1;
        self.parser.gl_charset = self.saved_charset.gl;
        self.parser.charset_target = self.saved_charset.target;
    }

    pub fn setTabAtCursor(self: *TerminalSession) void {
        self.activeScreen().setTabAtCursor();
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
            self.activeScreen().clear();
            self.activeScreen().setCursor(0, 0);
        }
        self.activeScreen().markDirtyAll();
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
        self.activeScreen().markDirtyAll();
    }

    pub fn snapshot(self: *TerminalSession) TerminalSnapshot {
        const screen = self.activeScreenConst();
        const view = screen.snapshotView();
        const alt_active = self.isAltActive();
        const kitty = kitty_mod.kittyStateConst(self);
        return TerminalSnapshot{
            .rows = view.rows,
            .cols = view.cols,
            .cells = view.cells,
            .dirty_rows = view.dirty_rows,
            .dirty_cols_start = view.dirty_cols_start,
            .dirty_cols_end = view.dirty_cols_end,
            .cursor = view.cursor,
            .cursor_style = view.cursor_style,
            .cursor_visible = view.cursor_visible,
            .dirty = view.dirty,
            .damage = view.damage,
            .alt_active = alt_active,
            .screen_reverse = screen.screen_reverse,
            .generation = self.output_generation.load(.acquire),
            .kitty_images = kitty.images.items,
            .kitty_placements = kitty.placements.items,
            .kitty_generation = kitty.generation,
        };
    }

    pub fn renderCache(self: *TerminalSession) *const RenderCache {
        const idx = self.render_cache_index.load(.acquire);
        return &self.render_caches[idx];
    }

    pub fn syncUpdatesActive(self: *const TerminalSession) bool {
        return self.sync_updates_active;
    }

    pub fn setSyncUpdates(self: *TerminalSession, enabled: bool) void {
        if (self.sync_updates_active == enabled) return;
        self.sync_updates_active = enabled;
        if (!enabled) {
            self.activeScreen().markDirtyAll();
        }
        self.force_full_damage.store(true, .release);
        const offset: usize = self.history.scrollOffset();
        self.updateViewCacheNoLock(self.output_generation.load(.acquire), offset);
    }

    pub fn takeOscClipboard(self: *TerminalSession) ?[]const u8 {
        if (!self.osc_clipboard_pending) return null;
        self.osc_clipboard_pending = false;
        return self.osc_clipboard.items;
    }

    pub fn hyperlinkUri(self: *const TerminalSession, link_id: u32) ?[]const u8 {
        return hyperlink_table.hyperlinkUri(self, link_id);
    }

    pub fn currentCwd(self: *const TerminalSession) []const u8 {
        return self.cwd;
    }

    pub fn clearDirty(self: *TerminalSession) void {
        self.activeScreen().clearDirty();
    }

    pub fn clearSelection(self: *TerminalSession) void {
        selection_mod.clearSelection(self);
    }

    pub fn startSelection(self: *TerminalSession, row: usize, col: usize) void {
        selection_mod.startSelection(self, row, col);
    }

    pub fn updateSelection(self: *TerminalSession, row: usize, col: usize) void {
        selection_mod.updateSelection(self, row, col);
    }

    pub fn finishSelection(self: *TerminalSession) void {
        selection_mod.finishSelection(self);
    }

    pub fn selectionState(self: *TerminalSession) ?TerminalSelection {
        return selection_mod.selectionState(self);
    }

    pub fn bracketedPasteEnabled(self: *TerminalSession) bool {
        return self.bracketed_paste;
    }

    pub fn mouseReportingEnabled(self: *TerminalSession) bool {
        const input_snapshot = self.input_snapshot;
        return input_snapshot.mouse_mode_x10.load(.acquire) or input_snapshot.mouse_mode_button.load(.acquire) or input_snapshot.mouse_mode_any.load(.acquire);
    }

    pub fn isAlive(self: *TerminalSession) bool {
        if (self.pty) |*pty| {
            return pty.isAlive();
        }
        return false;
    }

    pub fn getDamage(self: *TerminalSession) ?struct {
        start_row: usize,
        end_row: usize,
        start_col: usize,
        end_col: usize,
    } {
        return self.activeScreenConst().getDamage();
    }

    pub fn markDirty(self: *TerminalSession) void {
        self.activeScreen().markDirtyAll();
    }
};

pub const InputSnapshot = struct {
    app_cursor_keys: std.atomic.Value(bool),
    app_keypad: std.atomic.Value(bool),
    key_mode_flags: std.atomic.Value(u32),
    mouse_mode_x10: std.atomic.Value(bool),
    mouse_mode_button: std.atomic.Value(bool),
    mouse_mode_any: std.atomic.Value(bool),
    mouse_mode_sgr: std.atomic.Value(bool),

    pub fn init() InputSnapshot {
        return .{
            .app_cursor_keys = std.atomic.Value(bool).init(false),
            .app_keypad = std.atomic.Value(bool).init(false),
            .key_mode_flags = std.atomic.Value(u32).init(0),
            .mouse_mode_x10 = std.atomic.Value(bool).init(false),
            .mouse_mode_button = std.atomic.Value(bool).init(false),
            .mouse_mode_any = std.atomic.Value(bool).init(false),
            .mouse_mode_sgr = std.atomic.Value(bool).init(false),
        };
    }
};

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
pub const VTERM_KEY_LEFT_SHIFT = types.VTERM_KEY_LEFT_SHIFT;
pub const VTERM_KEY_RIGHT_SHIFT = types.VTERM_KEY_RIGHT_SHIFT;
pub const VTERM_KEY_LEFT_CTRL = types.VTERM_KEY_LEFT_CTRL;
pub const VTERM_KEY_RIGHT_CTRL = types.VTERM_KEY_RIGHT_CTRL;
pub const VTERM_KEY_LEFT_ALT = types.VTERM_KEY_LEFT_ALT;
pub const VTERM_KEY_RIGHT_ALT = types.VTERM_KEY_RIGHT_ALT;
pub const VTERM_KEY_LEFT_SUPER = types.VTERM_KEY_LEFT_SUPER;
pub const VTERM_KEY_RIGHT_SUPER = types.VTERM_KEY_RIGHT_SUPER;
pub const KeypadKey = input_mod.KeypadKey;
pub const KeyAction = input_mod.KeyAction;

pub const VTERM_MOD_NONE = types.VTERM_MOD_NONE;
pub const VTERM_MOD_SHIFT = types.VTERM_MOD_SHIFT;
pub const VTERM_MOD_ALT = types.VTERM_MOD_ALT;
pub const VTERM_MOD_CTRL = types.VTERM_MOD_CTRL;

const default_scrollback_rows: usize = 1000;
const key_mode_disambiguate: u32 = 1;
const key_mode_report_all_event_types: u32 = 2;
const key_mode_report_alternate_key: u32 = 4;
const key_mode_report_text: u32 = 8;
const key_mode_embed_text: u32 = 16;

fn keyName(key: Key) []const u8 {
    return switch (key) {
        VTERM_KEY_ENTER => "enter",
        VTERM_KEY_TAB => "tab",
        VTERM_KEY_BACKSPACE => "backspace",
        VTERM_KEY_ESCAPE => "escape",
        VTERM_KEY_UP => "up",
        VTERM_KEY_DOWN => "down",
        VTERM_KEY_LEFT => "left",
        VTERM_KEY_RIGHT => "right",
        VTERM_KEY_INS => "insert",
        VTERM_KEY_DEL => "delete",
        VTERM_KEY_HOME => "home",
        VTERM_KEY_END => "end",
        VTERM_KEY_PAGEUP => "page_up",
        VTERM_KEY_PAGEDOWN => "page_down",
        else => "unknown",
    };
}

fn keypadKeyName(key: input_mod.KeypadKey) []const u8 {
    return switch (key) {
        .kp0 => "kp0",
        .kp1 => "kp1",
        .kp2 => "kp2",
        .kp3 => "kp3",
        .kp4 => "kp4",
        .kp5 => "kp5",
        .kp6 => "kp6",
        .kp7 => "kp7",
        .kp8 => "kp8",
        .kp9 => "kp9",
        .kp_decimal => "kp_decimal",
        .kp_divide => "kp_divide",
        .kp_multiply => "kp_multiply",
        .kp_subtract => "kp_subtract",
        .kp_add => "kp_add",
        .kp_enter => "kp_enter",
        .kp_equal => "kp_equal",
    };
}
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
