const std = @import("std");

fn configureWindowsLinker(step: *std.Build.Step.Compile, target: std.Build.ResolvedTarget) void {
    _ = step;
    _ = target;
}

pub const BuildDependencies = struct {
    treesitter: ?*std.Build.Step.Compile,
    sdl_lib: *std.Build.Step.Compile,
    zlua_module: *std.Build.Module,
    lua_lib: ?*std.Build.Step.Compile,
    freetype_lib: ?*std.Build.Step.Compile,
    harfbuzz_lib: ?*std.Build.Step.Compile,
};

pub fn resolveDependencies(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    use_vcpkg: bool,
    need_treesitter: bool,
) BuildDependencies {
    const tree_sitter_dep = if (need_treesitter)
        b.dependency("tree_sitter", .{
            .target = target,
            .optimize = optimize,
        })
    else
        null;
    const treesitter = if (tree_sitter_dep) |dep| dep.artifact("tree-sitter") else null;
    if (treesitter) |lib| configureWindowsLinker(lib, target);

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");
    configureWindowsLinker(sdl_lib, target);

    const zlua_dep = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
    });
    const zlua_module = zlua_dep.module("zlua");
    const lua_lib: ?*std.Build.Step.Compile = null;

    const freetype_dep = if (!use_vcpkg)
        b.dependency("freetype", .{
            .target = target,
            .optimize = optimize,
            .use_system_zlib = true,
            .enable_brotli = false,
        })
    else
        null;

    const harfbuzz_dep = if (!use_vcpkg)
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
    if (freetype_lib) |lib| configureWindowsLinker(lib, target);
    if (harfbuzz_lib) |lib| configureWindowsLinker(lib, target);

    return .{
        .treesitter = treesitter,
        .sdl_lib = sdl_lib,
        .zlua_module = zlua_module,
        .lua_lib = lua_lib,
        .freetype_lib = freetype_lib,
        .harfbuzz_lib = harfbuzz_lib,
    };
}
