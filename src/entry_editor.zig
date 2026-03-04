const std = @import("std");
const app_entry_runtime = @import("app/app_entry_runtime.zig");
const runner = @import("app/runner.zig");

pub const zide_focused_mode = app_entry_runtime.AppMode.editor;

pub fn main() !void {
    try runner.runWithGpa(struct {
        fn call(allocator: std.mem.Allocator) !void {
            try app_entry_runtime.runWithMode(allocator, .editor);
        }
    }.call);
}
