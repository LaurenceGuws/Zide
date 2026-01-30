const std = @import("std");
const r = @import("ui/renderer.zig");
const iface = @import("ui/renderer/interface.zig");
const window = @import("platform/window.zig");
const input = @import("platform/input.zig");

pub const MousePos = iface.MousePos;
pub const Color = iface.Color;
pub const Theme = iface.Theme;

pub const MOUSE_LEFT = input.MOUSE_LEFT;
pub const MOUSE_RIGHT = input.MOUSE_RIGHT;
pub const MOUSE_MIDDLE = input.MOUSE_MIDDLE;

pub const KEY_LEFT_CONTROL = input.KEY_LEFT_CONTROL;
pub const KEY_RIGHT_CONTROL = input.KEY_RIGHT_CONTROL;
pub const KEY_LEFT_ALT = input.KEY_LEFT_ALT;
pub const KEY_RIGHT_ALT = input.KEY_RIGHT_ALT;
pub const KEY_LEFT_SHIFT = input.KEY_LEFT_SHIFT;
pub const KEY_RIGHT_SHIFT = input.KEY_RIGHT_SHIFT;
pub const KEY_LEFT_SUPER = input.KEY_LEFT_SUPER;
pub const KEY_RIGHT_SUPER = input.KEY_RIGHT_SUPER;
pub const KEY_KP_ADD = input.KEY_KP_ADD;
pub const KEY_KP_SUBTRACT = input.KEY_KP_SUBTRACT;
pub const KEY_KP_0 = input.KEY_KP_0;
pub const KEY_KP_1 = input.KEY_KP_1;
pub const KEY_KP_2 = input.KEY_KP_2;
pub const KEY_KP_3 = input.KEY_KP_3;
pub const KEY_KP_4 = input.KEY_KP_4;
pub const KEY_KP_5 = input.KEY_KP_5;
pub const KEY_KP_6 = input.KEY_KP_6;
pub const KEY_KP_7 = input.KEY_KP_7;
pub const KEY_KP_8 = input.KEY_KP_8;
pub const KEY_KP_9 = input.KEY_KP_9;
pub const KEY_KP_DECIMAL = input.KEY_KP_DECIMAL;
pub const KEY_KP_DIVIDE = input.KEY_KP_DIVIDE;
pub const KEY_KP_MULTIPLY = input.KEY_KP_MULTIPLY;
pub const KEY_KP_ENTER = input.KEY_KP_ENTER;
pub const KEY_KP_EQUAL = input.KEY_KP_EQUAL;
pub const KEY_EQUAL = input.KEY_EQUAL;
pub const KEY_MINUS = input.KEY_MINUS;
pub const KEY_ZERO = input.KEY_ZERO;
pub const KEY_ONE = input.KEY_ONE;
pub const KEY_TWO = input.KEY_TWO;
pub const KEY_THREE = input.KEY_THREE;
pub const KEY_FOUR = input.KEY_FOUR;
pub const KEY_FIVE = input.KEY_FIVE;
pub const KEY_SIX = input.KEY_SIX;
pub const KEY_SEVEN = input.KEY_SEVEN;
pub const KEY_EIGHT = input.KEY_EIGHT;
pub const KEY_NINE = input.KEY_NINE;
pub const KEY_ENTER = input.KEY_ENTER;
pub const KEY_BACKSPACE = input.KEY_BACKSPACE;
pub const KEY_DELETE = input.KEY_DELETE;
pub const KEY_TAB = input.KEY_TAB;
pub const KEY_ESCAPE = input.KEY_ESCAPE;
pub const KEY_UP = input.KEY_UP;
pub const KEY_DOWN = input.KEY_DOWN;
pub const KEY_LEFT = input.KEY_LEFT;
pub const KEY_RIGHT = input.KEY_RIGHT;
pub const KEY_HOME = input.KEY_HOME;
pub const KEY_END = input.KEY_END;
pub const KEY_PAGE_UP = input.KEY_PAGE_UP;
pub const KEY_PAGE_DOWN = input.KEY_PAGE_DOWN;
pub const KEY_INSERT = input.KEY_INSERT;
pub const KEY_GRAVE = input.KEY_GRAVE;
pub const KEY_Q = input.KEY_Q;
pub const KEY_N = input.KEY_N;
pub const KEY_S = input.KEY_S;
pub const KEY_Z = input.KEY_Z;
pub const KEY_Y = input.KEY_Y;
pub const KEY_C = input.KEY_C;
pub const KEY_V = input.KEY_V;
pub const KEY_X = input.KEY_X;
pub const KEY_A = input.KEY_A;
pub const KEY_B = input.KEY_B;
pub const KEY_D = input.KEY_D;
pub const KEY_E = input.KEY_E;
pub const KEY_F = input.KEY_F;
pub const KEY_G = input.KEY_G;
pub const KEY_H = input.KEY_H;
pub const KEY_I = input.KEY_I;
pub const KEY_J = input.KEY_J;
pub const KEY_K = input.KEY_K;
pub const KEY_L = input.KEY_L;
pub const KEY_M = input.KEY_M;
pub const KEY_O = input.KEY_O;
pub const KEY_P = input.KEY_P;
pub const KEY_R = input.KEY_R;
pub const KEY_T = input.KEY_T;
pub const KEY_U = input.KEY_U;
pub const KEY_W = input.KEY_W;
pub const KEY_SLASH = input.KEY_SLASH;
pub const KEY_PERIOD = input.KEY_PERIOD;
pub const KEY_COMMA = input.KEY_COMMA;
pub const KEY_APOSTROPHE = input.KEY_APOSTROPHE;
pub const KEY_SEMICOLON = input.KEY_SEMICOLON;
pub const KEY_LEFT_BRACKET = input.KEY_LEFT_BRACKET;
pub const KEY_RIGHT_BRACKET = input.KEY_RIGHT_BRACKET;
pub const KEY_BACKSLASH = input.KEY_BACKSLASH;
pub const KEY_SPACE = input.KEY_SPACE;

pub const setSdlLogLevel = r.setSdlLogLevel;
pub const pollInputEvents = input.pollInputEvents;
pub const getTime = input.getTime;
pub const waitTime = input.waitTime;
pub const isWindowResized = r.isWindowResized;
pub const getScreenWidth = r.getScreenWidth;
pub const getScreenHeight = r.getScreenHeight;
pub const WindowMetrics = window.WindowMetrics;
pub const TextComposition = input.TextComposition;

pub const Shell = struct {
    renderer: *r.Renderer,

    pub fn init(allocator: std.mem.Allocator, initial_width: i32, initial_height: i32, title: [*:0]const u8) !*Shell {
        const renderer = try r.Renderer.init(allocator, initial_width, initial_height, title);
        errdefer renderer.deinit();
        const shell = try allocator.create(Shell);
        shell.* = .{ .renderer = renderer };
        return shell;
    }

    pub fn deinit(self: *Shell, allocator: std.mem.Allocator) void {
        self.renderer.deinit();
        allocator.destroy(self);
    }

    pub fn refreshUiScale(self: *Shell) !bool {
        return self.renderer.refreshUiScale();
    }

    pub fn applyPendingZoom(self: *Shell, now: f64) !bool {
        return self.renderer.applyPendingZoom(now);
    }

    pub fn queueUserZoom(self: *Shell, delta: f32, now: f64) bool {
        return self.renderer.queueUserZoom(delta, now);
    }

    pub fn resetUserZoomTarget(self: *Shell, now: f64) bool {
        return self.renderer.resetUserZoomTarget(now);
    }

    pub fn uiScaleFactor(self: *Shell) f32 {
        return self.renderer.uiScaleFactor();
    }

    pub fn shouldClose(self: *Shell) bool {
        return self.renderer.shouldClose();
    }

    pub fn requestClose(self: *Shell) void {
        self.renderer.should_close_flag = true;
    }

    pub fn width(self: *Shell) i32 {
        return self.renderer.width;
    }

    pub fn height(self: *Shell) i32 {
        return self.renderer.height;
    }

    pub fn setSize(self: *Shell, new_width: i32, new_height: i32) void {
        self.renderer.width = new_width;
        self.renderer.height = new_height;
    }

    pub fn refreshWindowMetrics(self: *Shell, reason: []const u8) WindowMetrics {
        return self.renderer.refreshWindowMetrics(reason);
    }

    pub fn setTextInputRect(self: *Shell, x: i32, y: i32, w: i32, h: i32) void {
        self.renderer.setTextInputRect(x, y, w, h);
    }

    pub fn charWidth(self: *Shell) f32 {
        return self.renderer.char_width;
    }

    pub fn charHeight(self: *Shell) f32 {
        return self.renderer.char_height;
    }

    pub fn iconCharHeight(self: *Shell) f32 {
        return self.renderer.icon_char_height;
    }

    pub fn fontSize(self: *Shell) f32 {
        return self.renderer.font_size;
    }

    pub fn terminalCellWidth(self: *Shell) f32 {
        return self.renderer.terminal_cell_width;
    }

    pub fn terminalCellHeight(self: *Shell) f32 {
        return self.renderer.terminal_cell_height;
    }

    pub fn mouseScale(self: *Shell) MousePos {
        return self.renderer.mouse_scale;
    }

    pub fn theme(self: *Shell) *const Theme {
        return &self.renderer.theme;
    }

    pub fn setTheme(self: *Shell, new_theme: Theme) void {
        self.renderer.theme = new_theme;
    }

    pub fn rendererPtr(self: *Shell) *r.Renderer {
        return self.renderer;
    }

    pub fn beginFrame(self: *Shell) void {
        self.renderer.beginFrame();
    }

    pub fn endFrame(self: *Shell) void {
        self.renderer.endFrame();
    }

    pub fn beginClip(self: *Shell, x: i32, y: i32, w: i32, h: i32) void {
        self.renderer.beginClip(x, y, w, h);
    }

    pub fn endClip(self: *Shell) void {
        self.renderer.endClip();
    }

    pub fn drawRect(self: *Shell, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        self.renderer.drawRect(x, y, w, h, color);
    }

    pub fn drawRectOutline(self: *Shell, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        self.renderer.drawRectOutline(x, y, w, h, color);
    }

    pub fn drawText(self: *Shell, text: []const u8, x: f32, y: f32, color: Color) void {
        self.renderer.drawText(text, x, y, color);
    }

    pub fn drawTextSized(self: *Shell, text: []const u8, x: f32, y: f32, size: f32, color: Color) void {
        self.renderer.drawTextSized(text, x, y, size, color);
    }

    pub fn drawIconText(self: *Shell, text: []const u8, x: f32, y: f32, color: Color) void {
        self.renderer.drawIconText(text, x, y, color);
    }

    pub fn measureIconTextWidth(self: *Shell, text: []const u8) f32 {
        return self.renderer.measureIconTextWidth(text);
    }

    pub fn getMousePos(self: *Shell) MousePos {
        return self.renderer.getMousePos();
    }

    pub fn getMousePosRaw(self: *Shell) MousePos {
        return self.renderer.getMousePosRaw();
    }

    pub fn getMousePosScaled(self: *Shell, scale: f32) MousePos {
        return self.renderer.getMousePosScaled(scale);
    }

    pub fn getMouseWheelMove(self: *Shell) f32 {
        return self.renderer.getMouseWheelMove();
    }

    pub fn isMouseButtonDown(self: *Shell, button: i32) bool {
        return self.renderer.isMouseButtonDown(button);
    }

    pub fn isMouseButtonPressed(self: *Shell, button: i32) bool {
        return self.renderer.isMouseButtonPressed(button);
    }

    pub fn isMouseButtonReleased(self: *Shell, button: i32) bool {
        return self.renderer.isMouseButtonReleased(button);
    }

    pub fn isKeyDown(self: *Shell, key: i32) bool {
        return self.renderer.isKeyDown(key);
    }

    pub fn isKeyPressed(self: *Shell, key: i32) bool {
        return self.renderer.isKeyPressed(key);
    }

    pub fn isKeyRepeated(self: *Shell, key: i32) bool {
        return self.renderer.isKeyRepeated(key);
    }

    pub fn getCharPressed(self: *Shell) ?u32 {
        return self.renderer.getCharPressed();
    }

    pub fn setClipboardText(self: *Shell, text: [*:0]const u8) void {
        self.renderer.setClipboardText(text);
    }

    pub fn getClipboardText(self: *Shell) ?[]const u8 {
        return self.renderer.getClipboardText();
    }

    pub fn getDpiScale(self: *Shell) MousePos {
        return self.renderer.getDpiScale();
    }

    pub fn getScreenSize(self: *Shell) MousePos {
        return self.renderer.getScreenSize();
    }

    pub fn getRenderSize(self: *Shell) MousePos {
        return self.renderer.getRenderSize();
    }

    pub fn getMonitorSize(self: *Shell) MousePos {
        return self.renderer.getMonitorSize();
    }
};
