const std = @import("std");
const focused_entry_runtime = @import("app/focused_entry_runtime.zig");
const runner = @import("app/runner.zig");

pub const zide_focused_mode = focused_entry_runtime.AppMode.editor;

pub fn main() !void {
    try runner.runWithGpa(struct {
        fn call(allocator: std.mem.Allocator) !void {
            try focused_entry_runtime.run(allocator, .editor);
        }
    }.call);
}
