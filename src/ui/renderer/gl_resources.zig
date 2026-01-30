const gl = @import("gl.zig");
const std = @import("std");

pub const GlResources = struct {
    shader_program: gl.GLuint,
    vao: gl.GLuint,
    vbo: gl.GLuint,
    uniform_proj: gl.GLint,
    uniform_tex: gl.GLint,
};

pub fn destroy(resources: GlResources) void {
    if (resources.vbo != 0) {
        gl.DeleteBuffers(1, &resources.vbo);
    }
    if (resources.vao != 0) {
        gl.DeleteVertexArrays(1, &resources.vao);
    }
    if (resources.shader_program != 0) {
        gl.DeleteProgram(resources.shader_program);
    }
}

pub fn computeBufferBytes(vertex_size: usize, count: usize) gl.GLsizeiptr {
    return @as(gl.GLsizeiptr, @intCast(vertex_size * count));
}
