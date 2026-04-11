const std = @import("std");
const android_gles_runtime = @import("../../platform/android_gles_runtime.zig");
const surface_draw = @import("surface_draw.zig");

pub const State = struct {
    runtime: android_gles_runtime.State = .{},
    frame_begin_count: u64 = 0,
    frame_submit_count: u64 = 0,
    queued_surface_draws: std.ArrayListUnmanaged(surface_draw.SurfaceDraw) = .{},
};
