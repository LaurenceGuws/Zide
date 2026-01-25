const std = @import("std");
const r = @import("ui/renderer.zig");

pub const MousePos = r.MousePos;
pub const Color = r.Color;
pub const Theme = r.Theme;

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
