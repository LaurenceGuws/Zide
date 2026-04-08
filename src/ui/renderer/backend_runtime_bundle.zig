const std = @import("std");
const opengl_runtime_state = @import("opengl_runtime_state.zig");
const metal_runtime_state = @import("metal_runtime_state.zig");

fn runtimePtrType(comptime Ptr: type, comptime State: type) type {
    const info = @typeInfo(Ptr).pointer;
    return if (info.is_const) *const State else *State;
}

pub const Bundle = union(enum) {
    none,
    opengl: opengl_runtime_state.State,
    metal: metal_runtime_state.State,

    pub fn init(backend: anytype) Bundle {
        return switch (backend) {
            .opengl => .{ .opengl = .{} },
            .metal => .{ .metal = .{} },
        };
    }

    pub fn openglState(self: anytype) runtimePtrType(@TypeOf(self), opengl_runtime_state.State) {
        return switch (self.*) {
            .opengl => |*state| state,
            else => unreachable,
        };
    }

    pub fn metalState(self: anytype) runtimePtrType(@TypeOf(self), metal_runtime_state.State) {
        return switch (self.*) {
            .metal => |*state| state,
            else => unreachable,
        };
    }
};

const TestBackend = enum {
    opengl,
    metal,
};

test "init selects only requested backend runtime" {
    var gl_bundle = Bundle.init(TestBackend.opengl);
    try std.testing.expectEqual(Bundle.Tag.opengl, std.meta.activeTag(gl_bundle));
    gl_bundle.openglState().resources.resources_ready = true;
    try std.testing.expect(gl_bundle.openglState().resources.resources_ready);

    var metal_bundle = Bundle.init(TestBackend.metal);
    try std.testing.expectEqual(Bundle.Tag.metal, std.meta.activeTag(metal_bundle));
    metal_bundle.metalState().preview_source = .uploaded_coverage_glyph;
    try std.testing.expectEqual(metal_runtime_state.AtlasPreviewSource.uploaded_coverage_glyph, metal_bundle.metalState().preview_source);
}
