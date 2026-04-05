const gl = @import("gl.zig");
const types = @import("types.zig");

pub const PresentableTarget = struct {
    texture: types.Texture,
    fbo: gl.GLuint,
    logical_width: i32,
    logical_height: i32,
};
