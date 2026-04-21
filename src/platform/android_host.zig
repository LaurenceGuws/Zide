const host_lifecycle_runtime = @import("host_lifecycle_runtime.zig");
const native_host = @import("native_host.zig");

pub fn usesAndroidActivityHost(app_host: native_host.PlatformAppHost) bool {
    return host_lifecycle_runtime.usesAndroidActivityHost(app_host);
}

pub fn onWillEnterForeground(app_host: *native_host.PlatformAppHost) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    host_lifecycle_runtime.noteWillEnterForeground(app_host);
    return true;
}

pub fn onDidEnterForeground(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    host_lifecycle_runtime.noteDidEnterForeground(app_host, render_host);
    return true;
}

pub fn onWillEnterBackground(app_host: *native_host.PlatformAppHost) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    host_lifecycle_runtime.noteWillEnterBackground(app_host);
    return true;
}

pub fn onDidEnterBackground(app_host: *native_host.PlatformAppHost) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    host_lifecycle_runtime.noteDidEnterBackground(app_host);
    return true;
}

pub fn onSurfaceMetrics(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
    metrics: native_host.RenderSurfaceMetrics,
) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    host_lifecycle_runtime.noteSurfaceMetrics(render_host, metrics);
    return true;
}

pub fn onSurfaceDestroyed(
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    host_lifecycle_runtime.noteSurfaceDestroyed(app_host, render_host);
    return true;
}

pub fn onSurfaceFocus(app_host: *native_host.PlatformAppHost, focused: bool) bool {
    if (!usesAndroidActivityHost(app_host.*)) return false;
    host_lifecycle_runtime.noteWindowFocusFromInputRuntime(app_host, focused);
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

    try std.testing.expect(onWillEnterForeground(&app_host));
    try std.testing.expectEqual(native_host.AppLifecycleState.started, app_host.lifecycle_state);

    try std.testing.expect(onDidEnterForeground(&app_host, &render_host));
    try std.testing.expectEqual(native_host.AppLifecycleState.resumed, app_host.lifecycle_state);
    try std.testing.expect(render_host.redraw_requested);

    render_host.clearRedrawRequested();
    try std.testing.expect(onSurfaceMetrics(&app_host, &render_host, .{
        .logical_width = 120,
        .logical_height = 80,
        .drawable_width = 240,
        .drawable_height = 160,
        .display_scale = 2.0,
        .pixel_density = 2.0,
    }));
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, render_host.surface_availability);
    try std.testing.expect(render_host.redraw_requested);

    try std.testing.expect(onSurfaceFocus(&app_host, true));
    try std.testing.expect(app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);

    app_host.noteTextInputActive(true);
    try std.testing.expect(app_host.text_input_active);

    try std.testing.expect(onSurfaceFocus(&app_host, false));
    try std.testing.expect(!app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);

    try std.testing.expect(onWillEnterBackground(&app_host));
    try std.testing.expectEqual(native_host.AppLifecycleState.paused, app_host.lifecycle_state);

    try std.testing.expect(onDidEnterBackground(&app_host));
    try std.testing.expectEqual(native_host.AppLifecycleState.stopped, app_host.lifecycle_state);
    try std.testing.expect(!app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);

    try std.testing.expect(onSurfaceDestroyed(&app_host, &render_host));
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.unavailable, render_host.surface_availability);
    try std.testing.expect(!render_host.redraw_requested);
}
