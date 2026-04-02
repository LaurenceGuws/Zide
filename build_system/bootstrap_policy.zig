const std = @import("std");
const builtin = @import("builtin");
const mode_specs = @import("mode_specs.zig");
const platform_capabilities = @import("platform_capabilities.zig");

pub fn defaultTargetQuery() std.Target.Query {
    return if (builtin.os.tag == .windows) .{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .abi = .msvc,
    } else .{};
}

pub fn parseBuildModeOption(b: *std.Build) mode_specs.BuildMode {
    return parseBuildModeRaw(readBuildModeOptionRaw(b));
}

pub fn readBuildModeOptionRaw(b: *std.Build) []const u8 {
    return b.option(
        []const u8,
        "mode",
        "Build app mode: ide (default), terminal, editor",
    ) orelse "ide";
}

pub fn parseBuildModeRaw(build_mode_raw: []const u8) mode_specs.BuildMode {
    return mode_specs.parseBuildMode(build_mode_raw);
}
