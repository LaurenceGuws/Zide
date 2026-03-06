const std = @import("std");
const dependency_path = @import("dependency_path.zig");

pub const AppLinkContext = struct {
    dep_path: dependency_path.DependencySource,
    target_os: std.Target.Os.Tag,
    use_vcpkg: bool,
    vcpkg_lib: ?[]const u8,
    vcpkg_include: ?[]const u8,
    treesitter: ?*std.Build.Step.Compile,
    sdl_lib: ?*std.Build.Step.Compile,
    lua_lib: ?*std.Build.Step.Compile,
    freetype_lib: ?*std.Build.Step.Compile,
    harfbuzz_lib: ?*std.Build.Step.Compile,
};

pub const VcpkgPaths = struct {
    include: ?[]const u8,
    lib: ?[]const u8,
    bin: ?[]const u8,
};
