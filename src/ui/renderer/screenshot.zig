const std = @import("std");
const gl = @import("gl.zig");

pub fn dumpFramebufferPpm(
    allocator: std.mem.Allocator,
    width: i32,
    height: i32,
    path: []const u8,
) !void {
    if (width <= 0 or height <= 0) return;

    const w: usize = @intCast(width);
    const h: usize = @intCast(height);
    const byte_count = w * h * 4;

    const pixels = try allocator.alloc(u8, byte_count);
    defer allocator.free(pixels);

    // Read back RGBA8 from the currently bound framebuffer.
    gl.ReadPixels(0, 0, width, height, gl.c.GL_RGBA, gl.c.GL_UNSIGNED_BYTE, pixels.ptr);

    var file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();

    // Binary PPM (P6), top-to-bottom.
    var header_buf: [64]u8 = undefined;
    const header = try std.fmt.bufPrint(&header_buf, "P6\n{d} {d}\n255\n", .{ width, height });
    try file.writeAll(header);

    const row_bytes = w * 3;
    const row_rgb = try allocator.alloc(u8, row_bytes);
    defer allocator.free(row_rgb);

    var row: usize = 0;
    while (row < h) : (row += 1) {
        const src_row = (h - 1 - row); // OpenGL is bottom-left origin.
        var col: usize = 0;
        while (col < w) : (col += 1) {
            const idx = (src_row * w + col) * 4;
            const dst = col * 3;
            row_rgb[dst + 0] = pixels[idx + 0];
            row_rgb[dst + 1] = pixels[idx + 1];
            row_rgb[dst + 2] = pixels[idx + 2];
        }
        try file.writeAll(row_rgb);
    }
}
