const native_host = @import("native_host.zig");
const sdl_api = @import("sdl_api.zig");
const sdl_native_host = @import("sdl_native_host.zig");

pub fn usesAndroidActivityHost(app_host: native_host.PlatformAppHost) bool {
    return app_host.kind == .android_activity;
}

pub fn noteWillEnterForeground(app_host: *native_host.PlatformAppHost) void {
    app_host.noteStarted();
}

pub fn noteDidEnterForeground(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
) void {
    app_host.noteResumed();
    render_host.noteRedrawRequested();
}

pub fn noteWillEnterBackground(app_host: *native_host.PlatformAppHost) void {
    app_host.notePaused();
}

pub fn noteDidEnterBackground(app_host: *native_host.PlatformAppHost) void {
    app_host.noteStopped();
}

pub fn noteSurfaceMetrics(
    render_host: *native_host.PlatformRenderHost,
    metrics: native_host.RenderSurfaceMetrics,
) void {
    render_host.noteSurfaceAvailable(metrics);
    render_host.noteRedrawRequested();
}

pub fn noteSurfaceDestroyed(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
) void {
    render_host.noteSurfaceUnavailable();
    app_host.noteSurfaceFocused(false);
    app_host.noteTextInputActive(false);
}

pub fn noteWindowFocusFromInputRuntime(
    app_host: *native_host.PlatformAppHost,
    focused: bool,
) void {
    app_host.noteSurfaceFocused(focused);
    if (focused and !usesAndroidActivityHost(app_host.*)) {
        app_host.noteTextInputActive(true);
    }
}

pub fn noteSdlWindowRefresh(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
    window: *sdl_api.c.SDL_Window,
) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    noteSurfaceMetrics(render_host, sdl_native_host.captureWindowSurfaceMetrics(window));
    return true;
}

test "focus policy keeps android text input host-driven on gain" {
    const std = @import("std");

    var android_host = native_host.PlatformAppHost{
        .kind = .android_activity,
        .lifecycle_state = .started,
    };
    noteWindowFocusFromInputRuntime(&android_host, true);
    try std.testing.expect(android_host.surface_focused);
    try std.testing.expect(!android_host.text_input_active);

    var desktop_host = native_host.PlatformAppHost{
        .kind = .sdl_desktop,
        .lifecycle_state = .started,
    };
    noteWindowFocusFromInputRuntime(&desktop_host, true);
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

    noteSurfaceDestroyed(&app_host, &render_host);
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

    noteWillEnterForeground(&app_host);
    try std.testing.expectEqual(native_host.AppLifecycleState.started, app_host.lifecycle_state);

    noteDidEnterForeground(&app_host, &render_host);
    try std.testing.expectEqual(native_host.AppLifecycleState.resumed, app_host.lifecycle_state);
    try std.testing.expect(render_host.redraw_requested);

    render_host.clearRedrawRequested();
    noteSurfaceMetrics(&render_host, .{
        .logical_width = 120,
        .logical_height = 80,
        .drawable_width = 240,
        .drawable_height = 160,
        .display_scale = 2.0,
        .pixel_density = 2.0,
    });
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, render_host.surface_availability);
    try std.testing.expect(render_host.redraw_requested);

    noteWindowFocusFromInputRuntime(&app_host, true);
    try std.testing.expect(app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);

    app_host.noteTextInputActive(true);
    try std.testing.expect(app_host.text_input_active);

    noteWindowFocusFromInputRuntime(&app_host, false);
    try std.testing.expect(!app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);

    noteWillEnterBackground(&app_host);
    try std.testing.expectEqual(native_host.AppLifecycleState.paused, app_host.lifecycle_state);

    noteDidEnterBackground(&app_host);
    try std.testing.expectEqual(native_host.AppLifecycleState.stopped, app_host.lifecycle_state);
    try std.testing.expect(!app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);
}
