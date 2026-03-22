const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4) {
        std.debug.print("usage: gui-smokes-manual <editor-exe> <ide-exe> <terminal-exe>\n", .{});
        return error.InvalidArguments;
    }

    for (args[1..4]) |exe_path| {
        try spawnGui(allocator, exe_path);
    }
}

fn spawnGui(allocator: std.mem.Allocator, exe_path: []const u8) !void {
    var child = std.process.Child.init(&.{exe_path}, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
}
