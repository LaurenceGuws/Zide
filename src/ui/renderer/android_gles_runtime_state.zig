const std = @import("std");
const android_gles_runtime = @import("../../platform/android_gles_runtime.zig");
const opengl_runtime_state = @import("opengl_runtime_state.zig");
const surface_draw = @import("surface_draw.zig");

pub const State = struct {
    runtime: android_gles_runtime.State = .{},
    resources: opengl_runtime_state.ResourceRuntime = .{},
    frame_begin_count: u64 = 0,
    frame_submit_count: u64 = 0,
    queued_surface_draws: std.ArrayListUnmanaged(surface_draw.SurfaceDraw) = .{},
};
