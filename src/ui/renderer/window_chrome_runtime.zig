const std = @import("std");
const builtin = @import("builtin");
const app_logger = @import("../../app_logger.zig");
const native_host = @import("../../platform/native_host.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const windows_frame_material = @import("../../platform/windows_frame_material.zig");
const windows_integrated_frame = @import("../../platform/windows_integrated_frame.zig");
const windows_snap_layout_sink = @import("../../platform/windows_snap_layout_sink.zig");
const shared_types = @import("../../types/mod.zig");

const Rect = shared_types.layout.Rect;

pub const WindowChromeMode = enum {
    native,
    terminal_integrated,
    top_bar_integrated,
};

pub const WindowChromeContract = struct {
    mode: WindowChromeMode = .native,
    caption_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    sink_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    minimize_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    maximize_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    close_rect: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    resize_border_px: f32 = 8.0,
};

pub const WindowChromeState = struct {
    contract: WindowChromeContract = .{},
    applied_mode: WindowChromeMode = .native,
    applied_material: windows_frame_material.Policy = .{},
    integrated_frame: windows_integrated_frame.FrameOwner = .{},
    snap_sink: windows_snap_layout_sink.Sink = .{},
};

pub const WindowChromeDomain = struct {
    render_host: *const native_host.PlatformRenderHost,
    window: *sdl_api.c.SDL_Window,
    window_focused: bool,
    contract: *WindowChromeContract,
    applied_mode: *WindowChromeMode,
    applied_material: *windows_frame_material.Policy,
    integrated_frame: *windows_integrated_frame.FrameOwner,
    snap_sink: *windows_snap_layout_sink.Sink,
    hit_test_callback: sdl_api.HitTest,
    hit_test_data: ?*anyopaque,
};

pub fn applyContract(domain: WindowChromeDomain, contract: WindowChromeContract) void {
    domain.contract.* = if (builtin.target.os.tag == .windows) contract else .{};
    if (builtin.target.os.tag != .windows) return;

    const material_policy = windows_frame_material.policyForChromeMode(domain.contract.mode, domain.window_focused);
    if (!std.meta.eql(domain.applied_material.*, material_policy)) {
        windows_frame_material.apply(domain.render_host.*, material_policy);
        domain.applied_material.* = material_policy;
    }

    const integrated = domain.contract.mode != .native;
    if (domain.applied_mode.* != domain.contract.mode) {
        domain.applied_mode.* = domain.contract.mode;

        if (!sdl_api.setWindowBordered(domain.window, !integrated)) {
            app_logger.logger("sdl.window").logStdout(.warning, "SDL_SetWindowBordered failed integrated={d} err={s}", .{
                @intFromBool(integrated),
                sdl_api.getError(),
            });
        }
        if (!sdl_api.setWindowHitTest(
            domain.window,
            if (integrated) domain.hit_test_callback else null,
            if (integrated) domain.hit_test_data else null,
        )) {
            app_logger.logger("sdl.window").logStdout(.warning, "SDL_SetWindowHitTest failed integrated={d} err={s}", .{
                @intFromBool(integrated),
                sdl_api.getError(),
            });
        }
        _ = sdl_api.syncWindow(domain.window);
    }

    domain.integrated_frame.sync(domain.render_host.*, domain.contract.mode, windowIsMaximized(domain.window), windowIsFullscreen(domain.window));
    domain.snap_sink.sync(domain.render_host.*, domain.contract.*, windowIsMaximized(domain.window));
}

pub fn deinit(domain: WindowChromeDomain) void {
    domain.integrated_frame.deinit();
    domain.snap_sink.deinit();
}

pub fn sinkActive(sink: *const windows_snap_layout_sink.Sink) bool {
    return sink.active();
}

pub fn minimizeHovered(sink: *const windows_snap_layout_sink.Sink) bool {
    return sink.minimizeHovered();
}

pub fn maximizeHovered(sink: *const windows_snap_layout_sink.Sink) bool {
    return sink.maximizeHovered();
}

pub fn closeHovered(sink: *const windows_snap_layout_sink.Sink) bool {
    return sink.closeHovered();
}

pub fn minimizePressed(sink: *const windows_snap_layout_sink.Sink) bool {
    return sink.minimizePressed();
}

pub fn maximizePressed(sink: *const windows_snap_layout_sink.Sink) bool {
    return sink.maximizePressed();
}

pub fn closePressed(sink: *const windows_snap_layout_sink.Sink) bool {
    return sink.closePressed();
}

pub fn sinkOwnsChrome(sink: *const windows_snap_layout_sink.Sink) bool {
    return sink.ownsChrome();
}

pub fn windowIsMaximized(window: *sdl_api.c.SDL_Window) bool {
    return (sdl_api.getWindowFlags(window) & sdl_api.c.SDL_WINDOW_MAXIMIZED) != 0;
}

pub fn windowIsFullscreen(window: *sdl_api.c.SDL_Window) bool {
    return (sdl_api.getWindowFlags(window) & sdl_api.c.SDL_WINDOW_FULLSCREEN) != 0;
}

pub fn hitTest(
    contract: WindowChromeContract,
    window_width: i32,
    window_height: i32,
    maximized: bool,
    x: f32,
    y: f32,
) sdl_api.HitTestResult {
    if (contract.mode == .native) return sdl_api.c.SDL_HITTEST_NORMAL;

    const border = @max(@as(f32, 1.0), contract.resize_border_px);
    const width_f = @as(f32, @floatFromInt(window_width));
    const height_f = @as(f32, @floatFromInt(window_height));

    const left = x < border;
    const right = x >= width_f - border;
    const top = y < border;
    const bottom = y >= height_f - border;

    if (!maximized) {
        if (top and left) return sdl_api.c.SDL_HITTEST_RESIZE_TOPLEFT;
        if (top and right) return sdl_api.c.SDL_HITTEST_RESIZE_TOPRIGHT;
        if (bottom and left) return sdl_api.c.SDL_HITTEST_RESIZE_BOTTOMLEFT;
        if (bottom and right) return sdl_api.c.SDL_HITTEST_RESIZE_BOTTOMRIGHT;
        if (top) return sdl_api.c.SDL_HITTEST_RESIZE_TOP;
        if (right) return sdl_api.c.SDL_HITTEST_RESIZE_RIGHT;
        if (bottom) return sdl_api.c.SDL_HITTEST_RESIZE_BOTTOM;
        if (left) return sdl_api.c.SDL_HITTEST_RESIZE_LEFT;
    }

    if (pointInRect(x, y, contract.caption_rect)) return sdl_api.c.SDL_HITTEST_DRAGGABLE;
    return sdl_api.c.SDL_HITTEST_NORMAL;
}

fn pointInRect(x: f32, y: f32, rect: Rect) bool {
    return x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height;
}

test "integrated hit test uses resize borders before caption drag" {
    const contract = WindowChromeContract{
        .mode = .terminal_integrated,
        .caption_rect = .{ .x = 80, .y = 0, .width = 120, .height = 30 },
        .resize_border_px = 8,
    };

    try std.testing.expectEqual(@as(i32, sdl_api.c.SDL_HITTEST_RESIZE_TOPLEFT), @as(i32, @intCast(hitTest(contract, 800, 600, false, 2, 2))));
    try std.testing.expectEqual(@as(i32, sdl_api.c.SDL_HITTEST_DRAGGABLE), @as(i32, @intCast(hitTest(contract, 800, 600, false, 120, 10))));
    try std.testing.expectEqual(@as(i32, sdl_api.c.SDL_HITTEST_NORMAL), @as(i32, @intCast(hitTest(contract, 800, 600, false, 250, 40))));
}

test "maximized integrated hit test disables resize edges" {
    const contract = WindowChromeContract{
        .mode = .terminal_integrated,
        .caption_rect = .{ .x = 0, .y = 0, .width = 200, .height = 30 },
        .resize_border_px = 8,
    };

    try std.testing.expectEqual(@as(i32, sdl_api.c.SDL_HITTEST_DRAGGABLE), @as(i32, @intCast(hitTest(contract, 800, 600, true, 10, 4))));
}
