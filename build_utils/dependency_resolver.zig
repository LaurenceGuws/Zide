const std = @import("std");
const dependency_path = @import("dependency_path.zig");

pub const BuildDependencies = struct {
    treesitter: *std.Build.Step.Compile,
    sdl_lib: *std.Build.Step.Compile,
    zlua_module: *std.Build.Module,
    lua_lib: *std.Build.Step.Compile,
    freetype_lib: ?*std.Build.Step.Compile,
    harfbuzz_lib: ?*std.Build.Step.Compile,
};

pub fn resolveDependencies(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    dep_path: dependency_path.DependencySource,
    use_vcpkg: bool,
) BuildDependencies {
    const tree_sitter_dep = b.dependency("tree_sitter", .{
        .target = target,
        .optimize = optimize,
    });
    const treesitter = tree_sitter_dep.artifact("tree-sitter");

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");

    const zlua_dep = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
    });
    const zlua_module = zlua_dep.module("zlua");
    const lua_lib = zlua_dep.artifact("lua");

    const freetype_dep = if (dep_path == .zig and !use_vcpkg)
        b.dependency("freetype", .{
            .target = target,
            .optimize = optimize,
            .use_system_zlib = true,
            .enable_brotli = false,
        })
    else
        null;

    const harfbuzz_dep = if (dep_path == .zig and !use_vcpkg)
        b.dependency("harfbuzz", .{
            .target = target,
            .optimize = optimize,
            .enable_freetype = true,
            .freetype_use_system_zlib = true,
            .freetype_enable_brotli = false,
        })
    else
        null;

    const freetype_lib: ?*std.Build.Step.Compile = if (freetype_dep) |dep| dep.artifact("freetype") else null;
    const harfbuzz_lib: ?*std.Build.Step.Compile = if (harfbuzz_dep) |dep| dep.artifact("harfbuzz") else null;

    return .{
        .treesitter = treesitter,
        .sdl_lib = sdl_lib,
        .zlua_module = zlua_module,
        .lua_lib = lua_lib,
        .freetype_lib = freetype_lib,
        .harfbuzz_lib = harfbuzz_lib,
    };
}
