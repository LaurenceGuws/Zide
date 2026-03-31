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
const session_host_types = @import("session_host_types.zig");
const session_selection = @import("session_selection.zig");
const session_interaction = @import("session_interaction.zig");
const session_init_options = @import("session_init_options.zig");
const session_input_snapshot = @import("session_input_snapshot.zig");
const session_presentation_feedback = @import("session_presentation_feedback.zig");
const terminal_publication = @import("terminal_publication.zig");
const session_protocol = @import("session_protocol.zig");
const session_config = @import("session_config.zig");
const session_content_api = @import("session_content_api.zig");
const session_runtime = @import("session_runtime.zig");
const session_debug = @import("terminal_session_debug.zig");
const session_runtime_api = @import("session_runtime_api.zig");
const session_publication_api = @import("session_publication_api.zig");
const session_input_api = @import("session_input_api.zig");
const session_protocol_api = @import("session_protocol_api.zig");
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

pub const RenderCache = @import("render_cache.zig").RenderCache;

pub const TerminalSnapshot = snapshot_mod.TerminalSnapshot;
pub const DebugSnapshot = snapshot_mod.DebugSnapshot;
pub const ScrollbackInfo = session_content.ScrollbackInfo;
pub const ScrollbackRange = session_content.ScrollbackRange;
pub const SelectionGesture = session_selection.SelectionGesture;
pub const ClickSelectionResult = session_selection.ClickSelectionResult;
pub const SessionMetadata = session_host_types.SessionMetadata;
pub const ActivityMetadata = session_host_types.ActivityMetadata;
pub const ProgressMetadata = session_host_types.ProgressMetadata;
pub const ProgressState = session_host_types.ProgressState;
pub const PresentedRenderCache = terminal_publication.PresentedRenderCache;
pub const PresentationCapture = terminal_publication.PresentationCapture;
pub const AltExitPresentationInfo = terminal_publication.AltExitPresentationInfo;
pub const PresentationFeedback = terminal_publication.PresentationFeedback;

pub const PtyWriteGuard = terminal_transport.Writer;
pub const InputSnapshot = session_input_snapshot.InputSnapshot;

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

pub fn debugScrollUp(self: *TerminalSession) void {
    session_debug.debugScrollUp(self);
}

pub fn debugSetScrollOffset(self: *TerminalSession, offset: usize) void {
    session_debug.debugSetScrollOffset(self, offset);
}

pub fn debugSetScrollbackCell(self: *TerminalSession, row: usize, col: usize, codepoint: u32) void {
    session_debug.debugSetScrollbackCell(self, row, col, codepoint);
}

pub fn debugPushScrollbackRow(self: *TerminalSession, text: []const u8) void {
    session_debug.debugPushScrollbackRow(self, text);
}

pub fn debugSetGridRow(self: *TerminalSession, row_index: usize, text: []const u8) void {
    session_debug.debugSetGridRow(self, row_index, text);
}

/// Minimal terminal stub so the UI panel stays wired while backend is removed.
pub const TerminalSession = struct {
    const Self = @This();
    const ContentAPI = session_content_api.API(Self, Cell, ScrollbackInfo, ScrollbackRange);

    pub const InitOptions = session_init_options.InitOptions;
    pub const scrollbackInfo = ContentAPI.scrollbackInfo;
    pub const copyScrollbackRange = ContentAPI.copyScrollbackRange;
    pub const selectionPlainTextAlloc = ContentAPI.selectionPlainTextAlloc;
    pub const scrollbackPlainTextAlloc = ContentAPI.scrollbackPlainTextAlloc;
    pub const scrollbackAnsiTextAlloc = ContentAPI.scrollbackAnsiTextAlloc;
    pub const setScrollOffset = ContentAPI.setScrollOffset;
    pub const setScrollOffsetLocked = ContentAPI.setScrollOffsetLocked;
    pub const resetToLiveBottomLocked = ContentAPI.resetToLiveBottomLocked;
    pub const resetToLiveBottomForInputLocked = ContentAPI.resetToLiveBottomForInputLocked;
    pub const setScrollOffsetFromNormalizedTrackLocked = ContentAPI.setScrollOffsetFromNormalizedTrackLocked;
    pub const scrollSelectionDragLocked = ContentAPI.scrollSelectionDragLocked;
    pub const scrollBy = ContentAPI.scrollBy;
    pub const scrollByLocked = ContentAPI.scrollByLocked;
    pub const scrollWheelLocked = ContentAPI.scrollWheelLocked;
    pub const clearSelection = session_selection.clearSelection;
    pub const clearSelectionLocked = session_selection.clearSelectionLocked;
    pub const clearSelectionIfActiveLocked = session_selection.clearSelectionIfActiveLocked;
    pub const startSelection = session_selection.startSelection;
    pub const startSelectionLocked = session_selection.startSelectionLocked;
    pub const updateSelection = session_selection.updateSelection;
    pub const updateSelectionLocked = session_selection.updateSelectionLocked;
    pub const finishSelection = session_selection.finishSelection;
    pub const finishSelectionLocked = session_selection.finishSelectionLocked;
    pub const finishSelectionIfActiveLocked = session_selection.finishSelectionIfActiveLocked;
    pub const selectRange = session_selection.selectRange;
    pub const selectRangeLocked = session_selection.selectRangeLocked;
    pub const selectCellLocked = session_selection.selectCellLocked;
    pub const selectOrUpdateCellLocked = session_selection.selectOrUpdateCellLocked;
    pub const selectOrderedRangeLocked = session_selection.selectOrderedRangeLocked;
    pub const beginClickSelectionLocked = session_selection.beginClickSelectionLocked;
    pub const extendGestureSelectionLocked = session_selection.extendGestureSelectionLocked;
    pub const selectOrUpdateCellInRowLocked = session_selection.selectOrUpdateCellInRowLocked;
    pub const takeOscClipboardCopy = session_queries.takeOscClipboardCopy;
    pub const tryTakeOscClipboardCopy = session_queries.tryTakeOscClipboardCopy;
    pub const copyHyperlinkUri = session_queries.copyHyperlinkUri;
    pub const copyMetadata = session_host_queries.copyMetadata;
    pub const currentActivityMetadata = session_host_queries.currentActivityMetadata;
    pub const copyActivityMetadata = session_host_queries.copyActivityMetadata;
    pub const isAlive = session_host_queries.isAlive;
    pub const bracketedPasteEnabled = session_interaction.bracketedPasteEnabled;
    pub const focusReportingEnabled = session_interaction.focusReportingEnabled;
    pub const autoRepeatEnabled = session_interaction.autoRepeatEnabled;
    pub const mouseAlternateScrollEnabled = session_interaction.mouseAlternateScrollEnabled;
    pub const mouseModeX10Enabled = session_interaction.mouseModeX10Enabled;
    pub const mouseModeButtonEnabled = session_interaction.mouseModeButtonEnabled;
    pub const mouseModeAnyEnabled = session_interaction.mouseModeAnyEnabled;
    pub const mouseModeSgrEnabled = session_interaction.mouseModeSgrEnabled;
    pub const mouseModeSgrPixelsEnabled = session_interaction.mouseModeSgrPixelsEnabled;
    pub const kittyPasteEvents5522Enabled = session_interaction.kittyPasteEvents5522Enabled;
    pub const sendKittyPasteEvent5522 = session_interaction.sendKittyPasteEvent5522;
    pub const sendKittyPasteEvent5522WithHtml = session_interaction.sendKittyPasteEvent5522WithHtml;
    pub const sendKittyPasteEvent5522WithMime = session_interaction.sendKittyPasteEvent5522WithMime;
    pub const sendKittyPasteEvent5522WithMimeRich = session_interaction.sendKittyPasteEvent5522WithMimeRich;
    pub const mouseReportingEnabled = session_interaction.mouseReportingEnabled;
    pub const getDamage = session_interaction.getDamage;
    pub const keyModeFlagsValue = session_interaction.keyModeFlagsValue;
    pub const keyModePush = session_interaction.keyModePush;
    pub const keyModePushLocked = session_interaction.keyModePushLocked;
    pub const keyModePop = session_interaction.keyModePop;
    pub const keyModePopLocked = session_interaction.keyModePopLocked;
    pub const keyModeModify = session_interaction.keyModeModify;
    pub const keyModeModifyLocked = session_interaction.keyModeModifyLocked;
    pub const keyModeQuery = session_interaction.keyModeQuery;
    pub const keyModeQueryLocked = session_interaction.keyModeQueryLocked;
    pub const setAppCursorKeys = session_interaction.setAppCursorKeys;
    pub const setAppCursorKeysLocked = session_interaction.setAppCursorKeysLocked;
    pub const setAutoRepeat = session_interaction.setAutoRepeat;
    pub const setAutoRepeatLocked = session_interaction.setAutoRepeatLocked;
    pub const setBracketedPaste = session_interaction.setBracketedPaste;
    pub const setBracketedPasteLocked = session_interaction.setBracketedPasteLocked;
    pub const setFocusReporting = session_interaction.setFocusReporting;
    pub const setFocusReportingLocked = session_interaction.setFocusReportingLocked;
    pub const setMouseAlternateScroll = session_interaction.setMouseAlternateScroll;
    pub const setMouseAlternateScrollLocked = session_interaction.setMouseAlternateScrollLocked;
    pub const setMouseModeX10 = session_interaction.setMouseModeX10;
    pub const setMouseModeX10Locked = session_interaction.setMouseModeX10Locked;
    pub const setMouseModeButton = session_interaction.setMouseModeButton;
    pub const setMouseModeButtonLocked = session_interaction.setMouseModeButtonLocked;
    pub const setMouseModeAny = session_interaction.setMouseModeAny;
    pub const setMouseModeAnyLocked = session_interaction.setMouseModeAnyLocked;
    pub const setMouseModeSgr = session_interaction.setMouseModeSgr;
    pub const setMouseModeSgrLocked = session_interaction.setMouseModeSgrLocked;
    pub const setMouseModeSgrPixels = session_interaction.setMouseModeSgrPixels;
    pub const setMouseModeSgrPixelsLocked = session_interaction.setMouseModeSgrPixelsLocked;
    pub const resetInputModes = session_interaction.resetInputModes;
    pub const resetInputModesLocked = session_interaction.resetInputModesLocked;
    pub const setKeypadMode = session_interaction.setKeypadMode;
    pub const setKeypadModeLocked = session_interaction.setKeypadModeLocked;

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
    parse_publishes_since_log: usize,
    parse_bytes_since_log: usize,
    last_parse_publish_ms: i64,
    parse_bytes_since_publish: usize,
    render_caches: [2]RenderCache,
    render_cache_index: std.atomic.Value(u8),
    view_cache_pending: std.atomic.Value(bool),
    view_cache_request_offset: std.atomic.Value(u64),
    child_exited: std.atomic.Value(bool),
    child_exit_code: std.atomic.Value(i32),
    launch_shell_path: ?[]u8,
    tearing_down: bool,

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
        session_runtime.setInputPressure(self, value);
    }

    fn updateViewCacheNoLock(self: *TerminalSession, generation: u64, scroll_offset: usize) void {
        terminal_publication.updateViewCacheNoLock(self, generation, scroll_offset);
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

    pub const prepareForShutdown = session_runtime_api.prepareForShutdown;
    pub const start = session_runtime_api.start;
    pub const attachPtyTransport = session_runtime_api.attachPtyTransport;
    pub const detachPtyTransport = session_runtime_api.detachPtyTransport;
    pub const startNoThreads = session_runtime_api.startNoThreads;
    pub const setLaunchShellPath = session_runtime_api.setLaunchShellPath;
    pub const launchShellPath = session_runtime_api.launchShellPath;
    pub const attachExternalTransport = session_runtime_api.attachExternalTransport;
    pub const enqueueExternalBytes = session_runtime_api.enqueueExternalBytes;
    pub const closeExternalTransport = session_runtime_api.closeExternalTransport;
    pub const reportExternalChildExit = session_runtime_api.reportExternalChildExit;
    pub const takeExternalOutgoingBytes = session_runtime_api.takeExternalOutgoingBytes;
    pub const poll = session_runtime_api.poll;
    pub const refreshChildExit = session_runtime_api.refreshChildExit;
    pub const hasData = session_runtime_api.hasData;

    pub fn lock(self: *TerminalSession) void {
        self.state_mutex.lock();
    }

    pub fn tryLock(self: *TerminalSession) bool {
        return self.state_mutex.tryLock();
    }

    pub fn unlock(self: *TerminalSession) void {
        self.state_mutex.unlock();
    }

    pub const currentGeneration = session_publication_api.currentGeneration;
    pub const publishedGeneration = session_publication_api.publishedGeneration;
    pub const presentedGeneration = session_publication_api.presentedGeneration;
    pub const notePresentedGeneration = session_publication_api.notePresentedGeneration;
    pub const acknowledgePresentedGeneration = session_publication_api.acknowledgePresentedGeneration;
    pub const hasPublishedGenerationBacklog = session_publication_api.hasPublishedGenerationBacklog;
    pub const pollBacklogHint = session_runtime_api.pollBacklogHint;
    pub const lockPtyWriter = session_runtime_api.lockPtyWriter;
    pub const writePtyBytes = session_runtime_api.writePtyBytes;

    pub const sendKey = session_input_api.sendKey;
    pub const sendKeyAction = session_input_api.sendKeyAction;
    pub const sendKeyActionWithMetadata = session_input_api.sendKeyActionWithMetadata;
    pub const sendKeypad = session_input_api.sendKeypad;
    pub const sendKeypadAction = session_input_api.sendKeypadAction;
    pub const appKeypadEnabled = session_input_api.appKeypadEnabled;
    pub const appCursorKeysEnabled = session_input_api.appCursorKeysEnabled;
    pub const sendChar = session_input_api.sendChar;
    pub const sendCharAction = session_input_api.sendCharAction;
    pub const sendCharActionWithMetadata = session_input_api.sendCharActionWithMetadata;
    pub const reportMouseEvent = session_input_api.reportMouseEvent;
    pub const reportAlternateScrollWheel = session_input_api.reportAlternateScrollWheel;
    pub const sendText = session_input_api.sendText;
    pub const sendBytes = session_input_api.sendBytes;
    pub const reportFocusChanged = session_input_api.reportFocusChanged;
    pub const reportColorSchemeChanged = session_input_api.reportColorSchemeChanged;

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

    pub const handleControl = session_protocol_api.handleControl;
    pub const parseDcs = session_protocol_api.parseDcs;
    pub const parseApc = session_protocol_api.parseApc;
    pub const parseOsc = session_protocol_api.parseOsc;
    pub fn appendHyperlink(self: *TerminalSession, uri: []const u8) ?u32 {
        return session_protocol_api.appendHyperlink(self, uri, max_hyperlinks);
    }
    pub const clearAllKittyImages = session_protocol_api.clearAllKittyImages;
    pub const handleCsi = session_protocol_api.handleCsi;
    pub const feedOutputBytes = session_protocol_api.feedOutputBytes;
    pub const resetState = session_protocol_api.resetState;
    pub const resetStateLocked = session_protocol_api.resetStateLocked;
    pub const reverseIndex = session_protocol_api.reverseIndex;
    pub const eraseDisplay = session_protocol_api.eraseDisplay;
    pub const eraseLine = session_protocol_api.eraseLine;
    pub const insertChars = session_protocol_api.insertChars;
    pub const deleteChars = session_protocol_api.deleteChars;
    pub const eraseChars = session_protocol_api.eraseChars;
    pub const insertLines = session_protocol_api.insertLines;
    pub const deleteLines = session_protocol_api.deleteLines;
    pub const scrollRegionUp = session_protocol_api.scrollRegionUp;
    pub const scrollRegionUpWithOrigin = session_protocol_api.scrollRegionUpWithOrigin;
    pub const scrollRegionDown = session_protocol_api.scrollRegionDown;
    pub const paletteColor = session_protocol_api.paletteColor;
    pub const handleCodepoint = session_protocol_api.handleCodepoint;
    pub const handleAsciiSlice = session_protocol_api.handleAsciiSlice;
    pub const newline = session_protocol_api.newline;
    pub const wrapNewline = session_protocol_api.wrapNewline;

    fn scrollUp(self: *TerminalSession) void {
        scrolling_mod.scrollUp(self);
    }

    pub const getCell = session_protocol_api.getCell;
    pub const getCursorPos = session_protocol_api.getCursorPos;

    pub fn updateViewCacheForScroll(self: *TerminalSession) void {
        terminal_publication.updateViewCacheForScroll(self);
    }

    pub fn updateViewCacheForScrollLocked(self: *TerminalSession) void {
        terminal_publication.updateViewCacheForScrollLocked(self);
    }

    pub const setCursorStyle = session_protocol_api.setCursorStyle;
    pub const decrqssReplyInto = session_protocol_api.decrqssReplyInto;
    pub const saveCursor = session_protocol_api.saveCursor;
    pub const restoreCursor = session_protocol_api.restoreCursor;
    pub const setTabAtCursor = session_protocol_api.setTabAtCursor;
    pub const enterAltScreen = session_protocol_api.enterAltScreen;
    pub const exitAltScreen = session_protocol_api.exitAltScreen;

    pub const snapshot = session_publication_api.snapshot;
    pub const renderCache = session_publication_api.renderCache;
    pub const copyPublishedRenderCache = session_publication_api.copyPublishedRenderCache;
    pub const capturePresentation = session_publication_api.capturePresentation;
    pub const completePresentationFeedback = session_publication_api.completePresentationFeedback;
    pub const finishFramePresentation = session_publication_api.finishFramePresentation;
    pub const syncUpdatesActive = session_publication_api.syncUpdatesActive;
    pub const setSyncUpdates = session_publication_api.setSyncUpdates;
    pub const setSyncUpdatesLocked = session_publication_api.setSyncUpdatesLocked;
    pub const clearPublishedDamageIfGeneration = session_publication_api.clearPublishedDamageIfGeneration;

    pub const CloseConfirmSignals = session_host_types.CloseConfirmSignals;
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
