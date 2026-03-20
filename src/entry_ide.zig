const std = @import("std");
const focused_entry_runtime = @import("app/focused_entry_runtime.zig");
const terminal_cli = @import("app/terminal_cli.zig");
const runner = @import("app/runner.zig");
const _windows_gui_entry = @import("windows_gui_entry.zig");
comptime {
    _ = _windows_gui_entry;
}

pub const zide_focused_mode = focused_entry_runtime.AppMode.ide;
pub const zide_app_identity_name: [*:0]const u8 = "Zide";
pub const zide_app_identity_id: [*:0]const u8 = "LaurenceGuws.Zide";

pub fn main() !void {
    try runner.runWithGpa(struct {
        fn call(allocator: std.mem.Allocator) !void {
            try terminal_cli.applyKnownOverridesFromProcessArgs(allocator);
            try focused_entry_runtime.run(allocator, .ide);
        }
    }.call);
}
