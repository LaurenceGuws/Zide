const std = @import("std");
const app = @import("../main.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    try app.runWithMode(allocator, .terminal);
}

