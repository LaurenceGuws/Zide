const std = @import("std");
const app_logger = @import("../app_logger.zig");
const gl = @import("renderer/gl.zig");
const draw_ops = @import("renderer/draw_ops.zig");
const shape_utils = @import("renderer/shape_utils.zig");
const texture_draw = @import("renderer/texture_draw.zig");
const types = @import("renderer/types.zig");

const Vertex = draw_ops.Vertex;
const BatchDraw = draw_ops.BatchDraw;

pub const GlyphCache = struct {
    allocator: std.mem.Allocator,
    vertices: std.ArrayList(Vertex),
    draws: std.ArrayList(BatchDraw),

    pub fn init(allocator: std.mem.Allocator) GlyphCache {
        return .{
            .allocator = allocator,
            .vertices = std.ArrayList(Vertex).empty,
            .draws = std.ArrayList(BatchDraw).empty,
        };
    }

    pub fn deinit(self: *GlyphCache) void {
        self.vertices.deinit(self.allocator);
        self.draws.deinit(self.allocator);
    }

    pub fn begin(self: *GlyphCache) void {
        self.vertices.clearRetainingCapacity();
        self.draws.clearRetainingCapacity();
    }

    pub fn addQuad(self: *GlyphCache, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, bg_color: types.Rgba, kind: types.TextureKind) void {
        const log = app_logger.logger("renderer.glyph_cache");
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

        const base = self.vertices.items.len;
        const verts = [_]Vertex{
            .{ .x = x0, .y = y0, .u = u_min, .v = v_min, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
            .{ .x = x1, .y = y0, .u = u_max, .v = v_min, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
            .{ .x = x1, .y = y1, .u = u_max, .v = v_max, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
            .{ .x = x0, .y = y0, .u = u_min, .v = v_min, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
            .{ .x = x1, .y = y1, .u = u_max, .v = v_max, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
            .{ .x = x0, .y = y1, .u = u_min, .v = v_max, .r = r, .g = g, .b = b, .a = a, .br = br, .bg = bg, .bb = bb, .ba = ba },
        };
        self.vertices.appendSlice(self.allocator, &verts) catch |err| {
                            log.logf(.warning, "glyph cache vertices append failed texture={d} err={s}", .{ texture.id, @errorName(err) });
            return;
        };
        if (self.draws.items.len > 0) {
            const last_idx = self.draws.items.len - 1;
            if (self.draws.items[last_idx].texture_id == texture.id and self.draws.items[last_idx].kind == kind) {
                self.draws.items[last_idx].count += 6;
                return;
            }
        }
        self.draws.append(self.allocator, .{
            .texture_id = texture.id,
            .kind = kind,
            .start = base,
            .count = 6,
        }) catch |err| {
                            log.logf(.warning, "glyph cache draw append failed texture={d} err={s}", .{ texture.id, @errorName(err) });
        };
    }

    pub fn addRect(self: *GlyphCache, white_texture: types.Texture, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
        if (w <= 0 or h <= 0) return;
        const dest = shape_utils.rectFromInts(x, y, w, h);
        const src = texture_draw.unitSrcRect();
        self.addQuad(white_texture, src, dest, color, types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 }, .rgba);
    }

    pub fn flush(self: *GlyphCache, renderer: anytype) void {
        const vertex_count = self.vertices.items.len;
        if (vertex_count == 0) return;
        draw_ops.ensureVboCapacity(renderer, vertex_count);
        gl.UseProgram(renderer.shader_program);
        gl.BindVertexArray(renderer.vao);
        gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, renderer.vbo);
        gl.BufferSubData(
            gl.c.GL_ARRAY_BUFFER,
            0,
            @as(gl.GLsizeiptr, @intCast(@sizeOf(Vertex) * vertex_count)),
            self.vertices.items.ptr,
        );
        for (self.draws.items) |draw| {
            if (draw.texture_id == 0) continue;
            gl.ActiveTexture(gl.c.GL_TEXTURE0);
            gl.BindTexture(gl.c.GL_TEXTURE_2D, draw.texture_id);
            if (renderer.uniform_kind >= 0) gl.Uniform1i(renderer.uniform_kind, @intFromEnum(draw.kind));
            applyBlendForKind(draw.kind);
            gl.DrawArrays(gl.c.GL_TRIANGLES, @intCast(draw.start), @intCast(draw.count));
        }
    }
};

fn applyBlendForKind(kind: types.TextureKind) void {
    switch (kind) {
        .font_coverage => gl.BlendFunc(gl.c.GL_ONE, gl.c.GL_ONE_MINUS_SRC_ALPHA),
        .linear_premul => gl.BlendFunc(gl.c.GL_ONE, gl.c.GL_ONE_MINUS_SRC_ALPHA),
        .rgba => gl.BlendFunc(gl.c.GL_SRC_ALPHA, gl.c.GL_ONE_MINUS_SRC_ALPHA),
    }
}
