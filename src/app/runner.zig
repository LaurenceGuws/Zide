const std = @import("std");

pub fn runWithGpa(comptime run_fn: fn (allocator: std.mem.Allocator) anyerror!void) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    try run_fn(allocator);
}
