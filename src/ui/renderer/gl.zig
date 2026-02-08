const std = @import("std");
const sdl_api = @import("../../platform/sdl_api.zig");

pub const c = sdl_api.c;

pub const GLenum = c.GLenum;
pub const GLuint = c.GLuint;
pub const GLint = c.GLint;
pub const GLsizei = c.GLsizei;
pub const GLchar = c.GLchar;
pub const GLsizeiptr = c.GLsizeiptr;
pub const GLintptr = c.GLintptr;
pub const GLfloat = c.GLfloat;
pub const GLboolean = c.GLboolean;

pub var CreateShader: *const fn (GLenum) callconv(.c) GLuint = undefined;
pub var ShaderSource: *const fn (GLuint, GLsizei, [*]const [*]const GLchar, ?[*]const GLint) callconv(.c) void = undefined;
pub var CompileShader: *const fn (GLuint) callconv(.c) void = undefined;
pub var GetShaderiv: *const fn (GLuint, GLenum, *GLint) callconv(.c) void = undefined;
pub var GetShaderInfoLog: *const fn (GLuint, GLsizei, ?*GLsizei, [*]GLchar) callconv(.c) void = undefined;
pub var DeleteShader: *const fn (GLuint) callconv(.c) void = undefined;

pub var CreateProgram: *const fn () callconv(.c) GLuint = undefined;
pub var AttachShader: *const fn (GLuint, GLuint) callconv(.c) void = undefined;
pub var LinkProgram: *const fn (GLuint) callconv(.c) void = undefined;
pub var GetProgramiv: *const fn (GLuint, GLenum, *GLint) callconv(.c) void = undefined;
pub var GetProgramInfoLog: *const fn (GLuint, GLsizei, ?*GLsizei, [*]GLchar) callconv(.c) void = undefined;
pub var UseProgram: *const fn (GLuint) callconv(.c) void = undefined;
pub var DeleteProgram: *const fn (GLuint) callconv(.c) void = undefined;
pub var GetUniformLocation: *const fn (GLuint, [*:0]const GLchar) callconv(.c) GLint = undefined;
pub var Uniform1i: *const fn (GLint, GLint) callconv(.c) void = undefined;
pub var Uniform1f: *const fn (GLint, GLfloat) callconv(.c) void = undefined;
pub var Uniform4f: *const fn (GLint, GLfloat, GLfloat, GLfloat, GLfloat) callconv(.c) void = undefined;
pub var UniformMatrix4fv: *const fn (GLint, GLsizei, GLboolean, [*]const GLfloat) callconv(.c) void = undefined;

pub var GenVertexArrays: *const fn (GLsizei, *GLuint) callconv(.c) void = undefined;
pub var BindVertexArray: *const fn (GLuint) callconv(.c) void = undefined;
pub var DeleteVertexArrays: *const fn (GLsizei, *const GLuint) callconv(.c) void = undefined;
pub var GenBuffers: *const fn (GLsizei, *GLuint) callconv(.c) void = undefined;
pub var BindBuffer: *const fn (GLenum, GLuint) callconv(.c) void = undefined;
pub var BufferData: *const fn (GLenum, GLsizeiptr, ?*const anyopaque, GLenum) callconv(.c) void = undefined;
pub var BufferSubData: *const fn (GLenum, GLintptr, GLsizeiptr, *const anyopaque) callconv(.c) void = undefined;
pub var DeleteBuffers: *const fn (GLsizei, *const GLuint) callconv(.c) void = undefined;
pub var EnableVertexAttribArray: *const fn (GLuint) callconv(.c) void = undefined;
pub var VertexAttribPointer: *const fn (GLuint, GLint, GLenum, GLboolean, GLsizei, ?*const anyopaque) callconv(.c) void = undefined;

pub var GenTextures: *const fn (GLsizei, *GLuint) callconv(.c) void = undefined;
pub var BindTexture: *const fn (GLenum, GLuint) callconv(.c) void = undefined;
pub var TexParameteri: *const fn (GLenum, GLenum, GLint) callconv(.c) void = undefined;
pub var TexImage2D: *const fn (GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, ?*const anyopaque) callconv(.c) void = undefined;
pub var TexSubImage2D: *const fn (GLenum, GLint, GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, *const anyopaque) callconv(.c) void = undefined;
pub var CopyTexSubImage2D: *const fn (GLenum, GLint, GLint, GLint, GLint, GLint, GLsizei, GLsizei) callconv(.c) void = undefined;
pub var DeleteTextures: *const fn (GLsizei, *const GLuint) callconv(.c) void = undefined;
pub var ActiveTexture: *const fn (GLenum) callconv(.c) void = undefined;
pub var PixelStorei: *const fn (GLenum, GLint) callconv(.c) void = undefined;

pub var GenFramebuffers: *const fn (GLsizei, *GLuint) callconv(.c) void = undefined;
pub var BindFramebuffer: *const fn (GLenum, GLuint) callconv(.c) void = undefined;
pub var FramebufferTexture2D: *const fn (GLenum, GLenum, GLenum, GLuint, GLint) callconv(.c) void = undefined;
pub var CheckFramebufferStatus: *const fn (GLenum) callconv(.c) GLenum = undefined;
pub var DeleteFramebuffers: *const fn (GLsizei, *const GLuint) callconv(.c) void = undefined;

pub var Enable: *const fn (GLenum) callconv(.c) void = undefined;
pub var Disable: *const fn (GLenum) callconv(.c) void = undefined;
pub var BlendFunc: *const fn (GLenum, GLenum) callconv(.c) void = undefined;
pub var BlendFuncSeparate: *const fn (GLenum, GLenum, GLenum, GLenum) callconv(.c) void = undefined;
pub var BlendEquation: *const fn (GLenum) callconv(.c) void = undefined;
pub var Viewport: *const fn (GLint, GLint, GLsizei, GLsizei) callconv(.c) void = undefined;
pub var Scissor: *const fn (GLint, GLint, GLsizei, GLsizei) callconv(.c) void = undefined;
pub var ClearColor: *const fn (GLfloat, GLfloat, GLfloat, GLfloat) callconv(.c) void = undefined;
pub var Clear: *const fn (GLenum) callconv(.c) void = undefined;
pub var ReadPixels: *const fn (GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, *anyopaque) callconv(.c) void = undefined;
pub var DrawArrays: *const fn (GLenum, GLint, GLsizei) callconv(.c) void = undefined;

var loaded: bool = false;

pub fn load() !void {
    if (loaded) return;
    CreateShader = try loadProc(@TypeOf(CreateShader), "glCreateShader");
    ShaderSource = try loadProc(@TypeOf(ShaderSource), "glShaderSource");
    CompileShader = try loadProc(@TypeOf(CompileShader), "glCompileShader");
    GetShaderiv = try loadProc(@TypeOf(GetShaderiv), "glGetShaderiv");
    GetShaderInfoLog = try loadProc(@TypeOf(GetShaderInfoLog), "glGetShaderInfoLog");
    DeleteShader = try loadProc(@TypeOf(DeleteShader), "glDeleteShader");

    CreateProgram = try loadProc(@TypeOf(CreateProgram), "glCreateProgram");
    AttachShader = try loadProc(@TypeOf(AttachShader), "glAttachShader");
    LinkProgram = try loadProc(@TypeOf(LinkProgram), "glLinkProgram");
    GetProgramiv = try loadProc(@TypeOf(GetProgramiv), "glGetProgramiv");
    GetProgramInfoLog = try loadProc(@TypeOf(GetProgramInfoLog), "glGetProgramInfoLog");
    UseProgram = try loadProc(@TypeOf(UseProgram), "glUseProgram");
    DeleteProgram = try loadProc(@TypeOf(DeleteProgram), "glDeleteProgram");
    GetUniformLocation = try loadProc(@TypeOf(GetUniformLocation), "glGetUniformLocation");
    Uniform1i = try loadProc(@TypeOf(Uniform1i), "glUniform1i");
    Uniform1f = try loadProc(@TypeOf(Uniform1f), "glUniform1f");
    Uniform4f = try loadProc(@TypeOf(Uniform4f), "glUniform4f");
    UniformMatrix4fv = try loadProc(@TypeOf(UniformMatrix4fv), "glUniformMatrix4fv");

    GenVertexArrays = try loadProc(@TypeOf(GenVertexArrays), "glGenVertexArrays");
    BindVertexArray = try loadProc(@TypeOf(BindVertexArray), "glBindVertexArray");
    DeleteVertexArrays = try loadProc(@TypeOf(DeleteVertexArrays), "glDeleteVertexArrays");
    GenBuffers = try loadProc(@TypeOf(GenBuffers), "glGenBuffers");
    BindBuffer = try loadProc(@TypeOf(BindBuffer), "glBindBuffer");
    BufferData = try loadProc(@TypeOf(BufferData), "glBufferData");
    BufferSubData = try loadProc(@TypeOf(BufferSubData), "glBufferSubData");
    DeleteBuffers = try loadProc(@TypeOf(DeleteBuffers), "glDeleteBuffers");
    EnableVertexAttribArray = try loadProc(@TypeOf(EnableVertexAttribArray), "glEnableVertexAttribArray");
    VertexAttribPointer = try loadProc(@TypeOf(VertexAttribPointer), "glVertexAttribPointer");

    GenTextures = try loadProc(@TypeOf(GenTextures), "glGenTextures");
    BindTexture = try loadProc(@TypeOf(BindTexture), "glBindTexture");
    TexParameteri = try loadProc(@TypeOf(TexParameteri), "glTexParameteri");
    TexImage2D = try loadProc(@TypeOf(TexImage2D), "glTexImage2D");
    TexSubImage2D = try loadProc(@TypeOf(TexSubImage2D), "glTexSubImage2D");
    CopyTexSubImage2D = try loadProc(@TypeOf(CopyTexSubImage2D), "glCopyTexSubImage2D");
    DeleteTextures = try loadProc(@TypeOf(DeleteTextures), "glDeleteTextures");
    ActiveTexture = try loadProc(@TypeOf(ActiveTexture), "glActiveTexture");
    PixelStorei = try loadProc(@TypeOf(PixelStorei), "glPixelStorei");

    GenFramebuffers = try loadProc(@TypeOf(GenFramebuffers), "glGenFramebuffers");
    BindFramebuffer = try loadProc(@TypeOf(BindFramebuffer), "glBindFramebuffer");
    FramebufferTexture2D = try loadProc(@TypeOf(FramebufferTexture2D), "glFramebufferTexture2D");
    CheckFramebufferStatus = try loadProc(@TypeOf(CheckFramebufferStatus), "glCheckFramebufferStatus");
    DeleteFramebuffers = try loadProc(@TypeOf(DeleteFramebuffers), "glDeleteFramebuffers");

    Enable = try loadProc(@TypeOf(Enable), "glEnable");
    Disable = try loadProc(@TypeOf(Disable), "glDisable");
    BlendFunc = try loadProc(@TypeOf(BlendFunc), "glBlendFunc");
    BlendFuncSeparate = try loadProc(@TypeOf(BlendFuncSeparate), "glBlendFuncSeparate");
    BlendEquation = try loadProc(@TypeOf(BlendEquation), "glBlendEquation");
    Viewport = try loadProc(@TypeOf(Viewport), "glViewport");
    Scissor = try loadProc(@TypeOf(Scissor), "glScissor");
    ClearColor = try loadProc(@TypeOf(ClearColor), "glClearColor");
    Clear = try loadProc(@TypeOf(Clear), "glClear");
    ReadPixels = try loadProc(@TypeOf(ReadPixels), "glReadPixels");
    DrawArrays = try loadProc(@TypeOf(DrawArrays), "glDrawArrays");

    loaded = true;
}

fn loadProc(comptime T: type, name: [:0]const u8) !T {
    const ptr = c.SDL_GL_GetProcAddress(name) orelse return error.MissingGlProc;
    return @ptrCast(ptr);
}
