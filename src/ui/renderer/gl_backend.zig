const gl = @import("gl.zig");
const types = @import("types.zig");

pub const RenderTarget = struct {
    texture: types.Texture,
    fbo: gl.GLuint,
};

pub fn initGlResources(renderer: anytype) !void {
    const vertex_src =
        "#version 330 core\n" ++
        "layout (location = 0) in vec2 a_pos;\n" ++
        "layout (location = 1) in vec2 a_uv;\n" ++
        "layout (location = 2) in vec4 a_color;\n" ++
        "out vec2 v_uv;\n" ++
        "out vec4 v_color;\n" ++
        "uniform mat4 u_proj;\n" ++
        "void main() {\n" ++
        "    v_uv = a_uv;\n" ++
        "    v_color = a_color;\n" ++
        "    gl_Position = u_proj * vec4(a_pos, 0.0, 1.0);\n" ++
        "}\n";
    const fragment_src =
        "#version 330 core\n" ++
        "in vec2 v_uv;\n" ++
        "in vec4 v_color;\n" ++
        "out vec4 frag_color;\n" ++
        "uniform sampler2D u_tex;\n" ++
        "void main() {\n" ++
        "    vec4 tex = texture(u_tex, v_uv);\n" ++
        "    frag_color = tex * v_color;\n" ++
        "}\n";

    const vert = try compileShader(gl.c.GL_VERTEX_SHADER, vertex_src);
    defer gl.DeleteShader(vert);
    const frag = try compileShader(gl.c.GL_FRAGMENT_SHADER, fragment_src);
    defer gl.DeleteShader(frag);
    const program = try linkProgram(vert, frag);
    renderer.shader_program = program;
    gl.UseProgram(program);

    renderer.uniform_proj = gl.GetUniformLocation(program, "u_proj");
    renderer.uniform_tex = gl.GetUniformLocation(program, "u_tex");
    if (renderer.uniform_tex >= 0) gl.Uniform1i(renderer.uniform_tex, 0);

    gl.GenVertexArrays(1, &renderer.vao);
    gl.GenBuffers(1, &renderer.vbo);
    gl.BindVertexArray(renderer.vao);
    gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, renderer.vbo);
    gl.BufferData(
        gl.c.GL_ARRAY_BUFFER,
        @as(gl.GLsizeiptr, @intCast(@sizeOf(@TypeOf(renderer.batch_vertices.items[0])) * 6)),
        null,
        gl.c.GL_DYNAMIC_DRAW,
    );
    renderer.vbo_capacity_vertices = 6;

    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(0, 2, gl.c.GL_FLOAT, gl.c.GL_FALSE, @sizeOf(@TypeOf(renderer.batch_vertices.items[0])), @ptrFromInt(0));
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(
        1,
        2,
        gl.c.GL_FLOAT,
        gl.c.GL_FALSE,
        @sizeOf(@TypeOf(renderer.batch_vertices.items[0])),
        @ptrFromInt(2 * @sizeOf(f32)),
    );
    gl.EnableVertexAttribArray(2);
    gl.VertexAttribPointer(
        2,
        4,
        gl.c.GL_FLOAT,
        gl.c.GL_FALSE,
        @sizeOf(@TypeOf(renderer.batch_vertices.items[0])),
        @ptrFromInt(4 * @sizeOf(f32)),
    );

    gl.Enable(gl.c.GL_BLEND);
    gl.BlendFunc(gl.c.GL_SRC_ALPHA, gl.c.GL_ONE_MINUS_SRC_ALPHA);
    gl.Disable(gl.c.GL_DEPTH_TEST);
    gl.Disable(gl.c.GL_CULL_FACE);

    renderer.white_texture = createSolidTexture(1, 1, .{ 255, 255, 255, 255 });
    updateProjection(renderer, renderer.render_width, renderer.render_height);
}

pub fn bindDefaultTarget(renderer: anytype) void {
    gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, 0);
    updateProjection(renderer, renderer.render_width, renderer.render_height);
}

pub fn beginRenderTarget(renderer: anytype, target: ?RenderTarget) bool {
    if (target) |t| {
        gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, t.fbo);
        updateProjection(renderer, t.texture.width, t.texture.height);
        return true;
    }
    return false;
}

pub fn ensureRenderTarget(target: *?RenderTarget, width: i32, height: i32, filter: i32) bool {
    if (width <= 0 or height <= 0) return false;
    if (target.*) |t| {
        if (t.texture.width == width and t.texture.height == height) return false;
        destroyRenderTarget(target);
    }

    const texture = createTextureEmpty(width, height, filter);
    var fbo: gl.GLuint = 0;
    gl.GenFramebuffers(1, &fbo);
    gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, fbo);
    gl.FramebufferTexture2D(gl.c.GL_FRAMEBUFFER, gl.c.GL_COLOR_ATTACHMENT0, gl.c.GL_TEXTURE_2D, texture.id, 0);
    const status = gl.CheckFramebufferStatus(gl.c.GL_FRAMEBUFFER);
    gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, 0);
    if (status != gl.c.GL_FRAMEBUFFER_COMPLETE) {
        gl.DeleteFramebuffers(1, &fbo);
        gl.DeleteTextures(1, &texture.id);
        return false;
    }

    target.* = .{ .texture = texture, .fbo = fbo };
    return true;
}

pub fn destroyRenderTarget(target: *?RenderTarget) void {
    if (target.*) |t| {
        gl.DeleteFramebuffers(1, &t.fbo);
        gl.DeleteTextures(1, &t.texture.id);
        target.* = null;
    }
}

pub fn updateProjection(renderer: anytype, width: i32, height: i32) void {
    renderer.target_width = width;
    renderer.target_height = height;
    gl.Viewport(0, 0, width, height);
    if (renderer.uniform_proj >= 0) {
        const w = @as(f32, @floatFromInt(width));
        const h = @as(f32, @floatFromInt(height));
        const proj = [_]f32{
            2.0 / w, 0, 0, 0,
            0, -2.0 / h, 0, 0,
            0, 0, 1, 0,
            -1, 1, 0, 1,
        };
        gl.UseProgram(renderer.shader_program);
        gl.UniformMatrix4fv(renderer.uniform_proj, 1, gl.c.GL_FALSE, &proj);
    }
}

fn compileShader(kind: gl.GLenum, source: []const u8) !gl.GLuint {
    const shader = gl.CreateShader(kind);
    const src_ptr: [*]const gl.GLchar = @ptrCast(source.ptr);
    const src_len: gl.GLint = @intCast(source.len);
    const lengths = [_]gl.GLint{src_len};
    gl.ShaderSource(shader, 1, @ptrCast(&src_ptr), @ptrCast(&lengths));
    gl.CompileShader(shader);
    var status: gl.GLint = 0;
    gl.GetShaderiv(shader, gl.c.GL_COMPILE_STATUS, &status);
    if (status == 0) {
        var log_buf: [1024]u8 = undefined;
        var len: gl.GLsizei = 0;
        gl.GetShaderInfoLog(shader, log_buf.len, &len, @ptrCast(&log_buf));
        return error.GlShaderCompileFailed;
    }
    return shader;
}

fn linkProgram(vert: gl.GLuint, frag: gl.GLuint) !gl.GLuint {
    const program = gl.CreateProgram();
    gl.AttachShader(program, vert);
    gl.AttachShader(program, frag);
    gl.LinkProgram(program);
    var status: gl.GLint = 0;
    gl.GetProgramiv(program, gl.c.GL_LINK_STATUS, &status);
    if (status == 0) {
        var log_buf: [1024]u8 = undefined;
        var len: gl.GLsizei = 0;
        gl.GetProgramInfoLog(program, log_buf.len, &len, @ptrCast(&log_buf));
        return error.GlProgramLinkFailed;
    }
    return program;
}

fn createSolidTexture(width: i32, height: i32, rgba: [4]u8) types.Texture {
    var id: gl.GLuint = 0;
    gl.GenTextures(1, &id);
    gl.BindTexture(gl.c.GL_TEXTURE_2D, id);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, gl.c.GL_NEAREST);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, gl.c.GL_NEAREST);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_S, gl.c.GL_CLAMP_TO_EDGE);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_T, gl.c.GL_CLAMP_TO_EDGE);
    gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
    gl.TexImage2D(
        gl.c.GL_TEXTURE_2D,
        0,
        gl.c.GL_RGBA,
        width,
        height,
        0,
        gl.c.GL_RGBA,
        gl.c.GL_UNSIGNED_BYTE,
        &rgba,
    );
    return .{ .id = id, .width = width, .height = height };
}

fn createTextureEmpty(width: i32, height: i32, filter: i32) types.Texture {
    var id: gl.GLuint = 0;
    gl.GenTextures(1, &id);
    gl.BindTexture(gl.c.GL_TEXTURE_2D, id);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, filter);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, filter);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_S, gl.c.GL_CLAMP_TO_EDGE);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_T, gl.c.GL_CLAMP_TO_EDGE);
    gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
    gl.TexImage2D(
        gl.c.GL_TEXTURE_2D,
        0,
        gl.c.GL_RGBA,
        width,
        height,
        0,
        gl.c.GL_RGBA,
        gl.c.GL_UNSIGNED_BYTE,
        null,
    );
    return .{ .id = id, .width = width, .height = height };
}
