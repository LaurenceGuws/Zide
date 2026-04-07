const opengl_runtime_state = @import("opengl_runtime_state.zig");
const metal_runtime_state = @import("metal_runtime_state.zig");

pub const Bundle = struct {
    opengl: opengl_runtime_state.State = .{},
    metal: metal_runtime_state.State = .{},
};
