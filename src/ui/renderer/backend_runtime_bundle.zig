const std = @import("std");
const opengl_runtime_state = @import("opengl_runtime_state.zig");
const metal_runtime_state = @import("metal_runtime_state.zig");

fn runtimePtrType(comptime Ptr: type, comptime State: type) type {
    const info = @typeInfo(Ptr).pointer;
    return if (info.is_const) *const State else *State;
}

pub const Bundle = struct {
    storage: ?*anyopaque = null,

    pub fn init(allocator: std.mem.Allocator, backend: anytype) !Bundle {
        return switch (backend) {
            .opengl => initState(allocator, opengl_runtime_state.State),
            .metal => initState(allocator, metal_runtime_state.State),
        };
    }

    pub fn openglState(self: anytype) runtimePtrType(@TypeOf(self), opengl_runtime_state.State) {
        const storage = self.storage orelse unreachable;
        return @ptrCast(@alignCast(storage));
    }

    pub fn metalState(self: anytype) runtimePtrType(@TypeOf(self), metal_runtime_state.State) {
        const storage = self.storage orelse unreachable;
        return @ptrCast(@alignCast(storage));
    }

    pub fn deinitStorage(self: *Bundle, allocator: std.mem.Allocator, backend: anytype) void {
        const storage = self.storage orelse return;
        switch (backend) {
            .opengl => allocator.destroy(@as(*opengl_runtime_state.State, @ptrCast(@alignCast(storage)))),
            .metal => allocator.destroy(@as(*metal_runtime_state.State, @ptrCast(@alignCast(storage)))),
        }
        self.storage = null;
    }
};

fn initState(allocator: std.mem.Allocator, comptime State: type) !Bundle {
    const state = try allocator.create(State);
    state.* = .{};
    return .{ .storage = state };
}

const TestBackend = enum {
    opengl,
    metal,
};

test "init selects only requested backend runtime" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var gl_bundle = try Bundle.init(allocator, TestBackend.opengl);
    try std.testing.expect(gl_bundle.storage != null);
    gl_bundle.openglState().resources.resources_ready = true;
    try std.testing.expect(gl_bundle.openglState().resources.resources_ready);
    gl_bundle.deinitStorage(allocator, TestBackend.opengl);
    try std.testing.expect(gl_bundle.storage == null);

    var metal_bundle = try Bundle.init(allocator, TestBackend.metal);
    try std.testing.expect(metal_bundle.storage != null);
    metal_bundle.metalState().preview_source = .uploaded_coverage_glyph;
    try std.testing.expectEqual(metal_runtime_state.AtlasPreviewSource.uploaded_coverage_glyph, metal_bundle.metalState().preview_source);
    metal_bundle.deinitStorage(allocator, TestBackend.metal);
    try std.testing.expect(metal_bundle.storage == null);
}
