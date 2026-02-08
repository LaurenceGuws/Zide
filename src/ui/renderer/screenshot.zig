const std = @import("std");
const gl = @import("gl.zig");

pub fn dumpFramebufferPpm(
    allocator: std.mem.Allocator,
    width: i32,
    height: i32,
    path: []const u8,
) !void {
    try dumpFramebufferPpmScaled(allocator, width, height, width, height, path);
}

pub fn dumpFramebufferPpmScaled(
    allocator: std.mem.Allocator,
    src_width: i32,
    src_height: i32,
    out_width: i32,
    out_height: i32,
    path: []const u8,
) !void {
    if (src_width <= 0 or src_height <= 0) return;
    if (out_width <= 0 or out_height <= 0) return;

    const src_w: usize = @intCast(src_width);
    const src_h: usize = @intCast(src_height);
    const out_w: usize = @intCast(out_width);
    const out_h: usize = @intCast(out_height);

    const src_byte_count = src_w * src_h * 4;
    const pixels = try allocator.alloc(u8, src_byte_count);
    defer allocator.free(pixels);

    // Read back RGBA8 from the currently bound framebuffer.
    gl.ReadPixels(0, 0, src_width, src_height, gl.c.GL_RGBA, gl.c.GL_UNSIGNED_BYTE, pixels.ptr);

    var file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();

    var header_buf: [64]u8 = undefined;
    const header = try std.fmt.bufPrint(&header_buf, "P6\n{d} {d}\n255\n", .{ out_width, out_height });
    try file.writeAll(header);

    const row_bytes = out_w * 3;
    const row_rgb = try allocator.alloc(u8, row_bytes);
    defer allocator.free(row_rgb);

    // Box filter when scaling down, nearest-ish when scaling up.
    var oy: usize = 0;
    while (oy < out_h) : (oy += 1) {
        const fy0 = (oy * src_h) / out_h;
        const fy1_excl = ((oy + 1) * src_h) / out_h;
        const y0 = @min(fy0, src_h - 1);
        const y1 = @max(y0 + 1, fy1_excl);

        var ox: usize = 0;
        while (ox < out_w) : (ox += 1) {
            const fx0 = (ox * src_w) / out_w;
            const fx1_excl = ((ox + 1) * src_w) / out_w;
            const x0 = @min(fx0, src_w - 1);
            const x1 = @max(x0 + 1, fx1_excl);

            var r_sum: u32 = 0;
            var g_sum: u32 = 0;
            var b_sum: u32 = 0;
            var count: u32 = 0;

            var sy: usize = y0;
            while (sy < y1 and sy < src_h) : (sy += 1) {
                // Flip Y: OpenGL is bottom-left origin.
                const src_row = (src_h - 1 - sy);
                var sx: usize = x0;
                while (sx < x1 and sx < src_w) : (sx += 1) {
                    const idx = (src_row * src_w + sx) * 4;
                    r_sum += pixels[idx + 0];
                    g_sum += pixels[idx + 1];
                    b_sum += pixels[idx + 2];
                    count += 1;
                }
            }

            if (count == 0) count = 1;
            const dst = ox * 3;
            row_rgb[dst + 0] = @intCast(r_sum / count);
            row_rgb[dst + 1] = @intCast(g_sum / count);
            row_rgb[dst + 2] = @intCast(b_sum / count);
        }

        try file.writeAll(row_rgb);
    }
}
