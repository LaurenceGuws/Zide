const builtin = @import("builtin");
const android_gles_probe = @import("android_gles_probe.zig");
const android_host = @import("android_host.zig");
const android_shell_session = @import("android_shell_session.zig");
const native_host = @import("native_host.zig");
const renderer_mod = @import("../ui/renderer.zig");
const std = @import("std");

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
    renderer: ?*renderer_mod.Renderer = null,
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

fn destroyRenderer() void {
    const renderer = bridge_state.renderer orelse return;
    renderer.deinit();
    bridge_state.renderer = null;
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
    destroyRenderer();
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
    bridge_state.last_gles_probe_status = drawSharedRendererSurfaceFrame();
    return seq;
}

pub fn noteSurfaceDestroyed() u64 {
    swapNativeWindow(null);
    _ = android_host.noteSurfaceDestroyed(&bridge_state.app_host, &bridge_state.render_host);
    if (bridge_state.renderer) |renderer| {
        renderer.syncExternalHostState(bridge_state.app_host, bridge_state.render_host);
    }
    bridge_state.last_gles_probe_status = .surface_destroyed;
    return nextSequence();
}

pub fn noteSurfaceRedrawNeeded() u64 {
    bridge_state.last_gles_probe_status = drawSharedRendererSurfaceFrame();
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
    if (bridge_state.renderer) |renderer| {
        return renderer.backend.runtime.androidGlesState().runtime.swap_count;
    }
    return android_gles_probe.currentSwapCount();
}

pub fn currentGlesProbeBoundEpoch() u64 {
    if (bridge_state.renderer) |renderer| {
        return renderer.backend.runtime.androidGlesState().runtime.bound_epoch;
    }
    return android_gles_probe.currentBoundEpoch();
}

pub fn currentGlesProbeContextCreateCount() u32 {
    if (bridge_state.renderer) |renderer| {
        return renderer.backend.runtime.androidGlesState().runtime.context_create_count;
    }
    return android_gles_probe.currentContextCreateCount();
}

pub fn currentGlesProbeSurfaceCreateCount() u32 {
    if (bridge_state.renderer) |renderer| {
        return renderer.backend.runtime.androidGlesState().runtime.surface_create_count;
    }
    return android_gles_probe.currentSurfaceCreateCount();
}

pub fn currentGlesProbeTextureCreateCount() u32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_probe.currentTextureCreateCount();
}

pub fn currentGlesProbeTextureAlive() bool {
    if (bridge_state.renderer != null) return false;
    return android_gles_probe.currentTextureAlive();
}

pub fn currentGlesProbeTextureUploadCount() u32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_probe.currentTextureUploadCount();
}

pub fn currentGlesProbeTextureUpdateCount() u32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_probe.currentTextureUpdateCount();
}

pub fn currentGlesProbeTextureResizeCount() u32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_probe.currentTextureResizeCount();
}

pub fn currentGlesProbeTextureWidth() i32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_probe.currentTextureWidth();
}

pub fn currentGlesProbeTextureHeight() i32 {
    if (bridge_state.renderer != null) return 0;
    return android_gles_probe.currentTextureHeight();
}

pub fn restartShellSession() i32 {
    android_shell_session.restart() catch return @intFromEnum(android_shell_session.lastStartStatus());
    return @intFromEnum(android_shell_session.lastStartStatus());
}

pub fn pollShellSession() i32 {
    android_shell_session.pollAndRefresh() catch return @intFromEnum(android_shell_session.lastStartStatus());
    return @intFromEnum(android_shell_session.lastStartStatus());
}

pub fn isShellSessionAlive() bool {
    return android_shell_session.isAlive();
}

pub fn sendShellCodepoint(codepoint: i32) i32 {
    if (codepoint < 0 or codepoint > 0x10ffff) return @intFromEnum(android_shell_session.SendStatus.send_failed);
    return @intFromEnum(android_shell_session.sendCodepoint(@intCast(codepoint)));
}

pub fn ensureAndroidGlesRenderer() !bool {
    if (bridge_state.renderer != null) return false;
    if (!bridge_state.render_host.hasSurface()) return false;

    const renderer = try renderer_mod.Renderer.initExternalHostBackendSmoke(
        std.heap.c_allocator,
        bridge_state.app_host,
        bridge_state.render_host,
        .{
            .renderer_backend = .android_gles,
            .runtime_profile = .backend_smoke,
        },
    );
    bridge_state.renderer = renderer;
    return true;
}

pub fn drawAndroidGlesRendererFrame() !bool {
    const renderer = bridge_state.renderer orelse return false;
    renderer.syncExternalHostState(bridge_state.app_host, bridge_state.render_host);
    if (!renderer.beginFrame()) return false;
    return renderer.submitFrame().succeeded;
}

fn drawSharedRendererSurfaceFrame() android_gles_probe.ProbeStatus {
    ensureAndroidGlesRenderer() catch return .init_failed;
    return if (drawAndroidGlesRendererFrame() catch false) .drawn else .surface_failed;
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

test "bridge can create and draw a shared android gles renderer for backend smoke" {
    try std.testing.expectEqual(@as(u64, 1), noteCreate());
    try std.testing.expectEqual(@as(u64, 2), noteResume());
    try std.testing.expectEqual(@as(u64, 3), noteSurfaceAvailableFromJava(@ptrFromInt(1), @ptrFromInt(0x1000), 400, 200));

    try std.testing.expect(try ensureAndroidGlesRenderer());
    try std.testing.expect(!try ensureAndroidGlesRenderer());
    try std.testing.expect(try drawAndroidGlesRendererFrame());

    destroyRenderer();
    try std.testing.expectEqual(@as(?*renderer_mod.Renderer, null), bridge_state.renderer);
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
