const std = @import("std");
const app_entry_runtime = @import("app/app_entry_runtime.zig");

pub const AppMode = app_entry_runtime.AppMode;

pub fn runWithMode(allocator: std.mem.Allocator, app_mode: AppMode) !void {
    try app_entry_runtime.runWithMode(allocator, app_mode);
}

pub fn runFromArgs(allocator: std.mem.Allocator) !void {
    try app_entry_runtime.runFromArgs(allocator);
}

pub fn main() !void {
    try app_entry_runtime.runMain();
}

test {
    _ = @import("main_tests.zig");
}
