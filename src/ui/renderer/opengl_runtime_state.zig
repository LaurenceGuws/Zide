const std = @import("std");
const gl = @import("gl.zig");
const gl_presentable_target = @import("gl_presentable_target.zig");
const scene_target_state = @import("scene_target_state.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const surface_draw = @import("surface_draw.zig");
const types = @import("types.zig");

const PresentableTargetState = gl_presentable_target.PresentableTargetState;
const SceneTargetState = scene_target_state.SceneTargetState;

pub const TargetRuntime = struct {
    presentable_targets: PresentableTargetState = .{},
    scene_target: SceneTargetState = .{},
};

pub const ResourceRuntime = struct {
    resources_ready: bool = false,
    shader_program: gl.GLuint = 0,
    vao: gl.GLuint = 0,
    vbo: gl.GLuint = 0,
    vbo_capacity_vertices: usize = 0,
    uniform_proj: gl.GLint = -1,
    uniform_tex: gl.GLint = -1,
    uniform_kind: gl.GLint = -1,
    uniform_text_gamma: gl.GLint = -1,
    uniform_text_contrast: gl.GLint = -1,
    uniform_dst_linear: gl.GLint = -1,
    uniform_linear_correction: gl.GLint = -1,
    white_texture: types.Texture = .{ .id = 0, .width = 0, .height = 0 },
};

pub const QueuedSurfaceDraw = struct {
    draw: surface_draw.SurfaceDraw,
    owns_raw_image_texture: bool = false,
};

pub const State = struct {
    context: ?sdl_api.c.SDL_GLContext = null,
    resources: ResourceRuntime = .{},
    targets: TargetRuntime = .{},
    queued_surface_draws: std.ArrayListUnmanaged(QueuedSurfaceDraw) = .{},
};
