const r = @import("ui/renderer.zig");

pub const Renderer = r.Renderer;
pub const MousePos = r.MousePos;
pub const Color = r.Color;

pub const MOUSE_LEFT = r.MOUSE_LEFT;
pub const MOUSE_RIGHT = r.MOUSE_RIGHT;

pub const KEY_LEFT_CONTROL = r.KEY_LEFT_CONTROL;
pub const KEY_RIGHT_CONTROL = r.KEY_RIGHT_CONTROL;
pub const KEY_LEFT_ALT = r.KEY_LEFT_ALT;
pub const KEY_RIGHT_ALT = r.KEY_RIGHT_ALT;
pub const KEY_KP_ADD = r.KEY_KP_ADD;
pub const KEY_KP_SUBTRACT = r.KEY_KP_SUBTRACT;
pub const KEY_EQUAL = r.KEY_EQUAL;
pub const KEY_MINUS = r.KEY_MINUS;
pub const KEY_ZERO = r.KEY_ZERO;
pub const KEY_GRAVE = r.KEY_GRAVE;
pub const KEY_Q = r.KEY_Q;
pub const KEY_N = r.KEY_N;

pub const setRaylibLogLevel = r.setRaylibLogLevel;
pub const pollInputEvents = r.pollInputEvents;
pub const getTime = r.getTime;
pub const waitTime = r.waitTime;
pub const isWindowResized = r.isWindowResized;
pub const getScreenWidth = r.getScreenWidth;
pub const getScreenHeight = r.getScreenHeight;
