const native_host = @import("native_host.zig");
const sdl_api = @import("sdl_api.zig");
const sdl_native_host = @import("sdl_native_host.zig");

pub fn isAndroidActivityHost(app_host: native_host.PlatformAppHost) bool {
    return app_host.kind == .android_activity;
}

pub fn onWillEnterForeground(app_host: *native_host.PlatformAppHost) void {
    app_host.noteStarted();
}

pub fn onDidEnterForeground(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
) void {
    app_host.noteResumed();
    render_host.noteRedrawRequested();
}

pub fn onWillEnterBackground(app_host: *native_host.PlatformAppHost) void {
    app_host.notePaused();
}

pub fn onDidEnterBackground(app_host: *native_host.PlatformAppHost) void {
    app_host.noteStopped();
}

pub fn onSurfaceMetricsChanged(
    render_host: *native_host.PlatformRenderHost,
    metrics: native_host.RenderSurfaceMetrics,
) void {
    render_host.noteSurfaceAvailable(metrics);
    render_host.noteRedrawRequested();
}

pub fn onSurfaceDestroyed(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
) void {
    render_host.noteSurfaceUnavailable();
    app_host.noteSurfaceFocused(false);
    app_host.noteTextInputActive(false);
}

pub fn onWindowFocusChanged(
    app_host: *native_host.PlatformAppHost,
    focused: bool,
) void {
    app_host.noteSurfaceFocused(focused);
    if (focused and !isAndroidActivityHost(app_host.*)) {
        app_host.noteTextInputActive(true);
    }
}

pub fn onWindowRefresh(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
    window: *sdl_api.c.SDL_Window,
) bool {
    if (!isAndroidActivityHost(app_host.*)) return false;
    onSurfaceMetricsChanged(render_host, sdl_native_host.captureWindowSurfaceMetrics(window));
    return true;
}

test "focus policy keeps android text input host-driven on gain" {
    const std = @import("std");

    var android_host = native_host.PlatformAppHost{
        .kind = .android_activity,
        .lifecycle_state = .started,
    };
    onWindowFocusChanged(&android_host, true);
    try std.testing.expect(android_host.surface_focused);
    try std.testing.expect(!android_host.text_input_active);

    var desktop_host = native_host.PlatformAppHost{
        .kind = .sdl_desktop,
        .lifecycle_state = .started,
    };
    onWindowFocusChanged(&desktop_host, true);
    try std.testing.expect(desktop_host.surface_focused);
    try std.testing.expect(desktop_host.text_input_active);
}

test "surface destruction clears host and render state" {
    const std = @import("std");

    var app_host = native_host.PlatformAppHost{
        .kind = .android_activity,
        .lifecycle_state = .resumed,
        .surface_focused = true,
        .text_input_active = true,
    };
    var render_host = native_host.PlatformRenderHost{
        .binding = .opengl,
        .surface_availability = .available,
        .surface_metrics = .{
            .logical_width = 100,
            .logical_height = 50,
            .drawable_width = 200,
            .drawable_height = 100,
            .display_scale = 2.0,
            .pixel_density = 2.0,
        },
        .native_handles = .{
            .android_native_window = @ptrFromInt(1),
        },
    };

    onSurfaceDestroyed(&app_host, &render_host);
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.unavailable, render_host.surface_availability);
    try std.testing.expect(!app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);
}

test "lifecycle transition helpers update app and render host state" {
    const std = @import("std");

    var app_host = native_host.PlatformAppHost{
        .kind = .android_activity,
        .lifecycle_state = .started,
    };
    var render_host = native_host.PlatformRenderHost{
        .binding = .none,
        .surface_availability = .unavailable,
        .surface_metrics = .{},
        .native_handles = .{},
    };

    onWillEnterForeground(&app_host);
    try std.testing.expectEqual(native_host.AppLifecycleState.started, app_host.lifecycle_state);

    onDidEnterForeground(&app_host, &render_host);
    try std.testing.expectEqual(native_host.AppLifecycleState.resumed, app_host.lifecycle_state);
    try std.testing.expect(render_host.redraw_requested);

    render_host.clearRedrawRequested();
    onSurfaceMetricsChanged(&render_host, .{
        .logical_width = 120,
        .logical_height = 80,
        .drawable_width = 240,
        .drawable_height = 160,
        .display_scale = 2.0,
        .pixel_density = 2.0,
    });
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, render_host.surface_availability);
    try std.testing.expect(render_host.redraw_requested);

    onWindowFocusChanged(&app_host, true);
    try std.testing.expect(app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);

    app_host.noteTextInputActive(true);
    try std.testing.expect(app_host.text_input_active);

    onWindowFocusChanged(&app_host, false);
    try std.testing.expect(!app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);

    onWillEnterBackground(&app_host);
    try std.testing.expectEqual(native_host.AppLifecycleState.paused, app_host.lifecycle_state);

    onDidEnterBackground(&app_host);
    try std.testing.expectEqual(native_host.AppLifecycleState.stopped, app_host.lifecycle_state);
    try std.testing.expect(!app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);
}
