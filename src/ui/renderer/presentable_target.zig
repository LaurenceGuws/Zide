const gl = @import("gl.zig");
const types = @import("types.zig");

pub const PresentableTarget = struct {
    texture: types.Texture,
    fbo: gl.GLuint,
    logical_width: i32,
    logical_height: i32,
};

pub const PresentableTargetState = struct {
    terminal: ?PresentableTarget = null,
    terminal_scroll: ?PresentableTarget = null,
    editor: ?PresentableTarget = null,
};
