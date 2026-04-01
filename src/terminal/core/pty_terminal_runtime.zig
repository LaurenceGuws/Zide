const std = @import("std");
const input_mod = @import("../input/input.zig");
const pty_io = @import("runtime/pty_io.zig");
const view_cache = @import("publication/view_cache.zig");
const resize_reflow = @import("resize_reflow.zig");
const input_modes = @import("input_modes.zig");
const hyperlink_table = @import("hyperlink_table.zig");
const terminal_core_mod = @import("terminal_core.zig");
const host_queries = @import("session/host_queries.zig");
const queries = @import("session/queries.zig");
const content = @import("session/content.zig");
const host_types = @import("session/host_types.zig");
const host_selection = @import("session/selection.zig");
const interaction = @import("session/interaction.zig");
const session_input = @import("session/input.zig");
const init_options = @import("session/init_options.zig");
const input_snapshot = @import("session/input_snapshot.zig");
const control = @import("session/control.zig");
const mode_effects = @import("session/mode_effects.zig");
const presentation_feedback = @import("session/presentation_feedback.zig");
const terminal_publication = @import("publication/terminal_publication.zig");
const config = @import("session/config.zig");
const runtime = @import("session/runtime.zig");
const session_debug = @import("session/debug_ops.zig");
const publication_fields = @import("session/publication_fields.zig");
const runtime_fields = @import("session/runtime_fields.zig");
const interaction_fields = @import("session/interaction_fields.zig");
const control_fields = @import("session/control_fields.zig");
const osc_kitty_clipboard = @import("../protocol/osc_kitty_clipboard.zig");
const terminal_transport = @import("runtime/terminal_transport.zig");
const TerminalCoreType = terminal_core_mod.TerminalCore;

pub const PtyTerminalRuntime = struct {
    const Self = @This();

    pub const InitOptions = init_options.InitOptions;
    pub const scrollbackInfo = content.scrollbackInfo;
    pub const copyScrollbackRange = content.copyScrollbackRange;
    pub const selectionPlainTextAlloc = content.selectionPlainTextAlloc;
    pub const scrollbackPlainTextAlloc = content.scrollbackPlainTextAlloc;
    pub const scrollbackAnsiTextAlloc = content.scrollbackAnsiTextAlloc;
    pub const setScrollOffset = content.setScrollOffset;
    pub const setScrollOffsetLocked = content.setScrollOffsetLocked;
    pub const resetToLiveBottomLocked = content.resetToLiveBottomLocked;
    pub const resetToLiveBottomForInputLocked = content.resetToLiveBottomForInputLocked;
    pub const setScrollOffsetFromNormalizedTrackLocked = content.setScrollOffsetFromNormalizedTrackLocked;
    pub const scrollSelectionDragLocked = content.scrollSelectionDragLocked;
    pub const scrollBy = content.scrollBy;
    pub const scrollByLocked = content.scrollByLocked;
    pub const scrollWheelLocked = content.scrollWheelLocked;
    pub const clearSelection = host_selection.clearSelection;
    pub const clearSelectionLocked = host_selection.clearSelectionLocked;
    pub const clearSelectionIfActiveLocked = host_selection.clearSelectionIfActiveLocked;
    pub const startSelection = host_selection.startSelection;
    pub const startSelectionLocked = host_selection.startSelectionLocked;
    pub const updateSelection = host_selection.updateSelection;
    pub const updateSelectionLocked = host_selection.updateSelectionLocked;
    pub const finishSelection = host_selection.finishSelection;
    pub const finishSelectionLocked = host_selection.finishSelectionLocked;
    pub const finishSelectionIfActiveLocked = host_selection.finishSelectionIfActiveLocked;
    pub const selectRange = host_selection.selectRange;
    pub const selectRangeLocked = host_selection.selectRangeLocked;
    pub const selectCellLocked = host_selection.selectCellLocked;
    pub const selectOrUpdateCellLocked = host_selection.selectOrUpdateCellLocked;
    pub const selectOrderedRangeLocked = host_selection.selectOrderedRangeLocked;
    pub const beginClickSelectionLocked = host_selection.beginClickSelectionLocked;
    pub const extendGestureSelectionLocked = host_selection.extendGestureSelectionLocked;
    pub const selectOrUpdateCellInRowLocked = host_selection.selectOrUpdateCellInRowLocked;
    pub const takeOscClipboardCopy = queries.takeOscClipboardCopy;
    pub const tryTakeOscClipboardCopy = queries.tryTakeOscClipboardCopy;
    pub const copyHyperlinkUri = queries.copyHyperlinkUri;
    pub const copyMetadata = host_queries.copyMetadata;
    pub const titleText = host_queries.titleText;
    pub const displayTitleText = host_queries.displayTitleText;
    pub const cwdText = host_queries.cwdText;
    pub const altScreenActive = host_queries.altScreenActive;
    pub const currentActivityMetadata = host_queries.currentActivityMetadata;
    pub const copyActivityMetadata = host_queries.copyActivityMetadata;
    pub const isAlive = host_queries.isAlive;
    pub const bracketedPasteEnabled = interaction.bracketedPasteEnabled;
    pub const focusReportingEnabled = interaction.focusReportingEnabled;
    pub const autoRepeatEnabled = interaction.autoRepeatEnabled;
    pub const mouseAlternateScrollEnabled = interaction.mouseAlternateScrollEnabled;
    pub const mouseModeX10Enabled = interaction.mouseModeX10Enabled;
    pub const mouseModeButtonEnabled = interaction.mouseModeButtonEnabled;
    pub const mouseModeAnyEnabled = interaction.mouseModeAnyEnabled;
    pub const mouseModeSgrEnabled = interaction.mouseModeSgrEnabled;
    pub const mouseModeSgrPixelsEnabled = interaction.mouseModeSgrPixelsEnabled;
    pub const kittyPasteEvents5522Enabled = interaction.kittyPasteEvents5522Enabled;
    pub const sendKittyPasteEvent5522 = interaction.sendKittyPasteEvent5522;
    pub const sendKittyPasteEvent5522WithHtml = interaction.sendKittyPasteEvent5522WithHtml;
    pub const sendKittyPasteEvent5522WithMime = interaction.sendKittyPasteEvent5522WithMime;
    pub const sendKittyPasteEvent5522WithMimeRich = interaction.sendKittyPasteEvent5522WithMimeRich;
    pub const mouseReportingEnabled = interaction.mouseReportingEnabled;
    pub const getDamage = interaction.getDamage;
    pub const keyModeFlagsValue = interaction.keyModeFlagsValue;
    pub const keyModePush = interaction.keyModePush;
    pub const keyModePushLocked = interaction.keyModePushLocked;
    pub const keyModePop = interaction.keyModePop;
    pub const keyModePopLocked = interaction.keyModePopLocked;
    pub const keyModeModify = interaction.keyModeModify;
    pub const keyModeModifyLocked = interaction.keyModeModifyLocked;
    pub const keyModeQuery = interaction.keyModeQuery;
    pub const keyModeQueryLocked = interaction.keyModeQueryLocked;
    pub const setAppCursorKeys = interaction.setAppCursorKeys;
    pub const setAppCursorKeysLocked = interaction.setAppCursorKeysLocked;
    pub const setAutoRepeat = interaction.setAutoRepeat;
    pub const setAutoRepeatLocked = interaction.setAutoRepeatLocked;
    pub const setBracketedPaste = interaction.setBracketedPaste;
    pub const setBracketedPasteLocked = interaction.setBracketedPasteLocked;
    pub const setFocusReporting = interaction.setFocusReporting;
    pub const setFocusReportingLocked = interaction.setFocusReportingLocked;
    pub const setMouseAlternateScroll = interaction.setMouseAlternateScroll;
    pub const setMouseAlternateScrollLocked = interaction.setMouseAlternateScrollLocked;
    pub const setMouseModeX10 = interaction.setMouseModeX10;
    pub const setMouseModeX10Locked = interaction.setMouseModeX10Locked;
    pub const setMouseModeButton = interaction.setMouseModeButton;
    pub const setMouseModeButtonLocked = interaction.setMouseModeButtonLocked;
    pub const setMouseModeAny = interaction.setMouseModeAny;
    pub const setMouseModeAnyLocked = interaction.setMouseModeAnyLocked;
    pub const setMouseModeSgr = interaction.setMouseModeSgr;
    pub const setMouseModeSgrLocked = interaction.setMouseModeSgrLocked;
    pub const setMouseModeSgrPixels = interaction.setMouseModeSgrPixels;
    pub const setMouseModeSgrPixelsLocked = interaction.setMouseModeSgrPixelsLocked;
    pub const resetInputModes = interaction.resetInputModes;
    pub const resetInputModesLocked = interaction.resetInputModesLocked;
    pub const setKeypadMode = interaction.setKeypadMode;
    pub const setKeypadModeLocked = interaction.setKeypadModeLocked;

    allocator: std.mem.Allocator,
    runtime: runtime_fields.Fields,
    core: TerminalCoreType,
    interaction: interaction_fields.Fields,
    publication: publication_fields.Fields,
    control: control_fields.Fields,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*PtyTerminalRuntime {
        return initWithOptions(allocator, rows, cols, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, rows: u16, cols: u16, options: InitOptions) !*PtyTerminalRuntime {
        return try runtime.init(PtyTerminalRuntime, allocator, rows, cols, options);
    }

    pub const setInputPressure = runtime.setInputPressure;

    pub const setDefaultColorsLocked = config.setDefaultColorsLocked;
    pub const setDefaultColors = config.setDefaultColors;
    pub const setAnsiColors = config.setAnsiColors;
    pub const remapAnsiColors = config.remapAnsiColors;
    pub const setPaletteColorLocked = config.setPaletteColorLocked;
    pub const resetPaletteColorLocked = config.resetPaletteColorLocked;
    pub const resetAllPaletteColorsLocked = config.resetAllPaletteColorsLocked;
    pub const setDynamicColorCodeLocked = config.setDynamicColorCodeLocked;
    pub const applyThemePalette = config.applyThemePalette;
    pub const setConfiguredCursorStyle = config.setConfiguredCursorStyle;

    pub const deinit = runtime.deinit;

    pub const prepareForShutdown = runtime.prepareForShutdown;
    pub const start = runtime.start;
    pub const attachPtyTransport = runtime.attachPtyTransport;
    pub const detachPtyTransport = runtime.detachPtyTransport;
    pub const startNoThreads = runtime.startNoThreads;
    pub const attachExternalTransport = runtime.attachExternalTransport;
    pub const enqueueExternalBytes = runtime.enqueueExternalBytes;
    pub const closeExternalTransport = runtime.closeExternalTransport;
    pub const reportExternalChildExit = runtime.reportExternalChildExit;
    pub const takeExternalOutgoingBytes = runtime.takeExternalOutgoingBytes;
    pub const poll = runtime.poll;
    pub const refreshChildExit = runtime.refreshChildExit;
    pub const hasData = runtime.hasData;

    pub const setLaunchShellPath = runtime.setLaunchShellPath;
    pub const launchShellPath = runtime.launchShellPath;
    pub const lock = control.lock;
    pub const tryLock = control.tryLock;
    pub const unlock = control.unlock;

    pub const pendingGeneration = terminal_publication.pendingGeneration;
    pub const publishedGeneration = terminal_publication.publishedGeneration;
    pub const presentedGeneration = terminal_publication.presentedGeneration;
    pub const notePresentedGeneration = terminal_publication.notePresentedGeneration;
    pub const acknowledgePresentedGeneration = terminal_publication.acknowledgePresentedGeneration;
    pub const hasPublishedGenerationBacklog = terminal_publication.hasPublishedGenerationBacklog;
    pub const pollBacklogHint = runtime.pollBacklogHint;
    pub const lockPtyWriter = runtime.lockPtyWriter;
    pub const writePtyBytes = runtime.writePtyBytes;

    pub const sendKey = session_input.sendKey;
    pub const sendKeyAction = session_input.sendKeyAction;
    pub const sendKeyActionWithMetadata = session_input.sendKeyActionWithMetadata;
    pub const sendKeypad = session_input.sendKeypad;
    pub const sendKeypadAction = session_input.sendKeypadAction;
    pub const appKeypadEnabled = session_input.appKeypadEnabled;
    pub const appCursorKeysEnabled = session_input.appCursorKeysEnabled;
    pub const sendChar = session_input.sendChar;
    pub const sendCharAction = session_input.sendCharAction;
    pub const sendCharActionWithMetadata = session_input.sendCharActionWithMetadata;
    pub const reportMouseEvent = session_input.reportMouseEvent;
    pub const reportAlternateScrollWheel = session_input.reportAlternateScrollWheel;
    pub const sendText = session_input.sendText;
    pub const sendBytes = session_input.sendBytes;
    pub const reportFocusChanged = session_input.reportFocusChanged;
    pub const reportColorSchemeChanged = session_input.reportColorSchemeChanged;

    pub const resize = runtime.resize;

    pub const setColumnMode132 = config.setColumnMode132;
    pub const setColumnMode132Locked = config.setColumnMode132Locked;
    pub const setCellSize = config.setCellSize;

    pub const appendHyperlink = @import("protocol/terminal_core_protocol.zig").appendHyperlink2048;
    pub const feedOutputBytes = @import("protocol/terminal_core_feed.zig").feedOutputBytes;
    pub const resetState = mode_effects.resetState;
    pub const resetStateLocked = mode_effects.resetStateLocked;
    pub const updateViewCacheForScroll = terminal_publication.updateViewCacheForScroll;
    pub const updateViewCacheForScrollLocked = terminal_publication.updateViewCacheForScrollLocked;

    pub const enterAltScreen = mode_effects.enterAltScreen;
    pub const exitAltScreen = mode_effects.exitAltScreen;

    pub const snapshot = terminal_publication.snapshot;
    pub const renderCache = terminal_publication.renderCache;
    pub const copyPublishedRenderCache = terminal_publication.copyPublishedRenderCache;
    pub const capturePresentation = terminal_publication.capturePresentation;
    pub const completePresentationFeedback = terminal_publication.completePresentationFeedback;
    pub const finishFramePresentation = terminal_publication.finishFramePresentation;
    pub const syncUpdatesActive = terminal_publication.syncUpdatesActive;
    pub const clearPublishedDamageIfGeneration = terminal_publication.clearPublishedDamageIfGeneration;
};

const default_scrollback_rows: usize = 1000;
const key_mode_disambiguate: u32 = 1;
const key_mode_report_all_event_types: u32 = 2;
const key_mode_report_alternate_key: u32 = 4;
const key_mode_report_text: u32 = 8;
const key_mode_embed_text: u32 = 16;

const mouse_button_left_mask: u8 = 1;
const mouse_button_middle_mask: u8 = 2;
const mouse_button_right_mask: u8 = 4;
