const std = @import("std");
const build_options = @import("build_options");

pub fn main() !void {
    std.debug.print("build target\n", .{});
    std.debug.print("arch: {s}\n", .{build_options.target_arch});
    std.debug.print("os: {s}\n", .{build_options.target_os});
    std.debug.print("abi: {s}\n", .{build_options.target_abi});
    std.debug.print("optimize: {s}\n", .{build_options.optimize_mode});
}
