const std = @import("std");

fn configureWindowsLinker(step: *std.Build.Step.Compile, target: std.Build.ResolvedTarget) void {
    _ = step;
    _ = target;
}

pub const BuildDependencies = struct {
    treesitter: ?*std.Build.Step.Compile,
    sdl_lib: *std.Build.Step.Compile,
    zlua_module: *std.Build.Module,
    zlua_portable_module: *std.Build.Module,
    lua_lib: ?*std.Build.Step.Compile,
    freetype_lib: ?*std.Build.Step.Compile,
    harfbuzz_lib: ?*std.Build.Step.Compile,
};

pub fn resolveDependencies(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
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
    const zlua_portable_dep = b.dependency("zlua_portable", .{
        .target = target,
        .optimize = optimize,
    });
    const zlua_portable_module = zlua_portable_dep.module("zlua_portable");
    const lua_lib: ?*std.Build.Step.Compile = null;

    const freetype_dep = b.dependency("freetype", .{
        .target = target,
        .optimize = optimize,
        .use_system_zlib = target.result.os.tag != .windows,
        .enable_brotli = false,
    });

    const harfbuzz_dep = b.dependency("harfbuzz", .{
        .target = target,
        .optimize = optimize,
        .enable_freetype = true,
        .freetype_use_system_zlib = target.result.os.tag != .windows,
        .freetype_enable_brotli = false,
    });

    const freetype_lib: ?*std.Build.Step.Compile = freetype_dep.artifact("freetype");
    const harfbuzz_lib: ?*std.Build.Step.Compile = harfbuzz_dep.artifact("harfbuzz");
    if (freetype_lib) |lib| configureWindowsLinker(lib, target);
    if (harfbuzz_lib) |lib| configureWindowsLinker(lib, target);

    return .{
        .treesitter = treesitter,
        .sdl_lib = sdl_lib,
        .zlua_module = zlua_module,
        .zlua_portable_module = zlua_portable_module,
        .lua_lib = lua_lib,
        .freetype_lib = freetype_lib,
        .harfbuzz_lib = harfbuzz_lib,
    };
}
