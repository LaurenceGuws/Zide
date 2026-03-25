const builtin = @import("builtin");
const sdl_api = @import("sdl_api.zig");
const window_chrome_runtime = @import("../ui/renderer/window_chrome_runtime.zig");

pub const Policy = struct {
    dark_mode: bool = true,
    backdrop: Backdrop = .none,
    focused: bool = true,
    border_color: ?Color = null,
    corner_preference: CornerPreference = .round,
};

pub const Backdrop = enum {
    none,
    mica,
    tabbed,
};

pub const CornerPreference = enum {
    default,
    no_round,
    round,
    round_small,
};

const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 0xff,
};

pub fn policyForChromeMode(mode: window_chrome_runtime.WindowChromeMode, focused: bool) Policy {
    const active_border = switch (mode) {
        .native => Color{ .r = 70, .g = 74, .b = 86 },
        .terminal_integrated => Color{ .r = 82, .g = 90, .b = 112 },
        .top_bar_integrated => Color{ .r = 94, .g = 101, .b = 121 },
    };
    const inactive_border = switch (mode) {
        .native => Color{ .r = 52, .g = 55, .b = 64 },
        .terminal_integrated => Color{ .r = 58, .g = 63, .b = 76 },
        .top_bar_integrated => Color{ .r = 64, .g = 68, .b = 82 },
    };

    return switch (mode) {
        .native => .{
            .dark_mode = true,
            .backdrop = .none,
            .focused = focused,
            .border_color = if (focused) active_border else inactive_border,
            .corner_preference = .round,
        },
        .terminal_integrated => .{
            .dark_mode = true,
            .backdrop = .tabbed,
            .focused = focused,
            .border_color = if (focused) active_border else inactive_border,
            .corner_preference = .round,
        },
        .top_bar_integrated => .{
            .dark_mode = true,
            .backdrop = .mica,
            .focused = focused,
            .border_color = if (focused) active_border else inactive_border,
            .corner_preference = .round,
        },
    };
}

pub fn apply(window: *sdl_api.c.SDL_Window, policy: Policy) void {
    if (builtin.target.os.tag != .windows) return;
    const hwnd = sdl_api.getWindowWin32Hwnd(window) orelse return;
    applyToHwnd(hwnd, policy);
}

fn applyToHwnd(hwnd: ?*anyopaque, policy: Policy) void {
    const dark_mode: BOOL = if (policy.dark_mode) 1 else 0;
    _ = DwmSetWindowAttribute(
        hwnd,
        DWMWA_USE_IMMERSIVE_DARK_MODE,
        &dark_mode,
        @sizeOf(BOOL),
    );

    const backdrop: i32 = switch (policy.backdrop) {
        .none => DWMSBT_NONE,
        .mica => DWMSBT_MAINWINDOW,
        .tabbed => DWMSBT_TABBEDWINDOW,
    };
    _ = DwmSetWindowAttribute(
        hwnd,
        DWMWA_SYSTEMBACKDROP_TYPE,
        &backdrop,
        @sizeOf(i32),
    );

    const border_color = colorRef(policy.border_color orelse Color{ .r = 0, .g = 0, .b = 0, .a = 0 });
    _ = DwmSetWindowAttribute(
        hwnd,
        DWMWA_BORDER_COLOR,
        &border_color,
        @sizeOf(COLORREF),
    );

    const corner: u32 = switch (policy.corner_preference) {
        .default => DWMWCP_DEFAULT,
        .no_round => DWMWCP_DONOTROUND,
        .round => DWMWCP_ROUND,
        .round_small => DWMWCP_ROUNDSMALL,
    };
    _ = DwmSetWindowAttribute(
        hwnd,
        DWMWA_WINDOW_CORNER_PREFERENCE,
        &corner,
        @sizeOf(u32),
    );
}

fn colorRef(color: Color) COLORREF {
    return @as(COLORREF, color.r) |
        (@as(COLORREF, color.g) << 8) |
        (@as(COLORREF, color.b) << 16);
}

const HWND = ?*anyopaque;
const HRESULT = i32;
const BOOL = i32;
const DWORD = u32;
const COLORREF = u32;

const DWMWA_USE_IMMERSIVE_DARK_MODE: DWORD = 20;
const DWMWA_WINDOW_CORNER_PREFERENCE: DWORD = 33;
const DWMWA_BORDER_COLOR: DWORD = 34;
const DWMWA_SYSTEMBACKDROP_TYPE: DWORD = 38;

const DWMSBT_NONE: i32 = 1;
const DWMSBT_MAINWINDOW: i32 = 2;
const DWMSBT_TABBEDWINDOW: i32 = 4;
const DWMWCP_DEFAULT: u32 = 0;
const DWMWCP_DONOTROUND: u32 = 1;
const DWMWCP_ROUND: u32 = 2;
const DWMWCP_ROUNDSMALL: u32 = 3;

extern "dwmapi" fn DwmSetWindowAttribute(
    hwnd: HWND,
    dwAttribute: DWORD,
    pvAttribute: *const anyopaque,
    cbAttribute: DWORD,
) callconv(.winapi) HRESULT;
