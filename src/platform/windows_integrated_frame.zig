const std = @import("std");
const builtin = @import("builtin");
const native_host = @import("native_host.zig");
const app_logger = @import("../app_logger.zig");
const window_chrome_runtime = @import("../ui/renderer/window_chrome_runtime.zig");

pub const FrameOwner = if (builtin.target.os.tag == .windows) WindowsIntegratedFrame else StubFrameOwner;

const StubFrameOwner = struct {
    pub fn deinit(_: *StubFrameOwner) void {}
    pub fn sync(_: *StubFrameOwner, _: native_host.PlatformRenderHost, _: window_chrome_runtime.WindowChromeMode, _: bool, _: bool) void {}
};

const WindowsIntegratedFrame = struct {
    const HWND = ?*anyopaque;
    const UINT = u32;
    const WPARAM = usize;
    const LPARAM = isize;
    const LRESULT = isize;
    const DWORD = u32;
    const BOOL = i32;
    const LONG = i32;
    const DWORD_PTR = usize;
    const UINT_PTR = usize;
    const HRESULT = i32;
    const RECT = extern struct {
        left: LONG,
        top: LONG,
        right: LONG,
        bottom: LONG,
    };
    const NCCALCSIZE_PARAMS = extern struct {
        rgrc: [3]RECT,
        lppos: ?*anyopaque,
    };
    const MARGINS = extern struct {
        cxLeftWidth: i32,
        cxRightWidth: i32,
        cyTopHeight: i32,
        cyBottomHeight: i32,
    };
    const SUBCLASSPROC = *const fn (HWND, UINT, WPARAM, LPARAM, UINT_PTR, DWORD_PTR) callconv(.winapi) LRESULT;

    const WM_NCCALCSIZE: UINT = 0x0083;
    const GWL_STYLE: i32 = -16;
    const GWL_EXSTYLE: i32 = -20;
    const WS_MAXIMIZE: DWORD = 0x01000000;
    const SM_CYSIZEFRAME: i32 = 33;
    const SM_CXPADDEDBORDER: i32 = 92;
    const SWP_NOMOVE: UINT = 0x0002;
    const SWP_NOSIZE: UINT = 0x0001;
    const SWP_NOZORDER: UINT = 0x0004;
    const SWP_NOACTIVATE: UINT = 0x0010;
    const SWP_FRAMECHANGED: UINT = 0x0020;
    const SUBCLASS_ID: UINT_PTR = 0x5A4944455F46524D; // "ZIDE_FRM"

    extern "comctl32" fn SetWindowSubclass(hWnd: HWND, pfnSubclass: SUBCLASSPROC, uIdSubclass: UINT_PTR, dwRefData: DWORD_PTR) callconv(.winapi) BOOL;
    extern "comctl32" fn RemoveWindowSubclass(hWnd: HWND, pfnSubclass: SUBCLASSPROC, uIdSubclass: UINT_PTR) callconv(.winapi) BOOL;
    extern "comctl32" fn DefSubclassProc(hWnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
    extern "user32" fn GetWindowLongW(hWnd: HWND, nIndex: i32) callconv(.winapi) LONG;
    extern "user32" fn GetDpiForWindow(hWnd: HWND) callconv(.winapi) UINT;
    extern "user32" fn GetSystemMetricsForDpi(nIndex: i32, dpi: UINT) callconv(.winapi) i32;
    extern "user32" fn IsZoomed(hWnd: HWND) callconv(.winapi) BOOL;
    extern "user32" fn AdjustWindowRectExForDpi(lpRect: *RECT, dwStyle: DWORD, bMenu: BOOL, dwExStyle: DWORD, dpi: UINT) callconv(.winapi) BOOL;
    extern "user32" fn SetWindowPos(hWnd: HWND, hWndInsertAfter: HWND, X: i32, Y: i32, cx: i32, cy: i32, uFlags: UINT) callconv(.winapi) BOOL;
    extern "dwmapi" fn DwmExtendFrameIntoClientArea(hwnd: HWND, pMarInset: *const MARGINS) callconv(.winapi) HRESULT;

    hwnd: HWND = null,
    installed: bool = false,
    mode: window_chrome_runtime.WindowChromeMode = .native,
    maximized: bool = false,
    fullscreen: bool = false,
    applied_top_margin: i32 = -1,

    pub fn deinit(self: *WindowsIntegratedFrame) void {
        self.uninstall();
    }

    pub fn sync(self: *WindowsIntegratedFrame, render_host: native_host.PlatformRenderHost, mode: window_chrome_runtime.WindowChromeMode, maximized: bool, fullscreen: bool) void {
        if (mode == .native) {
            self.uninstall();
            return;
        }

        const hwnd = render_host.win32Hwnd() orelse {
            self.uninstall();
            return;
        };

        if (self.hwnd != hwnd) {
            self.uninstall();
        }
        if (!self.installed) {
            self.install(hwnd);
        }
        self.mode = mode;
        self.maximized = self.querySyncMaximized(hwnd, maximized);
        self.fullscreen = fullscreen;
        self.updateFrameMargins();
        app_logger.logger("windows.chrome").logf(.info, "integrated_frame sync hwnd=0x{x} mode={s} maximized={d} fullscreen={d} top_margin={d}", .{
            pointerValue(hwnd),
            @tagName(mode),
            @intFromBool(self.maximized),
            @intFromBool(fullscreen),
            self.applied_top_margin,
        });
    }

    fn install(self: *WindowsIntegratedFrame, hwnd: HWND) void {
        if (hwnd == null) return;
        if (SetWindowSubclass(hwnd, &subclassProc, SUBCLASS_ID, @intFromPtr(self)) == 0) {
            app_logger.logger("windows.chrome").logStdout(.warning, "SetWindowSubclass integrated frame failed hwnd=0x{x}", .{pointerValue(hwnd)});
            return;
        }
        self.hwnd = hwnd;
        self.installed = true;
        self.applied_top_margin = -1;
        self.forceFrameChanged();
    }

    fn uninstall(self: *WindowsIntegratedFrame) void {
        if (self.installed and self.hwnd != null) {
            self.applyTopMargin(0);
            _ = RemoveWindowSubclass(self.hwnd, &subclassProc, SUBCLASS_ID);
            self.forceFrameChanged();
        }
        self.* = .{};
    }

    fn forceFrameChanged(self: *WindowsIntegratedFrame) void {
        const hwnd = self.hwnd orelse return;
        _ = SetWindowPos(hwnd, null, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    }

    fn updateFrameMargins(self: *WindowsIntegratedFrame) void {
        if (!self.installed) return;
        const top_margin = self.computeTopMargin();
        self.applyTopMargin(top_margin);
    }

    fn computeTopMargin(self: *const WindowsIntegratedFrame) i32 {
        const hwnd = self.hwnd orelse return 0;
        if (self.maximized or self.fullscreen) return 0;

        var frame = RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
        const style = @as(DWORD, @bitCast(GetWindowLongW(hwnd, GWL_STYLE)));
        const exstyle = @as(DWORD, @bitCast(GetWindowLongW(hwnd, GWL_EXSTYLE)));
        const dpi = GetDpiForWindow(hwnd);
        if (AdjustWindowRectExForDpi(&frame, style, 0, exstyle, dpi) == 0) {
            return 1;
        }
        return @max(1, -frame.top);
    }

    fn getResizeHandleHeight(self: *const WindowsIntegratedFrame) i32 {
        const hwnd = self.hwnd orelse return 0;
        const dpi = GetDpiForWindow(hwnd);
        return @max(0, GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi) + GetSystemMetricsForDpi(SM_CYSIZEFRAME, dpi));
    }

    fn applyTopMargin(self: *WindowsIntegratedFrame, top_margin: i32) void {
        if (self.applied_top_margin == top_margin) return;
        const hwnd = self.hwnd orelse return;
        const margins = MARGINS{
            .cxLeftWidth = 0,
            .cxRightWidth = 0,
            .cyTopHeight = top_margin,
            .cyBottomHeight = 0,
        };
        _ = DwmExtendFrameIntoClientArea(hwnd, &margins);
        self.applied_top_margin = top_margin;
    }

    fn querySyncMaximized(_: *const WindowsIntegratedFrame, hwnd: HWND, sdl_maximized: bool) bool {
        if (hwnd == null) return sdl_maximized;
        return IsZoomed(hwnd) != 0;
    }

    fn queryNcCalcMaximized(_: *const WindowsIntegratedFrame, hwnd: HWND, sdl_maximized: bool) bool {
        if (hwnd == null) return sdl_maximized;
        const style = @as(DWORD, @bitCast(GetWindowLongW(hwnd, GWL_STYLE)));
        return (style & WS_MAXIMIZE) != 0;
    }

    fn subclassProc(hwnd: HWND, msg: UINT, wparam: WPARAM, lparam: LPARAM, _: UINT_PTR, ref_data: DWORD_PTR) callconv(.winapi) LRESULT {
        const self: *WindowsIntegratedFrame = @ptrFromInt(ref_data);
        switch (msg) {
            WM_NCCALCSIZE => {
                if (self.mode != .native and wparam != 0) {
                    const params: *NCCALCSIZE_PARAMS = @ptrFromInt(@as(usize, @bitCast(lparam)));
                    const original_top = params.rgrc[0].top;
                    const ret = DefSubclassProc(hwnd, msg, wparam, lparam);
                    if (ret != 0) return ret;

                    const live_maximized = self.queryNcCalcMaximized(hwnd, self.maximized);
                    params.rgrc[0].top = original_top;

                    if (live_maximized and !self.fullscreen) {
                        const resize_handle_height = self.getResizeHandleHeight();
                        params.rgrc[0].top += resize_handle_height;
                        app_logger.logger("windows.chrome").logf(.info, "integrated_frame nccalc hwnd=0x{x} mode={s} maximized={d} fullscreen={d} restored_top={d} resize_handle={d} final_top={d}", .{
                            pointerValue(hwnd),
                            @tagName(self.mode),
                            @intFromBool(live_maximized),
                            @intFromBool(self.fullscreen),
                            original_top,
                            resize_handle_height,
                            params.rgrc[0].top,
                        });
                        return 0;
                    }

                    app_logger.logger("windows.chrome").logf(.info, "integrated_frame nccalc hwnd=0x{x} mode={s} maximized={d} fullscreen={d} restored_top={d} final_top={d}", .{
                        pointerValue(hwnd),
                        @tagName(self.mode),
                        @intFromBool(live_maximized),
                        @intFromBool(self.fullscreen),
                        original_top,
                        params.rgrc[0].top,
                    });
                    return 0;
                }
            },
            else => {},
        }
        return DefSubclassProc(hwnd, msg, wparam, lparam);
    }

    fn pointerValue(hwnd: HWND) usize {
        return if (hwnd) |value| @intFromPtr(value) else 0;
    }
};
