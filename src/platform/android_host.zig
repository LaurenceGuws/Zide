const native_host = @import("native_host.zig");
const sdl_native_host = @import("sdl_native_host.zig");
const sdl_api = @import("sdl_api.zig");

pub fn usesAndroidActivityHost(app_host: native_host.PlatformAppHost) bool {
    return app_host.kind == .android_activity;
}

pub fn noteWillEnterForeground(app_host: *native_host.PlatformAppHost) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    app_host.noteStarted();
    return true;
}

pub fn noteDidEnterForeground(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    app_host.noteResumed();
    render_host.noteRedrawRequested();
    return true;
}

pub fn noteWillEnterBackground(app_host: *native_host.PlatformAppHost) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    app_host.notePaused();
    return true;
}

pub fn noteDidEnterBackground(app_host: *native_host.PlatformAppHost) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    app_host.noteStopped();
    return true;
}

pub fn noteWindowRefresh(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
    window: *sdl_api.c.SDL_Window,
) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    render_host.noteSurfaceAvailable(sdl_native_host.captureWindowSurfaceMetrics(window));
    render_host.noteRedrawRequested();
    return true;
}

pub fn noteSurfaceMetrics(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
    metrics: native_host.RenderSurfaceMetrics,
) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    render_host.noteSurfaceAvailable(metrics);
    render_host.noteRedrawRequested();
    return true;
}

pub fn noteSurfaceDestroyed(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    render_host.noteSurfaceUnavailable();
    app_host.noteSurfaceFocused(false);
    app_host.noteTextInputActive(false);
    return true;
}

pub fn noteSurfaceFocus(app_host: *native_host.PlatformAppHost, focused: bool) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    app_host.noteSurfaceFocused(focused);
    if (!focused) app_host.noteTextInputActive(false);
    return true;
}

test "android host lifecycle transitions update shared host state" {
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

    try std.testing.expect(noteWillEnterForeground(&app_host));
    try std.testing.expectEqual(native_host.AppLifecycleState.started, app_host.lifecycle_state);

    try std.testing.expect(noteDidEnterForeground(&app_host, &render_host));
    try std.testing.expectEqual(native_host.AppLifecycleState.resumed, app_host.lifecycle_state);
    try std.testing.expect(render_host.redraw_requested);

    render_host.clearRedrawRequested();
    try std.testing.expect(noteSurfaceMetrics(&app_host, &render_host, .{
        .logical_width = 120,
        .logical_height = 80,
        .drawable_width = 240,
        .drawable_height = 160,
        .display_scale = 2.0,
        .pixel_density = 2.0,
    }));
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, render_host.surface_availability);
    try std.testing.expect(render_host.redraw_requested);

    try std.testing.expect(noteSurfaceFocus(&app_host, true));
    try std.testing.expect(app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);

    app_host.noteTextInputActive(true);
    try std.testing.expect(app_host.text_input_active);

    try std.testing.expect(noteSurfaceFocus(&app_host, false));
    try std.testing.expect(!app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);

    try std.testing.expect(noteWillEnterBackground(&app_host));
    try std.testing.expectEqual(native_host.AppLifecycleState.paused, app_host.lifecycle_state);

    try std.testing.expect(noteDidEnterBackground(&app_host));
    try std.testing.expectEqual(native_host.AppLifecycleState.stopped, app_host.lifecycle_state);
    try std.testing.expect(!app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);

    try std.testing.expect(noteSurfaceDestroyed(&app_host, &render_host));
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.unavailable, render_host.surface_availability);
    try std.testing.expect(!render_host.redraw_requested);
}
