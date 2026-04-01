const session_mod = @import("pty_terminal_runtime.zig");
const host_types = @import("session/host_types.zig");
const interaction = @import("session/interaction.zig");
const selection_mod = @import("selection.zig");
const types_api = @import("session/types_api.zig");
const workspace_mod = @import("workspace.zig");

pub const PtyTerminalRuntime = session_mod.PtyTerminalRuntime;
pub const TerminalWorkspace = workspace_mod.TerminalWorkspace;
pub const TerminalTabId = workspace_mod.TabId;
pub const TerminalTabSyncEntry = workspace_mod.TabSyncEntry;
pub const TerminalTabSyncState = workspace_mod.TabSyncState;

pub const ActivityMetadata = host_types.ActivityMetadata;
pub const ProgressMetadata = host_types.ProgressMetadata;
pub const ProgressState = host_types.ProgressState;

pub const VTERM_KEY_NONE = types_api.VTERM_KEY_NONE;
pub const VTERM_KEY_ENTER = types_api.VTERM_KEY_ENTER;
pub const VTERM_KEY_TAB = types_api.VTERM_KEY_TAB;
pub const VTERM_KEY_BACKSPACE = types_api.VTERM_KEY_BACKSPACE;
pub const VTERM_KEY_ESCAPE = types_api.VTERM_KEY_ESCAPE;
pub const VTERM_KEY_UP = types_api.VTERM_KEY_UP;
pub const VTERM_KEY_DOWN = types_api.VTERM_KEY_DOWN;
pub const VTERM_KEY_LEFT = types_api.VTERM_KEY_LEFT;
pub const VTERM_KEY_RIGHT = types_api.VTERM_KEY_RIGHT;
pub const VTERM_KEY_INS = types_api.VTERM_KEY_INS;
pub const VTERM_KEY_DEL = types_api.VTERM_KEY_DEL;
pub const VTERM_KEY_HOME = types_api.VTERM_KEY_HOME;
pub const VTERM_KEY_END = types_api.VTERM_KEY_END;
pub const VTERM_KEY_PAGEUP = types_api.VTERM_KEY_PAGEUP;
pub const VTERM_KEY_PAGEDOWN = types_api.VTERM_KEY_PAGEDOWN;
pub const VTERM_KEY_LEFT_SHIFT = types_api.VTERM_KEY_LEFT_SHIFT;
pub const VTERM_KEY_RIGHT_SHIFT = types_api.VTERM_KEY_RIGHT_SHIFT;
pub const VTERM_KEY_LEFT_CTRL = types_api.VTERM_KEY_LEFT_CTRL;
pub const VTERM_KEY_RIGHT_CTRL = types_api.VTERM_KEY_RIGHT_CTRL;
pub const VTERM_KEY_LEFT_ALT = types_api.VTERM_KEY_LEFT_ALT;
pub const VTERM_KEY_RIGHT_ALT = types_api.VTERM_KEY_RIGHT_ALT;
pub const VTERM_KEY_LEFT_SUPER = types_api.VTERM_KEY_LEFT_SUPER;
pub const VTERM_KEY_RIGHT_SUPER = types_api.VTERM_KEY_RIGHT_SUPER;
pub const KeypadKey = types_api.KeypadKey;
pub const KeyAction = types_api.KeyAction;
pub const keyModeFlagsValue = interaction.keyModeFlagsValue;

pub const VTERM_MOD_NONE = types_api.VTERM_MOD_NONE;
pub const VTERM_MOD_SHIFT = types_api.VTERM_MOD_SHIFT;
pub const VTERM_MOD_ALT = types_api.VTERM_MOD_ALT;
pub const VTERM_MOD_CTRL = types_api.VTERM_MOD_CTRL;

pub const Key = types_api.Key;
pub const Modifier = types_api.Modifier;
pub const MouseButton = types_api.MouseButton;
pub const MouseEventKind = types_api.MouseEventKind;
pub const MouseEvent = types_api.MouseEvent;

pub const SelectionPos = types_api.SelectionPos;
pub const TerminalSelection = types_api.TerminalSelection;
pub const SelectionGesture = selection_mod.SelectionGesture;
pub const ClickSelectionResult = selection_mod.ClickSelectionResult;
