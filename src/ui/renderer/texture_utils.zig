const gl = @import("gl.zig");
const types = @import("types.zig");

pub fn createTextureFromRgba(width: i32, height: i32, data: []const u8, filter: i32) ?types.Texture {
    if (width <= 0 or height <= 0) return null;
    if (@as(usize, @intCast(width * height * 4)) > data.len) return null;

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
        data.ptr,
    );
    return .{ .id = id, .width = width, .height = height };
}

pub fn createTextureFromRgb(width: i32, height: i32, data: []const u8, filter: i32) ?types.Texture {
    if (width <= 0 or height <= 0) return null;
    if (@as(usize, @intCast(width * height * 3)) > data.len) return null;

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
        gl.c.GL_RGB,
        width,
        height,
        0,
        gl.c.GL_RGB,
        gl.c.GL_UNSIGNED_BYTE,
        data.ptr,
    );
    return .{ .id = id, .width = width, .height = height };
}

pub fn destroyTexture(texture: *types.Texture) void {
    if (texture.id != 0) {
        gl.DeleteTextures(1, &texture.id);
        texture.id = 0;
    }
}
