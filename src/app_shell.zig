const std = @import("std");
const r = @import("ui/renderer.zig");
const iface = @import("ui/renderer/interface.zig");
const window = @import("platform/window_metrics.zig");
const platform_input_events = @import("platform/input_events.zig");

pub const MousePos = iface.MousePos;
pub const Color = iface.Color;
pub const Theme = iface.Theme;
pub const WindowChangeMask = r.WindowChangeMask;
pub const FrameSubmission = r.FrameSubmission;
pub const WindowGeometryDiagnostics = r.WindowGeometryDiagnostics;
pub const WindowRefreshResult = r.WindowRefreshResult;
pub const ScreenshotMode = r.ScreenshotMode;
pub const TerminalPresentationMode = r.TerminalPresentationMode;
pub const TextRenderingMode = r.TextRenderingMode;
pub const RendererCapabilities = r.RendererCapabilities;
pub const AtlasPreviewSource = r.AtlasPreviewSource;
pub const ScreenshotRequestResult = enum {
    completed,
    armed_present_capture,
};

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
pub const KEY_F1 = r.KEY_F1;
pub const KEY_F2 = r.KEY_F2;
pub const KEY_F3 = r.KEY_F3;
pub const KEY_F4 = r.KEY_F4;
pub const KEY_F5 = r.KEY_F5;
pub const KEY_F6 = r.KEY_F6;
pub const KEY_F7 = r.KEY_F7;
pub const KEY_F8 = r.KEY_F8;
pub const KEY_F9 = r.KEY_F9;
pub const KEY_F10 = r.KEY_F10;
pub const KEY_F11 = r.KEY_F11;
pub const KEY_F12 = r.KEY_F12;
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

pub const setSdlLogLevel = r.setSdlLogLevel;
pub const pollInputEvents = r.pollInputEvents;
pub const getTime = r.getTime;
pub const waitTime = r.waitTime;
pub const waitForWakeOrTimeout = r.waitForWakeOrTimeout;
pub const requestWake = r.requestWake;
pub const windowChanges = r.windowChanges;
pub const getScreenWidth = r.getScreenWidth;
pub const getScreenHeight = r.getScreenHeight;
pub const WindowMetrics = window.WindowMetrics;
pub const UiGeometryContext = r.UiGeometryContext;
pub const TerminalCellGeometry = r.Renderer.TerminalCellGeometry;
pub const TerminalViewGeometry = r.TerminalViewGeometry;
pub const RendererInitOptions = r.Renderer.InitOptions;
pub const TextComposition = r.Renderer.TextComposition;
pub const WindowChromeMode = r.Renderer.WindowChromeMode;
pub const WindowChromeContract = r.Renderer.WindowChromeContract;
pub const RendererBackend = r.RendererBackend;
pub const RendererRuntimeProfile = r.RendererRuntimeProfile;
pub const ExternalIntent = r.ExternalIntent;

pub const Shell = struct {
    renderer: *r.Renderer,

    pub fn init(allocator: std.mem.Allocator, initial_width: i32, initial_height: i32, title: [*:0]const u8, init_options: RendererInitOptions) !*Shell {
        const renderer = try r.Renderer.init(allocator, initial_width, initial_height, title, init_options);
        errdefer renderer.deinit();
        const shell = try allocator.create(Shell);
        shell.* = .{ .renderer = renderer };
        return shell;
    }

    pub fn runStartupBackendSmoke(initial_width: i32, initial_height: i32, title: [*:0]const u8, backend: RendererBackend) !bool {
        return r.Renderer.runStartupBackendSmoke(initial_width, initial_height, title, backend);
    }

    pub fn deinit(self: *Shell, allocator: std.mem.Allocator) void {
        self.renderer.deinit();
        allocator.destroy(self);
    }

    pub fn applyPendingZoom(self: *Shell, now: f64) !WindowRefreshResult {
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

    pub fn windowFocused(self: *Shell) bool {
        return self.renderer.windowFocused();
    }

    pub fn requestClose(self: *Shell) void {
        self.renderer.input.should_close_flag = true;
    }

    pub fn clearCloseRequest(self: *Shell) void {
        self.renderer.input.should_close_flag = false;
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

    pub fn refreshWindowState(self: *Shell, reason: []const u8, changes: WindowChangeMask) !WindowRefreshResult {
        return self.renderer.refreshWindowState(reason, changes);
    }

    pub fn setWindowChrome(self: *Shell, contract: WindowChromeContract) void {
        self.renderer.setWindowChrome(contract);
    }

    pub fn minimizeWindow(self: *Shell) bool {
        return self.renderer.minimizeWindow();
    }

    pub fn showWindowSystemMenu(self: *Shell, x: i32, y: i32) bool {
        return self.renderer.showWindowSystemMenu(x, y);
    }

    pub fn toggleMaximizeWindow(self: *Shell) bool {
        return self.renderer.toggleMaximizeWindow();
    }

    pub fn windowIsMaximized(self: *Shell) bool {
        return self.renderer.windowIsMaximized();
    }

    pub fn integratedWindowChromeSinkActive(self: *Shell) bool {
        return self.renderer.integratedWindowChromeSinkActive();
    }

    pub fn integratedWindowChromeMinimizeHovered(self: *Shell) bool {
        return self.renderer.integratedWindowChromeMinimizeHovered();
    }

    pub fn integratedWindowChromeMaximizeHovered(self: *Shell) bool {
        return self.renderer.integratedWindowChromeMaximizeHovered();
    }

    pub fn integratedWindowChromeCloseHovered(self: *Shell) bool {
        return self.renderer.integratedWindowChromeCloseHovered();
    }

    pub fn integratedWindowChromeMinimizePressed(self: *Shell) bool {
        return self.renderer.integratedWindowChromeMinimizePressed();
    }

    pub fn integratedWindowChromeMaximizePressed(self: *Shell) bool {
        return self.renderer.integratedWindowChromeMaximizePressed();
    }

    pub fn integratedWindowChromeClosePressed(self: *Shell) bool {
        return self.renderer.integratedWindowChromeClosePressed();
    }

    pub fn integratedWindowChromeSinkOwnsChrome(self: *Shell) bool {
        return self.renderer.integratedWindowChromeSinkOwnsChrome();
    }

    pub fn takePendingExternalIntent(self: *Shell) ?ExternalIntent {
        return self.renderer.takePendingExternalIntent();
    }

    pub fn macosRequestActivation(self: *Shell) void {
        self.renderer.macosRequestActivation();
    }

    pub fn macosRequestQuit(self: *Shell) void {
        self.renderer.macosRequestQuit();
    }

    pub fn macosRequestOpenFile(self: *Shell, path: []const u8) bool {
        return self.renderer.macosRequestOpenFile(path);
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

    pub fn editorCharWidth(self: *Shell) f32 {
        return self.renderer.editor_char_width;
    }

    pub fn editorCharHeight(self: *Shell) f32 {
        return self.renderer.editor_char_height;
    }

    pub fn iconCharHeight(self: *Shell) f32 {
        return self.renderer.icon_char_height;
    }

    pub fn fontSize(self: *Shell) f32 {
        return self.renderer.font_size;
    }

    pub fn baseFontSize(self: *Shell) f32 {
        return self.renderer.baseFontSize();
    }

    pub fn userZoomFactor(self: *Shell) f32 {
        return self.renderer.userZoomFactor();
    }

    pub fn userZoomTargetFactor(self: *Shell) f32 {
        return self.renderer.userZoomTargetFactor();
    }

    pub fn uiGeometryContext(self: *Shell) UiGeometryContext {
        return self.renderer.uiGeometryContext();
    }

    pub fn windowGeometryDiagnostics(self: *Shell) WindowGeometryDiagnostics {
        return self.renderer.windowGeometryDiagnostics();
    }

    pub fn refreshWindowGeometryDiagnostics(self: *Shell, reason: []const u8) WindowGeometryDiagnostics {
        return self.renderer.refreshWindowGeometryDiagnostics(reason);
    }

    pub fn terminalViewGeometry(self: *Shell, viewport: @import("types/mod.zig").layout.Rect, rows: usize, cols: usize) TerminalViewGeometry {
        return self.renderer.terminalViewGeometry(viewport, rows, cols);
    }

    pub fn terminalCellGeometry(self: *Shell) TerminalCellGeometry {
        return self.renderer.terminalCellGeometry();
    }

    pub fn terminalCellWidth(self: *Shell) f32 {
        return self.renderer.terminal_cell_width;
    }

    pub fn terminalCellHeight(self: *Shell) f32 {
        return self.renderer.terminal_cell_height;
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

    pub fn endFrame(self: *Shell) FrameSubmission {
        return self.renderer.submitFrame();
    }

    pub fn armPresentCapture(self: *Shell, path: []const u8) void {
        self.renderer.armPresentCapture(path);
    }

    pub fn screenshotMode(self: *const Shell) ScreenshotMode {
        return self.renderer.screenshotMode();
    }

    pub fn rendererCapabilities(self: *const Shell) RendererCapabilities {
        return self.renderer.capabilities();
    }

    pub fn lastPresentTrace(self: *const Shell) r.PresentTrace {
        return self.renderer.lastPresentTrace();
    }

    pub fn dumpWindowScreenshotPpm(self: *Shell, path: []const u8) !void {
        try self.renderer.dumpWindowScreenshotPpm(path);
    }

    pub fn dumpWindowScreenshotPpmSized(self: *Shell, path: []const u8, out_width: i32, out_height: i32) !void {
        try self.renderer.dumpWindowScreenshotPpmSized(path, out_width, out_height);
    }

    pub fn requestWindowScreenshotPpm(self: *Shell, path: []const u8) !ScreenshotRequestResult {
        return switch (self.screenshotMode()) {
            .direct_window_readback => blk: {
                try self.dumpWindowScreenshotPpm(path);
                break :blk .completed;
            },
            .present_capture => blk: {
                self.armPresentCapture(path);
                break :blk .armed_present_capture;
            },
            .unavailable => error.RendererScreenshotUnavailable,
        };
    }

    pub fn requestWindowScreenshotPpmSized(self: *Shell, path: []const u8, out_width: i32, out_height: i32) !ScreenshotRequestResult {
        return switch (self.screenshotMode()) {
            .direct_window_readback => blk: {
                try self.dumpWindowScreenshotPpmSized(path, out_width, out_height);
                break :blk .completed;
            },
            .present_capture => error.RendererSizedScreenshotUnavailable,
            .unavailable => error.RendererScreenshotUnavailable,
        };
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

    pub fn drawTextOnBg(self: *Shell, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
        self.renderer.drawTextOnBg(text, x, y, color, bg);
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

    pub fn getTextPressed(self: *Shell) ?platform_input_events.TextPress {
        return self.renderer.getTextPressed();
    }

    pub fn getFocusEvent(self: *Shell) ?bool {
        return self.renderer.getFocusEvent();
    }

    pub fn getTextComposition(self: *Shell) r.Renderer.TextComposition {
        return self.renderer.getTextComposition();
    }

    pub fn getKeyPressed(self: *Shell) ?platform_input_events.KeyPress {
        return self.renderer.getKeyPressed();
    }

    pub fn isKeyReleased(self: *Shell, key: i32) bool {
        return self.renderer.isKeyReleased(key);
    }

    pub fn mouseButtonClicks(self: *Shell, button: i32) u8 {
        return self.renderer.mouseButtonClicks(button);
    }

    pub fn mouseButtonPressPos(self: *Shell, button: i32) ?MousePos {
        return self.renderer.mouseButtonPressPos(button);
    }

    pub fn setClipboardText(self: *Shell, text: [*:0]const u8) void {
        self.renderer.setClipboardText(text);
    }

    pub fn getClipboardText(self: *Shell) ?[]const u8 {
        return self.renderer.getClipboardText();
    }

    pub fn getClipboardMimeData(self: *Shell, allocator: std.mem.Allocator, mime_type: [*:0]const u8) ?[]u8 {
        return self.renderer.getClipboardMimeData(allocator, mime_type);
    }
};
