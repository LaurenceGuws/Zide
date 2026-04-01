const std = @import("std");
const build_options = @import("build_options");

pub fn main() !void {
    std.debug.print("build policy\n", .{});
    std.debug.print("mode: {s}\n", .{build_options.build_mode});
    std.debug.print("renderer_backend: {s}\n", .{build_options.renderer_backend});
    std.debug.print("target: {s}-{s}-{s}\n", .{
        build_options.target_arch,
        build_options.target_os,
        build_options.target_abi,
    });
    std.debug.print("optimize: {s}\n", .{build_options.optimize_mode});
    std.debug.print("treesitter_enabled: {any}\n", .{build_options.treesitter_enabled});
    std.debug.print("\n", .{});

    std.debug.print("supported -D options\n", .{});
    std.debug.print("- -Dmode=ide|terminal|editor\n", .{});
    std.debug.print("- -Drenderer-backend=sdl_gl\n", .{});
    std.debug.print("- standard Zig target/optimize options\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("hard constraints\n", .{});
    std.debug.print("- terminal mode must not resolve tree-sitter\n", .{});
    std.debug.print("- non-terminal modes must resolve tree-sitter\n", .{});
    std.debug.print("- renderer backend support is currently SDL GL only\n", .{});
    std.debug.print("- build graph is intentionally split between runtime app planning and extended IDE/test planning\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("operator intent\n", .{});
    std.debug.print("- use report-build-surface for the step taxonomy\n", .{});
    std.debug.print("- use report-build-profiles for the dependency profile matrix\n", .{});
    std.debug.print("- use report-build-policy for the active option/constraint summary\n", .{});
}
