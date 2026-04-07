const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const gl = @import("gl.zig");
const gl_backend = @import("gl_backend.zig");
const shape_utils = @import("shape_utils.zig");
const texture_draw = @import("texture_draw.zig");
const types = @import("types.zig");

pub const BatchDraw = struct {
    texture_id: gl.GLuint,
    kind: types.TextureKind,
    start: usize,
    count: usize,
};

pub const Vertex = packed struct {
    x: f32,
    y: f32,
    u: f32,
    v: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    br: f32,
    bg: f32,
    bb: f32,
    ba: f32,
};

pub const BatchState = struct {
    vertices: std.ArrayList(Vertex) = std.ArrayList(Vertex).empty,
    draws: std.ArrayList(BatchDraw) = std.ArrayList(BatchDraw).empty,
};

pub fn deinit(state: *BatchState, allocator: std.mem.Allocator) void {
    state.vertices.deinit(allocator);
    state.draws.deinit(allocator);
}

/// OpenGL-only: shared batch pipeline binding for vertex-stream glyph uploads
/// (terminal batch flush and `glyph_cache` flush).
pub fn bindBatchPipelineForVertexStream(renderer: anytype) void {
    gl_backend.bindBatchPipeline(renderer);
}

/// OpenGL-only: texture-kind uniform for vertex-stream glyph draws.
pub fn setTextureKindForVertexStream(renderer: anytype, kind: types.TextureKind) void {
    gl_backend.setTextureKind(renderer, kind);
}

pub fn beginTerminalBatch(renderer: anytype) void {
    renderer.batch.vertices.clearRetainingCapacity();
    renderer.batch.draws.clearRetainingCapacity();
}

pub fn flushTerminalBatch(renderer: anytype) void {
    const vertex_count = renderer.batch.vertices.items.len;
    if (vertex_count == 0) return;
    gl_backend.flushQueuedSurfaceDrawsBeforeImmediateWork(renderer);
    ensureVboCapacity(renderer, vertex_count);
    bindBatchPipelineForVertexStream(renderer);
    gl.BufferSubData(
        gl.c.GL_ARRAY_BUFFER,
        0,
        @as(gl.GLsizeiptr, @intCast(@sizeOf(Vertex) * vertex_count)),
        renderer.batch.vertices.items.ptr,
    );
    for (renderer.batch.draws.items) |draw| {
        if (draw.texture_id == 0) continue;
        gl.ActiveTexture(gl.c.GL_TEXTURE0);
        gl.BindTexture(gl.c.GL_TEXTURE_2D, draw.texture_id);
        setTextureKindForVertexStream(renderer, draw.kind);
        applyBlendForKind(draw.kind);
        gl.DrawArrays(gl.c.GL_TRIANGLES, @intCast(draw.start), @intCast(draw.count));
    }
}

/// Immediate GL textured quad: does **not** flush the deferred `SurfaceDraw` queue.
/// Use only from OpenGL surface replay (`gl_backend` presentable/scene paths) where
/// flushing would re-enter replay; normal callers must use [`drawTextureRect`].
pub fn drawTextureRectImmediate(renderer: anytype, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, bg_color: types.Rgba, kind: types.TextureKind) void {
    if (texture.id == 0 or texture.width <= 0 or texture.height <= 0) return;
    bindBatchPipelineForVertexStream(renderer);
    gl.ActiveTexture(gl.c.GL_TEXTURE0);
    gl.BindTexture(gl.c.GL_TEXTURE_2D, texture.id);
    setTextureKindForVertexStream(renderer, kind);
    applyBlendForKind(kind);

    const tex_w = @as(f32, @floatFromInt(texture.width));
    const tex_h = @as(f32, @floatFromInt(texture.height));
    const u_min = src.x / tex_w;
    const v_min = src.y / tex_h;
    const u_max = (src.x + src.width) / tex_w;
    const v_max = (src.y + src.height) / tex_h;

    const r = @as(f32, @floatFromInt(color.r)) / 255.0;
    const g = @as(f32, @floatFromInt(color.g)) / 255.0;
    const b = @as(f32, @floatFromInt(color.b)) / 255.0;
    const a = @as(f32, @floatFromInt(color.a)) / 255.0;

    const br = @as(f32, @floatFromInt(bg_color.r)) / 255.0;
    const bg = @as(f32, @floatFromInt(bg_color.g)) / 255.0;
    const bb = @as(f32, @floatFromInt(bg_color.b)) / 255.0;
    const ba = @as(f32, @floatFromInt(bg_color.a)) / 255.0;

    const x0 = dest.x;
    const y0 = dest.y;
    const x1 = dest.x + dest.width;
    const y1 = dest.y + dest.height;

    const verts = [_]Vertex{
        .{ .x = x0, .y = y0, .u = u_min, .v = v_min, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x1, .y = y0, .u = u_max, .v = v_min, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x1, .y = y1, .u = u_max, .v = v_max, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x0, .y = y0, .u = u_min, .v = v_min, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x1, .y = y1, .u = u_max, .v = v_max, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x0, .y = y1, .u = u_min, .v = v_max, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
    };

    gl.BufferSubData(
        gl.c.GL_ARRAY_BUFFER,
        0,
        @as(gl.GLsizeiptr, @intCast(@sizeOf(Vertex) * 6)),
        &verts,
    );
    gl.DrawArrays(gl.c.GL_TRIANGLES, 0, 6);
}

/// Single-texture immediate draw used by text and UI paths on OpenGL. Flushes deferred
/// `SurfaceDraw` work first so list order matches “surface queue, then immediate GL.”
pub fn drawTextureRect(renderer: anytype, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, bg_color: types.Rgba, kind: types.TextureKind) void {
    gl_backend.flushQueuedSurfaceDrawsBeforeImmediateWork(renderer);
    drawTextureRectImmediate(renderer, texture, src, dest, color, bg_color, kind);
}

fn applyBlendForKind(kind: types.TextureKind) void {
    switch (kind) {
        .font_coverage => gl.BlendFunc(gl.c.GL_ONE, gl.c.GL_ONE_MINUS_SRC_ALPHA),
        .linear_premul => gl.BlendFunc(gl.c.GL_ONE, gl.c.GL_ONE_MINUS_SRC_ALPHA),
        .rgba => gl.BlendFunc(gl.c.GL_SRC_ALPHA, gl.c.GL_ONE_MINUS_SRC_ALPHA),
    }
}

pub fn addBatchQuad(renderer: anytype, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, bg_color: types.Rgba, kind: types.TextureKind) void {
    const log = app_logger.logger("renderer.batch");
    if (texture.id == 0 or texture.width <= 0 or texture.height <= 0) return;
    const tex_w = @as(f32, @floatFromInt(texture.width));
    const tex_h = @as(f32, @floatFromInt(texture.height));
    const u_min = src.x / tex_w;
    const v_min = src.y / tex_h;
    const u_max = (src.x + src.width) / tex_w;
    const v_max = (src.y + src.height) / tex_h;

    const r = @as(f32, @floatFromInt(color.r)) / 255.0;
    const g = @as(f32, @floatFromInt(color.g)) / 255.0;
    const b = @as(f32, @floatFromInt(color.b)) / 255.0;
    const a = @as(f32, @floatFromInt(color.a)) / 255.0;

    const br = @as(f32, @floatFromInt(bg_color.r)) / 255.0;
    const bg = @as(f32, @floatFromInt(bg_color.g)) / 255.0;
    const bb = @as(f32, @floatFromInt(bg_color.b)) / 255.0;
    const ba = @as(f32, @floatFromInt(bg_color.a)) / 255.0;

    const x0 = dest.x;
    const y0 = dest.y;
    const x1 = dest.x + dest.width;
    const y1 = dest.y + dest.height;

    const base = renderer.batch.vertices.items.len;
    const verts = [_]Vertex{
        .{ .x = x0, .y = y0, .u = u_min, .v = v_min, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x1, .y = y0, .u = u_max, .v = v_min, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x1, .y = y1, .u = u_max, .v = v_max, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x0, .y = y0, .u = u_min, .v = v_min, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x1, .y = y1, .u = u_max, .v = v_max, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x0, .y = y1, .u = u_min, .v = v_max, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
    };
    renderer.batch.vertices.appendSlice(renderer.allocator, &verts) catch |err| {
        log.logf(.warning, "batch vertices append failed texture={d} err={s}", .{ texture.id, @errorName(err) });
        return;
    };
    if (renderer.batch.draws.items.len > 0) {
        const last_idx = renderer.batch.draws.items.len - 1;
        if (renderer.batch.draws.items[last_idx].texture_id == texture.id and renderer.batch.draws.items[last_idx].kind == kind) {
            renderer.batch.draws.items[last_idx].count += 6;
            return;
        }
    }
    renderer.batch.draws.append(renderer.allocator, .{
        .texture_id = texture.id,
        .kind = kind,
        .start = base,
        .count = 6,
    }) catch |err| {
        log.logf(.warning, "batch draws append failed texture={d} err={s}", .{ texture.id, @errorName(err) });
    };
}

pub fn addTerminalRect(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
    if (w <= 0 or h <= 0) return;
    const dest = shape_utils.rectFromInts(x, y, w, h);
    const src = texture_draw.unitSrcRect();
    addBatchQuad(renderer, gl_backend.whiteTexture(renderer), src, dest, color, types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 }, .rgba);
}

pub fn ensureVboCapacity(renderer: anytype, vertex_count: usize) void {
    gl_backend.ensureVboCapacity(renderer, vertex_count, @sizeOf(Vertex));
}
