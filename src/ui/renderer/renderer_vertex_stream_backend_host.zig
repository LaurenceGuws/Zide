const android_gles_backend = @import("android_gles_backend.zig");
const gl_backend = @import("gl_backend.zig");
const types = @import("types.zig");

pub fn bindBatchPipelineForVertexStream(renderer: anytype) void {
    switch (renderer.backend.kind) {
        .opengl => gl_backend.bindBatchPipeline(renderer),
        .android_gles => android_gles_backend.bindBatchPipeline(renderer),
        .metal => {},
    }
}

pub fn setTextureKindForVertexStream(renderer: anytype, kind: types.TextureKind) void {
    switch (renderer.backend.kind) {
        .opengl => gl_backend.setTextureKind(renderer, kind),
        .android_gles => android_gles_backend.setTextureKind(renderer, kind),
        .metal => {},
    }
}

pub fn flushQueuedSurfaceDrawsBeforeImmediateVertexStreamWork(renderer: anytype) void {
    switch (renderer.backend.kind) {
        .opengl => gl_backend.flushQueuedSurfaceDrawsBeforeImmediateWork(renderer),
        .android_gles => android_gles_backend.flushQueuedSurfaceDrawsBeforeImmediateWork(renderer),
        .metal => {},
    }
}

pub fn whiteTexture(renderer: anytype) types.Texture {
    return switch (renderer.backend.kind) {
        .opengl => gl_backend.whiteTexture(renderer),
        .android_gles => android_gles_backend.whiteTexture(renderer),
        .metal => .{ .id = 0, .width = 0, .height = 0 },
    };
}

pub fn ensureVboCapacity(renderer: anytype, vertex_count: usize, vertex_size: usize) void {
    switch (renderer.backend.kind) {
        .opengl => gl_backend.ensureVboCapacity(renderer, vertex_count, vertex_size),
        .android_gles => android_gles_backend.ensureVboCapacity(renderer, vertex_count, vertex_size),
        .metal => {},
    }
}
