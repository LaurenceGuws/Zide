const std = @import("std");
const gl = @import("gl.zig");
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

pub fn beginTerminalBatch(renderer: anytype) void {
    renderer.batch_vertices.clearRetainingCapacity();
    renderer.batch_draws.clearRetainingCapacity();
}

pub fn flushTerminalBatch(renderer: anytype) void {
    const vertex_count = renderer.batch_vertices.items.len;
    if (vertex_count == 0) return;
    ensureVboCapacity(renderer, vertex_count);
    gl.UseProgram(renderer.shader_program);
    gl.BindVertexArray(renderer.vao);
    gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, renderer.vbo);
    gl.BufferSubData(
        gl.c.GL_ARRAY_BUFFER,
        0,
        @as(gl.GLsizeiptr, @intCast(@sizeOf(Vertex) * vertex_count)),
        renderer.batch_vertices.items.ptr,
    );
    for (renderer.batch_draws.items) |draw| {
        if (draw.texture_id == 0) continue;
        gl.ActiveTexture(gl.c.GL_TEXTURE0);
        gl.BindTexture(gl.c.GL_TEXTURE_2D, draw.texture_id);
        if (renderer.uniform_kind >= 0) gl.Uniform1i(renderer.uniform_kind, @intFromEnum(draw.kind));
        applyBlendForKind(draw.kind);
        gl.DrawArrays(gl.c.GL_TRIANGLES, @intCast(draw.start), @intCast(draw.count));
    }
}

pub fn drawTextureRect(renderer: anytype, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, bg_color: types.Rgba, kind: types.TextureKind) void {
    if (texture.id == 0 or texture.width <= 0 or texture.height <= 0) return;
    gl.UseProgram(renderer.shader_program);
    gl.BindVertexArray(renderer.vao);
    gl.ActiveTexture(gl.c.GL_TEXTURE0);
    gl.BindTexture(gl.c.GL_TEXTURE_2D, texture.id);
    if (renderer.uniform_kind >= 0) gl.Uniform1i(renderer.uniform_kind, @intFromEnum(kind));
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

    gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, renderer.vbo);
    gl.BufferSubData(
        gl.c.GL_ARRAY_BUFFER,
        0,
        @as(gl.GLsizeiptr, @intCast(@sizeOf(Vertex) * 6)),
        &verts,
    );
    gl.DrawArrays(gl.c.GL_TRIANGLES, 0, 6);
}

fn applyBlendForKind(kind: types.TextureKind) void {
    switch (kind) {
        .font_coverage => gl.BlendFunc(gl.c.GL_ONE, gl.c.GL_ONE_MINUS_SRC_ALPHA),
        .linear_premul => gl.BlendFunc(gl.c.GL_ONE, gl.c.GL_ONE_MINUS_SRC_ALPHA),
        .rgba => gl.BlendFunc(gl.c.GL_SRC_ALPHA, gl.c.GL_ONE_MINUS_SRC_ALPHA),
    }
}

pub fn addBatchQuad(renderer: anytype, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, bg_color: types.Rgba, kind: types.TextureKind) void {
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

    const base = renderer.batch_vertices.items.len;
    const verts = [_]Vertex{
        .{ .x = x0, .y = y0, .u = u_min, .v = v_min, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x1, .y = y0, .u = u_max, .v = v_min, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x1, .y = y1, .u = u_max, .v = v_max, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x0, .y = y0, .u = u_min, .v = v_min, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x1, .y = y1, .u = u_max, .v = v_max, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        .{ .x = x0, .y = y1, .u = u_min, .v = v_max, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
    };
    renderer.batch_vertices.appendSlice(renderer.allocator, &verts) catch return;
    if (renderer.batch_draws.items.len > 0) {
        const last_idx = renderer.batch_draws.items.len - 1;
        if (renderer.batch_draws.items[last_idx].texture_id == texture.id and renderer.batch_draws.items[last_idx].kind == kind) {
            renderer.batch_draws.items[last_idx].count += 6;
            return;
        }
    }
    _ = renderer.batch_draws.append(renderer.allocator, .{
        .texture_id = texture.id,
        .kind = kind,
        .start = base,
        .count = 6,
    }) catch {};
}

pub fn addTerminalRect(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
    if (w <= 0 or h <= 0) return;
    const dest = shape_utils.rectFromInts(x, y, w, h);
    const src = texture_draw.unitSrcRect();
    addBatchQuad(renderer, renderer.white_texture, src, dest, color, types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 }, .rgba);
}

pub fn ensureVboCapacity(renderer: anytype, vertex_count: usize) void {
    if (vertex_count <= renderer.vbo_capacity_vertices) return;
    var next_cap = renderer.vbo_capacity_vertices * 2;
    if (next_cap < 6) next_cap = 6;
    if (next_cap < vertex_count) next_cap = vertex_count;
    gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, renderer.vbo);
    gl.BufferData(
        gl.c.GL_ARRAY_BUFFER,
        @as(gl.GLsizeiptr, @intCast(@sizeOf(Vertex) * next_cap)),
        null,
        gl.c.GL_DYNAMIC_DRAW,
    );
    renderer.vbo_capacity_vertices = next_cap;
}
