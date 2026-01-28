const std = @import("std");

const c = @cImport({
    @cInclude("stb_image.h");
});

pub const DecodeError = error{
    DecodeFailed,
    OutOfMemory,
};

pub fn decodePngRgba(allocator: std.mem.Allocator, data: []const u8) DecodeError!struct { data: []u8, width: u32, height: u32 } {
    if (data.len == 0) return error.DecodeFailed;
    var w: c_int = 0;
    var h: c_int = 0;
    var comp: c_int = 0;
    const ptr = c.stbi_load_from_memory(data.ptr, @intCast(data.len), &w, &h, &comp, 4);
    if (ptr == null or w <= 0 or h <= 0) return error.DecodeFailed;
    defer c.stbi_image_free(ptr);

    const len: usize = @as(usize, @intCast(w)) * @as(usize, @intCast(h)) * 4;
    const out = allocator.alloc(u8, len) catch return error.OutOfMemory;
    const src = @as([*]const u8, @ptrCast(ptr))[0..len];
    std.mem.copyForwards(u8, out, src);
    return .{ .data = out, .width = @intCast(w), .height = @intCast(h) };
}
