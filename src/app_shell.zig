const std = @import("std");
const r = @import("ui/renderer.zig");

pub const MousePos = r.MousePos;
pub const Color = r.Color;
pub const Theme = r.Theme;

pub const MOUSE_LEFT = r.MOUSE_LEFT;
pub const MOUSE_RIGHT = r.MOUSE_RIGHT;
pub const MOUSE_MIDDLE = r.MOUSE_MIDDLE;

pub const KEY_LEFT_CONTROL = r.KEY_LEFT_CONTROL;
pub const KEY_RIGHT_CONTROL = r.KEY_RIGHT_CONTROL;
pub const KEY_LEFT_ALT = r.KEY_LEFT_ALT;
pub const KEY_RIGHT_ALT = r.KEY_RIGHT_ALT;
pub const KEY_LEFT_SHIFT = r.KEY_LEFT_SHIFT;
pub const KEY_RIGHT_SHIFT = r.KEY_RIGHT_SHIFT;
pub const KEY_LEFT_SUPER = r.KEY_LEFT_SUPER;
pub const KEY_RIGHT_SUPER = r.KEY_RIGHT_SUPER;
pub const KEY_KP_ADD = r.KEY_KP_ADD;
pub const KEY_KP_SUBTRACT = r.KEY_KP_SUBTRACT;
pub const KEY_KP_0 = r.KEY_KP_0;
pub const KEY_KP_1 = r.KEY_KP_1;
pub const KEY_KP_2 = r.KEY_KP_2;
pub const KEY_KP_3 = r.KEY_KP_3;
pub const KEY_KP_4 = r.KEY_KP_4;
pub const KEY_KP_5 = r.KEY_KP_5;
pub const KEY_KP_6 = r.KEY_KP_6;
pub const KEY_KP_7 = r.KEY_KP_7;
pub const KEY_KP_8 = r.KEY_KP_8;
pub const KEY_KP_9 = r.KEY_KP_9;
pub const KEY_KP_DECIMAL = r.KEY_KP_DECIMAL;
pub const KEY_KP_DIVIDE = r.KEY_KP_DIVIDE;
pub const KEY_KP_MULTIPLY = r.KEY_KP_MULTIPLY;
pub const KEY_KP_ENTER = r.KEY_KP_ENTER;
pub const KEY_KP_EQUAL = r.KEY_KP_EQUAL;
pub const KEY_EQUAL = r.KEY_EQUAL;
pub const KEY_MINUS = r.KEY_MINUS;
pub const KEY_ZERO = r.KEY_ZERO;
pub const KEY_ONE = r.KEY_ONE;
pub const KEY_TWO = r.KEY_TWO;
pub const KEY_THREE = r.KEY_THREE;
pub const KEY_FOUR = r.KEY_FOUR;
pub const KEY_FIVE = r.KEY_FIVE;
pub const KEY_SIX = r.KEY_SIX;
pub const KEY_SEVEN = r.KEY_SEVEN;
pub const KEY_EIGHT = r.KEY_EIGHT;
pub const KEY_NINE = r.KEY_NINE;
pub const KEY_ENTER = r.KEY_ENTER;
pub const KEY_BACKSPACE = r.KEY_BACKSPACE;
pub const KEY_DELETE = r.KEY_DELETE;
pub const KEY_TAB = r.KEY_TAB;
pub const KEY_ESCAPE = r.KEY_ESCAPE;
pub const KEY_UP = r.KEY_UP;
pub const KEY_DOWN = r.KEY_DOWN;
pub const KEY_LEFT = r.KEY_LEFT;
pub const KEY_RIGHT = r.KEY_RIGHT;
pub const KEY_HOME = r.KEY_HOME;
pub const KEY_END = r.KEY_END;
pub const KEY_PAGE_UP = r.KEY_PAGE_UP;
pub const KEY_PAGE_DOWN = r.KEY_PAGE_DOWN;
pub const KEY_INSERT = r.KEY_INSERT;
pub const KEY_GRAVE = r.KEY_GRAVE;
pub const KEY_Q = r.KEY_Q;
pub const KEY_N = r.KEY_N;
pub const KEY_S = r.KEY_S;
pub const KEY_Z = r.KEY_Z;
pub const KEY_Y = r.KEY_Y;
pub const KEY_C = r.KEY_C;
pub const KEY_V = r.KEY_V;
pub const KEY_X = r.KEY_X;
pub const KEY_A = r.KEY_A;
pub const KEY_B = r.KEY_B;
pub const KEY_D = r.KEY_D;
pub const KEY_E = r.KEY_E;
pub const KEY_F = r.KEY_F;
pub const KEY_G = r.KEY_G;
pub const KEY_H = r.KEY_H;
pub const KEY_I = r.KEY_I;
pub const KEY_J = r.KEY_J;
pub const KEY_K = r.KEY_K;
pub const KEY_L = r.KEY_L;
pub const KEY_M = r.KEY_M;
pub const KEY_O = r.KEY_O;
pub const KEY_P = r.KEY_P;
pub const KEY_R = r.KEY_R;
pub const KEY_T = r.KEY_T;
pub const KEY_U = r.KEY_U;
pub const KEY_W = r.KEY_W;
pub const KEY_SLASH = r.KEY_SLASH;
pub const KEY_PERIOD = r.KEY_PERIOD;
pub const KEY_COMMA = r.KEY_COMMA;
pub const KEY_APOSTROPHE = r.KEY_APOSTROPHE;
pub const KEY_SEMICOLON = r.KEY_SEMICOLON;
pub const KEY_LEFT_BRACKET = r.KEY_LEFT_BRACKET;
pub const KEY_RIGHT_BRACKET = r.KEY_RIGHT_BRACKET;
pub const KEY_BACKSLASH = r.KEY_BACKSLASH;
pub const KEY_SPACE = r.KEY_SPACE;

pub const setRaylibLogLevel = r.setRaylibLogLevel;
pub const pollInputEvents = r.pollInputEvents;
pub const getTime = r.getTime;
pub const waitTime = r.waitTime;
pub const isWindowResized = r.isWindowResized;
pub const getScreenWidth = r.getScreenWidth;
pub const getScreenHeight = r.getScreenHeight;

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
