const std = @import("std");
const build_options = @import("build_options");

pub fn main() !void {
    std.debug.print("build bootstrap\n", .{});
    std.debug.print("mode: {s}\n", .{build_options.build_mode});
    std.debug.print("dependency_path: {s}\n", .{build_options.dependency_path});
    std.debug.print("renderer_backend: {s}\n", .{build_options.renderer_backend});
    std.debug.print("target_os: {s}\n", .{build_options.target_os});
    std.debug.print("use_vcpkg: {any}\n", .{build_options.use_vcpkg});
    std.debug.print("treesitter_enabled: {any}\n", .{build_options.treesitter_enabled});
}
