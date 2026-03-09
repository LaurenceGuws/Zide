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
const palette_mod = @import("../protocol/palette.zig");
const pty_io = @import("pty_io.zig");
const view_cache = @import("view_cache.zig");
const resize_reflow = @import("resize_reflow.zig");
const selection_mod = @import("selection.zig");
const scrolling_mod = @import("scrolling.zig");
const control_handlers = @import("control_handlers.zig");
const parser_hooks = @import("parser_hooks.zig");
const input_modes = @import("input_modes.zig");
const hyperlink_table = @import("hyperlink_table.zig");
const state_reset = @import("state_reset.zig");
const scrollback_view = @import("scrollback_view.zig");
const osc_kitty_clipboard = @import("../protocol/osc_kitty_clipboard.zig");
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
pub const PresentedRenderCache = struct {
    generation: u64,
    dirty: Dirty,
};

pub const AltExitPresentationInfo = struct {
    draw_ms: f64,
    rows: usize,
    cols: usize,
    history_len: usize,
    scroll_offset: usize,
};

pub const PresentationFeedback = struct {
    presented: ?PresentedRenderCache = null,
    texture_updated: bool = false,
    alt_exit_info: ?AltExitPresentationInfo = null,
};

pub const PtyWriteGuard = struct {
    mutex: *std.Thread.Mutex,
    pty: *Pty,

    pub fn write(self: *PtyWriteGuard, bytes: []const u8) !usize {
        return self.pty.write(bytes);
    }

    pub fn unlock(self: *PtyWriteGuard) void {
        self.mutex.unlock();
    }
};

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
        .focus_reporting = self.focus_reporting,
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

fn isNavigationKey(key: Key) bool {
    return switch (key) {
        VTERM_KEY_LEFT, VTERM_KEY_RIGHT, VTERM_KEY_UP, VTERM_KEY_DOWN, VTERM_KEY_HOME, VTERM_KEY_END => true,
        else => false,
    };
}

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
    focus_reporting: bool,
    auto_repeat: bool,
    app_cursor_keys: bool,
    app_keypad: bool,
    mouse_alternate_scroll: bool,
    inband_resize_notifications_2048: bool,
    report_color_scheme_2031: bool,
    grapheme_cluster_shaping_2027: bool,
    color_scheme_dark: bool,
    kitty_paste_events_5522: bool,
    input: input_mod.InputState,
    input_snapshot: InputSnapshot,
    pty_write_mutex: std.Thread.Mutex,
    cell_width: u16,
    cell_height: u16,
    parser: parser_mod.Parser,
    osc_clipboard: std.ArrayList(u8),
    osc_clipboard_pending: bool,
    kitty_osc5522_clipboard_text: std.ArrayList(u8),
    kitty_osc5522_clipboard_html: std.ArrayList(u8),
    kitty_osc5522_clipboard_uri_list: std.ArrayList(u8),
    kitty_osc5522_clipboard_png: std.ArrayList(u8),
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
    presented_generation: std.atomic.Value(u64),
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
        log.logf(.info, "terminal init rows={d} cols={d} scrollback_max={d}", .{ rows, cols, scrollback_rows });
        log.logStdout(.info, "terminal init rows={d} cols={d}", .{ rows, cols });
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
            .focus_reporting = false,
            .auto_repeat = true,
            .app_cursor_keys = false,
            .app_keypad = false,
            .mouse_alternate_scroll = true,
            .inband_resize_notifications_2048 = false,
            .report_color_scheme_2031 = false,
            .grapheme_cluster_shaping_2027 = false,
            .color_scheme_dark = true,
            .kitty_paste_events_5522 = false,
            .input = input_mod.InputState.init(),
            .input_snapshot = InputSnapshot.init(),
            .pty_write_mutex = .{},
            .cell_width = 0,
            .cell_height = 0,
            .parser = parser_mod.Parser.init(allocator),
            .osc_clipboard = .empty,
            .osc_clipboard_pending = false,
            .kitty_osc5522_clipboard_text = .empty,
            .kitty_osc5522_clipboard_html = .empty,
            .kitty_osc5522_clipboard_uri_list = .empty,
            .kitty_osc5522_clipboard_png = .empty,
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
            .presented_generation = std.atomic.Value(u64).init(0),
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
        const screen = self.activeScreenConst();
        self.input_snapshot.app_cursor_keys.store(self.app_cursor_keys, .release);
        self.input_snapshot.app_keypad.store(self.app_keypad, .release);
        self.input_snapshot.key_mode_flags.store(self.keyModeFlags(), .release);
        self.input_snapshot.mouse_mode_x10.store(self.input.mouse_mode_x10, .release);
        self.input_snapshot.mouse_mode_button.store(self.input.mouse_mode_button, .release);
        self.input_snapshot.mouse_mode_any.store(self.input.mouse_mode_any, .release);
        self.input_snapshot.mouse_mode_sgr.store(self.input.mouse_mode_sgr, .release);
        self.input_snapshot.focus_reporting.store(self.focus_reporting, .release);
        self.input_snapshot.bracketed_paste.store(self.bracketed_paste, .release);
        self.input_snapshot.auto_repeat.store(self.auto_repeat, .release);
        self.input_snapshot.mouse_alternate_scroll.store(self.mouse_alternate_scroll, .release);
        self.input_snapshot.alt_active.store(self.active == .alt, .release);
        self.input_snapshot.screen_rows.store(screen.grid.rows, .release);
        self.input_snapshot.screen_cols.store(screen.grid.cols, .release);
    }

    fn setActiveScreenMode(self: *TerminalSession, active: ActiveScreen) void {
        self.active = active;
        self.updateInputSnapshot();
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

    pub fn setDefaultColorsLocked(self: *TerminalSession, fg: types.Color, bg: types.Color) void {
        const old_attrs = self.primary.default_attrs;
        var new_attrs = types.defaultCell().attrs;
        new_attrs.fg = fg;
        new_attrs.bg = bg;
        new_attrs.underline_color = fg;

        self.primary.updateDefaultColors(old_attrs, new_attrs);
        self.alt.updateDefaultColors(old_attrs, new_attrs);
        self.history.updateDefaultColors(old_attrs.fg, old_attrs.bg, new_attrs.fg, new_attrs.bg);
        self.updateViewCacheNoLock(self.output_generation.load(.acquire), self.history.scrollOffset());
    }

    pub fn setDefaultColors(self: *TerminalSession, fg: types.Color, bg: types.Color) void {
        self.lock();
        defer self.unlock();
        self.setDefaultColorsLocked(fg, bg);
    }

    fn setAnsiColorsLocked(self: *TerminalSession, colors: [16]types.Color) void {
        for (0..16) |i| {
            self.palette_default[i] = colors[i];
            self.palette_current[i] = colors[i];
        }
        self.updateViewCacheNoLock(self.output_generation.load(.acquire), self.history.scrollOffset());
    }

    pub fn setAnsiColors(self: *TerminalSession, colors: [16]types.Color) void {
        self.lock();
        defer self.unlock();
        self.setAnsiColorsLocked(colors);
    }

    fn remapAnsiColorsLocked(self: *TerminalSession, old_colors: [16]types.Color, new_colors: [16]types.Color) void {
        self.primary.updateAnsiColors(old_colors, new_colors);
        self.alt.updateAnsiColors(old_colors, new_colors);
        self.history.updateAnsiColors(old_colors, new_colors);
        self.updateViewCacheNoLock(self.output_generation.load(.acquire), self.history.scrollOffset());
    }

    pub fn remapAnsiColors(self: *TerminalSession, old_colors: [16]types.Color, new_colors: [16]types.Color) void {
        self.lock();
        defer self.unlock();
        self.remapAnsiColorsLocked(old_colors, new_colors);
    }

    fn snapshotAnsiColorsLocked(self: *const TerminalSession) [16]types.Color {
        var colors: [16]types.Color = undefined;
        for (0..16) |i| {
            colors[i] = self.palette_current[i];
        }
        return colors;
    }

    pub fn applyThemePalette(
        self: *TerminalSession,
        fg: types.Color,
        bg: types.Color,
        ansi: ?[16]types.Color,
    ) void {
        self.lock();
        defer self.unlock();

        const old_ansi = if (ansi != null) self.snapshotAnsiColorsLocked() else undefined;
        self.setDefaultColorsLocked(fg, bg);
        if (ansi) |colors| {
            self.setAnsiColorsLocked(colors);
            self.remapAnsiColorsLocked(old_ansi, colors);
        }
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
        self.kitty_osc5522_clipboard_text.deinit(self.allocator);
        self.kitty_osc5522_clipboard_html.deinit(self.allocator);
        self.kitty_osc5522_clipboard_uri_list.deinit(self.allocator);
        self.kitty_osc5522_clipboard_png.deinit(self.allocator);
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

    pub fn startNoThreads(self: *TerminalSession, shell: ?[:0]const u8) !void {
        try pty_io.startNoThreads(self, shell);
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
            if (pty.pollExit() catch |err| blk: {
                const log = app_logger.logger("terminal.pty");
                log.logf(.warning, "pty pollExit failed err={s}", .{@errorName(err)});
                break :blk null;
            }) |code| {
                self.child_exit_code.store(code, .release);
                self.child_exited.store(true, .release);

                const log = app_logger.logger("terminal.pty");
                log.logf(.info, "pty child exited code={d}", .{code});
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

    pub fn currentGeneration(self: *const TerminalSession) u64 {
        return self.output_generation.load(.acquire);
    }

    pub fn publishedGeneration(self: *const TerminalSession) u64 {
        const idx = self.render_cache_index.load(.acquire);
        return self.render_caches[idx].generation;
    }

    pub fn presentedGeneration(self: *const TerminalSession) u64 {
        return self.presented_generation.load(.acquire);
    }

    pub fn notePresentedGeneration(self: *TerminalSession, generation: u64) void {
        self.presented_generation.store(generation, .release);
    }

    pub fn acknowledgePresentedGeneration(self: *TerminalSession, generation: u64) bool {
        self.notePresentedGeneration(generation);
        if (self.renderCacheSyncUpdatesActiveForGeneration(generation)) {
            return self.clearPublishedDamageIfGeneration(generation, false);
        }
        return self.clearPublishedDamageIfGeneration(generation, true);
    }

    fn renderCacheSyncUpdatesActiveForGeneration(self: *TerminalSession, generation: u64) bool {
        inline for (0..2) |i| {
            if (self.render_caches[i].generation == generation) {
                return self.render_caches[i].sync_updates_active;
            }
        }
        return self.sync_updates_active;
    }

    pub fn hasPublishedGenerationBacklog(self: *TerminalSession) bool {
        return self.currentGeneration() != self.publishedGeneration();
    }

    pub fn pollBacklogHint(self: *TerminalSession) bool {
        return self.hasData() or self.hasPublishedGenerationBacklog();
    }

    pub fn lockPtyWriter(self: *TerminalSession) ?PtyWriteGuard {
        if (self.pty) |*pty| {
            self.pty_write_mutex.lock();
            return .{
                .mutex = &self.pty_write_mutex,
                .pty = pty,
            };
        }
        return null;
    }

    pub fn writePtyBytes(self: *TerminalSession, bytes: []const u8) !void {
        var writer = self.lockPtyWriter() orelse return;
        defer writer.unlock();
        _ = try writer.write(bytes);
    }

    pub fn sendKey(self: *TerminalSession, key: Key, mod: Modifier) !void {
        try self.sendKeyAction(key, mod, input_mod.KeyAction.press);
    }

    pub fn sendKeyAction(self: *TerminalSession, key: Key, mod: Modifier, action: input_mod.KeyAction) !void {
        if (action == .repeat and !self.input_snapshot.auto_repeat.load(.acquire)) return;
        const log = app_logger.logger("terminal.input");
        const input_snapshot = self.input_snapshot;
        const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
        const app_cursor = input_snapshot.app_cursor_keys.load(.acquire);
        if (isNavigationKey(key)) {
            log.logf(.info, "sendKey key={s} code={d} mod=0x{x} action={s} app_cursor={any} key_mode=0x{x}", .{
                keyName(key),
                key,
                mod,
                @tagName(action),
                app_cursor,
                key_mode_flags,
            });
        }
        if (self.lockPtyWriter()) |writer_guard| {
            var writer = writer_guard;
            defer writer.unlock();
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
                    if (isNavigationKey(key)) {
                        log.logf(.info, "sendKey path=app_cursor seq_len={d}", .{seq.len});
                    }
                    _ = try writer.write(seq);
                    return;
                }
            }
            if (isNavigationKey(key)) {
                log.logf(.info, "sendKey path=encoded", .{});
            }
            _ = try input_mod.sendKeyAction(writer.pty, key, mod, key_mode_flags, action);
        }
    }

    pub fn sendKeyActionWithMetadata(
        self: *TerminalSession,
        key: Key,
        mod: Modifier,
        action: input_mod.KeyAction,
        alternate_meta: ?types.KeyboardAlternateMetadata,
    ) !void {
        if (action == .repeat and !self.input_snapshot.auto_repeat.load(.acquire)) return;
        const log = app_logger.logger("terminal.input");
        const input_snapshot = self.input_snapshot;
        const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
        const app_cursor = input_snapshot.app_cursor_keys.load(.acquire);
        if (isNavigationKey(key)) {
            log.logf(.info, "sendKey(meta) key={s} code={d} mod=0x{x} action={s} app_cursor={any} key_mode=0x{x} alt_meta={any}", .{
                keyName(key),
                key,
                mod,
                @tagName(action),
                app_cursor,
                key_mode_flags,
                alternate_meta != null,
            });
        }
        if (self.lockPtyWriter()) |writer_guard| {
            var writer = writer_guard;
            defer writer.unlock();
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
                    if (isNavigationKey(key)) {
                        log.logf(.info, "sendKey(meta) path=app_cursor seq_len={d}", .{seq.len});
                    }
                    _ = try writer.write(seq);
                    return;
                }
            }
            if (isNavigationKey(key)) {
                log.logf(.info, "sendKey(meta) path=encoded", .{});
            }
            _ = try input_mod.sendKeyActionEvent(writer.pty, .{
                .key = key,
                .mod = mod,
                .key_mode_flags = key_mode_flags,
                .action = action,
                .protocol = .{ .alternate = alternate_meta },
            });
        }
    }

    pub fn sendKeypad(self: *TerminalSession, key: input_mod.KeypadKey, mod: Modifier) !void {
        try self.sendKeypadAction(key, mod, input_mod.KeyAction.press);
    }

    pub fn sendKeypadAction(self: *TerminalSession, key: input_mod.KeypadKey, mod: Modifier, action: input_mod.KeyAction) !void {
        if (action == .repeat and !self.input_snapshot.auto_repeat.load(.acquire)) return;
        const log = app_logger.logger("terminal.input");
        const input_snapshot = self.input_snapshot;
        const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
        const app_keypad = input_snapshot.app_keypad.load(.acquire);
        log.logf(.info, "sendKeypad key={s} mod=0x{x} action={s} app_keypad={any} key_mode=0x{x}", .{
            keypadKeyName(key),
            mod,
            @tagName(action),
            app_keypad,
            key_mode_flags,
        });
        if (self.lockPtyWriter()) |writer_guard| {
            var writer = writer_guard;
            defer writer.unlock();
            if (action == .press) {
                _ = try input_mod.sendKeypad(writer.pty, key, mod, app_keypad, key_mode_flags);
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
        if (action == .repeat and !self.input_snapshot.auto_repeat.load(.acquire)) return;
        const log = app_logger.logger("terminal.input");
        const input_snapshot = self.input_snapshot;
        const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
        log.logf(.info, "sendChar cp={d} mod=0x{x} action={s} key_mode=0x{x}", .{
            char,
            mod,
            @tagName(action),
            key_mode_flags,
        });
        if (self.lockPtyWriter()) |writer_guard| {
            var writer = writer_guard;
            defer writer.unlock();
            _ = try input_mod.sendCharAction(writer.pty, char, mod, key_mode_flags, action);
        } else {
            self.echoCharLocallyIfEnabled(char, mod, action);
        }
    }

    pub fn sendCharActionWithMetadata(
        self: *TerminalSession,
        char: u32,
        mod: Modifier,
        action: input_mod.KeyAction,
        alternate_meta: ?types.KeyboardAlternateMetadata,
    ) !void {
        if (action == .repeat and !self.input_snapshot.auto_repeat.load(.acquire)) return;
        const log = app_logger.logger("terminal.input");
        const input_snapshot = self.input_snapshot;
        const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
        log.logf(.info, "sendChar(meta) cp={d} mod=0x{x} action={s} key_mode=0x{x} alt_meta={any}", .{
            char,
            mod,
            @tagName(action),
            key_mode_flags,
            alternate_meta != null,
        });
        if (self.lockPtyWriter()) |writer_guard| {
            var writer = writer_guard;
            defer writer.unlock();
            _ = try input_mod.sendCharActionEvent(writer.pty, .{
                .codepoint = char,
                .mod = mod,
                .key_mode_flags = key_mode_flags,
                .action = action,
                .protocol = .{ .alternate = alternate_meta },
            });
        } else {
            self.echoCharLocallyIfEnabled(char, mod, action);
        }
    }

    fn echoCharLocallyIfEnabled(self: *TerminalSession, char: u32, mod: Modifier, action: input_mod.KeyAction) void {
        if (action == .release) return;
        if (mod != VTERM_MOD_NONE) return;
        if (char < 0x20 or char == 0x7F) return;
        if (char > 0x10FFFF or (char >= 0xD800 and char <= 0xDFFF)) return;
        const screen = self.activeScreen();
        if (!screen.local_echo_mode_12) return;
        self.handleCodepoint(char);
    }

    pub fn reportMouseEvent(self: *TerminalSession, event: MouseEvent) !bool {
        if (self.pty == null) return false;
        const screen = self.activeScreen();
        if (self.lockPtyWriter()) |writer_guard| {
            var writer = writer_guard;
            defer writer.unlock();
            return self.input.reportMouseEvent(writer.pty, event, screen.grid.rows, screen.grid.cols);
        }
        return false;
    }

    pub fn reportAlternateScrollWheel(self: *TerminalSession, wheel_steps: i32, mod: Modifier) !bool {
        if (wheel_steps == 0) return false;
        if (!self.input_snapshot.mouse_alternate_scroll.load(.acquire)) return false;
        if (!self.input_snapshot.alt_active.load(.acquire)) return false;
        var remaining = wheel_steps;
        while (remaining != 0) {
            const key: Key = if (remaining > 0) VTERM_KEY_UP else VTERM_KEY_DOWN;
            try self.sendKeyAction(key, mod, input_mod.KeyAction.press);
            remaining += if (remaining > 0) -1 else 1;
        }
        return true;
    }

    pub fn sendText(self: *TerminalSession, text: []const u8) !void {
        if (text.len == 0) return;
        const log = app_logger.logger("terminal.input");
        log.logf(.info, "sendText len={d}", .{text.len});
        if (self.lockPtyWriter()) |writer_guard| {
            var writer = writer_guard;
            defer writer.unlock();
            try input_mod.sendText(writer.pty, text);
        }
    }

    pub fn sendBytes(self: *TerminalSession, bytes: []const u8) !void {
        if (bytes.len == 0) return;
        if (self.lockPtyWriter()) |writer_guard| {
            var writer = writer_guard;
            defer writer.unlock();
            _ = try writer.write(bytes);
        }
    }

    pub fn reportFocusChanged(self: *TerminalSession, focused: bool) !bool {
        const log = app_logger.logger("terminal.input");
        if (!self.focusReportingEnabled()) {
            log.logf(.debug, "focus report skipped focused={d} reason=disabled", .{@intFromBool(focused)});
            return false;
        }
        if (self.lockPtyWriter()) |writer_guard| {
            var writer = writer_guard;
            defer writer.unlock();
            _ = try writer.write(if (focused) "\x1b[I" else "\x1b[O");
            return true;
        }
        log.logf(.warning, "focus report dropped focused={d} reason=missing-pty", .{@intFromBool(focused)});
        return false;
    }

    pub fn reportColorSchemeChanged(self: *TerminalSession, dark: bool) !bool {
        const log = app_logger.logger("terminal.input");
        self.color_scheme_dark = dark;
        if (!self.report_color_scheme_2031) {
            log.logf(.debug, "color-scheme report skipped dark={d} reason=disabled", .{@intFromBool(dark)});
            return false;
        }
        if (self.lockPtyWriter()) |writer_guard| {
            var writer = writer_guard;
            var buf: [16]u8 = undefined;
            const seq = try std.fmt.bufPrint(&buf, "\x1b[?997;{d}n", .{if (dark) @as(u8, 1) else @as(u8, 2)});
            defer writer.unlock();
            _ = try writer.write(seq);
            return true;
        }
        log.logf(.warning, "color-scheme report dropped dark={d} reason=missing-pty", .{@intFromBool(dark)});
        return false;
    }

    pub fn resize(self: *TerminalSession, rows: u16, cols: u16) !void {
        try resize_reflow.resize(self, rows, cols);
        try self.reportInBandResize2048(rows, cols);
    }

    fn reportInBandResize2048(self: *TerminalSession, rows: u16, cols: u16) !void {
        if (!self.inband_resize_notifications_2048) return;
        if (self.lockPtyWriter()) |writer_guard| {
            var writer = writer_guard;
            const rows_px: u32 = @as(u32, rows) * @as(u32, self.cell_height);
            const cols_px: u32 = @as(u32, cols) * @as(u32, self.cell_width);
            var buf: [64]u8 = undefined;
            const seq = try std.fmt.bufPrint(
                &buf,
                "\x1b[48;{d};{d};{d};{d}t",
                .{ rows, cols, rows_px, cols_px },
            );
            defer writer.unlock();
            _ = try writer.write(seq);
        }
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
        self.updateViewCacheNoLock(self.output_generation.load(.acquire), self.history.scrollOffset());
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

    pub fn clearAllKittyImages(self: *TerminalSession) void {
        kitty_mod.clearAllKittyImages(self);
    }

    pub fn handleCsi(self: *TerminalSession, action: csi_mod.CsiAction) void {
        parser_hooks.handleCsi(self, action);
    }

    pub fn feedOutputBytes(self: *TerminalSession, bytes: []const u8) void {
        if (bytes.len == 0) return;
        self.parser.handleSlice(self, bytes);
        _ = self.output_generation.fetchAdd(1, .acq_rel);
        self.updateViewCacheNoLock(self.output_generation.load(.acquire), self.history.scrollOffset());
    }

    pub fn resetState(self: *TerminalSession) void {
        state_reset.resetState(self);
    }

    pub fn reverseIndex(self: *TerminalSession) void {
        control_handlers.reverseIndex(self);
    }

    pub fn eraseDisplay(self: *TerminalSession, mode: i32) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.eraseDisplay(mode, blank_cell);
        if (mode == 2 or mode == 3) {
            self.clearSelection();
            _ = self.clear_generation.fetchAdd(1, .acq_rel);
        }
    }

    pub fn eraseLine(self: *TerminalSession, mode: i32) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.eraseLine(mode, blank_cell);
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
        return scrollback_view.scrollbackCount(self);
    }

    pub fn scrollbackRow(self: *TerminalSession, index: usize) ?[]const Cell {
        return scrollback_view.scrollbackRow(self, index);
    }

    pub fn scrollOffset(self: *TerminalSession) usize {
        return scrollback_view.scrollOffset(self);
    }

    pub fn setScrollOffset(self: *TerminalSession, offset: usize) void {
        scrollback_view.setScrollOffset(self, offset);
    }

    pub fn scrollBy(self: *TerminalSession, delta: isize) void {
        scrollback_view.scrollBy(self, delta);
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
        return self.input_snapshot.key_mode_flags.load(.acquire);
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

    pub fn setAppCursorKeys(self: *TerminalSession, enabled: bool) void {
        input_modes.setAppCursorKeys(self, enabled);
    }

    pub fn setAutoRepeat(self: *TerminalSession, enabled: bool) void {
        input_modes.setAutoRepeat(self, enabled);
    }

    pub fn setBracketedPaste(self: *TerminalSession, enabled: bool) void {
        input_modes.setBracketedPaste(self, enabled);
    }

    pub fn setFocusReporting(self: *TerminalSession, enabled: bool) void {
        input_modes.setFocusReporting(self, enabled);
    }

    pub fn setMouseAlternateScroll(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseAlternateScroll(self, enabled);
    }

    pub fn setMouseModeX10(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeX10(self, enabled);
    }

    pub fn setMouseModeButton(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeButton(self, enabled);
    }

    pub fn setMouseModeAny(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeAny(self, enabled);
    }

    pub fn setMouseModeSgr(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeSgr(self, enabled);
    }

    pub fn setMouseModeSgrPixels(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeSgrPixels(self, enabled);
    }

    pub fn resetInputModes(self: *TerminalSession) void {
        input_modes.resetInputModes(self);
    }

    pub fn setCursorStyle(self: *TerminalSession, mode: i32) void {
        self.activeScreen().setCursorStyle(mode);
    }

    pub fn decrqssReplyInto(self: *TerminalSession, text: []const u8, buf: []u8) ?[]const u8 {
        const log = app_logger.logger("terminal.apc");
        if (std.mem.eql(u8, text, " q")) {
            const style = self.activeScreen().cursor_style;
            return switch (style.shape) {
                .block => if (style.blink) "1 q" else "2 q",
                .underline => if (style.blink) "3 q" else "4 q",
                .bar => if (style.blink) "5 q" else "6 q",
            };
        }
        if (std.mem.eql(u8, text, "m")) {
            return self.decrqssSgrReply(buf);
        }
        if (std.mem.eql(u8, text, "r")) {
            const screen = self.activeScreen();
            return std.fmt.bufPrint(buf, "{d};{d}r", .{
                screen.scroll_top + 1,
                screen.scroll_bottom + 1,
            }) catch |err| {
                log.logf(.warning, "decrqss r reply format failed err={s}", .{@errorName(err)});
                return null;
            };
        }
        if (std.mem.eql(u8, text, "s")) {
            const screen = self.activeScreen();
            return std.fmt.bufPrint(buf, "{d};{d}s", .{
                screen.left_margin + 1,
                screen.right_margin + 1,
            }) catch |err| {
                log.logf(.warning, "decrqss s reply format failed err={s}", .{@errorName(err)});
                return null;
            };
        }
        return null;
    }

    fn decrqssSgrReply(self: *TerminalSession, buf: []u8) ?[]const u8 {
        const screen = self.activeScreen();
        const attrs = screen.current_attrs;
        const defaults = screen.default_attrs;
        var pos: usize = 0;

        if (attrs.bold) if (!appendParam(buf, &pos, 1)) return null;
        if (attrs.blink and !attrs.blink_fast) {
            if (!appendParam(buf, &pos, 5)) return null;
        }
        if (attrs.blink and attrs.blink_fast) {
            if (!appendParam(buf, &pos, 6)) return null;
        }
        if (attrs.reverse) {
            if (!appendParam(buf, &pos, 7)) return null;
        }
        if (attrs.underline) {
            if (!appendParam(buf, &pos, 4)) return null;
        }

        if (!colorEq(attrs.fg, defaults.fg)) {
            const code = self.decrqssPaletteSgrCode(attrs.fg, true) orelse return null;
            if (!appendParam(buf, &pos, code)) return null;
        }
        if (!colorEq(attrs.bg, defaults.bg)) {
            const code = self.decrqssPaletteSgrCode(attrs.bg, false) orelse return null;
            if (!appendParam(buf, &pos, code)) return null;
        }

        if (pos == 0) {
            if (buf.len < 1) return null;
            buf[0] = 'm';
            return buf[0..1];
        }
        if (pos + 1 > buf.len) return null;
        buf[pos] = 'm';
        return buf[0 .. pos + 1];
    }

    fn decrqssPaletteSgrCode(self: *TerminalSession, color: types.Color, fg: bool) ?u8 {
        var idx: u8 = 0;
        while (idx < 16) : (idx += 1) {
            if (colorEq(color, self.paletteColor(idx))) {
                if (idx < 8) return (if (fg) @as(u8, 30) else @as(u8, 40)) + idx;
                return (if (fg) @as(u8, 90) else @as(u8, 100)) + (idx - 8);
            }
        }
        return null;
    }

    fn colorEq(a: types.Color, b: types.Color) bool {
        return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
    }

    fn appendParam(buf: []u8, pos: *usize, param: u8) bool {
        const log = app_logger.logger("terminal.csi");
        var tmp: [4]u8 = undefined;
        const text = std.fmt.bufPrint(&tmp, "{d}", .{param}) catch |err| {
            log.logf(.warning, "appendParam format failed param={d}: {s}", .{ param, @errorName(err) });
            return false;
        };
        var needed = text.len;
        if (pos.* > 0) needed += 1;
        if (pos.* + needed > buf.len) return false;
        if (pos.* > 0) {
            buf[pos.*] = ';';
            pos.* += 1;
        }
        @memcpy(buf[pos.* .. pos.* + text.len], text);
        pos.* += text.len;
        return true;
    }

    pub fn saveCursor(self: *TerminalSession) void {
        state_reset.saveCursor(self);
    }

    pub fn setKeypadMode(self: *TerminalSession, enabled: bool) void {
        input_modes.setKeypadMode(self, enabled);
    }

    pub fn restoreCursor(self: *TerminalSession) void {
        state_reset.restoreCursor(self);
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
        self.setActiveScreenMode(.alt);
        kitty_mod.clearKittyImages(self);
        if (clear) {
            self.activeScreen().clear();
            self.activeScreen().setCursor(0, 0);
        }
        self.activeScreen().markDirtyAllWithReason(.alt_enter, @src());
    }

    pub fn exitAltScreen(self: *TerminalSession, restore_cursor: bool) void {
        if (!self.isAltActive()) return;
        kitty_mod.clearKittyImages(self);
        self.setActiveScreenMode(.primary);
        self.alt_exit_pending.store(true, .release);
        self.alt_exit_time_ms.store(std.time.milliTimestamp(), .release);
        self.history.restoreScrollOffset(self.primary.grid.rows);
        self.clearSelection();
        if (restore_cursor) {
            self.restoreCursor();
        }
        self.activeScreen().markDirtyAllWithReason(.alt_exit, @src());
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

    pub fn copyPublishedRenderCache(self: *TerminalSession, dst: *RenderCache) !PresentedRenderCache {
        self.lock();
        defer self.unlock();
        if (self.view_cache_pending.load(.acquire)) {
            self.updateViewCacheForScrollLocked();
        }
        const cache = self.renderCache();
        try render_cache_mod.copySnapshot(dst, self.allocator, cache);
        return .{
            .generation = cache.generation,
            .dirty = cache.dirty,
        };
    }

    pub fn completePresentationFeedback(self: *TerminalSession, feedback: PresentationFeedback) void {
        if (feedback.presented) |presented| {
            if (feedback.texture_updated or presented.dirty == .none) {
                _ = self.acknowledgePresentedGeneration(presented.generation);
            }
        }
        if (feedback.alt_exit_info) |info| {
            const exit_time_ms = self.alt_exit_time_ms.swap(-1, .acq_rel);
            const exit_to_draw_ms: f64 = if (exit_time_ms >= 0)
                @as(f64, @floatFromInt(std.time.milliTimestamp() - exit_time_ms))
            else
                -1.0;
            const log = app_logger.logger("terminal.alt");
            log.logf(.info, "alt_exit_draw_ms={d:.2} exit_to_draw_ms={d:.2} rows={d} cols={d} history={d} scroll_offset={d}", .{
                info.draw_ms,
                exit_to_draw_ms,
                info.rows,
                info.cols,
                info.history_len,
                info.scroll_offset,
            });
        }
    }

    pub fn syncUpdatesActive(self: *const TerminalSession) bool {
        return self.sync_updates_active;
    }

    pub fn setSyncUpdates(self: *TerminalSession, enabled: bool) void {
        if (self.sync_updates_active == enabled) return;
        self.sync_updates_active = enabled;
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

    pub fn currentTitle(self: *TerminalSession) []const u8 {
        if (self.pty) |*pty| {
            if (pty.foregroundProcessLabel()) |label| {
                return label;
            }
        }
        return self.title;
    }

    fn clearPublishedDamageIfGeneration(self: *TerminalSession, expected_generation: u64, clear_screen_dirty: bool) bool {
        self.lock();
        defer self.unlock();
        if (self.output_generation.load(.acquire) != expected_generation) return false;
        if (clear_screen_dirty) {
            self.activeScreen().clearDirty();
        }
        inline for (0..2) |i| {
            self.render_caches[i].dirty = .none;
            self.render_caches[i].damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
        }
        return true;
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
        return self.input_snapshot.bracketed_paste.load(.acquire);
    }

    pub fn focusReportingEnabled(self: *TerminalSession) bool {
        return self.input_snapshot.focus_reporting.load(.acquire);
    }

    pub fn autoRepeatEnabled(self: *TerminalSession) bool {
        return self.input_snapshot.auto_repeat.load(.acquire);
    }

    pub fn mouseAlternateScrollEnabled(self: *TerminalSession) bool {
        return self.input_snapshot.mouse_alternate_scroll.load(.acquire);
    }

    pub fn kittyPasteEvents5522Enabled(self: *TerminalSession) bool {
        return self.kitty_paste_events_5522;
    }

    pub fn sendKittyPasteEvent5522(self: *TerminalSession, clip: []const u8) !bool {
        return self.sendKittyPasteEvent5522WithMime(clip, null, null);
    }

    pub fn sendKittyPasteEvent5522WithHtml(self: *TerminalSession, clip: []const u8, html: ?[]const u8) !bool {
        return self.sendKittyPasteEvent5522WithMime(clip, html, null);
    }

    pub fn sendKittyPasteEvent5522WithMime(self: *TerminalSession, clip: []const u8, html: ?[]const u8, uri_list: ?[]const u8) !bool {
        return self.sendKittyPasteEvent5522WithMimeRich(clip, html, uri_list, null);
    }

    pub fn sendKittyPasteEvent5522WithMimeRich(
        self: *TerminalSession,
        clip: []const u8,
        html: ?[]const u8,
        uri_list: ?[]const u8,
        png: ?[]const u8,
    ) !bool {
        const log = app_logger.logger("terminal.osc");
        if (!self.kitty_paste_events_5522) {
            log.logf(.debug, "osc5522 paste skipped reason=disabled", .{});
            return false;
        }
        if (self.pty == null) {
            log.logf(.warning, "osc5522 paste dropped reason=missing-pty", .{});
            return false;
        }

        self.kitty_osc5522_clipboard_text.clearRetainingCapacity();
        try self.kitty_osc5522_clipboard_text.ensureTotalCapacity(self.allocator, clip.len);
        try self.kitty_osc5522_clipboard_text.appendSlice(self.allocator, clip);
        self.kitty_osc5522_clipboard_html.clearRetainingCapacity();
        if (html) |html_bytes| {
            try self.kitty_osc5522_clipboard_html.ensureTotalCapacity(self.allocator, html_bytes.len);
            try self.kitty_osc5522_clipboard_html.appendSlice(self.allocator, html_bytes);
        }
        self.kitty_osc5522_clipboard_uri_list.clearRetainingCapacity();
        if (uri_list) |uri_bytes| {
            try self.kitty_osc5522_clipboard_uri_list.ensureTotalCapacity(self.allocator, uri_bytes.len);
            try self.kitty_osc5522_clipboard_uri_list.appendSlice(self.allocator, uri_bytes);
        }
        self.kitty_osc5522_clipboard_png.clearRetainingCapacity();
        if (png) |png_bytes| {
            try self.kitty_osc5522_clipboard_png.ensureTotalCapacity(self.allocator, png_bytes.len);
            try self.kitty_osc5522_clipboard_png.appendSlice(self.allocator, png_bytes);
        }

        if (self.lockPtyWriter()) |writer_guard| {
            var writer = writer_guard;
            defer writer.unlock();
            osc_kitty_clipboard.sendPasteEventMimes(self, &writer, .st);
            return true;
        }
        log.logf(.warning, "osc5522 paste dropped after buffer prep reason=missing-pty", .{});
        return false;
    }

    pub fn mouseReportingEnabled(self: *TerminalSession) bool {
        const input_snapshot = self.input_snapshot;
        return input_snapshot.mouse_mode_x10.load(.acquire) or input_snapshot.mouse_mode_button.load(.acquire) or input_snapshot.mouse_mode_any.load(.acquire);
    }

    pub const CloseConfirmSignals = struct {
        foreground_process: bool = false,
        semantic_command: bool = false,
        alt_screen: bool = false,
        mouse_reporting: bool = false,

        pub fn any(self: CloseConfirmSignals) bool {
            return self.foreground_process or self.semantic_command or self.alt_screen or self.mouse_reporting;
        }
    };

    pub fn closeConfirmSignals(self: *TerminalSession) CloseConfirmSignals {
        var signals = CloseConfirmSignals{};
        if (!self.isAlive()) return signals;

        if (self.pty) |*pty| {
            signals.foreground_process = pty.hasForegroundProcessOutsideShell();
        }
        signals.semantic_command = self.semantic_prompt.input_active or self.semantic_prompt.output_active;
        signals.alt_screen = self.isAltActive();
        signals.mouse_reporting = self.mouseReportingEnabled();
        return signals;
    }

    pub fn shouldConfirmClose(self: *TerminalSession) bool {
        return self.closeConfirmSignals().any();
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
};

pub const InputSnapshot = struct {
    app_cursor_keys: std.atomic.Value(bool),
    app_keypad: std.atomic.Value(bool),
    key_mode_flags: std.atomic.Value(u32),
    mouse_mode_x10: std.atomic.Value(bool),
    mouse_mode_button: std.atomic.Value(bool),
    mouse_mode_any: std.atomic.Value(bool),
    mouse_mode_sgr: std.atomic.Value(bool),
    focus_reporting: std.atomic.Value(bool),
    bracketed_paste: std.atomic.Value(bool),
    auto_repeat: std.atomic.Value(bool),
    mouse_alternate_scroll: std.atomic.Value(bool),
    alt_active: std.atomic.Value(bool),
    screen_rows: std.atomic.Value(u16),
    screen_cols: std.atomic.Value(u16),

    pub fn init() InputSnapshot {
        return .{
            .app_cursor_keys = std.atomic.Value(bool).init(false),
            .app_keypad = std.atomic.Value(bool).init(false),
            .key_mode_flags = std.atomic.Value(u32).init(0),
            .mouse_mode_x10 = std.atomic.Value(bool).init(false),
            .mouse_mode_button = std.atomic.Value(bool).init(false),
            .mouse_mode_any = std.atomic.Value(bool).init(false),
            .mouse_mode_sgr = std.atomic.Value(bool).init(false),
            .focus_reporting = std.atomic.Value(bool).init(false),
            .bracketed_paste = std.atomic.Value(bool).init(false),
            .auto_repeat = std.atomic.Value(bool).init(true),
            .mouse_alternate_scroll = std.atomic.Value(bool).init(true),
            .alt_active = std.atomic.Value(bool).init(false),
            .screen_rows = std.atomic.Value(u16).init(0),
            .screen_cols = std.atomic.Value(u16).init(0),
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

test "full-region scroll publishes partial cache damage at live bottom" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row: usize = 0;
    while (row < 3) : (row += 1) {
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            var cell = base;
            cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(row));
            session.primary.grid.cells.items[row * 4 + col] = cell;
        }
    }
    session.primary.setCursor(2, 0);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.scrollUp();
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(i32, 1), cache.viewport_shift_rows);
    try std.testing.expectEqual(@as(usize, 1), session.scrollbackCount());
}

test "feedOutputBytes keeps incremental damage after baseline publish" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 1, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.feedOutputBytes("A");

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
}

test "acknowledgePresentedGeneration derives sync dirty retirement from cache" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 1, 4);
    defer session.deinit();

    session.primary.markDirtyAllWithReason(.unknown, @src());
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    const normal_generation = session.renderCache().generation;
    try std.testing.expect(session.acknowledgePresentedGeneration(normal_generation));
    try std.testing.expectEqual(Dirty.none, session.primary.grid.dirty);

    session.primary.markDirtyAllWithReason(.unknown, @src());
    session.setSyncUpdates(true);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    const sync_generation = session.renderCache().generation;
    try std.testing.expect(session.acknowledgePresentedGeneration(sync_generation));
    try std.testing.expectEqual(Dirty.full, session.primary.grid.dirty);
}

test "row hash refinement does not skip unpresented top rows" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row: usize = 0;
    while (row < 3) : (row += 1) {
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            var cell = base;
            cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(row));
            session.primary.grid.cells.items[row * 4 + col] = cell;
        }
    }
    session.primary.setCursor(2, 0);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.scrollUp();
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    session.scrollUp();
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expect(cache.dirty_rows.items[0]);
}

test "setSyncUpdates enable does not force redraw when screen is otherwise clean" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.setSyncUpdates(true);

    const cache = session.renderCache();
    try std.testing.expect(session.syncUpdatesActive());
    try std.testing.expectEqual(Dirty.none, cache.dirty);
    try std.testing.expectEqual(@as(u64, 0), cache.full_dirty_seq);
}

test "setSyncUpdates disable stays clean when no buffered changes exist" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    session.setSyncUpdates(true);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.setSyncUpdates(false);

    const cache = session.renderCache();
    try std.testing.expect(!session.syncUpdatesActive());
    try std.testing.expectEqual(Dirty.none, cache.dirty);
}

test "setSyncUpdates disable preserves buffered partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.setSyncUpdates(true);

    var cell = session.primary.defaultCell();
    cell.codepoint = 'Z';
    session.primary.grid.cells.items[0] = cell;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    session.setSyncUpdates(false);

    const cache = session.renderCache();
    try std.testing.expect(!session.syncUpdatesActive());
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
}

test "visible history changes publish partial cache damage without force-full" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row_a = [_]Cell{ base, base, base, base };
    var row_b = [_]Cell{ base, base, base, base };
    for (&row_a, 0..) |*cell, col| cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(col));
    for (&row_b, 0..) |*cell, col| cell.codepoint = @as(u32, 'E') + @as(u32, @intCast(col));

    session.history.pushRow(&row_a, false, base);
    session.history.pushRow(&row_b, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, base);
    session.history.setScrollOffset(session.primary.grid.rows, 2);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    const new_fg = Color{ .r = 0x11, .g = 0x22, .b = 0x33, .a = 0xff };
    session.history.updateDefaultColors(base.attrs.fg, base.attrs.bg, new_fg, base.attrs.bg);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expectEqual(new_fg, cache.cells.items[0].attrs.fg);
}

test "visible history changes without presented diff base stay partial" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row_a = [_]Cell{ base, base, base, base };
    var row_b = [_]Cell{ base, base, base, base };
    for (&row_a, 0..) |*cell, col| cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(col));
    for (&row_b, 0..) |*cell, col| cell.codepoint = @as(u32, 'E') + @as(u32, @intCast(col));

    session.history.pushRow(&row_a, false, base);
    session.history.pushRow(&row_b, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, base);
    session.history.setScrollOffset(session.primary.grid.rows, 2);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    const new_fg = Color{ .r = 0x44, .g = 0x55, .b = 0x66, .a = 0xff };
    session.history.updateDefaultColors(base.attrs.fg, base.attrs.bg, new_fg, base.attrs.bg);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expect(cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 3), cache.dirty_cols_end.items[0]);
    try std.testing.expectEqual(new_fg, cache.cells.items[0].attrs.fg);
}

test "scrollback offset change publishes shift-exposed partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var history_rows = [_][4]Cell{
        .{ base, base, base, base },
        .{ base, base, base, base },
        .{ base, base, base, base },
        .{ base, base, base, base },
    };
    for (&history_rows, 0..) |*history_row, row_idx| {
        for (history_row, 0..) |*cell, col| {
            cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(row_idx * 4 + col));
        }
        session.history.pushRow(history_row, false, base);
    }

    session.history.ensureViewCache(session.primary.grid.cols, base);
    session.history.setScrollOffset(session.primary.grid.rows, 2);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.setScrollOffset(1);

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(i32, 1), cache.viewport_shift_rows);
    try std.testing.expect(cache.viewport_shift_exposed_only);
    try std.testing.expect(!cache.dirty_rows.items[0]);
    try std.testing.expect(cache.dirty_rows.items[1]);
}

test "cursor style updates publish through cache without texture invalidation" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.primary.cursor_style = .{ .shape = .bar, .blink = false };
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.none, cache.dirty);
    try std.testing.expectEqual(types.CursorStyle{ .shape = .bar, .blink = false }, cache.cursor_style);
}

test "kitty generation delta does not force full damage when cell damage is partial" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.kitty_primary.generation += 1;
    session.primary.grid.markDirtyRange(0, 0, 0, 0);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.end_col);
}

test "kitty generation delta without visible damage stays clean" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.kitty_primary.generation += 1;
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.none, cache.dirty);
}

test "clear generation delta without visible damage stays clean" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    _ = session.clear_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.none, cache.dirty);
}

test "default color remap stays on partial path" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    const old_attrs = session.primary.default_attrs;
    const new_fg = Color{ .r = 0xaa, .g = 0xbb, .b = 0xcc, .a = 0xff };
    session.setDefaultColors(new_fg, old_attrs.bg);

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 3), cache.dirty_cols_end.items[0]);
    try std.testing.expectEqual(new_fg, cache.cells.items[0].attrs.fg);
}

test "screen reverse toggle stays on partial path" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.activeScreen().setScreenReverse(true);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expect(cache.screen_reverse);
    try std.testing.expectEqual(@as(u16, 0), cache.dirty_cols_start.items[0]);
    try std.testing.expectEqual(@as(u16, 3), cache.dirty_cols_end.items[0]);
}

test "eraseDisplay cursor-to-end keeps partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    for (session.primary.grid.cells.items, 0..) |*cell, idx| {
        cell.* = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(idx % 4));
    }
    session.primary.setCursor(1, 1);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.eraseDisplay(0);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.end_row);
}

test "eraseDisplay start-to-cursor keeps partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    for (session.primary.grid.cells.items, 0..) |*cell, idx| {
        cell.* = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(idx % 4));
    }
    session.primary.setCursor(1, 2);

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.eraseDisplay(1);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
}

test "eraseDisplay full keeps full-width partial damage" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 3, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    for (session.primary.grid.cells.items, 0..) |*cell, idx| {
        cell.* = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(idx % 4));
    }

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.eraseDisplay(2);
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 2), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
}

test "screen clear stays on partial path" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    for (session.primary.grid.cells.items, 0..) |*cell, idx| {
        cell.* = base;
        cell.codepoint = @as(u32, 'A') + @as(u32, @intCast(idx % 4));
    }

    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());
    session.notePresentedGeneration(session.renderCache().generation);

    session.primary.clearDirty();
    session.alt.clearDirty();
    try std.testing.expect(session.acknowledgePresentedGeneration(session.renderCache().generation));

    session.activeScreen().clear();
    _ = session.output_generation.fetchAdd(1, .acq_rel);
    session.updateViewCacheNoLock(session.output_generation.load(.acquire), session.history.scrollOffset());

    const cache = session.renderCache();
    try std.testing.expectEqual(Dirty.partial, cache.dirty);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_row);
    try std.testing.expectEqual(@as(usize, 1), cache.damage.end_row);
    try std.testing.expectEqual(@as(usize, 0), cache.damage.start_col);
    try std.testing.expectEqual(@as(usize, 3), cache.damage.end_col);
}
