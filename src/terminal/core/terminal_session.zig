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
const session_queries = @import("session_queries.zig");
const session_content = @import("session_content.zig");
const session_selection = @import("session_selection.zig");
const session_input = @import("session_input.zig");
const session_interaction = @import("session_interaction.zig");
const session_rendering = @import("session_rendering.zig");
const session_protocol = @import("session_protocol.zig");
const session_config = @import("session_config.zig");
const session_runtime = @import("session_runtime.zig");
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
pub const ScrollbackInfo = session_content.ScrollbackInfo;
pub const ScrollbackRange = session_content.ScrollbackRange;
pub const SelectionGesture = session_selection.SelectionGesture;
pub const ClickSelectionResult = session_selection.ClickSelectionResult;
pub const SessionMetadata = session_queries.SessionMetadata;
pub const PresentedRenderCache = session_rendering.PresentedRenderCache;
pub const PresentationCapture = session_rendering.PresentationCapture;

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
        .selection = selection_mod.selectionState(self),
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
    self.parser.handleSlice(parser_mod.Parser.SessionFacade.from(self), bytes);
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
        input_modes.publishSnapshot(&session);
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

    fn setActiveScreenMode(self: *TerminalSession, active: ActiveScreen) void {
        self.active = active;
        input_modes.publishSnapshot(self);
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
        session_config.setDefaultColorsLocked(self, fg, bg);
    }

    pub fn setDefaultColors(self: *TerminalSession, fg: types.Color, bg: types.Color) void {
        session_config.setDefaultColors(self, fg, bg);
    }

    pub fn setAnsiColors(self: *TerminalSession, colors: [16]types.Color) void {
        session_config.setAnsiColors(self, colors);
    }

    pub fn remapAnsiColors(self: *TerminalSession, old_colors: [16]types.Color, new_colors: [16]types.Color) void {
        session_config.remapAnsiColors(self, old_colors, new_colors);
    }

    pub fn setPaletteColorLocked(self: *TerminalSession, idx: usize, color: types.Color) void {
        session_config.setPaletteColorLocked(self, idx, color);
    }

    pub fn resetPaletteColorLocked(self: *TerminalSession, idx: usize) void {
        session_config.resetPaletteColorLocked(self, idx);
    }

    pub fn resetAllPaletteColorsLocked(self: *TerminalSession) void {
        session_config.resetAllPaletteColorsLocked(self);
    }

    pub fn setDynamicColorCodeLocked(self: *TerminalSession, code: u8, color: ?types.Color) void {
        session_config.setDynamicColorCodeLocked(self, code, color);
    }

    pub fn applyThemePalette(
        self: *TerminalSession,
        fg: types.Color,
        bg: types.Color,
        ansi: ?[16]types.Color,
    ) void {
        session_config.applyThemePalette(self, fg, bg, ansi);
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
        try session_runtime.start(self, shell);
    }

    pub fn startNoThreads(self: *TerminalSession, shell: ?[:0]const u8) !void {
        try session_runtime.startNoThreads(self, shell);
    }

    pub fn poll(self: *TerminalSession) !void {
        return session_runtime.poll(self);
    }

    pub fn hasData(self: *TerminalSession) bool {
        return session_runtime.hasData(self);
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
        return session_rendering.currentGeneration(self);
    }

    pub fn publishedGeneration(self: *const TerminalSession) u64 {
        return session_rendering.publishedGeneration(self);
    }

    pub fn presentedGeneration(self: *const TerminalSession) u64 {
        return session_rendering.presentedGeneration(self);
    }

    pub fn notePresentedGeneration(self: *TerminalSession, generation: u64) void {
        session_rendering.notePresentedGeneration(self, generation);
    }

    pub fn acknowledgePresentedGeneration(self: *TerminalSession, generation: u64) bool {
        return session_rendering.acknowledgePresentedGeneration(self, generation);
    }

    pub fn hasPublishedGenerationBacklog(self: *TerminalSession) bool {
        return session_rendering.hasPublishedGenerationBacklog(self);
    }

    pub fn pollBacklogHint(self: *TerminalSession) bool {
        return session_rendering.pollBacklogHint(self);
    }

    pub fn lockPtyWriter(self: *TerminalSession) ?PtyWriteGuard {
        return session_runtime.lockPtyWriter(self);
    }

    pub fn writePtyBytes(self: *TerminalSession, bytes: []const u8) !void {
        try session_runtime.writePtyBytes(self, bytes);
    }

    pub fn sendKey(self: *TerminalSession, key: Key, mod: Modifier) !void {
        try session_input.sendKey(self, key, mod);
    }

    pub fn sendKeyAction(self: *TerminalSession, key: Key, mod: Modifier, action: input_mod.KeyAction) !void {
        try session_input.sendKeyAction(self, key, mod, action);
    }

    pub fn sendKeyActionWithMetadata(
        self: *TerminalSession,
        key: Key,
        mod: Modifier,
        action: input_mod.KeyAction,
        alternate_meta: ?types.KeyboardAlternateMetadata,
    ) !void {
        try session_input.sendKeyActionWithMetadata(self, key, mod, action, alternate_meta);
    }

    pub fn sendKeypad(self: *TerminalSession, key: input_mod.KeypadKey, mod: Modifier) !void {
        try session_input.sendKeypad(self, key, mod);
    }

    pub fn sendKeypadAction(self: *TerminalSession, key: input_mod.KeypadKey, mod: Modifier, action: input_mod.KeyAction) !void {
        try session_input.sendKeypadAction(self, key, mod, action);
    }

    pub fn appKeypadEnabled(self: *const TerminalSession) bool {
        return session_input.appKeypadEnabled(self);
    }

    pub fn appCursorKeysEnabled(self: *const TerminalSession) bool {
        return session_input.appCursorKeysEnabled(self);
    }

    pub fn sendChar(self: *TerminalSession, char: u32, mod: Modifier) !void {
        try session_input.sendChar(self, char, mod);
    }

    pub fn sendCharAction(self: *TerminalSession, char: u32, mod: Modifier, action: input_mod.KeyAction) !void {
        try session_input.sendCharAction(self, char, mod, action);
    }

    pub fn sendCharActionWithMetadata(
        self: *TerminalSession,
        char: u32,
        mod: Modifier,
        action: input_mod.KeyAction,
        alternate_meta: ?types.KeyboardAlternateMetadata,
    ) !void {
        try session_input.sendCharActionWithMetadata(self, char, mod, action, alternate_meta);
    }

    pub fn reportMouseEvent(self: *TerminalSession, event: MouseEvent) !bool {
        return session_input.reportMouseEvent(self, event);
    }

    pub fn reportAlternateScrollWheel(self: *TerminalSession, wheel_steps: i32, mod: Modifier) !bool {
        return session_input.reportAlternateScrollWheel(self, wheel_steps, mod);
    }

    pub fn sendText(self: *TerminalSession, text: []const u8) !void {
        try session_input.sendText(self, text);
    }

    pub fn sendBytes(self: *TerminalSession, bytes: []const u8) !void {
        try session_input.sendBytes(self, bytes);
    }

    pub fn reportFocusChanged(self: *TerminalSession, focused: bool) !bool {
        return session_input.reportFocusChanged(self, focused);
    }

    pub fn reportColorSchemeChanged(self: *TerminalSession, dark: bool) !bool {
        return session_input.reportColorSchemeChanged(self, dark);
    }

    pub fn resize(self: *TerminalSession, rows: u16, cols: u16) !void {
        try session_runtime.resize(self, rows, cols);
    }

    pub fn setColumnMode132(self: *TerminalSession, enabled: bool) void {
        session_config.setColumnMode132(self, enabled);
    }

    pub fn setColumnMode132Locked(self: *TerminalSession, enabled: bool) void {
        session_config.setColumnMode132Locked(self, enabled);
    }

    pub fn setCellSize(self: *TerminalSession, cell_width: u16, cell_height: u16) void {
        session_config.setCellSize(self, cell_width, cell_height);
    }

    pub fn handleControl(self: *TerminalSession, byte: u8) void {
        session_protocol.handleControl(self, byte);
    }

    pub fn parseDcs(self: *TerminalSession, payload: []const u8) void {
        session_protocol.parseDcs(self, payload);
    }

    pub fn parseApc(self: *TerminalSession, payload: []const u8) void {
        session_protocol.parseApc(self, payload);
    }

    pub fn parseOsc(self: *TerminalSession, payload: []const u8, terminator: OscTerminator) void {
        session_protocol.parseOsc(self, payload, terminator);
    }
    pub fn appendHyperlink(self: *TerminalSession, uri: []const u8) ?u32 {
        return session_protocol.appendHyperlink(self, uri, max_hyperlinks);
    }

    pub fn clearAllKittyImages(self: *TerminalSession) void {
        session_protocol.clearAllKittyImages(self);
    }

    pub fn handleCsi(self: *TerminalSession, action: csi_mod.CsiAction) void {
        session_protocol.handleCsi(self, action);
    }

    pub fn feedOutputBytes(self: *TerminalSession, bytes: []const u8) void {
        session_protocol.feedOutputBytes(self, bytes);
    }

    pub fn resetState(self: *TerminalSession) void {
        session_protocol.resetState(self);
    }

    pub fn resetStateLocked(self: *TerminalSession) void {
        session_protocol.resetStateLocked(self);
    }

    pub fn reverseIndex(self: *TerminalSession) void {
        session_protocol.reverseIndex(self);
    }

    pub fn eraseDisplay(self: *TerminalSession, mode: i32) void {
        session_protocol.eraseDisplay(self, mode);
    }

    pub fn eraseLine(self: *TerminalSession, mode: i32) void {
        session_protocol.eraseLine(self, mode);
    }

    pub fn insertChars(self: *TerminalSession, count: usize) void {
        session_protocol.insertChars(self, count);
    }

    pub fn deleteChars(self: *TerminalSession, count: usize) void {
        session_protocol.deleteChars(self, count);
    }

    pub fn eraseChars(self: *TerminalSession, count: usize) void {
        session_protocol.eraseChars(self, count);
    }

    pub fn insertLines(self: *TerminalSession, count: usize) void {
        session_protocol.insertLines(self, count);
    }

    pub fn deleteLines(self: *TerminalSession, count: usize) void {
        session_protocol.deleteLines(self, count);
    }

    pub fn scrollRegionUp(self: *TerminalSession, count: usize) void {
        session_protocol.scrollRegionUp(self, count);
    }

    pub fn scrollRegionDown(self: *TerminalSession, count: usize) void {
        session_protocol.scrollRegionDown(self, count);
    }

    fn applySgr(self: *TerminalSession, action: csi_mod.CsiAction) void {
        protocol_csi.applySgr(self, action);
    }

    pub fn paletteColor(self: *const TerminalSession, idx: u8) types.Color {
        return session_protocol.paletteColor(self, idx);
    }

    pub fn handleCodepoint(self: *TerminalSession, codepoint: u32) void {
        session_protocol.handleCodepoint(self, codepoint);
    }

    pub fn handleAsciiSlice(self: *TerminalSession, bytes: []const u8) void {
        session_protocol.handleAsciiSlice(self, bytes);
    }

    pub fn newline(self: *TerminalSession) void {
        session_protocol.newline(self);
    }

    pub fn wrapNewline(self: *TerminalSession) void {
        session_protocol.wrapNewline(self);
    }

    fn scrollUp(self: *TerminalSession) void {
        scrolling_mod.scrollUp(self);
    }

    pub fn getCell(self: *TerminalSession, row: usize, col: usize) Cell {
        return session_protocol.getCell(self, row, col);
    }

    pub fn getCursorPos(self: *TerminalSession) CursorPos {
        return session_protocol.getCursorPos(self);
    }

    pub fn scrollbackInfo(self: *TerminalSession) ScrollbackInfo {
        return session_content.scrollbackInfo(self);
    }

    pub fn copyScrollbackRange(
        self: *TerminalSession,
        allocator: std.mem.Allocator,
        start_row: usize,
        max_rows: usize,
        out: *std.ArrayList(Cell),
    ) !ScrollbackRange {
        return session_content.copyScrollbackRange(self, allocator, start_row, max_rows, out);
    }

    pub fn selectionPlainTextAlloc(self: *TerminalSession, allocator: std.mem.Allocator) !?[]u8 {
        return session_content.selectionPlainTextAlloc(self, allocator);
    }

    pub fn scrollbackPlainTextAlloc(self: *TerminalSession, allocator: std.mem.Allocator) ![]u8 {
        return session_content.scrollbackPlainTextAlloc(self, allocator);
    }

    pub fn scrollbackAnsiTextAlloc(self: *TerminalSession, allocator: std.mem.Allocator) ![]u8 {
        return session_content.scrollbackAnsiTextAlloc(self, allocator);
    }

    pub fn setScrollOffset(self: *TerminalSession, offset: usize) void {
        session_content.setScrollOffset(self, offset);
    }

    pub fn setScrollOffsetLocked(self: *TerminalSession, offset: usize) void {
        session_content.setScrollOffsetLocked(self, offset);
    }

    pub fn resetToLiveBottomLocked(self: *TerminalSession) bool {
        return session_content.resetToLiveBottomLocked(self);
    }

    pub fn resetToLiveBottomForInputLocked(self: *TerminalSession, saw_non_modifier_key_press: bool, saw_text_input: bool) bool {
        return session_content.resetToLiveBottomForInputLocked(self, saw_non_modifier_key_press, saw_text_input);
    }

    pub fn setScrollOffsetFromNormalizedTrackLocked(self: *TerminalSession, track_ratio: f32) ?usize {
        return session_content.setScrollOffsetFromNormalizedTrackLocked(self, track_ratio);
    }

    pub fn scrollSelectionDragLocked(self: *TerminalSession, toward_top: bool) bool {
        return session_content.scrollSelectionDragLocked(self, toward_top);
    }

    pub fn scrollBy(self: *TerminalSession, delta: isize) void {
        session_content.scrollBy(self, delta);
    }

    pub fn scrollByLocked(self: *TerminalSession, delta: isize) void {
        session_content.scrollByLocked(self, delta);
    }

    pub fn scrollWheelLocked(self: *TerminalSession, wheel_steps: i32) bool {
        return session_content.scrollWheelLocked(self, wheel_steps);
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

    pub fn keyModePushLocked(self: *TerminalSession, flags: u32) void {
        input_modes.keyModePushLocked(self, flags);
    }

    pub fn keyModePop(self: *TerminalSession, count: usize) void {
        input_modes.keyModePop(self, count);
    }

    pub fn keyModePopLocked(self: *TerminalSession, count: usize) void {
        input_modes.keyModePopLocked(self, count);
    }

    pub fn keyModeModify(self: *TerminalSession, flags: u32, mode: u32) void {
        input_modes.keyModeModify(self, flags, mode);
    }

    pub fn keyModeModifyLocked(self: *TerminalSession, flags: u32, mode: u32) void {
        input_modes.keyModeModifyLocked(self, flags, mode);
    }

    pub fn keyModeQuery(self: *TerminalSession) void {
        input_modes.keyModeQuery(self);
    }

    pub fn keyModeQueryLocked(self: *TerminalSession) void {
        input_modes.keyModeQueryLocked(self);
    }

    pub fn setAppCursorKeys(self: *TerminalSession, enabled: bool) void {
        input_modes.setAppCursorKeys(self, enabled);
    }

    pub fn setAppCursorKeysLocked(self: *TerminalSession, enabled: bool) void {
        input_modes.setAppCursorKeysLocked(self, enabled);
    }

    pub fn setAutoRepeat(self: *TerminalSession, enabled: bool) void {
        input_modes.setAutoRepeat(self, enabled);
    }

    pub fn setAutoRepeatLocked(self: *TerminalSession, enabled: bool) void {
        input_modes.setAutoRepeatLocked(self, enabled);
    }

    pub fn setBracketedPaste(self: *TerminalSession, enabled: bool) void {
        input_modes.setBracketedPaste(self, enabled);
    }

    pub fn setBracketedPasteLocked(self: *TerminalSession, enabled: bool) void {
        input_modes.setBracketedPasteLocked(self, enabled);
    }

    pub fn setFocusReporting(self: *TerminalSession, enabled: bool) void {
        input_modes.setFocusReporting(self, enabled);
    }

    pub fn setFocusReportingLocked(self: *TerminalSession, enabled: bool) void {
        input_modes.setFocusReportingLocked(self, enabled);
    }

    pub fn setMouseAlternateScroll(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseAlternateScroll(self, enabled);
    }

    pub fn setMouseAlternateScrollLocked(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseAlternateScrollLocked(self, enabled);
    }

    pub fn setMouseModeX10(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeX10(self, enabled);
    }

    pub fn setMouseModeX10Locked(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeX10Locked(self, enabled);
    }

    pub fn setMouseModeButton(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeButton(self, enabled);
    }

    pub fn setMouseModeButtonLocked(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeButtonLocked(self, enabled);
    }

    pub fn setMouseModeAny(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeAny(self, enabled);
    }

    pub fn setMouseModeAnyLocked(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeAnyLocked(self, enabled);
    }

    pub fn setMouseModeSgr(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeSgr(self, enabled);
    }

    pub fn setMouseModeSgrLocked(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeSgrLocked(self, enabled);
    }

    pub fn setMouseModeSgrPixels(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeSgrPixels(self, enabled);
    }

    pub fn setMouseModeSgrPixelsLocked(self: *TerminalSession, enabled: bool) void {
        input_modes.setMouseModeSgrPixelsLocked(self, enabled);
    }

    pub fn resetInputModes(self: *TerminalSession) void {
        input_modes.resetInputModes(self);
    }

    pub fn resetInputModesLocked(self: *TerminalSession) void {
        input_modes.resetInputModesLocked(self);
    }

    pub fn setCursorStyle(self: *TerminalSession, mode: i32) void {
        session_protocol.setCursorStyle(self, mode);
    }

    pub fn decrqssReplyInto(self: *TerminalSession, text: []const u8, buf: []u8) ?[]const u8 {
        return session_protocol.decrqssReplyInto(self, text, buf);
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
        session_protocol.saveCursor(self);
    }

    pub fn setKeypadMode(self: *TerminalSession, enabled: bool) void {
        input_modes.setKeypadMode(self, enabled);
    }

    pub fn setKeypadModeLocked(self: *TerminalSession, enabled: bool) void {
        input_modes.setKeypadModeLocked(self, enabled);
    }

    pub fn restoreCursor(self: *TerminalSession) void {
        session_protocol.restoreCursor(self);
    }

    pub fn setTabAtCursor(self: *TerminalSession) void {
        session_protocol.setTabAtCursor(self);
    }

    pub fn enterAltScreen(self: *TerminalSession, clear: bool, save_cursor: bool) void {
        session_protocol.enterAltScreen(self, clear, save_cursor);
    }

    pub fn exitAltScreen(self: *TerminalSession, restore_cursor: bool) void {
        session_protocol.exitAltScreen(self, restore_cursor);
    }

    pub fn snapshot(self: *TerminalSession) TerminalSnapshot {
        return session_rendering.snapshot(self);
    }

    pub fn renderCache(self: *TerminalSession) *const RenderCache {
        return session_rendering.renderCache(self);
    }

    pub fn copyPublishedRenderCache(self: *TerminalSession, dst: *RenderCache) !PresentedRenderCache {
        return session_rendering.copyPublishedRenderCache(self, dst);
    }

    pub fn capturePresentation(self: *TerminalSession, dst: *RenderCache) !PresentationCapture {
        return session_rendering.capturePresentation(self, dst);
    }

    pub fn completePresentationFeedback(self: *TerminalSession, feedback: PresentationFeedback) void {
        session_rendering.completePresentationFeedback(self, feedback);
    }

    pub fn finishFramePresentation(self: *TerminalSession, feedback: PresentationFeedback) void {
        session_rendering.completePresentationFeedback(self, feedback);
    }

    pub fn pasteSystemClipboard(
        self: *TerminalSession,
        clip_opt: ?[]const u8,
        html: ?[]const u8,
        uri_list: ?[]const u8,
        png: ?[]const u8,
    ) !bool {
        return session_interaction.pasteSystemClipboard(self, clip_opt, html, uri_list, png);
    }

    pub fn pasteSelectionClipboard(
        self: *TerminalSession,
        clip_opt: ?[]const u8,
        html: ?[]const u8,
        uri_list: ?[]const u8,
        png: ?[]const u8,
    ) !bool {
        return session_interaction.pasteSelectionClipboard(self, clip_opt, html, uri_list, png);
    }

    pub fn syncUpdatesActive(self: *const TerminalSession) bool {
        return session_rendering.syncUpdatesActive(self);
    }

    pub fn setSyncUpdates(self: *TerminalSession, enabled: bool) void {
        session_rendering.setSyncUpdates(self, enabled);
    }

    pub fn setSyncUpdatesLocked(self: *TerminalSession, enabled: bool) void {
        session_rendering.setSyncUpdatesLocked(self, enabled);
    }

    fn takeOscClipboardCopyLocked(self: *TerminalSession, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) !bool {
        return session_queries.takeOscClipboardCopyLocked(self, allocator, out);
    }

    pub fn takeOscClipboardCopy(self: *TerminalSession, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) !bool {
        self.lock();
        defer self.unlock();
        return self.takeOscClipboardCopyLocked(allocator, out);
    }

    pub fn tryTakeOscClipboardCopy(self: *TerminalSession, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) !bool {
        out.clearRetainingCapacity();
        if (!self.tryLock()) return false;
        defer self.unlock();
        return self.takeOscClipboardCopyLocked(allocator, out);
    }

    pub fn copyHyperlinkUri(self: *TerminalSession, allocator: std.mem.Allocator, link_id: u32, out: *std.ArrayList(u8)) !?[]const u8 {
        return session_queries.copyHyperlinkUri(self, allocator, link_id, out);
    }

    pub fn copyMetadata(
        self: *TerminalSession,
        allocator: std.mem.Allocator,
        title_out: *std.ArrayList(u8),
        cwd_out: *std.ArrayList(u8),
    ) !SessionMetadata {
        return session_queries.copyMetadata(self, allocator, title_out, cwd_out);
    }

    pub fn clearPublishedDamageIfGeneration(self: *TerminalSession, expected_generation: u64, clear_screen_dirty: bool) bool {
        return session_rendering.clearPublishedDamageIfGeneration(self, expected_generation, clear_screen_dirty);
    }

    pub fn clearSelection(self: *TerminalSession) void {
        session_selection.clearSelection(self);
    }

    pub fn clearSelectionLocked(self: *TerminalSession) void {
        session_selection.clearSelectionLocked(self);
    }

    pub fn clearSelectionIfActiveLocked(self: *TerminalSession) bool {
        return session_selection.clearSelectionIfActiveLocked(self);
    }

    pub fn startSelection(self: *TerminalSession, row: usize, col: usize) void {
        session_selection.startSelection(self, row, col);
    }

    pub fn startSelectionLocked(self: *TerminalSession, row: usize, col: usize) void {
        session_selection.startSelectionLocked(self, row, col);
    }

    pub fn updateSelection(self: *TerminalSession, row: usize, col: usize) void {
        session_selection.updateSelection(self, row, col);
    }

    pub fn updateSelectionLocked(self: *TerminalSession, row: usize, col: usize) void {
        session_selection.updateSelectionLocked(self, row, col);
    }

    pub fn finishSelection(self: *TerminalSession) void {
        session_selection.finishSelection(self);
    }

    pub fn finishSelectionLocked(self: *TerminalSession) void {
        session_selection.finishSelectionLocked(self);
    }

    pub fn finishSelectionIfActiveLocked(self: *TerminalSession) bool {
        return session_selection.finishSelectionIfActiveLocked(self);
    }

    pub fn selectRange(self: *TerminalSession, start_pos: SelectionPos, end_pos: SelectionPos, finished: bool) void {
        session_selection.selectRange(self, start_pos, end_pos, finished);
    }

    pub fn selectRangeLocked(self: *TerminalSession, start_pos: SelectionPos, end_pos: SelectionPos, finished: bool) void {
        session_selection.selectRangeLocked(self, start_pos, end_pos, finished);
    }

    pub fn selectCellLocked(self: *TerminalSession, pos: SelectionPos, finished: bool) void {
        session_selection.selectCellLocked(self, pos, finished);
    }

    pub fn selectOrUpdateCellLocked(self: *TerminalSession, pos: SelectionPos) bool {
        return session_selection.selectOrUpdateCellLocked(self, pos);
    }

    pub fn selectOrderedRangeLocked(
        self: *TerminalSession,
        anchor_start: SelectionPos,
        anchor_end: SelectionPos,
        target_start: SelectionPos,
        target_end: SelectionPos,
        finished: bool,
    ) bool {
        return session_selection.selectOrderedRangeLocked(self, anchor_start, anchor_end, target_start, target_end, finished);
    }

    pub fn beginClickSelectionLocked(
        self: *TerminalSession,
        row_cells: []const Cell,
        global_row: usize,
        col: usize,
        click_count: u8,
    ) ClickSelectionResult {
        return session_selection.beginClickSelectionLocked(self, row_cells, global_row, col, click_count);
    }

    pub fn extendGestureSelectionLocked(
        self: *TerminalSession,
        gesture: SelectionGesture,
        row_cells: []const Cell,
        global_row: usize,
        col: usize,
    ) bool {
        return session_selection.extendGestureSelectionLocked(self, gesture, row_cells, global_row, col);
    }

    pub fn selectOrUpdateCellInRowLocked(
        self: *TerminalSession,
        row_cells: []const Cell,
        global_row: usize,
        col: usize,
    ) bool {
        return session_selection.selectOrUpdateCellInRowLocked(self, row_cells, global_row, col);
    }

    pub fn bracketedPasteEnabled(self: *TerminalSession) bool {
        return session_interaction.bracketedPasteEnabled(self);
    }

    pub fn focusReportingEnabled(self: *TerminalSession) bool {
        return session_interaction.focusReportingEnabled(self);
    }

    pub fn autoRepeatEnabled(self: *TerminalSession) bool {
        return session_interaction.autoRepeatEnabled(self);
    }

    pub fn mouseAlternateScrollEnabled(self: *TerminalSession) bool {
        return session_interaction.mouseAlternateScrollEnabled(self);
    }

    pub fn mouseModeX10Enabled(self: *const TerminalSession) bool {
        return session_interaction.mouseModeX10Enabled(self);
    }

    pub fn mouseModeButtonEnabled(self: *const TerminalSession) bool {
        return session_interaction.mouseModeButtonEnabled(self);
    }

    pub fn mouseModeAnyEnabled(self: *const TerminalSession) bool {
        return session_interaction.mouseModeAnyEnabled(self);
    }

    pub fn mouseModeSgrEnabled(self: *const TerminalSession) bool {
        return session_interaction.mouseModeSgrEnabled(self);
    }

    pub fn mouseModeSgrPixelsEnabled(self: *const TerminalSession) bool {
        return session_interaction.mouseModeSgrPixelsEnabled(self);
    }

    pub fn kittyPasteEvents5522Enabled(self: *TerminalSession) bool {
        return session_interaction.kittyPasteEvents5522Enabled(self);
    }

    pub fn sendKittyPasteEvent5522(self: *TerminalSession, clip: []const u8) !bool {
        return session_interaction.sendKittyPasteEvent5522(self, clip);
    }

    pub fn sendKittyPasteEvent5522WithHtml(self: *TerminalSession, clip: []const u8, html: ?[]const u8) !bool {
        return session_interaction.sendKittyPasteEvent5522WithHtml(self, clip, html);
    }

    pub fn sendKittyPasteEvent5522WithMime(self: *TerminalSession, clip: []const u8, html: ?[]const u8, uri_list: ?[]const u8) !bool {
        return session_interaction.sendKittyPasteEvent5522WithMime(self, clip, html, uri_list);
    }

    pub fn sendKittyPasteEvent5522WithMimeRich(
        self: *TerminalSession,
        clip: []const u8,
        html: ?[]const u8,
        uri_list: ?[]const u8,
        png: ?[]const u8,
    ) !bool {
        return session_interaction.sendKittyPasteEvent5522WithMimeRich(self, clip, html, uri_list, png);
    }

    pub fn mouseReportingEnabled(self: *TerminalSession) bool {
        return session_interaction.mouseReportingEnabled(self);
    }

    pub const CloseConfirmSignals = session_queries.CloseConfirmSignals;

    pub fn closeConfirmSignals(self: *TerminalSession) CloseConfirmSignals {
        return session_queries.closeConfirmSignals(self);
    }

    pub fn shouldConfirmClose(self: *TerminalSession) bool {
        return session_queries.shouldConfirmClose(self);
    }

    pub fn isAlive(self: *TerminalSession) bool {
        return session_queries.isAlive(self);
    }

    pub fn getDamage(self: *TerminalSession) ?struct {
        start_row: usize,
        end_row: usize,
        start_col: usize,
        end_col: usize,
    } {
        return session_interaction.getDamage(self);
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
    mouse_mode_sgr_pixels_1016: std.atomic.Value(bool),
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
            .mouse_mode_sgr_pixels_1016 = std.atomic.Value(bool).init(false),
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
    try std.testing.expectEqual(@as(usize, 1), session.scrollbackInfo().total_rows);
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

test "selection plain text export is terminal-owned across history and grid" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var history_row = [_]Cell{ base, base, base, base };
    history_row[0].codepoint = 'A';
    history_row[1].codepoint = 'B';
    session.history.pushRow(&history_row, false, base);

    session.primary.grid.cells.items[0] = base;
    session.primary.grid.cells.items[1] = base;
    session.primary.grid.cells.items[2] = base;
    session.primary.grid.cells.items[3] = base;
    session.primary.grid.cells.items[0].codepoint = 'C';
    session.primary.grid.cells.items[1].codepoint = 'D';

    session.startSelection(0, 1);
    session.updateSelection(1, 1);
    session.finishSelection();

    const text_opt = try session.selectionPlainTextAlloc(allocator);
    try std.testing.expect(text_opt != null);
    const text = text_opt.?;
    defer allocator.free(text);

    try std.testing.expectEqualStrings("B\nCD", text);
}

test "selectRangeLocked applies and finishes selection in one backend step" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    session.lock();
    session.selectRangeLocked(.{ .row = 0, .col = 1 }, .{ .row = 1, .col = 2 }, true);
    session.unlock();

    const selection = session.selectionState().?;
    try std.testing.expect(selection.active);
    try std.testing.expect(!selection.selecting);
    try std.testing.expectEqual(@as(usize, 0), selection.start.row);
    try std.testing.expectEqual(@as(usize, 1), selection.start.col);
    try std.testing.expectEqual(@as(usize, 1), selection.end.row);
    try std.testing.expectEqual(@as(usize, 2), selection.end.col);
}

test "selection helper clears and finishes only when active" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    session.lock();
    try std.testing.expect(!session.clearSelectionIfActiveLocked());
    try std.testing.expect(!session.finishSelectionIfActiveLocked());

    session.selectCellLocked(.{ .row = 0, .col = 1 }, false);
    try std.testing.expect(session.clearSelectionIfActiveLocked());
    try std.testing.expect(session.selectionState() == null);

    session.selectCellLocked(.{ .row = 1, .col = 0 }, false);
    try std.testing.expect(session.finishSelectionIfActiveLocked());
    session.unlock();

    const selection = session.selectionState().?;
    try std.testing.expect(selection.active);
    try std.testing.expect(!selection.selecting);
}

test "selection drag helpers update ordered ranges and late-start cells" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    session.lock();
    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[1].codepoint = 'X';

    try std.testing.expect(!session.selectOrUpdateCellInRowLocked(&[_]Cell{ base, base }, 0, 0));
    try std.testing.expect(session.selectOrUpdateCellInRowLocked(&row, 1, 1));
    var selection = session.selectionState().?;
    try std.testing.expectEqual(@as(usize, 1), selection.start.row);
    try std.testing.expectEqual(@as(usize, 1), selection.start.col);
    try std.testing.expectEqual(@as(usize, 1), selection.end.row);
    try std.testing.expectEqual(@as(usize, 1), selection.end.col);

    try std.testing.expect(session.selectOrderedRangeLocked(
        .{ .row = 1, .col = 0 },
        .{ .row = 1, .col = 1 },
        .{ .row = 0, .col = 0 },
        .{ .row = 0, .col = 1 },
        false,
    ));
    session.unlock();

    selection = session.selectionState().?;
    try std.testing.expectEqual(@as(usize, 0), selection.start.row);
    try std.testing.expectEqual(@as(usize, 0), selection.start.col);
    try std.testing.expectEqual(@as(usize, 1), selection.end.row);
    try std.testing.expectEqual(@as(usize, 1), selection.end.col);
}

test "click selection helpers own word and line gesture policy" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base, base, base };
    row[0].codepoint = 'f';
    row[1].codepoint = 'o';
    row[2].codepoint = 'o';
    row[3].codepoint = '!';

    session.lock();
    const word_click = session.beginClickSelectionLocked(&row, 3, 1, 2);
    try std.testing.expect(word_click.started);
    try std.testing.expectEqual(.word, word_click.gesture.mode);
    try std.testing.expectEqual(@as(usize, 3), word_click.gesture.row);
    try std.testing.expectEqual(@as(usize, 0), word_click.gesture.col_start);
    try std.testing.expectEqual(@as(usize, 2), word_click.gesture.col_end);

    try std.testing.expect(session.extendGestureSelectionLocked(word_click.gesture, &row, 4, 3));
    var selection = session.selectionState().?;
    try std.testing.expectEqual(@as(usize, 3), selection.start.row);
    try std.testing.expectEqual(@as(usize, 0), selection.start.col);
    try std.testing.expectEqual(@as(usize, 4), selection.end.row);
    try std.testing.expectEqual(@as(usize, 3), selection.end.col);

    session.clearSelectionLocked();
    const line_click = session.beginClickSelectionLocked(&row, 5, 2, 3);
    try std.testing.expect(line_click.started);
    try std.testing.expectEqual(.line, line_click.gesture.mode);
    try std.testing.expectEqual(@as(usize, 5), line_click.gesture.row);
    try std.testing.expectEqual(@as(usize, 3), line_click.gesture.col_end);
    session.unlock();

    selection = session.selectionState().?;
    try std.testing.expectEqual(@as(usize, 5), selection.start.row);
    try std.testing.expectEqual(@as(usize, 0), selection.start.col);
    try std.testing.expectEqual(@as(usize, 5), selection.end.row);
    try std.testing.expectEqual(@as(usize, 3), selection.end.col);
}

test "resetToLiveBottomLocked resets scrollback offset only when needed" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[0].codepoint = 'A';
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, session.primary.defaultCell());
    session.history.setScrollOffset(session.primary.grid.rows, 1);

    session.lock();
    try std.testing.expect(session.resetToLiveBottomLocked());
    try std.testing.expectEqual(@as(usize, 0), session.history.scrollOffset());
    try std.testing.expect(!session.resetToLiveBottomLocked());
    session.unlock();
}

test "scrollSelectionDragLocked scrolls history view in drag direction" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[0].codepoint = 'A';
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, session.primary.defaultCell());
    session.history.setScrollOffset(session.primary.grid.rows, 1);

    session.lock();
    try std.testing.expect(session.scrollSelectionDragLocked(false));
    try std.testing.expectEqual(@as(usize, 0), session.history.scrollOffset());
    try std.testing.expect(session.scrollSelectionDragLocked(true));
    try std.testing.expectEqual(@as(usize, 1), session.history.scrollOffset());
    session.unlock();
}

test "setScrollOffsetFromNormalizedTrackLocked maps scrollbar track ratio to history offset" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[0].codepoint = 'A';
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, session.primary.defaultCell());

    session.lock();
    try std.testing.expectEqual(@as(?usize, 3), session.setScrollOffsetFromNormalizedTrackLocked(0.0));
    try std.testing.expectEqual(@as(usize, 3), session.history.scrollOffset());
    try std.testing.expectEqual(@as(?usize, 0), session.setScrollOffsetFromNormalizedTrackLocked(1.0));
    try std.testing.expectEqual(@as(usize, 0), session.history.scrollOffset());
    session.unlock();
}

test "scrollWheelLocked applies backend wheel policy" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row = [_]Cell{ base, base };
    row[0].codepoint = 'A';
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.pushRow(&row, false, base);
    session.history.ensureViewCache(session.primary.grid.cols, session.primary.defaultCell());

    session.lock();
    try std.testing.expect(session.scrollWheelLocked(1));
    try std.testing.expectEqual(@as(usize, 3), session.history.scrollOffset());
    try std.testing.expect(session.scrollWheelLocked(-1));
    try std.testing.expectEqual(@as(usize, 0), session.history.scrollOffset());
    try std.testing.expect(!session.scrollWheelLocked(0));
    session.unlock();
}

test "scrollback plain text export is terminal-owned" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 4);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var history_row = [_]Cell{ base, base, base, base };
    history_row[0].codepoint = 'A';
    history_row[1].codepoint = 'B';
    session.history.pushRow(&history_row, false, base);

    session.primary.grid.cells.items[0] = base;
    session.primary.grid.cells.items[1] = base;
    session.primary.grid.cells.items[2] = base;
    session.primary.grid.cells.items[3] = base;
    session.primary.grid.cells.items[4] = base;
    session.primary.grid.cells.items[5] = base;
    session.primary.grid.cells.items[6] = base;
    session.primary.grid.cells.items[7] = base;
    session.primary.grid.cells.items[0].codepoint = 'C';
    session.primary.grid.cells.items[1].codepoint = 'D';
    session.primary.grid.cells.items[4].codepoint = 'E';
    session.primary.grid.cells.items[5].codepoint = 'F';

    const text = try session.scrollbackPlainTextAlloc(allocator);
    defer allocator.free(text);

    try std.testing.expectEqualStrings("AB\nCD\nEF\n", text);
}

test "scrollback ansi text export is terminal-owned" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 1, 1);
    defer session.deinit();

    var cell = session.primary.defaultCell();
    cell.codepoint = 'A';
    session.primary.grid.cells.items[0] = cell;

    const text = try session.scrollbackAnsiTextAlloc(allocator);
    defer allocator.free(text);

    const expected = try std.fmt.allocPrint(
        allocator,
        "\x1b[0;38;2;{d};{d};{d};48;2;{d};{d};{d};58;2;{d};{d};{d}mA\x1b[0m\n",
        .{
            cell.attrs.fg.r,
            cell.attrs.fg.g,
            cell.attrs.fg.b,
            cell.attrs.bg.r,
            cell.attrs.bg.g,
            cell.attrs.bg.b,
            cell.attrs.underline_color.r,
            cell.attrs.underline_color.g,
            cell.attrs.underline_color.b,
        },
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, text);
}

test "scrollback range export is terminal-owned" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 3);
    defer session.deinit();

    const base = session.primary.defaultCell();
    var row0 = [_]Cell{ base, base, base };
    var row1 = [_]Cell{ base, base, base };
    row0[0].codepoint = 'A';
    row0[1].codepoint = 'B';
    row1[0].codepoint = 'C';
    row1[1].codepoint = 'D';
    session.history.pushRow(&row0, false, base);
    session.history.pushRow(&row1, false, base);

    var cells = std.ArrayList(Cell).empty;
    defer cells.deinit(allocator);
    const range = try session.copyScrollbackRange(allocator, 0, 0, &cells);

    try std.testing.expectEqual(@as(usize, 2), range.total_rows);
    try std.testing.expectEqual(@as(usize, 2), range.row_count);
    try std.testing.expectEqual(@as(usize, 3), range.cols);
    try std.testing.expectEqual(@as(usize, 6), cells.items.len);
    try std.testing.expectEqual(@as(u32, 'A'), cells.items[0].codepoint);
    try std.testing.expectEqual(@as(u32, 'B'), cells.items[1].codepoint);
    try std.testing.expectEqual(@as(u32, 'C'), cells.items[3].codepoint);
    try std.testing.expectEqual(@as(u32, 'D'), cells.items[4].codepoint);
}

test "terminal reset republishes input snapshot state" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    session.setKeypadMode(true);
    session.setAppCursorKeys(true);
    try std.testing.expect(session.appKeypadEnabled());
    try std.testing.expect(session.input_snapshot.app_cursor_keys.load(.acquire));

    session.resetState();

    try std.testing.expect(!session.appKeypadEnabled());
    try std.testing.expect(!session.input_snapshot.app_cursor_keys.load(.acquire));
}

test "feedOutputBytes publishes keypad mode through locked parser path" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    session.feedOutputBytes("\x1b=");
    try std.testing.expect(session.appKeypadEnabled());

    session.feedOutputBytes("\x1b>");
    try std.testing.expect(!session.appKeypadEnabled());
}

test "feedOutputBytes publishes kitty key mode flags through locked parser path" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    session.feedOutputBytes("\x1b[>13u");
    try std.testing.expectEqual(@as(u32, 13), session.keyModeFlagsValue());

    session.feedOutputBytes("\x1b[<1u");
    try std.testing.expectEqual(@as(u32, 0), session.keyModeFlagsValue());
}

test "feedOutputBytes RIS resets input modes and clears screen" {
    const allocator = std.testing.allocator;

    var session = try TerminalSession.init(allocator, 2, 2);
    defer session.deinit();

    session.feedOutputBytes(
        "\x1b[?1004h" ++
            "\x1b[?2004h" ++
            "\x1b[?1002h" ++
            "\x1b[?1006h" ++
            "\x1b[?1016h" ++
            "\x1b[?1h" ++
            "\x1b=" ++
            "AB",
    );

    try std.testing.expect(session.focusReportingEnabled());
    try std.testing.expect(session.bracketedPasteEnabled());
    try std.testing.expect(session.mouseReportingEnabled());
    try std.testing.expect(session.mouseModeSgrPixelsEnabled());
    try std.testing.expect(session.appCursorKeysEnabled());
    try std.testing.expect(session.appKeypadEnabled());
    try std.testing.expectEqual(@as(u32, 'A'), session.getCell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u32, 'B'), session.getCell(0, 1).codepoint);

    session.feedOutputBytes("\x1bc");

    try std.testing.expect(!session.focusReportingEnabled());
    try std.testing.expect(!session.bracketedPasteEnabled());
    try std.testing.expect(!session.mouseReportingEnabled());
    try std.testing.expect(!session.mouseModeSgrPixelsEnabled());
    try std.testing.expect(!session.appCursorKeysEnabled());
    try std.testing.expect(!session.appKeypadEnabled());
    try std.testing.expectEqual(@as(u32, 0), session.getCell(0, 0).codepoint);
    try std.testing.expectEqual(@as(u32, 0), session.getCell(0, 1).codepoint);
}
