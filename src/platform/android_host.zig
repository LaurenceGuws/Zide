const std = @import("std");
const native_host = @import("native_host.zig");
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
    render_host.noteSurfaceAvailable(native_host.captureWindowSurfaceMetrics(window));
    render_host.noteRedrawRequested();
    return true;
}

pub fn noteSurfaceFocus(app_host: *native_host.PlatformAppHost, focused: bool) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    app_host.noteSurfaceFocused(focused);
    app_host.noteTextInputActive(focused);
    return true;
}

test "android host lifecycle transitions update shared host state" {
    var app_host = native_host.PlatformAppHost{
        .kind = .android_activity,
        .lifecycle_state = .started,
    };
    var render_host = native_host.PlatformRenderHost{
        .sdl_window = @ptrFromInt(1),
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

    try std.testing.expect(noteSurfaceFocus(&app_host, true));
    try std.testing.expect(app_host.surface_focused);
    try std.testing.expect(app_host.text_input_active);

    try std.testing.expect(noteWillEnterBackground(&app_host));
    try std.testing.expectEqual(native_host.AppLifecycleState.paused, app_host.lifecycle_state);

    try std.testing.expect(noteDidEnterBackground(&app_host));
    try std.testing.expectEqual(native_host.AppLifecycleState.stopped, app_host.lifecycle_state);
    try std.testing.expect(!app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);
}
