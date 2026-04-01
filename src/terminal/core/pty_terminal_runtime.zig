const std = @import("std");
const pty_mod = @import("../io/pty.zig");
const input_mod = @import("../input/input.zig");
const history_mod = @import("../model/history.zig");
const csi_mod = @import("../parser/csi.zig");
const parser_mod = @import("../parser/parser.zig");
const protocol_csi = @import("../protocol/csi.zig");
const screen_mod = @import("../model/screen.zig");
const snapshot_mod = @import("publication/snapshot.zig");
const types = @import("../model/types.zig");
const kitty_mod = @import("../kitty/graphics.zig");
const semantic_prompt_mod = @import("semantic_prompt.zig");
const palette_mod = @import("../protocol/palette.zig");
const pty_io = @import("runtime/pty_io.zig");
const view_cache = @import("publication/view_cache.zig");
const resize_reflow = @import("resize_reflow.zig");
const selection_mod = @import("selection.zig");
const scrolling_mod = @import("scrolling.zig");
const control_handlers = @import("protocol/control_handlers.zig");
const input_modes = @import("input_modes.zig");
const hyperlink_table = @import("hyperlink_table.zig");
const terminal_core_mod = @import("terminal_core.zig");
const host_queries = @import("session/host_queries.zig");
const queries = @import("session/queries.zig");
const content = @import("session/content.zig");
const host_types = @import("session/host_types.zig");
const host_selection = @import("session/selection.zig");
const interaction = @import("session/interaction.zig");
const init_options = @import("session/init_options.zig");
const input_snapshot = @import("session/input_snapshot.zig");
const mode_effects = @import("session/mode_effects.zig");
const presentation_feedback = @import("session/presentation_feedback.zig");
const terminal_publication = @import("publication/terminal_publication.zig");
const config = @import("session/config.zig");
const runtime = @import("session/runtime.zig");
const debug_api = @import("session/debug_api.zig");
const runtime_api = @import("session/runtime_api.zig");
const publication_fields = @import("session/publication_fields.zig");
const runtime_fields = @import("session/runtime_fields.zig");
const interaction_fields = @import("session/interaction_fields.zig");
const control_fields = @import("session/control_fields.zig");
const input_api = @import("session/input_api.zig");
const config_api = @import("session/config_api.zig");
const lifecycle_api = @import("session/lifecycle_api.zig");
const surface_api = @import("session/surface_api.zig");
const types_api = @import("session/types_api.zig");
const osc_kitty_clipboard = @import("../protocol/osc_kitty_clipboard.zig");
const terminal_transport = @import("runtime/terminal_transport.zig");
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
const TerminalCore = terminal_core_mod.TerminalCore;

const KittyImageFormat = snapshot_mod.KittyImageFormat;
const KittyImage = snapshot_mod.KittyImage;
const KittyPlacement = snapshot_mod.KittyPlacement;

const RenderCache = @import("publication/render_cache.zig").RenderCache;

const TerminalSnapshot = snapshot_mod.TerminalSnapshot;
const DebugSnapshot = snapshot_mod.DebugSnapshot;
const ScrollbackInfo = content.ScrollbackInfo;
const ScrollbackRange = content.ScrollbackRange;
const SelectionGesture = host_selection.SelectionGesture;
const ClickSelectionResult = host_selection.ClickSelectionResult;
const SessionMetadata = host_types.SessionMetadata;
const ActivityMetadata = host_types.ActivityMetadata;
const ProgressMetadata = host_types.ProgressMetadata;
const ProgressState = host_types.ProgressState;
const PresentedRenderCache = terminal_publication.PresentedRenderCache;
const PresentationCapture = terminal_publication.PresentationCapture;
const AltExitPresentationInfo = terminal_publication.AltExitPresentationInfo;
const PresentationFeedback = terminal_publication.PresentationFeedback;

const PtyWriteGuard = terminal_transport.Writer;
const InputSnapshot = input_snapshot.InputSnapshot;

const debugSnapshot = debug_api.debugSnapshot;
const debugScrollbackRow = debug_api.debugScrollbackRow;
const debugSetCursor = debug_api.debugSetCursor;
const debugFeedBytes = debug_api.debugFeedBytes;
const debugScrollUp = debug_api.debugScrollUp;
const debugSetScrollOffset = debug_api.debugSetScrollOffset;
const debugSetScrollbackCell = debug_api.debugSetScrollbackCell;
const debugPushScrollbackRow = debug_api.debugPushScrollbackRow;
const debugSetGridRow = debug_api.debugSetGridRow;

pub const PtyTerminalRuntime = struct {
    const Self = @This();
    const SurfaceAPI = surface_api.API(Self, Cell, ScrollbackInfo, ScrollbackRange);

    pub const InitOptions = init_options.InitOptions;
    pub const scrollbackInfo = SurfaceAPI.scrollbackInfo;
    pub const copyScrollbackRange = SurfaceAPI.copyScrollbackRange;
    pub const selectionPlainTextAlloc = SurfaceAPI.selectionPlainTextAlloc;
    pub const scrollbackPlainTextAlloc = SurfaceAPI.scrollbackPlainTextAlloc;
    pub const scrollbackAnsiTextAlloc = SurfaceAPI.scrollbackAnsiTextAlloc;
    pub const setScrollOffset = SurfaceAPI.setScrollOffset;
    pub const setScrollOffsetLocked = SurfaceAPI.setScrollOffsetLocked;
    pub const resetToLiveBottomLocked = SurfaceAPI.resetToLiveBottomLocked;
    pub const resetToLiveBottomForInputLocked = SurfaceAPI.resetToLiveBottomForInputLocked;
    pub const setScrollOffsetFromNormalizedTrackLocked = SurfaceAPI.setScrollOffsetFromNormalizedTrackLocked;
    pub const scrollSelectionDragLocked = SurfaceAPI.scrollSelectionDragLocked;
    pub const scrollBy = SurfaceAPI.scrollBy;
    pub const scrollByLocked = SurfaceAPI.scrollByLocked;
    pub const scrollWheelLocked = SurfaceAPI.scrollWheelLocked;
    pub const clearSelection = SurfaceAPI.clearSelection;
    pub const clearSelectionLocked = SurfaceAPI.clearSelectionLocked;
    pub const clearSelectionIfActiveLocked = SurfaceAPI.clearSelectionIfActiveLocked;
    pub const startSelection = SurfaceAPI.startSelection;
    pub const startSelectionLocked = SurfaceAPI.startSelectionLocked;
    pub const updateSelection = SurfaceAPI.updateSelection;
    pub const updateSelectionLocked = SurfaceAPI.updateSelectionLocked;
    pub const finishSelection = SurfaceAPI.finishSelection;
    pub const finishSelectionLocked = SurfaceAPI.finishSelectionLocked;
    pub const finishSelectionIfActiveLocked = SurfaceAPI.finishSelectionIfActiveLocked;
    pub const selectRange = SurfaceAPI.selectRange;
    pub const selectRangeLocked = SurfaceAPI.selectRangeLocked;
    pub const selectCellLocked = SurfaceAPI.selectCellLocked;
    pub const selectOrUpdateCellLocked = SurfaceAPI.selectOrUpdateCellLocked;
    pub const selectOrderedRangeLocked = SurfaceAPI.selectOrderedRangeLocked;
    pub const beginClickSelectionLocked = SurfaceAPI.beginClickSelectionLocked;
    pub const extendGestureSelectionLocked = SurfaceAPI.extendGestureSelectionLocked;
    pub const selectOrUpdateCellInRowLocked = SurfaceAPI.selectOrUpdateCellInRowLocked;
    pub const takeOscClipboardCopy = SurfaceAPI.takeOscClipboardCopy;
    pub const tryTakeOscClipboardCopy = SurfaceAPI.tryTakeOscClipboardCopy;
    pub const copyHyperlinkUri = SurfaceAPI.copyHyperlinkUri;
    pub const copyMetadata = SurfaceAPI.copyMetadata;
    pub const titleText = SurfaceAPI.titleText;
    pub const displayTitleText = SurfaceAPI.displayTitleText;
    pub const cwdText = SurfaceAPI.cwdText;
    pub const altScreenActive = SurfaceAPI.altScreenActive;
    pub const currentActivityMetadata = SurfaceAPI.currentActivityMetadata;
    pub const copyActivityMetadata = SurfaceAPI.copyActivityMetadata;
    pub const isAlive = SurfaceAPI.isAlive;
    pub const bracketedPasteEnabled = SurfaceAPI.bracketedPasteEnabled;
    pub const focusReportingEnabled = SurfaceAPI.focusReportingEnabled;
    pub const autoRepeatEnabled = SurfaceAPI.autoRepeatEnabled;
    pub const mouseAlternateScrollEnabled = SurfaceAPI.mouseAlternateScrollEnabled;
    pub const mouseModeX10Enabled = SurfaceAPI.mouseModeX10Enabled;
    pub const mouseModeButtonEnabled = SurfaceAPI.mouseModeButtonEnabled;
    pub const mouseModeAnyEnabled = SurfaceAPI.mouseModeAnyEnabled;
    pub const mouseModeSgrEnabled = SurfaceAPI.mouseModeSgrEnabled;
    pub const mouseModeSgrPixelsEnabled = SurfaceAPI.mouseModeSgrPixelsEnabled;
    pub const kittyPasteEvents5522Enabled = SurfaceAPI.kittyPasteEvents5522Enabled;
    pub const sendKittyPasteEvent5522 = SurfaceAPI.sendKittyPasteEvent5522;
    pub const sendKittyPasteEvent5522WithHtml = SurfaceAPI.sendKittyPasteEvent5522WithHtml;
    pub const sendKittyPasteEvent5522WithMime = SurfaceAPI.sendKittyPasteEvent5522WithMime;
    pub const sendKittyPasteEvent5522WithMimeRich = SurfaceAPI.sendKittyPasteEvent5522WithMimeRich;
    pub const mouseReportingEnabled = SurfaceAPI.mouseReportingEnabled;
    pub const getDamage = SurfaceAPI.getDamage;
    pub const keyModeFlagsValue = SurfaceAPI.keyModeFlagsValue;
    pub const keyModePush = SurfaceAPI.keyModePush;
    pub const keyModePushLocked = SurfaceAPI.keyModePushLocked;
    pub const keyModePop = SurfaceAPI.keyModePop;
    pub const keyModePopLocked = SurfaceAPI.keyModePopLocked;
    pub const keyModeModify = SurfaceAPI.keyModeModify;
    pub const keyModeModifyLocked = SurfaceAPI.keyModeModifyLocked;
    pub const keyModeQuery = SurfaceAPI.keyModeQuery;
    pub const keyModeQueryLocked = SurfaceAPI.keyModeQueryLocked;
    pub const setAppCursorKeys = SurfaceAPI.setAppCursorKeys;
    pub const setAppCursorKeysLocked = SurfaceAPI.setAppCursorKeysLocked;
    pub const setAutoRepeat = SurfaceAPI.setAutoRepeat;
    pub const setAutoRepeatLocked = SurfaceAPI.setAutoRepeatLocked;
    pub const setBracketedPaste = SurfaceAPI.setBracketedPaste;
    pub const setBracketedPasteLocked = SurfaceAPI.setBracketedPasteLocked;
    pub const setFocusReporting = SurfaceAPI.setFocusReporting;
    pub const setFocusReportingLocked = SurfaceAPI.setFocusReportingLocked;
    pub const setMouseAlternateScroll = SurfaceAPI.setMouseAlternateScroll;
    pub const setMouseAlternateScrollLocked = SurfaceAPI.setMouseAlternateScrollLocked;
    pub const setMouseModeX10 = SurfaceAPI.setMouseModeX10;
    pub const setMouseModeX10Locked = SurfaceAPI.setMouseModeX10Locked;
    pub const setMouseModeButton = SurfaceAPI.setMouseModeButton;
    pub const setMouseModeButtonLocked = SurfaceAPI.setMouseModeButtonLocked;
    pub const setMouseModeAny = SurfaceAPI.setMouseModeAny;
    pub const setMouseModeAnyLocked = SurfaceAPI.setMouseModeAnyLocked;
    pub const setMouseModeSgr = SurfaceAPI.setMouseModeSgr;
    pub const setMouseModeSgrLocked = SurfaceAPI.setMouseModeSgrLocked;
    pub const setMouseModeSgrPixels = SurfaceAPI.setMouseModeSgrPixels;
    pub const setMouseModeSgrPixelsLocked = SurfaceAPI.setMouseModeSgrPixelsLocked;
    pub const resetInputModes = SurfaceAPI.resetInputModes;
    pub const resetInputModesLocked = SurfaceAPI.resetInputModesLocked;
    pub const setKeypadMode = SurfaceAPI.setKeypadMode;
    pub const setKeypadModeLocked = SurfaceAPI.setKeypadModeLocked;

    allocator: std.mem.Allocator,
    runtime: runtime_fields.Fields,
    core: TerminalCoreType,
    interaction: interaction_fields.Fields,
    publication: publication_fields.Fields,
    control: control_fields.Fields,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*PtyTerminalRuntime {
        return lifecycle_api.init(PtyTerminalRuntime, allocator, rows, cols);
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, rows: u16, cols: u16, options: InitOptions) !*PtyTerminalRuntime {
        return lifecycle_api.initWithOptions(PtyTerminalRuntime, allocator, rows, cols, options);
    }

    pub const activeScreen = lifecycle_api.activeScreen;
    pub const activeScreenConst = lifecycle_api.activeScreenConst;
    pub const setInputPressure = lifecycle_api.setInputPressure;

    pub const isAltActive = lifecycle_api.isAltActive;

    pub const setDefaultColorsLocked = config_api.setDefaultColorsLocked;
    pub const setDefaultColors = config_api.setDefaultColors;
    pub const setAnsiColors = config_api.setAnsiColors;
    pub const remapAnsiColors = config_api.remapAnsiColors;
    pub const setPaletteColorLocked = config_api.setPaletteColorLocked;
    pub const resetPaletteColorLocked = config_api.resetPaletteColorLocked;
    pub const resetAllPaletteColorsLocked = config_api.resetAllPaletteColorsLocked;
    pub const setDynamicColorCodeLocked = config_api.setDynamicColorCodeLocked;
    pub const applyThemePalette = config_api.applyThemePalette;
    pub const setConfiguredCursorStyle = config_api.setConfiguredCursorStyle;

    pub const deinit = lifecycle_api.deinit;

    pub const prepareForShutdown = runtime_api.prepareForShutdown;
    pub const start = runtime_api.start;
    pub const attachPtyTransport = runtime_api.attachPtyTransport;
    pub const detachPtyTransport = runtime_api.detachPtyTransport;
    pub const startNoThreads = runtime_api.startNoThreads;
    pub const setLaunchShellPath = runtime_api.setLaunchShellPath;
    pub const launchShellPath = runtime_api.launchShellPath;
    pub const attachExternalTransport = runtime_api.attachExternalTransport;
    pub const enqueueExternalBytes = runtime_api.enqueueExternalBytes;
    pub const closeExternalTransport = runtime_api.closeExternalTransport;
    pub const reportExternalChildExit = runtime_api.reportExternalChildExit;
    pub const takeExternalOutgoingBytes = runtime_api.takeExternalOutgoingBytes;
    pub const poll = runtime_api.poll;
    pub const refreshChildExit = runtime_api.refreshChildExit;
    pub const hasData = runtime_api.hasData;

    pub const lock = lifecycle_api.lock;
    pub const tryLock = lifecycle_api.tryLock;
    pub const unlock = lifecycle_api.unlock;

    pub const pendingGeneration = terminal_publication.pendingGeneration;
    pub const publishedGeneration = terminal_publication.publishedGeneration;
    pub const presentedGeneration = terminal_publication.presentedGeneration;
    pub const notePresentedGeneration = terminal_publication.notePresentedGeneration;
    pub const acknowledgePresentedGeneration = terminal_publication.acknowledgePresentedGeneration;
    pub const hasPublishedGenerationBacklog = terminal_publication.hasPublishedGenerationBacklog;
    pub const pollBacklogHint = runtime_api.pollBacklogHint;
    pub const lockPtyWriter = runtime_api.lockPtyWriter;
    pub const writePtyBytes = runtime_api.writePtyBytes;

    pub const sendKey = input_api.sendKey;
    pub const sendKeyAction = input_api.sendKeyAction;
    pub const sendKeyActionWithMetadata = input_api.sendKeyActionWithMetadata;
    pub const sendKeypad = input_api.sendKeypad;
    pub const sendKeypadAction = input_api.sendKeypadAction;
    pub const appKeypadEnabled = input_api.appKeypadEnabled;
    pub const appCursorKeysEnabled = input_api.appCursorKeysEnabled;
    pub const sendChar = input_api.sendChar;
    pub const sendCharAction = input_api.sendCharAction;
    pub const sendCharActionWithMetadata = input_api.sendCharActionWithMetadata;
    pub const reportMouseEvent = input_api.reportMouseEvent;
    pub const reportAlternateScrollWheel = input_api.reportAlternateScrollWheel;
    pub const sendText = input_api.sendText;
    pub const sendBytes = input_api.sendBytes;
    pub const reportFocusChanged = input_api.reportFocusChanged;
    pub const reportColorSchemeChanged = input_api.reportColorSchemeChanged;

    pub const resize = lifecycle_api.resize;

    pub const setColumnMode132 = config_api.setColumnMode132;
    pub const setColumnMode132Locked = config_api.setColumnMode132Locked;
    pub const setCellSize = config_api.setCellSize;

    pub const handleControl = control_handlers.handleControl;
    pub const parseDcs = @import("../protocol/dcs_apc.zig").parseDcs;
    pub const parseApc = @import("../protocol/dcs_apc.zig").parseApc;
    pub const parseOsc = @import("../protocol/osc.zig").parseOsc;
    pub const appendHyperlink = appendHyperlinkImpl;
    pub const clearAllKittyImages = @import("protocol/terminal_core_protocol.zig").clearAllKittyImages;
    pub const handleCsi = protocol_csi.handleCsi;
    pub const feedOutputBytes = feedOutputBytesImpl;
    pub const resetState = resetStateImpl;
    pub const resetStateLocked = mode_effects.resetStateLocked;
    pub const reverseIndex = @import("protocol/terminal_core_protocol.zig").reverseIndex;
    pub const eraseDisplay = @import("protocol/terminal_core_protocol.zig").eraseDisplay;
    pub const eraseLine = @import("protocol/terminal_core_protocol.zig").eraseLine;
    pub const insertChars = @import("protocol/terminal_core_protocol.zig").insertChars;
    pub const deleteChars = @import("protocol/terminal_core_protocol.zig").deleteChars;
    pub const eraseChars = @import("protocol/terminal_core_protocol.zig").eraseChars;
    pub const insertLines = @import("protocol/terminal_core_protocol.zig").insertLines;
    pub const deleteLines = @import("protocol/terminal_core_protocol.zig").deleteLines;
    pub const scrollRegionUp = @import("protocol/terminal_core_protocol.zig").scrollRegionUp;
    pub const scrollRegionUpWithOrigin = @import("protocol/terminal_core_protocol.zig").scrollRegionUpWithOrigin;
    pub const scrollRegionDown = @import("protocol/terminal_core_protocol.zig").scrollRegionDown;
    pub const paletteColor = @import("protocol/terminal_core_protocol.zig").paletteColor;
    pub const handleCodepoint = @import("protocol/terminal_core_text.zig").handleCodepoint;
    pub const handleAsciiSlice = @import("protocol/terminal_core_text.zig").handleAsciiSlice;
    pub const newline = @import("protocol/terminal_core_protocol.zig").newline;
    pub const wrapNewline = @import("protocol/terminal_core_protocol.zig").wrapNewline;

    fn scrollUp(self: *PtyTerminalRuntime) void {
        scrolling_mod.scrollUp(self);
    }

    pub const getCell = @import("protocol/terminal_core_protocol.zig").getCell;
    pub const getCursorPos = @import("protocol/terminal_core_protocol.zig").getCursorPos;

    pub const updateViewCacheForScroll = terminal_publication.updateViewCacheForScroll;
    pub const updateViewCacheForScrollLocked = terminal_publication.updateViewCacheForScrollLocked;

    pub const setCursorStyle = @import("protocol/terminal_core_protocol.zig").setCursorStyle;
    pub const decrqssReplyInto = @import("protocol/terminal_core_protocol.zig").decrqssReplyInto;
    pub const saveCursor = @import("terminal_core_modes.zig").saveCursor;
    pub const restoreCursor = @import("terminal_core_modes.zig").restoreCursor;
    pub const setTabAtCursor = @import("protocol/terminal_core_protocol.zig").setTabAtCursor;
    pub const enterAltScreen = mode_effects.enterAltScreen;
    pub const exitAltScreen = mode_effects.exitAltScreen;

    pub const snapshot = terminal_publication.snapshot;
    pub const renderCache = terminal_publication.renderCache;
    pub const copyPublishedRenderCache = terminal_publication.copyPublishedRenderCache;
    pub const capturePresentation = terminal_publication.capturePresentation;
    pub const completePresentationFeedback = terminal_publication.completePresentationFeedback;
    pub const finishFramePresentation = terminal_publication.finishFramePresentation;
    pub const syncUpdatesActive = terminal_publication.syncUpdatesActive;
    pub const setSyncUpdates = terminal_publication.setSyncUpdates;
    pub const setSyncUpdatesLocked = terminal_publication.setSyncUpdatesLocked;
    pub const clearPublishedDamageIfGeneration = terminal_publication.clearPublishedDamageIfGeneration;

    pub const CloseConfirmSignals = host_types.CloseConfirmSignals;
};

fn appendHyperlinkImpl(self: anytype, uri: []const u8) ?u32 {
    return @import("protocol/terminal_core_protocol.zig").appendHyperlink(self, uri, 2048);
}

fn feedOutputBytesImpl(self: anytype, bytes: []const u8) void {
    self.control.state_mutex.lock();
    defer self.control.state_mutex.unlock();
    const result = @import("protocol/terminal_core_feed.zig").feedOutputBytesLocked(self, bytes);
    terminal_publication.publishFeedResultLocked(self, result);
}

fn resetStateImpl(self: anytype) void {
    self.control.state_mutex.lock();
    defer self.control.state_mutex.unlock();
    mode_effects.resetStateLocked(self);
}

const Hyperlink = types_api.Hyperlink;

const VTERM_KEY_NONE = types_api.VTERM_KEY_NONE;
const VTERM_KEY_ENTER = types_api.VTERM_KEY_ENTER;
const VTERM_KEY_TAB = types_api.VTERM_KEY_TAB;
const VTERM_KEY_BACKSPACE = types_api.VTERM_KEY_BACKSPACE;
const VTERM_KEY_ESCAPE = types_api.VTERM_KEY_ESCAPE;
const VTERM_KEY_UP = types_api.VTERM_KEY_UP;
const VTERM_KEY_DOWN = types_api.VTERM_KEY_DOWN;
const VTERM_KEY_LEFT = types_api.VTERM_KEY_LEFT;
const VTERM_KEY_RIGHT = types_api.VTERM_KEY_RIGHT;
const VTERM_KEY_INS = types_api.VTERM_KEY_INS;
const VTERM_KEY_DEL = types_api.VTERM_KEY_DEL;
const VTERM_KEY_HOME = types_api.VTERM_KEY_HOME;
const VTERM_KEY_END = types_api.VTERM_KEY_END;
const VTERM_KEY_PAGEUP = types_api.VTERM_KEY_PAGEUP;
const VTERM_KEY_PAGEDOWN = types_api.VTERM_KEY_PAGEDOWN;
const VTERM_KEY_LEFT_SHIFT = types_api.VTERM_KEY_LEFT_SHIFT;
const VTERM_KEY_RIGHT_SHIFT = types_api.VTERM_KEY_RIGHT_SHIFT;
const VTERM_KEY_LEFT_CTRL = types_api.VTERM_KEY_LEFT_CTRL;
const VTERM_KEY_RIGHT_CTRL = types_api.VTERM_KEY_RIGHT_CTRL;
const VTERM_KEY_LEFT_ALT = types_api.VTERM_KEY_LEFT_ALT;
const VTERM_KEY_RIGHT_ALT = types_api.VTERM_KEY_RIGHT_ALT;
const VTERM_KEY_LEFT_SUPER = types_api.VTERM_KEY_LEFT_SUPER;
const VTERM_KEY_RIGHT_SUPER = types_api.VTERM_KEY_RIGHT_SUPER;
const KeypadKey = types_api.KeypadKey;
const KeyAction = types_api.KeyAction;

const VTERM_MOD_NONE = types_api.VTERM_MOD_NONE;
const VTERM_MOD_SHIFT = types_api.VTERM_MOD_SHIFT;
const VTERM_MOD_ALT = types_api.VTERM_MOD_ALT;
const VTERM_MOD_CTRL = types_api.VTERM_MOD_CTRL;

const default_scrollback_rows: usize = types_api.default_scrollback_rows;
const key_mode_disambiguate: u32 = 1;
const key_mode_report_all_event_types: u32 = 2;
const key_mode_report_alternate_key: u32 = 4;
const key_mode_report_text: u32 = 8;
const key_mode_embed_text: u32 = 16;

const mouse_button_left_mask: u8 = 1;
const mouse_button_middle_mask: u8 = 2;
const mouse_button_right_mask: u8 = 4;
const CursorPos = types_api.CursorPos;
const SelectionPos = types_api.SelectionPos;
const TerminalSelection = types_api.TerminalSelection;
const Cell = types_api.Cell;
const CellAttrs = types_api.CellAttrs;
const Color = types_api.Color;
const Key = types_api.Key;
const Modifier = types_api.Modifier;
const MouseButton = types_api.MouseButton;
const MouseEventKind = types_api.MouseEventKind;
const MouseEvent = types_api.MouseEvent;
