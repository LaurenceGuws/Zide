const std = @import("std");
const app = @import("../main.zig");
const runner = @import("runner.zig");

pub fn main() !void {
    try runner.runWithGpa(struct {
        fn call(allocator: std.mem.Allocator) !void {
            try app.runWithMode(allocator, .ide);
        }
    }.call);
}
