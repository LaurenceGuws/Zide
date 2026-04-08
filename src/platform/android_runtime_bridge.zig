const android_host = @import("android_host.zig");
const native_host = @import("native_host.zig");

const BridgeState = struct {
    seq: u64 = 0,
    app_host: native_host.PlatformAppHost = .{
        .kind = .android_activity,
        .lifecycle_state = .started,
    },
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

pub fn noteCreate() u64 {
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

pub fn noteSurfaceDestroyed() u64 {
    _ = android_host.noteSurfaceDestroyed(&bridge_state.app_host, &bridge_state.render_host);
    return nextSequence();
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
    try std.testing.expectEqual(@as(u64, 4), noteSurfaceAvailable(400, 200));
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.available, bridge_state.render_host.surface_availability);
    try std.testing.expectEqual(@as(i32, 400), bridge_state.render_host.surface_metrics.drawable_width);
    try std.testing.expect(bridge_state.render_host.redraw_requested);

    try std.testing.expectEqual(@as(u64, 5), noteWindowFocusChanged(true));
    try std.testing.expect(bridge_state.app_host.surface_focused);
    try std.testing.expect(!bridge_state.app_host.text_input_active);

    try std.testing.expectEqual(@as(u64, 6), notePause());
    try std.testing.expectEqual(native_host.AppLifecycleState.paused, bridge_state.app_host.lifecycle_state);
    try std.testing.expect(!bridge_state.app_host.active);
    try std.testing.expect(!bridge_state.app_host.surface_focused);

    try std.testing.expectEqual(@as(u64, 7), noteSurfaceDestroyed());
    try std.testing.expectEqual(native_host.RenderSurfaceAvailability.unavailable, bridge_state.render_host.surface_availability);

    try std.testing.expectEqual(@as(u64, 8), noteStop());
    try std.testing.expectEqual(native_host.AppLifecycleState.stopped, bridge_state.app_host.lifecycle_state);
}
