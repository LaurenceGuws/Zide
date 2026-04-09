const builtin = @import("builtin");
const android_gles_probe = @import("android_gles_probe.zig");
const android_host = @import("android_host.zig");
const android_pty_probe = @import("android_pty_probe.zig");
const native_host = @import("native_host.zig");

extern fn ANativeWindow_fromSurface(env: ?*anyopaque, surface: ?*anyopaque) ?*anyopaque;
extern fn ANativeWindow_release(window: *anyopaque) void;

const BridgeState = struct {
    seq: u64 = 0,
    app_host: native_host.PlatformAppHost = .{
        .kind = .android_activity,
        .lifecycle_state = .started,
    },
    last_gles_probe_status: android_gles_probe.ProbeStatus = .unavailable,
    last_surface_transition: native_host.SurfaceIdentityTransition = .unchanged,
    render_host: native_host.PlatformRenderHost = .{
        .binding = .none,
        .surface_availability = .unavailable,
        .surface_metrics = .{},
        .native_handles = .{},
    },
};

var bridge_state = BridgeState{};

fn nextSequence() u64 {
    bridge_state.seq += 1;
    return bridge_state.seq;
}

fn releaseNativeWindow(window: ?*anyopaque) void {
    if (builtin.is_test) return;
    const value = window orelse return;
    ANativeWindow_release(value);
}

fn swapNativeWindow(window: ?*anyopaque) void {
    releaseNativeWindow(bridge_state.render_host.androidNativeWindow());
    bridge_state.last_surface_transition = bridge_state.render_host.noteAndroidNativeWindow(window);
}

pub fn noteCreate() u64 {
    android_gles_probe.reset();
    bridge_state = .{};
    return nextSequence();
}

pub fn noteStart() u64 {
    _ = android_host.noteWillEnterForeground(&bridge_state.app_host);
    return nextSequence();
}

pub fn noteResume() u64 {
    _ = android_host.noteDidEnterForeground(&bridge_state.app_host, &bridge_state.render_host);
    return nextSequence();
}

pub fn notePause() u64 {
    _ = android_host.noteWillEnterBackground(&bridge_state.app_host);
    return nextSequence();
}

pub fn noteStop() u64 {
    _ = android_host.noteDidEnterBackground(&bridge_state.app_host);
    return nextSequence();
}

pub fn noteWindowFocusChanged(focused: bool) u64 {
    _ = android_host.noteSurfaceFocus(&bridge_state.app_host, focused);
    return nextSequence();
}

pub fn noteSurfaceAvailable(width: i32, height: i32) u64 {
    _ = android_host.noteSurfaceMetrics(&bridge_state.app_host, &bridge_state.render_host, .{
        .logical_width = width,
        .logical_height = height,
        .drawable_width = width,
        .drawable_height = height,
        .display_scale = 1.0,
        .pixel_density = 1.0,
    });
    return nextSequence();
}

pub fn noteSurfaceAvailableFromJava(
    env: ?*anyopaque,
    surface: ?*anyopaque,
    width: i32,
    height: i32,
) u64 {
    const native_window = if (builtin.is_test)
        surface
    else
        ANativeWindow_fromSurface(env, surface);
    swapNativeWindow(native_window);
    if (native_window == null) return noteSurfaceDestroyed();
    const seq = noteSurfaceAvailable(width, height);
    bridge_state.last_gles_probe_status = android_gles_probe.noteSurfaceAvailable(
        bridge_state.render_host.androidNativeWindow(),
        bridge_state.render_host.surfaceIdentityEpoch(),
        bridge_state.last_surface_transition,
    );
    return seq;
}

pub fn noteSurfaceDestroyed() u64 {
    swapNativeWindow(null);
    _ = android_host.noteSurfaceDestroyed(&bridge_state.app_host, &bridge_state.render_host);
    bridge_state.last_gles_probe_status = android_gles_probe.noteSurfaceDestroyed();
    return nextSequence();
}

pub fn noteSurfaceRedrawNeeded() u64 {
    bridge_state.last_gles_probe_status = android_gles_probe.noteSurfaceRedrawNeeded();
    return nextSequence();
}

pub fn currentNativeWindowToken() usize {
    return @intFromPtr(bridge_state.render_host.androidNativeWindow() orelse return 0);
}

pub fn currentSurfaceIdentityEpoch() u64 {
    return bridge_state.render_host.surfaceIdentityEpoch();
}

pub fn currentSurfaceIdentityTransition() native_host.SurfaceIdentityTransition {
    return bridge_state.last_surface_transition;
}

pub fn currentGlesProbeStatus() android_gles_probe.ProbeStatus {
    return bridge_state.last_gles_probe_status;
}

pub fn currentGlesProbeSwapCount() u32 {
    return android_gles_probe.currentSwapCount();
}

pub fn currentGlesProbeBoundEpoch() u64 {
    return android_gles_probe.currentBoundEpoch();
}

pub fn currentGlesProbeContextCreateCount() u32 {
    return android_gles_probe.currentContextCreateCount();
}

pub fn currentGlesProbeSurfaceCreateCount() u32 {
    return android_gles_probe.currentSurfaceCreateCount();
}

pub fn currentGlesProbeTextureCreateCount() u32 {
    return android_gles_probe.currentTextureCreateCount();
}

pub fn currentGlesProbeTextureAlive() bool {
    return android_gles_probe.currentTextureAlive();
}

pub fn startPtyLifetimeProbe() i64 {
    return android_pty_probe.start() catch -1;
}

pub fn stopPtyLifetimeProbe() void {
    android_pty_probe.stop();
}

pub fn isPtyLifetimeProbeAlive() bool {
    return android_pty_probe.isAlive();
}

pub fn ptyLifetimeProbeChildPid() i64 {
    return android_pty_probe.childPid();
}

pub fn ptyLifetimeProbeStartStatus() i32 {
    return @intFromEnum(android_pty_probe.lastStartStatus());
}

test "bridge routes Android lifecycle and surface truth through shared host state" {
    const std = @import("std");

    try std.testing.expectEqual(@as(u64, 1), noteCreate());
    try std.testing.expectEqual(native_host.AppLifecycleState.started, bridge_state.app_host.lifecycle_state);
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.unavailable, bridge_state.render_host.surface_availability);

    try std.testing.expectEqual(@as(u64, 2), noteStart());
    try std.testing.expectEqual(native_host.AppLifecycleState.started, bridge_state.app_host.lifecycle_state);

    try std.testing.expectEqual(@as(u64, 3), noteResume());
    try std.testing.expectEqual(native_host.AppLifecycleState.resumed, bridge_state.app_host.lifecycle_state);
    try std.testing.expect(bridge_state.app_host.active);
    try std.testing.expect(bridge_state.render_host.redraw_requested);

    bridge_state.render_host.clearRedrawRequested();
    try std.testing.expectEqual(@as(u64, 4), noteSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 400, 200));
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, bridge_state.render_host.surface_availability);
    try std.testing.expectEqual(@as(i32, 400), bridge_state.render_host.surface_metrics.drawable_width);
    try std.testing.expect(bridge_state.render_host.redraw_requested);
    try std.testing.expectEqual(@as(usize, 0x1000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 1), currentSurfaceIdentityEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.acquired, currentSurfaceIdentityTransition());
    try std.testing.expectEqual(android_gles_probe.ProbeStatus.drawn, currentGlesProbeStatus());

    bridge_state.render_host.clearRedrawRequested();
    try std.testing.expectEqual(@as(u64, 5), noteSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 420, 210));
    try std.testing.expectEqual(@as(i32, 420), bridge_state.render_host.surface_metrics.drawable_width);
    try std.testing.expectEqual(@as(usize, 0x1000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 1), currentSurfaceIdentityEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.unchanged, currentSurfaceIdentityTransition());

    try std.testing.expectEqual(@as(u64, 6), noteWindowFocusChanged(true));
    try std.testing.expect(bridge_state.app_host.surface_focused);
    try std.testing.expect(!bridge_state.app_host.text_input_active);

    try std.testing.expectEqual(@as(u64, 7), notePause());
    try std.testing.expectEqual(native_host.AppLifecycleState.paused, bridge_state.app_host.lifecycle_state);
    try std.testing.expect(!bridge_state.app_host.active);
    try std.testing.expect(!bridge_state.app_host.surface_focused);

    try std.testing.expectEqual(@as(u64, 8), noteSurfaceDestroyed());
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.unavailable, bridge_state.render_host.surface_availability);
    try std.testing.expectEqual(@as(usize, 0), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 2), currentSurfaceIdentityEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.retired, currentSurfaceIdentityTransition());
    try std.testing.expectEqual(android_gles_probe.ProbeStatus.surface_destroyed, currentGlesProbeStatus());

    try std.testing.expectEqual(@as(u64, 9), noteSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 430, 220));
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, bridge_state.render_host.surface_availability);
    try std.testing.expectEqual(@as(usize, 0x1000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 3), currentSurfaceIdentityEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.acquired, currentSurfaceIdentityTransition());

    try std.testing.expectEqual(@as(u64, 10), noteStop());
    try std.testing.expectEqual(native_host.AppLifecycleState.stopped, bridge_state.app_host.lifecycle_state);
}

test "bridge reports replaced when a live Android surface identity changes without retirement" {
    const std = @import("std");

    try std.testing.expectEqual(@as(u64, 1), noteCreate());
    try std.testing.expectEqual(@as(u64, 2), noteResume());

    try std.testing.expectEqual(@as(u64, 3), noteSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 400, 200));
    try std.testing.expectEqual(@as(usize, 0x1000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 1), currentSurfaceIdentityEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.acquired, currentSurfaceIdentityTransition());

    try std.testing.expectEqual(@as(u64, 4), noteSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x2000), 410, 210));
    try std.testing.expectEqual(@as(usize, 0x2000), currentNativeWindowToken());
    try std.testing.expectEqual(@as(u64, 2), currentSurfaceIdentityEpoch());
    try std.testing.expectEqual(native_host.SurfaceIdentityTransition.replaced, currentSurfaceIdentityTransition());
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, bridge_state.render_host.surface_availability);
}
