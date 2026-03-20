const std = @import("std");
const builtin = @import("builtin");
const sdl_api = @import("sdl_api.zig");
const app_logger = @import("../app_logger.zig");
const window_chrome_runtime = @import("../ui/renderer/window_chrome_runtime.zig");
const shared_types = @import("../types/mod.zig");

const Rect = shared_types.layout.Rect;

pub const Sink = if (builtin.target.os.tag == .windows) WindowsSink else StubSink;

const StubSink = struct {
    pub fn deinit(_: *StubSink) void {}
    pub fn sync(_: *StubSink, _: *sdl_api.c.SDL_Window, _: window_chrome_runtime.WindowChromeContract, _: bool) void {}
    pub fn active(_: *const StubSink) bool {
        return false;
    }
    pub fn minimizeHovered(_: *const StubSink) bool {
        return false;
    }
    pub fn maximizeHovered(_: *const StubSink) bool {
        return false;
    }
    pub fn closeHovered(_: *const StubSink) bool {
        return false;
    }
    pub fn minimizePressed(_: *const StubSink) bool {
        return false;
    }
    pub fn maximizePressed(_: *const StubSink) bool {
        return false;
    }
    pub fn closePressed(_: *const StubSink) bool {
        return false;
    }
    pub fn ownsChrome(_: *const StubSink) bool {
        return false;
    }
};

const WindowsSink = struct {
    const HWND = ?*anyopaque;
    const HINSTANCE = ?*anyopaque;
    const HRESULT = i32;
    const UINT = u32;
    const WPARAM = usize;
    const LPARAM = isize;
    const LRESULT = isize;
    const DWORD = u32;
    const BOOL = i32;
    const WinInt = i32;
    const LONG_PTR = isize;
    const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;
    const ATOM = u16;
    const DWORD_PTR = usize;

    const RECT = extern struct {
        left: i32,
        top: i32,
        right: i32,
        bottom: i32,
    };

    const POINT = extern struct {
        x: i32,
        y: i32,
    };

    const TRACKMOUSEEVENT = extern struct {
        cbSize: DWORD,
        dwFlags: DWORD,
        hwndTrack: HWND,
        dwHoverTime: DWORD,
    };

    const PAINTSTRUCT = extern struct {
        hdc: ?*anyopaque,
        fErase: BOOL,
        rcPaint: RECT,
        fRestore: BOOL,
        fIncUpdate: BOOL,
        rgbReserved: [32]u8,
    };

    const CREATESTRUCTW = extern struct {
        lpCreateParams: ?*anyopaque,
        hInstance: HINSTANCE,
        hMenu: ?*anyopaque,
        hwndParent: HWND,
        cy: i32,
        cx: i32,
        y: i32,
        x: i32,
        style: DWORD,
        lpszName: ?[*:0]const u16,
        lpszClass: ?*anyopaque,
        dwExStyle: DWORD,
    };

    const WNDCLASSEXW = extern struct {
        cbSize: UINT,
        style: UINT,
        lpfnWndProc: WNDPROC,
        cbClsExtra: i32,
        cbWndExtra: i32,
        hInstance: HINSTANCE,
        hIcon: ?*anyopaque,
        hCursor: ?*anyopaque,
        hbrBackground: ?*anyopaque,
        lpszMenuName: ?[*:0]const u16,
        lpszClassName: [*:0]const u16,
        hIconSm: ?*anyopaque,
    };

    const WS_CHILD: DWORD = 0x40000000;
    const WS_EX_TRANSPARENT: DWORD = 0x00000020;
    const SWP_NOSIZE: UINT = 0x0001;
    const SWP_NOMOVE: UINT = 0x0002;
    const SWP_NOZORDER: UINT = 0x0004;
    const SWP_NOACTIVATE: UINT = 0x0010;
    const SWP_SHOWWINDOW: UINT = 0x0040;
    const SWP_HIDEWINDOW: UINT = 0x0080;
    const GWLP_USERDATA: i32 = -21;
    const WM_NCCREATE: UINT = 0x0081;
    const WM_NCHITTEST: UINT = 0x0084;
    const WM_NCMOUSEMOVE: UINT = 0x00A0;
    const WM_NCLBUTTONDOWN: UINT = 0x00A1;
    const WM_NCLBUTTONUP: UINT = 0x00A2;
    const WM_NCLBUTTONDBLCLK: UINT = 0x00A3;
    const WM_NCRBUTTONDOWN: UINT = 0x00A4;
    const WM_NCRBUTTONUP: UINT = 0x00A5;
    const WM_NCRBUTTONDBLCLK: UINT = 0x00A6;
    const WM_MOUSEMOVE: UINT = 0x0200;
    const WM_LBUTTONUP: UINT = 0x0202;
    const WM_MOUSELEAVE: UINT = 0x02A3;
    const WM_NCMOUSELEAVE: UINT = 0x02A2;
    const WM_ERASEBKGND: UINT = 0x0014;
    const WM_PAINT: UINT = 0x000F;
    const WM_NCDESTROY: UINT = 0x0082;
    const WM_CLOSE: UINT = 0x0010;
    const HTTRANSPARENT: LRESULT = -1;
    const HTMAXBUTTON: LRESULT = 9;
    const HTMINBUTTON: LRESULT = 8;
    const HTTOP: LRESULT = 12;
    const HTCLOSE: LRESULT = 20;
    const HTCAPTION: LRESULT = 2;
    const TME_LEAVE: DWORD = 0x00000002;
    const TME_NONCLIENT: DWORD = 0x00000010;
    const SW_MINIMIZE: i32 = 6;
    const SW_MAXIMIZE: i32 = 3;
    const SW_RESTORE: i32 = 9;
    const ERROR_CLASS_ALREADY_EXISTS: DWORD = 1410;
    const CS_HREDRAW: UINT = 0x0002;
    const CS_VREDRAW: UINT = 0x0001;
    const CS_DBLCLKS: UINT = 0x0008;
    const IDC_ARROW_ORDINAL: usize = 32512;

    extern "kernel32" fn GetLastError() callconv(.winapi) DWORD;
    extern "kernel32" fn GetModuleHandleW(lpModuleName: ?[*:0]const u16) callconv(.winapi) HINSTANCE;
    extern "user32" fn LoadCursorW(hInstance: HINSTANCE, lpCursorName: ?[*:0]const u16) callconv(.winapi) ?*anyopaque;
    extern "user32" fn RegisterClassExW(lpWndClass: *const WNDCLASSEXW) callconv(.winapi) ATOM;
    extern "user32" fn CreateWindowExW(
        dwExStyle: DWORD,
        lpClassName: [*:0]const u16,
        lpWindowName: [*:0]const u16,
        dwStyle: DWORD,
        X: i32,
        Y: i32,
        nWidth: i32,
        nHeight: i32,
        hWndParent: HWND,
        hMenu: ?*anyopaque,
        hInstance: HINSTANCE,
        lpParam: ?*anyopaque,
    ) callconv(.winapi) HWND;
    extern "user32" fn DestroyWindow(hWnd: HWND) callconv(.winapi) BOOL;
    extern "user32" fn SetWindowPos(
        hWnd: HWND,
        hWndInsertAfter: HWND,
        X: i32,
        Y: i32,
        cx: i32,
        cy: i32,
        uFlags: UINT,
    ) callconv(.winapi) BOOL;
    extern "user32" fn SetWindowLongPtrW(hWnd: HWND, nIndex: i32, dwNewLong: LONG_PTR) callconv(.winapi) LONG_PTR;
    extern "user32" fn GetWindowLongPtrW(hWnd: HWND, nIndex: i32) callconv(.winapi) LONG_PTR;
    extern "user32" fn DefWindowProcW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
    extern "user32" fn TrackMouseEvent(lpEventTrack: *TRACKMOUSEEVENT) callconv(.winapi) BOOL;
    extern "user32" fn SetCapture(hWnd: HWND) callconv(.winapi) HWND;
    extern "user32" fn ReleaseCapture() callconv(.winapi) BOOL;
    extern "user32" fn GetCursorPos(lpPoint: *POINT) callconv(.winapi) BOOL;
    extern "user32" fn GetWindowRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;
    extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: i32) callconv(.winapi) BOOL;
    extern "user32" fn IsZoomed(hWnd: HWND) callconv(.winapi) BOOL;
    extern "user32" fn BeginPaint(hWnd: HWND, lpPaint: *PAINTSTRUCT) callconv(.winapi) ?*anyopaque;
    extern "user32" fn EndPaint(hWnd: HWND, lpPaint: *const PAINTSTRUCT) callconv(.winapi) BOOL;
    extern "user32" fn SendMessageW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
    extern "user32" fn PostMessageW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) BOOL;
    const HoverButton = enum(u8) {
        none,
        minimize,
        maximize_restore,
        close,
    };

    child_hwnd: HWND = null,
    parent_hwnd: HWND = null,
    owns_chrome: bool = false,
    parent_maximized: bool = false,
    hovered_button: HoverButton = .none,
    pressed_button: HoverButton = .none,
    tracking_mouse: bool = false,
    create_failed_logged: bool = false,
    visible_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    caption_local_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    minimize_local_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    maximize_local_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    close_local_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    resize_border_px: f32 = 0,

    const class_name = std.unicode.utf8ToUtf16LeStringLiteral("ZideSnapLayoutSink");
    var class_registered = false;
    var class_register_failed_logged = false;

    pub fn deinit(self: *WindowsSink) void {
        self.destroyChild();
    }

    pub fn active(self: *const WindowsSink) bool {
        return self.child_hwnd != null;
    }

    pub fn minimizeHovered(self: *const WindowsSink) bool {
        return self.hovered_button == .minimize;
    }

    pub fn maximizeHovered(self: *const WindowsSink) bool {
        return self.hovered_button == .maximize_restore;
    }

    pub fn closeHovered(self: *const WindowsSink) bool {
        return self.hovered_button == .close;
    }

    pub fn minimizePressed(self: *const WindowsSink) bool {
        return self.pressed_button == .minimize;
    }

    pub fn maximizePressed(self: *const WindowsSink) bool {
        return self.pressed_button == .maximize_restore;
    }

    pub fn closePressed(self: *const WindowsSink) bool {
        return self.pressed_button == .close;
    }

    pub fn ownsChrome(self: *const WindowsSink) bool {
        return self.owns_chrome and self.child_hwnd != null;
    }

    pub fn sync(self: *WindowsSink, window: *sdl_api.c.SDL_Window, contract: window_chrome_runtime.WindowChromeContract, maximized: bool) void {
        if (contract.mode != .terminal_integrated or contract.sink_rect.width <= 0 or contract.sink_rect.height <= 0 or contract.minimize_rect.width <= 0 or contract.maximize_rect.width <= 0 or contract.close_rect.width <= 0) {
            self.owns_chrome = false;
            self.hovered_button = .none;
            self.pressed_button = .none;
            self.tracking_mouse = false;
            self.hideChild();
            return;
        }

        const parent = sdl_api.getWindowWin32Hwnd(window) orelse {
            self.owns_chrome = false;
            self.hideChild();
            return;
        };
        self.parent_hwnd = parent;
        self.parent_maximized = maximized;
        self.resize_border_px = contract.resize_border_px;

        if (self.child_hwnd == null) {
            if (!ensureWindowClass()) {
                self.owns_chrome = false;
                return;
            }
            const instance = GetModuleHandleW(null);
            self.child_hwnd = CreateWindowExW(
                WS_EX_TRANSPARENT,
                class_name,
                std.unicode.utf8ToUtf16LeStringLiteral(""),
                WS_CHILD,
                0,
                0,
                0,
                0,
                parent,
                null,
                instance,
                self,
            );
            if (self.child_hwnd == null) {
                if (!self.create_failed_logged) {
                    app_logger.logger("windows.chrome").logStdout(.warning, "CreateWindowExW titleband sink failed parent=0x{x} err=0x{x}", .{
                        @intFromPtr(parent),
                        GetLastError(),
                    });
                    self.create_failed_logged = true;
                }
                self.owns_chrome = false;
                return;
            }

            self.create_failed_logged = false;
        }

        self.visible_rect = contract.sink_rect;
        self.caption_local_rect = .{
            .x = contract.caption_rect.x - contract.sink_rect.x,
            .y = contract.caption_rect.y - contract.sink_rect.y,
            .width = contract.caption_rect.width,
            .height = contract.caption_rect.height,
        };
        self.minimize_local_rect = .{
            .x = contract.minimize_rect.x - contract.sink_rect.x,
            .y = contract.minimize_rect.y - contract.sink_rect.y,
            .width = contract.minimize_rect.width,
            .height = contract.minimize_rect.height,
        };
        self.maximize_local_rect = .{
            .x = contract.maximize_rect.x - contract.sink_rect.x,
            .y = contract.maximize_rect.y - contract.sink_rect.y,
            .width = contract.maximize_rect.width,
            .height = contract.maximize_rect.height,
        };
        self.close_local_rect = .{
            .x = contract.close_rect.x - contract.sink_rect.x,
            .y = contract.close_rect.y - contract.sink_rect.y,
            .width = contract.close_rect.width,
            .height = contract.close_rect.height,
        };
        const x = snapInt(contract.sink_rect.x);
        const y = snapInt(contract.sink_rect.y);
        const w = @max(1, snapInt(contract.sink_rect.width));
        const h = @max(1, snapInt(contract.sink_rect.height));
        _ = SetWindowPos(self.child_hwnd, null, x, y, w, h, SWP_NOACTIVATE | SWP_NOZORDER | SWP_SHOWWINDOW);
        self.owns_chrome = true;
    }

    fn hideChild(self: *WindowsSink) void {
        if (self.child_hwnd) |hwnd| {
            _ = SetWindowPos(hwnd, null, 0, 0, 0, 0, SWP_NOACTIVATE | SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE | SWP_HIDEWINDOW);
        }
    }

    fn destroyChild(self: *WindowsSink) void {
        if (self.child_hwnd) |hwnd| {
            _ = SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
            _ = DestroyWindow(hwnd);
        }
        self.child_hwnd = null;
        self.parent_hwnd = null;
        self.owns_chrome = false;
        self.hovered_button = .none;
        self.pressed_button = .none;
        self.tracking_mouse = false;
        self.create_failed_logged = false;
    }

    fn toggleParentMaximize(self: *WindowsSink) void {
        const parent = self.parent_hwnd orelse return;
        if (IsZoomed(parent) != 0) {
            _ = ShowWindow(parent, SW_RESTORE);
        } else {
            _ = ShowWindow(parent, SW_MAXIMIZE);
        }
    }

    fn buttonFromHit(hit: LRESULT) HoverButton {
        return switch (hit) {
            HTMINBUTTON => .minimize,
            HTMAXBUTTON => .maximize_restore,
            HTCLOSE => .close,
            else => .none,
        };
    }

    fn invokeButton(self: *WindowsSink, button: HoverButton) void {
        const parent = self.parent_hwnd orelse return;
        switch (button) {
            .minimize => _ = ShowWindow(parent, SW_MINIMIZE),
            .maximize_restore => self.toggleParentMaximize(),
            .close => _ = PostMessageW(parent, WM_CLOSE, 0, 0),
            .none => {},
        }
    }

    fn currentHit(self: *WindowsSink) LRESULT {
        const hwnd = self.child_hwnd orelse return HTTRANSPARENT;
        var cursor: POINT = undefined;
        if (GetCursorPos(&cursor) == 0) return HTTRANSPARENT;
        return self.hitRegionAtScreenPoint(hwnd, cursor.x, cursor.y);
    }

    fn hitRegionAtScreenPoint(self: *WindowsSink, hwnd: HWND, screen_x: i32, screen_y: i32) LRESULT {
        var rect: RECT = undefined;
        if (GetWindowRect(hwnd, &rect) == 0) return HTTRANSPARENT;
        const local_x = @as(f32, @floatFromInt(screen_x - rect.left));
        const local_y = @as(f32, @floatFromInt(screen_y - rect.top));
        if (pointInRect(local_x, local_y, self.close_local_rect)) return HTCLOSE;
        if (pointInRect(local_x, local_y, self.maximize_local_rect)) return HTMAXBUTTON;
        if (pointInRect(local_x, local_y, self.minimize_local_rect)) return HTMINBUTTON;
        if (!self.parent_maximized and local_y < self.resize_border_px) return HTTOP;
        if (pointInRect(local_x, local_y, self.caption_local_rect)) return HTCAPTION;
        return HTTRANSPARENT;
    }

    fn beginTracking(self: *WindowsSink, nonclient: bool) void {
        if (self.tracking_mouse or self.child_hwnd == null) return;
        var event = TRACKMOUSEEVENT{
            .cbSize = @sizeOf(TRACKMOUSEEVENT),
            .dwFlags = if (nonclient) TME_LEAVE | TME_NONCLIENT else TME_LEAVE,
            .hwndTrack = self.child_hwnd,
            .dwHoverTime = 0,
        };
        if (TrackMouseEvent(&event) != 0) self.tracking_mouse = true;
    }

    fn ensureWindowClass() bool {
        if (class_registered) return true;

        const instance = GetModuleHandleW(null);
        var klass = WNDCLASSEXW{
            .cbSize = @sizeOf(WNDCLASSEXW),
            .style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS,
            .lpfnWndProc = &sinkProc,
            .cbClsExtra = 0,
            .cbWndExtra = @sizeOf(usize),
            .hInstance = instance,
            .hIcon = null,
            .hCursor = LoadCursorW(null, @ptrFromInt(IDC_ARROW_ORDINAL)),
            .hbrBackground = null,
            .lpszMenuName = null,
            .lpszClassName = class_name,
            .hIconSm = null,
        };
        const atom = RegisterClassExW(&klass);
        if (atom == 0) {
            const err = GetLastError();
            if (err != ERROR_CLASS_ALREADY_EXISTS) {
                if (!class_register_failed_logged) {
                    app_logger.logger("windows.chrome").logStdout(.warning, "RegisterClassExW titleband sink failed err=0x{x}", .{err});
                    class_register_failed_logged = true;
                }
                return false;
            }
        }
        class_registered = true;
        class_register_failed_logged = false;
        return true;
    }

    fn selfFromHwnd(hwnd: HWND) ?*WindowsSink {
        const raw = GetWindowLongPtrW(hwnd, GWLP_USERDATA);
        if (raw == 0) return null;
        return @ptrFromInt(@as(usize, @bitCast(raw)));
    }

    fn sinkProc(hwnd: HWND, msg: UINT, wparam: WPARAM, lparam: LPARAM) callconv(.winapi) LRESULT {
        if (msg == WM_NCCREATE) {
            const create_struct: *const CREATESTRUCTW = @ptrFromInt(@as(usize, @bitCast(lparam)));
            const raw_self = create_struct.lpCreateParams orelse {
                return 0;
            };
            _ = SetWindowLongPtrW(hwnd, GWLP_USERDATA, ptrToLong(raw_self));
            return 1;
        }

        const self = selfFromHwnd(hwnd) orelse return DefWindowProcW(hwnd, msg, wparam, lparam);

        switch (msg) {
            WM_NCHITTEST => {
                const screen_x = @as(i32, @intCast(@as(i16, @truncate(lparam & 0xffff))));
                const screen_y = @as(i32, @intCast(@as(i16, @truncate((lparam >> 16) & 0xffff))));
                return self.hitRegionAtScreenPoint(hwnd, screen_x, screen_y);
            },
            WM_NCMOUSEMOVE => {
                const hit = @as(LRESULT, @intCast(wparam));
                switch (hit) {
                    HTTOP, HTCAPTION => {
                        self.hovered_button = .none;
                        const parent = self.parent_hwnd orelse return 0;
                        return SendMessageW(parent, msg, wparam, lparam);
                    },
                    HTMINBUTTON, HTMAXBUTTON, HTCLOSE => {
                        self.hovered_button = buttonFromHit(hit);
                        self.beginTracking(true);
                    },
                    else => self.hovered_button = .none,
                }
                return 0;
            },
            WM_MOUSEMOVE => {
                const hit = self.currentHit();
                self.hovered_button = buttonFromHit(hit);
                if (hit == HTMINBUTTON or hit == HTMAXBUTTON or hit == HTCLOSE) {
                    self.beginTracking(false);
                }
                return 0;
            },
            WM_NCMOUSELEAVE, WM_MOUSELEAVE => {
                self.tracking_mouse = false;
                self.hovered_button = .none;
                return 0;
            },
            WM_NCLBUTTONDOWN => {
                const hit = @as(LRESULT, @intCast(wparam));
                switch (hit) {
                    HTTOP, HTCAPTION => {
                        const parent = self.parent_hwnd orelse return 0;
                        return SendMessageW(parent, msg, wparam, lparam);
                    },
                    HTMINBUTTON, HTMAXBUTTON, HTCLOSE => {
                        self.hovered_button = buttonFromHit(hit);
                        self.pressed_button = buttonFromHit(hit);
                        _ = SetCapture(hwnd);
                        return 0;
                    },
                    else => return DefWindowProcW(hwnd, msg, wparam, lparam),
                }
            },
            WM_NCLBUTTONDBLCLK => {
                const hit = @as(LRESULT, @intCast(wparam));
                switch (hit) {
                    HTTOP, HTCAPTION => {
                        const parent = self.parent_hwnd orelse return 0;
                        return SendMessageW(parent, msg, wparam, lparam);
                    },
                    HTMINBUTTON, HTMAXBUTTON, HTCLOSE => {
                        self.hovered_button = buttonFromHit(hit);
                        self.pressed_button = buttonFromHit(hit);
                        return 0;
                    },
                    else => return DefWindowProcW(hwnd, msg, wparam, lparam),
                }
            },
            WM_NCLBUTTONUP, WM_LBUTTONUP => {
                const hit: LRESULT = if (msg == WM_NCLBUTTONUP)
                    @as(LRESULT, @intCast(wparam))
                else
                    self.currentHit();
                if (msg == WM_NCLBUTTONUP) {
                    switch (hit) {
                        HTTOP, HTCAPTION => {
                            self.pressed_button = .none;
                            self.hovered_button = .none;
                            const parent = self.parent_hwnd orelse return 0;
                            return SendMessageW(parent, WM_NCLBUTTONUP, @intCast(hit), lparam);
                        },
                        else => {},
                    }
                }
                const pressed = self.pressed_button;
                self.pressed_button = .none;
                _ = ReleaseCapture();
                self.hovered_button = buttonFromHit(hit);
                if (pressed != .none and pressed == buttonFromHit(hit)) {
                    self.invokeButton(pressed);
                }
                return 0;
            },
            WM_NCRBUTTONDOWN, WM_NCRBUTTONUP, WM_NCRBUTTONDBLCLK => {
                const parent = self.parent_hwnd orelse return 0;
                return SendMessageW(parent, msg, wparam, lparam);
            },
            WM_ERASEBKGND => return 1,
            WM_PAINT => {
                var ps: PAINTSTRUCT = undefined;
                _ = BeginPaint(hwnd, &ps);
                _ = EndPaint(hwnd, &ps);
                return 0;
            },
            WM_NCDESTROY => {
                if (self.child_hwnd == hwnd) {
                    self.child_hwnd = null;
                }
                self.hovered_button = .none;
                self.pressed_button = .none;
                self.tracking_mouse = false;
                _ = SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
            },
            else => {},
        }

        return DefWindowProcW(hwnd, msg, wparam, lparam);
    }

    fn snapInt(value: f32) i32 {
        return @intFromFloat(std.math.round(value));
    }

    fn pointInRect(x: f32, y: f32, rect: Rect) bool {
        return x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height;
    }

    fn ptrToLong(ptr: anytype) LONG_PTR {
        return @as(LONG_PTR, @bitCast(@intFromPtr(ptr)));
    }
};
