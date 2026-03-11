const std = @import("std");
const focused_entry_runtime = @import("app/focused_entry_runtime.zig");
const terminal_cli = @import("app/terminal_cli.zig");
const runner = @import("app/runner.zig");

pub const zide_focused_mode = focused_entry_runtime.AppMode.terminal;

pub fn main() !void {
    try runner.runWithGpa(struct {
        fn call(allocator: std.mem.Allocator) !void {
            var cli = try terminal_cli.parseArgs(allocator);
            defer cli.deinit(allocator);
            if (cli.help) {
                try terminal_cli.printHelp(std.fs.File.stdout().deprecatedWriter());
                return;
            }
            try terminal_cli.applyEnv(&cli, allocator);
            try focused_entry_runtime.run(allocator, .terminal);
        }
    }.call);
}
