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
const parser_hooks = @import("protocol/parser_hooks.zig");
const input_modes = @import("input_modes.zig");
const hyperlink_table = @import("hyperlink_table.zig");
const terminal_core_mod = @import("terminal_core.zig");
const session_host_queries = @import("session/session_host_queries.zig");
const session_queries = @import("session/session_queries.zig");
const session_content = @import("session/session_content.zig");
const session_host_types = @import("session/session_host_types.zig");
const session_selection = @import("session/session_selection.zig");
const session_interaction = @import("session/session_interaction.zig");
const session_init_options = @import("session/session_init_options.zig");
const session_input_snapshot = @import("session/session_input_snapshot.zig");
const session_presentation_feedback = @import("session/session_presentation_feedback.zig");
const terminal_publication = @import("publication/terminal_publication.zig");
const session_config = @import("session/session_config.zig");
const session_runtime = @import("session/session_runtime.zig");
const session_debug_api = @import("session/session_debug_api.zig");
const session_runtime_api = @import("session/session_runtime_api.zig");
const session_publication_api = @import("session/session_publication_api.zig");
const session_publication_fields = @import("session/session_publication_fields.zig");
const session_runtime_fields = @import("session/session_runtime_fields.zig");
const session_interaction_fields = @import("session/session_interaction_fields.zig");
const session_control_fields = @import("session/session_control_fields.zig");
const session_input_api = @import("session/session_input_api.zig");
const terminal_protocol_api = @import("protocol/terminal_protocol_api.zig");
const session_config_api = @import("session/session_config_api.zig");
const session_lifecycle_api = @import("session/session_lifecycle_api.zig");
const session_surface_api = @import("session/session_surface_api.zig");
const session_types_api = @import("session/session_types_api.zig");
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
pub const TerminalCore = terminal_core_mod.TerminalCore;

pub const KittyImageFormat = snapshot_mod.KittyImageFormat;
pub const KittyImage = snapshot_mod.KittyImage;
pub const KittyPlacement = snapshot_mod.KittyPlacement;

pub const RenderCache = @import("publication/render_cache.zig").RenderCache;

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

pub const debugSnapshot = session_debug_api.debugSnapshot;
pub const debugScrollbackRow = session_debug_api.debugScrollbackRow;
pub const debugSetCursor = session_debug_api.debugSetCursor;
pub const debugFeedBytes = session_debug_api.debugFeedBytes;
pub const debugScrollUp = session_debug_api.debugScrollUp;
pub const debugSetScrollOffset = session_debug_api.debugSetScrollOffset;
pub const debugSetScrollbackCell = session_debug_api.debugSetScrollbackCell;
pub const debugPushScrollbackRow = session_debug_api.debugPushScrollbackRow;
pub const debugSetGridRow = session_debug_api.debugSetGridRow;

pub const PtyTerminalRuntime = struct {
    const Self = @This();
    const SurfaceAPI = session_surface_api.API(Self, Cell, ScrollbackInfo, ScrollbackRange);

    pub const InitOptions = session_init_options.InitOptions;
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
    runtime: session_runtime_fields.Fields,
    core: TerminalCoreType,
    interaction: session_interaction_fields.Fields,
    publication: session_publication_fields.Fields,
    control: session_control_fields.Fields,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*PtyTerminalRuntime {
        return session_lifecycle_api.init(PtyTerminalRuntime, allocator, rows, cols);
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, rows: u16, cols: u16, options: InitOptions) !*PtyTerminalRuntime {
        return session_lifecycle_api.initWithOptions(PtyTerminalRuntime, allocator, rows, cols, options);
    }

    pub const activeScreen = session_lifecycle_api.activeScreen;
    pub const activeScreenConst = session_lifecycle_api.activeScreenConst;
    pub const setInputPressure = session_lifecycle_api.setInputPressure;

    pub const isAltActive = session_lifecycle_api.isAltActive;

    pub const setDefaultColorsLocked = session_config_api.setDefaultColorsLocked;
    pub const setDefaultColors = session_config_api.setDefaultColors;
    pub const setAnsiColors = session_config_api.setAnsiColors;
    pub const remapAnsiColors = session_config_api.remapAnsiColors;
    pub const setPaletteColorLocked = session_config_api.setPaletteColorLocked;
    pub const resetPaletteColorLocked = session_config_api.resetPaletteColorLocked;
    pub const resetAllPaletteColorsLocked = session_config_api.resetAllPaletteColorsLocked;
    pub const setDynamicColorCodeLocked = session_config_api.setDynamicColorCodeLocked;
    pub const applyThemePalette = session_config_api.applyThemePalette;

    pub const deinit = session_lifecycle_api.deinit;

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

    pub const lock = session_lifecycle_api.lock;
    pub const tryLock = session_lifecycle_api.tryLock;
    pub const unlock = session_lifecycle_api.unlock;

    pub const pendingGeneration = session_publication_api.pendingGeneration;
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

    pub const resize = session_lifecycle_api.resize;

    pub const setColumnMode132 = session_config_api.setColumnMode132;
    pub const setColumnMode132Locked = session_config_api.setColumnMode132Locked;
    pub const setCellSize = session_config_api.setCellSize;

    pub const handleControl = terminal_protocol_api.handleControl;
    pub const parseDcs = terminal_protocol_api.parseDcs;
    pub const parseApc = terminal_protocol_api.parseApc;
    pub const parseOsc = terminal_protocol_api.parseOsc;
    pub const appendHyperlink = terminal_protocol_api.appendHyperlink;
    pub const clearAllKittyImages = terminal_protocol_api.clearAllKittyImages;
    pub const handleCsi = terminal_protocol_api.handleCsi;
    pub const feedOutputBytes = terminal_protocol_api.feedOutputBytes;
    pub const resetState = terminal_protocol_api.resetState;
    pub const resetStateLocked = terminal_protocol_api.resetStateLocked;
    pub const reverseIndex = terminal_protocol_api.reverseIndex;
    pub const eraseDisplay = terminal_protocol_api.eraseDisplay;
    pub const eraseLine = terminal_protocol_api.eraseLine;
    pub const insertChars = terminal_protocol_api.insertChars;
    pub const deleteChars = terminal_protocol_api.deleteChars;
    pub const eraseChars = terminal_protocol_api.eraseChars;
    pub const insertLines = terminal_protocol_api.insertLines;
    pub const deleteLines = terminal_protocol_api.deleteLines;
    pub const scrollRegionUp = terminal_protocol_api.scrollRegionUp;
    pub const scrollRegionUpWithOrigin = terminal_protocol_api.scrollRegionUpWithOrigin;
    pub const scrollRegionDown = terminal_protocol_api.scrollRegionDown;
    pub const paletteColor = terminal_protocol_api.paletteColor;
    pub const handleCodepoint = terminal_protocol_api.handleCodepoint;
    pub const handleAsciiSlice = terminal_protocol_api.handleAsciiSlice;
    pub const newline = terminal_protocol_api.newline;
    pub const wrapNewline = terminal_protocol_api.wrapNewline;

    fn scrollUp(self: *PtyTerminalRuntime) void {
        scrolling_mod.scrollUp(self);
    }

    pub const getCell = terminal_protocol_api.getCell;
    pub const getCursorPos = terminal_protocol_api.getCursorPos;

    pub const updateViewCacheForScroll = session_publication_api.updateViewCacheForScroll;
    pub const updateViewCacheForScrollLocked = session_publication_api.updateViewCacheForScrollLocked;

    pub const setCursorStyle = terminal_protocol_api.setCursorStyle;
    pub const decrqssReplyInto = terminal_protocol_api.decrqssReplyInto;
    pub const saveCursor = terminal_protocol_api.saveCursor;
    pub const restoreCursor = terminal_protocol_api.restoreCursor;
    pub const setTabAtCursor = terminal_protocol_api.setTabAtCursor;
    pub const enterAltScreen = terminal_protocol_api.enterAltScreen;
    pub const exitAltScreen = terminal_protocol_api.exitAltScreen;

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

pub const Hyperlink = session_types_api.Hyperlink;

pub const VTERM_KEY_NONE = session_types_api.VTERM_KEY_NONE;
pub const VTERM_KEY_ENTER = session_types_api.VTERM_KEY_ENTER;
pub const VTERM_KEY_TAB = session_types_api.VTERM_KEY_TAB;
pub const VTERM_KEY_BACKSPACE = session_types_api.VTERM_KEY_BACKSPACE;
pub const VTERM_KEY_ESCAPE = session_types_api.VTERM_KEY_ESCAPE;
pub const VTERM_KEY_UP = session_types_api.VTERM_KEY_UP;
pub const VTERM_KEY_DOWN = session_types_api.VTERM_KEY_DOWN;
pub const VTERM_KEY_LEFT = session_types_api.VTERM_KEY_LEFT;
pub const VTERM_KEY_RIGHT = session_types_api.VTERM_KEY_RIGHT;
pub const VTERM_KEY_INS = session_types_api.VTERM_KEY_INS;
pub const VTERM_KEY_DEL = session_types_api.VTERM_KEY_DEL;
pub const VTERM_KEY_HOME = session_types_api.VTERM_KEY_HOME;
pub const VTERM_KEY_END = session_types_api.VTERM_KEY_END;
pub const VTERM_KEY_PAGEUP = session_types_api.VTERM_KEY_PAGEUP;
pub const VTERM_KEY_PAGEDOWN = session_types_api.VTERM_KEY_PAGEDOWN;
pub const VTERM_KEY_LEFT_SHIFT = session_types_api.VTERM_KEY_LEFT_SHIFT;
pub const VTERM_KEY_RIGHT_SHIFT = session_types_api.VTERM_KEY_RIGHT_SHIFT;
pub const VTERM_KEY_LEFT_CTRL = session_types_api.VTERM_KEY_LEFT_CTRL;
pub const VTERM_KEY_RIGHT_CTRL = session_types_api.VTERM_KEY_RIGHT_CTRL;
pub const VTERM_KEY_LEFT_ALT = session_types_api.VTERM_KEY_LEFT_ALT;
pub const VTERM_KEY_RIGHT_ALT = session_types_api.VTERM_KEY_RIGHT_ALT;
pub const VTERM_KEY_LEFT_SUPER = session_types_api.VTERM_KEY_LEFT_SUPER;
pub const VTERM_KEY_RIGHT_SUPER = session_types_api.VTERM_KEY_RIGHT_SUPER;
pub const KeypadKey = session_types_api.KeypadKey;
pub const KeyAction = session_types_api.KeyAction;

pub const VTERM_MOD_NONE = session_types_api.VTERM_MOD_NONE;
pub const VTERM_MOD_SHIFT = session_types_api.VTERM_MOD_SHIFT;
pub const VTERM_MOD_ALT = session_types_api.VTERM_MOD_ALT;
pub const VTERM_MOD_CTRL = session_types_api.VTERM_MOD_CTRL;

pub const default_scrollback_rows: usize = session_types_api.default_scrollback_rows;
const key_mode_disambiguate: u32 = 1;
const key_mode_report_all_event_types: u32 = 2;
const key_mode_report_alternate_key: u32 = 4;
const key_mode_report_text: u32 = 8;
const key_mode_embed_text: u32 = 16;

const mouse_button_left_mask: u8 = 1;
const mouse_button_middle_mask: u8 = 2;
const mouse_button_right_mask: u8 = 4;
pub const CursorPos = session_types_api.CursorPos;
pub const SelectionPos = session_types_api.SelectionPos;
pub const TerminalSelection = session_types_api.TerminalSelection;
pub const Cell = session_types_api.Cell;
pub const CellAttrs = session_types_api.CellAttrs;
pub const Color = session_types_api.Color;
pub const Key = session_types_api.Key;
pub const Modifier = session_types_api.Modifier;
pub const MouseButton = session_types_api.MouseButton;
pub const MouseEventKind = session_types_api.MouseEventKind;
pub const MouseEvent = session_types_api.MouseEvent;
