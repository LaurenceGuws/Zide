const std = @import("std");
const build_options = @import("build_options");
const policy_catalog = @import("policy_catalog");

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
    for (policy_catalog.supported_options) |option| {
        std.debug.print("- {s}: {s}\n", .{ option.flag, option.description });
    }
    std.debug.print("\n", .{});

    std.debug.print("hard constraints\n", .{});
    for (policy_catalog.hard_constraints) |line| {
        std.debug.print("- {s}\n", .{line.text});
    }
    std.debug.print("\n", .{});

    std.debug.print("operator intent\n", .{});
    for (policy_catalog.operator_intent) |line| {
        std.debug.print("- {s}\n", .{line.text});
    }
}
