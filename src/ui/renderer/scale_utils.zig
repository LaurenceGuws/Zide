const iface = @import("interface.zig");
const std = @import("std");

pub const WaylandScaleState = struct {
    cache: ?f32,
    last_update: f64,
};

pub fn queryUiScale(
    allocator: std.mem.Allocator,
    dpi: iface.MousePos,
    now: f64,
    wayland: *WaylandScaleState,
) f32 {
    _ = allocator;
    _ = dpi;
    _ = now;
    _ = wayland;
    var scale: f32 = 1.0;

    if (std.c.getenv("ZIDE_UI_SCALE")) |raw| {
        const s = std.mem.trim(u8, std.mem.span(raw), " \t\r\n");
        const env_scale = std.fmt.parseFloat(f32, s) catch 1.0;
        if (env_scale > 0.0) scale *= env_scale;
    }

    return if (scale > 0.1) scale else 1.0;
}

pub fn queueUserZoom(current_target: f32, delta: f32, now: f64, min: f32, max: f32) struct {
    next_target: f32,
    changed: bool,
    request_time: f64,
} {
    const next = std.math.clamp(current_target + delta, min, max);
    if (std.math.approxEqAbs(f32, next, current_target, 0.0001)) {
        return .{ .next_target = current_target, .changed = false, .request_time = now };
    }
    return .{ .next_target = next, .changed = true, .request_time = now };
}

pub fn resetUserZoomTarget(current_target: f32, now: f64) struct {
    next_target: f32,
    changed: bool,
    request_time: f64,
} {
    if (std.math.approxEqAbs(f32, current_target, 1.0, 0.0001)) {
        return .{ .next_target = current_target, .changed = false, .request_time = now };
    }
    return .{ .next_target = 1.0, .changed = true, .request_time = now };
}

pub fn applyPendingZoom(
    current_zoom: f32,
    target_zoom: f32,
    now: f64,
    last_request_time: f64,
    last_apply_time: f64,
    min_delay: f64,
    min_apply_gap: f64,
) struct {
    next_zoom: f32,
    changed: bool,
    apply_time: f64,
} {
    if (std.math.approxEqAbs(f32, target_zoom, current_zoom, 0.0001)) {
        return .{ .next_zoom = current_zoom, .changed = false, .apply_time = last_apply_time };
    }
    if (now - last_request_time < min_delay) {
        return .{ .next_zoom = current_zoom, .changed = false, .apply_time = last_apply_time };
    }
    if (now - last_apply_time < min_apply_gap) {
        return .{ .next_zoom = current_zoom, .changed = false, .apply_time = last_apply_time };
    }
    return .{ .next_zoom = target_zoom, .changed = true, .apply_time = now };
}
