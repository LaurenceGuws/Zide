const std = @import("std");
const pty_mod = @import("../io/pty.zig");
const input_mod = @import("../input/input.zig");
const history_mod = @import("../model/history.zig");
const csi_mod = @import("../parser/csi.zig");
const parser_mod = @import("../parser/parser.zig");
const protocol_csi = @import("../protocol/csi.zig");
const screen_mod = @import("../model/screen.zig");
const snapshot_mod = @import("snapshot.zig");
const types = @import("../model/types.zig");
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
const terminal_core_mod = @import("terminal_core.zig");
const session_host_queries = @import("session_host_queries.zig");
const session_queries = @import("session_queries.zig");
const session_content = @import("session_content.zig");
const session_selection = @import("session_selection.zig");
const session_input = @import("session_input.zig");
const session_interaction = @import("session_interaction.zig");
const session_rendering = @import("session_rendering.zig");
const session_protocol = @import("session_protocol.zig");
const session_config = @import("session_config.zig");
const session_runtime = @import("session_runtime.zig");
const session_debug = @import("terminal_session_debug.zig");
const osc_kitty_clipboard = @import("../protocol/osc_kitty_clipboard.zig");
const terminal_transport = @import("terminal_transport.zig");
const Pty = pty_mod.Pty;
const PtySize = pty_mod.PtySize;
const Screen = screen_mod.Screen;
const Dirty = screen_mod.Dirty;
const Damage = screen_mod.Damage;
const OscTerminator = parser_mod.OscTerminator;
const Charset = parser_mod.Charset;
const CharsetTarget = parser_mod.CharsetTarget;

const SemanticPromptKind = semantic_prompt_mod.SemanticPromptKind;
const SemanticPromptState = semantic_prompt_mod.SemanticPromptState;
const TerminalCoreType = terminal_core_mod.TerminalCore;
const ActiveScreen = terminal_core_mod.ActiveScreen;
pub const TerminalCore = terminal_core_mod.TerminalCore;

pub const KittyImageFormat = snapshot_mod.KittyImageFormat;
pub const KittyImage = snapshot_mod.KittyImage;
pub const KittyPlacement = snapshot_mod.KittyPlacement;

const RenderCache = @import("render_cache.zig").RenderCache;

pub const TerminalSnapshot = snapshot_mod.TerminalSnapshot;
pub const DebugSnapshot = snapshot_mod.DebugSnapshot;
pub const ScrollbackInfo = session_content.ScrollbackInfo;
pub const ScrollbackRange = session_content.ScrollbackRange;
pub const SelectionGesture = session_selection.SelectionGesture;
pub const ClickSelectionResult = session_selection.ClickSelectionResult;
pub const SessionMetadata = session_host_queries.SessionMetadata;
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

pub const PtyWriteGuard = terminal_transport.Writer;

pub fn debugSnapshot(self: *TerminalSession) DebugSnapshot {
    return session_debug.debugSnapshot(self);
}

pub fn debugScrollbackRow(self: *TerminalSession, index: usize) ?[]const Cell {
    return session_debug.debugScrollbackRow(self, index);
}

pub fn debugSetCursor(self: *TerminalSession, row: usize, col: usize) void {
    session_debug.debugSetCursor(self, row, col);
}

pub fn debugFeedBytes(self: *TerminalSession, bytes: []const u8) void {
    session_debug.debugFeedBytes(self, bytes);
}

/// Minimal terminal stub so the UI panel stays wired while backend is removed.
pub const TerminalSession = struct {
    allocator: std.mem.Allocator,
    pty: ?Pty,
    external_transport: ?terminal_transport.ExternalTransport,
    core: TerminalCoreType,
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
    read_thread: ?std.Thread,
    read_thread_running: std.atomic.Value(bool),
    parse_thread: ?std.Thread,
    parse_thread_running: std.atomic.Value(bool),
    state_mutex: std.Thread.Mutex,
    io_mutex: std.Thread.Mutex,
    io_wait_cond: std.Thread.Condition,
    io_buffer: std.ArrayList(u8),
    io_read_offset: usize,
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
        return try session_runtime.init(allocator, rows, cols, options);
    }

    pub fn activeScreen(self: *TerminalSession) *Screen {
        return self.core.activeScreen();
    }

    pub fn activeScreenConst(self: *const TerminalSession) *const Screen {
        return self.core.activeScreenConst();
    }

    pub fn setInputPressure(self: *TerminalSession, value: bool) void {
        self.input_pressure.store(value, .release);
    }

    fn updateViewCacheNoLock(self: *TerminalSession, generation: u64, scroll_offset: usize) void {
        session_rendering.updateViewCacheNoLock(self, generation, scroll_offset);
    }

    pub fn isAltActive(self: *const TerminalSession) bool {
        return self.core.isAltActive();
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
        session_runtime.deinit(self);
    }

    pub fn start(self: *TerminalSession, shell: ?[:0]const u8) !void {
        try session_runtime.start(self, shell);
    }

    pub fn attachPtyTransport(self: *TerminalSession, pty: Pty) void {
        session_runtime.attachPtyTransport(self, pty);
    }

    pub fn detachPtyTransport(self: *TerminalSession) void {
        session_runtime.detachPtyTransport(self);
    }

    pub fn startNoThreads(self: *TerminalSession, shell: ?[:0]const u8) !void {
        try session_runtime.startNoThreads(self, shell);
    }

    pub fn attachExternalTransport(self: *TerminalSession) void {
        session_runtime.attachExternalTransport(self);
    }

    pub fn enqueueExternalBytes(self: *TerminalSession, bytes: []const u8) !bool {
        return try session_runtime.enqueueExternalBytes(self, bytes);
    }

    pub fn closeExternalTransport(self: *TerminalSession) bool {
        return session_runtime.closeExternalTransport(self);
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
        return session_runtime.pollBacklogHint(self);
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
        session_rendering.updateViewCacheForScroll(self);
    }

    pub fn updateViewCacheForScrollLocked(self: *TerminalSession) void {
        session_rendering.updateViewCacheForScrollLocked(self);
    }

    pub fn keyModeFlagsValue(self: *TerminalSession) u32 {
        return session_interaction.keyModeFlagsValue(self);
    }

    pub fn keyModePush(self: *TerminalSession, flags: u32) void {
        session_interaction.keyModePush(self, flags);
    }

    pub fn keyModePushLocked(self: *TerminalSession, flags: u32) void {
        session_interaction.keyModePushLocked(self, flags);
    }

    pub fn keyModePop(self: *TerminalSession, count: usize) void {
        session_interaction.keyModePop(self, count);
    }

    pub fn keyModePopLocked(self: *TerminalSession, count: usize) void {
        session_interaction.keyModePopLocked(self, count);
    }

    pub fn keyModeModify(self: *TerminalSession, flags: u32, mode: u32) void {
        session_interaction.keyModeModify(self, flags, mode);
    }

    pub fn keyModeModifyLocked(self: *TerminalSession, flags: u32, mode: u32) void {
        session_interaction.keyModeModifyLocked(self, flags, mode);
    }

    pub fn keyModeQuery(self: *TerminalSession) void {
        session_interaction.keyModeQuery(self);
    }

    pub fn keyModeQueryLocked(self: *TerminalSession) void {
        session_interaction.keyModeQueryLocked(self);
    }

    pub fn setAppCursorKeys(self: *TerminalSession, enabled: bool) void {
        session_interaction.setAppCursorKeys(self, enabled);
    }

    pub fn setAppCursorKeysLocked(self: *TerminalSession, enabled: bool) void {
        session_interaction.setAppCursorKeysLocked(self, enabled);
    }

    pub fn setAutoRepeat(self: *TerminalSession, enabled: bool) void {
        session_interaction.setAutoRepeat(self, enabled);
    }

    pub fn setAutoRepeatLocked(self: *TerminalSession, enabled: bool) void {
        session_interaction.setAutoRepeatLocked(self, enabled);
    }

    pub fn setBracketedPaste(self: *TerminalSession, enabled: bool) void {
        session_interaction.setBracketedPaste(self, enabled);
    }

    pub fn setBracketedPasteLocked(self: *TerminalSession, enabled: bool) void {
        session_interaction.setBracketedPasteLocked(self, enabled);
    }

    pub fn setFocusReporting(self: *TerminalSession, enabled: bool) void {
        session_interaction.setFocusReporting(self, enabled);
    }

    pub fn setFocusReportingLocked(self: *TerminalSession, enabled: bool) void {
        session_interaction.setFocusReportingLocked(self, enabled);
    }

    pub fn setMouseAlternateScroll(self: *TerminalSession, enabled: bool) void {
        session_interaction.setMouseAlternateScroll(self, enabled);
    }

    pub fn setMouseAlternateScrollLocked(self: *TerminalSession, enabled: bool) void {
        session_interaction.setMouseAlternateScrollLocked(self, enabled);
    }

    pub fn setMouseModeX10(self: *TerminalSession, enabled: bool) void {
        session_interaction.setMouseModeX10(self, enabled);
    }

    pub fn setMouseModeX10Locked(self: *TerminalSession, enabled: bool) void {
        session_interaction.setMouseModeX10Locked(self, enabled);
    }

    pub fn setMouseModeButton(self: *TerminalSession, enabled: bool) void {
        session_interaction.setMouseModeButton(self, enabled);
    }

    pub fn setMouseModeButtonLocked(self: *TerminalSession, enabled: bool) void {
        session_interaction.setMouseModeButtonLocked(self, enabled);
    }

    pub fn setMouseModeAny(self: *TerminalSession, enabled: bool) void {
        session_interaction.setMouseModeAny(self, enabled);
    }

    pub fn setMouseModeAnyLocked(self: *TerminalSession, enabled: bool) void {
        session_interaction.setMouseModeAnyLocked(self, enabled);
    }

    pub fn setMouseModeSgr(self: *TerminalSession, enabled: bool) void {
        session_interaction.setMouseModeSgr(self, enabled);
    }

    pub fn setMouseModeSgrLocked(self: *TerminalSession, enabled: bool) void {
        session_interaction.setMouseModeSgrLocked(self, enabled);
    }

    pub fn setMouseModeSgrPixels(self: *TerminalSession, enabled: bool) void {
        session_interaction.setMouseModeSgrPixels(self, enabled);
    }

    pub fn setMouseModeSgrPixelsLocked(self: *TerminalSession, enabled: bool) void {
        session_interaction.setMouseModeSgrPixelsLocked(self, enabled);
    }

    pub fn resetInputModes(self: *TerminalSession) void {
        session_interaction.resetInputModes(self);
    }

    pub fn resetInputModesLocked(self: *TerminalSession) void {
        session_interaction.resetInputModesLocked(self);
    }

    pub fn setCursorStyle(self: *TerminalSession, mode: i32) void {
        session_protocol.setCursorStyle(self, mode);
    }

    pub fn decrqssReplyInto(self: *TerminalSession, text: []const u8, buf: []u8) ?[]const u8 {
        return session_protocol.decrqssReplyInto(self, text, buf);
    }

    pub fn saveCursor(self: *TerminalSession) void {
        session_protocol.saveCursor(self);
    }

    pub fn setKeypadMode(self: *TerminalSession, enabled: bool) void {
        session_interaction.setKeypadMode(self, enabled);
    }

    pub fn setKeypadModeLocked(self: *TerminalSession, enabled: bool) void {
        session_interaction.setKeypadModeLocked(self, enabled);
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
        session_rendering.finishFramePresentation(self, feedback);
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

    pub fn takeOscClipboardCopy(self: *TerminalSession, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) !bool {
        return session_queries.takeOscClipboardCopy(self, allocator, out);
    }

    pub fn tryTakeOscClipboardCopy(self: *TerminalSession, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) !bool {
        return session_queries.tryTakeOscClipboardCopy(self, allocator, out);
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
        return session_host_queries.copyMetadata(self, allocator, title_out, cwd_out);
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

    pub const CloseConfirmSignals = session_host_queries.CloseConfirmSignals;

    pub fn closeConfirmSignals(self: *TerminalSession) CloseConfirmSignals {
        return session_host_queries.closeConfirmSignals(self);
    }

    pub fn shouldConfirmClose(self: *TerminalSession) bool {
        return session_host_queries.shouldConfirmClose(self);
    }

    pub fn isAlive(self: *TerminalSession) bool {
        return session_host_queries.isAlive(self);
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

pub const default_scrollback_rows: usize = 1000;
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
