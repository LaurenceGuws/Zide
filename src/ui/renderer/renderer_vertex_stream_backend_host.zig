const gl_backend = @import("gl_backend.zig");
const types = @import("types.zig");

pub fn bindBatchPipelineForVertexStream(renderer: anytype) void {
    gl_backend.bindBatchPipeline(renderer);
}

pub fn setTextureKindForVertexStream(renderer: anytype, kind: types.TextureKind) void {
    gl_backend.setTextureKind(renderer, kind);
}

pub fn flushQueuedSurfaceDrawsBeforeImmediateVertexStreamWork(renderer: anytype) void {
    gl_backend.flushQueuedSurfaceDrawsBeforeImmediateWork(renderer);
}

pub fn whiteTexture(renderer: anytype) types.Texture {
    return gl_backend.whiteTexture(renderer);
}

pub fn ensureVboCapacity(renderer: anytype, vertex_count: usize, vertex_size: usize) void {
    gl_backend.ensureVboCapacity(renderer, vertex_count, vertex_size);
}
