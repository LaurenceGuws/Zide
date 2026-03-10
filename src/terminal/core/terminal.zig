const session_mod = @import("terminal_session.zig");
const workspace_mod = @import("workspace.zig");

pub const KittyImageFormat = session_mod.KittyImageFormat;
pub const KittyImage = session_mod.KittyImage;
pub const KittyPlacement = session_mod.KittyPlacement;

pub const TerminalSnapshot = session_mod.TerminalSnapshot;
pub const DebugSnapshot = session_mod.DebugSnapshot;
pub const PresentedRenderCache = session_mod.PresentedRenderCache;
pub const PresentationCapture = session_mod.PresentationCapture;
pub const AltExitPresentationInfo = session_mod.AltExitPresentationInfo;
pub const PresentationFeedback = session_mod.PresentationFeedback;

pub const debugSnapshot = session_mod.debugSnapshot;
pub const debugScrollbackRow = session_mod.debugScrollbackRow;
pub const debugSetCursor = session_mod.debugSetCursor;
pub const debugFeedBytes = session_mod.debugFeedBytes;

pub const TerminalSession = session_mod.TerminalSession;
pub const TerminalWorkspace = workspace_mod.TerminalWorkspace;
pub const TerminalTabId = workspace_mod.TabId;
pub const TerminalTabSyncEntry = workspace_mod.TabSyncEntry;
pub const TerminalTabSyncState = workspace_mod.TabSyncState;

pub const Hyperlink = session_mod.Hyperlink;

pub const VTERM_KEY_NONE = session_mod.VTERM_KEY_NONE;
pub const VTERM_KEY_ENTER = session_mod.VTERM_KEY_ENTER;
pub const VTERM_KEY_TAB = session_mod.VTERM_KEY_TAB;
pub const VTERM_KEY_BACKSPACE = session_mod.VTERM_KEY_BACKSPACE;
pub const VTERM_KEY_ESCAPE = session_mod.VTERM_KEY_ESCAPE;
pub const VTERM_KEY_UP = session_mod.VTERM_KEY_UP;
pub const VTERM_KEY_DOWN = session_mod.VTERM_KEY_DOWN;
pub const VTERM_KEY_LEFT = session_mod.VTERM_KEY_LEFT;
pub const VTERM_KEY_RIGHT = session_mod.VTERM_KEY_RIGHT;
pub const VTERM_KEY_INS = session_mod.VTERM_KEY_INS;
pub const VTERM_KEY_DEL = session_mod.VTERM_KEY_DEL;
pub const VTERM_KEY_HOME = session_mod.VTERM_KEY_HOME;
pub const VTERM_KEY_END = session_mod.VTERM_KEY_END;
pub const VTERM_KEY_PAGEUP = session_mod.VTERM_KEY_PAGEUP;
pub const VTERM_KEY_PAGEDOWN = session_mod.VTERM_KEY_PAGEDOWN;
pub const VTERM_KEY_LEFT_SHIFT = session_mod.VTERM_KEY_LEFT_SHIFT;
pub const VTERM_KEY_RIGHT_SHIFT = session_mod.VTERM_KEY_RIGHT_SHIFT;
pub const VTERM_KEY_LEFT_CTRL = session_mod.VTERM_KEY_LEFT_CTRL;
pub const VTERM_KEY_RIGHT_CTRL = session_mod.VTERM_KEY_RIGHT_CTRL;
pub const VTERM_KEY_LEFT_ALT = session_mod.VTERM_KEY_LEFT_ALT;
pub const VTERM_KEY_RIGHT_ALT = session_mod.VTERM_KEY_RIGHT_ALT;
pub const VTERM_KEY_LEFT_SUPER = session_mod.VTERM_KEY_LEFT_SUPER;
pub const VTERM_KEY_RIGHT_SUPER = session_mod.VTERM_KEY_RIGHT_SUPER;
pub const KeypadKey = session_mod.KeypadKey;
pub const KeyAction = session_mod.KeyAction;
pub const keyModeFlagsValue = session_mod.TerminalSession.keyModeFlagsValue;

pub const VTERM_MOD_NONE = session_mod.VTERM_MOD_NONE;
pub const VTERM_MOD_SHIFT = session_mod.VTERM_MOD_SHIFT;
pub const VTERM_MOD_ALT = session_mod.VTERM_MOD_ALT;
pub const VTERM_MOD_CTRL = session_mod.VTERM_MOD_CTRL;

pub const CursorPos = session_mod.CursorPos;
pub const SelectionPos = session_mod.SelectionPos;
pub const TerminalSelection = session_mod.TerminalSelection;
pub const SelectionGesture = session_mod.SelectionGesture;
pub const ClickSelectionResult = session_mod.ClickSelectionResult;
pub const Cell = session_mod.Cell;
pub const CellAttrs = session_mod.CellAttrs;
pub const Color = session_mod.Color;
pub const Key = session_mod.Key;
pub const Modifier = session_mod.Modifier;
pub const MouseButton = session_mod.MouseButton;
pub const MouseEventKind = session_mod.MouseEventKind;
pub const MouseEvent = session_mod.MouseEvent;
