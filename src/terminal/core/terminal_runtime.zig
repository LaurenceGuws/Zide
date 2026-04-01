const runtime_mod = @import("pty_terminal_runtime.zig");
const input_mod = @import("../input/input.zig");
const types = @import("../model/types.zig");

pub const PtyTerminalRuntime = runtime_mod.PtyTerminalRuntime;

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
