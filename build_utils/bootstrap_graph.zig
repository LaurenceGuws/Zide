const std = @import("std");
const builtin = @import("builtin");
const dependency_path = @import("dependency_path.zig");
const app_types = @import("app_types.zig");
const vcpkg_paths = @import("vcpkg_paths.zig");
const dependency_resolver = @import("dependency_resolver.zig");
const mode_specs = @import("mode_specs.zig");

const AppLinkContext = app_types.AppLinkContext;
const parseDependencyPath = dependency_path.parseDependencyPath;
const resolveVcpkgPaths = vcpkg_paths.resolveVcpkgPaths;

pub const BuildBootstrap = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_mode: mode_specs.BuildMode,
    target_os: std.Target.Os.Tag,
    build_options: *std.Build.Step.Options,
    use_vcpkg: bool,
    vcpkg_bin: ?[]const u8,
    treesitter: ?*std.Build.Step.Compile,
    zlua_module: *std.Build.Module,
    app_link_ctx: AppLinkContext,
};

pub fn initBuildBootstrap(b: *std.Build) BuildBootstrap {
    const target = b.standardTargetOptions(.{
        .default_target = if (builtin.os.tag == .windows) .{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
            .abi = .msvc,
        } else .{},
    });
    const optimize = b.standardOptimizeOption(.{});

    const dep_path_raw = b.option(
        []const u8,
        "path",
        "Dependency path: link (default) or zig package manager",
    ) orelse "link";
    const build_mode_raw = b.option(
        []const u8,
        "mode",
        "Build app mode: ide (default), terminal, editor",
    ) orelse "ide";

    const dep_path = parseDependencyPath(dep_path_raw);
    const build_mode = mode_specs.parseBuildMode(build_mode_raw);
    const target_os = target.result.os.tag;

    const default_renderer_backend = "sdl_gl";
    const renderer_backend = b.option(
        []const u8,
        "renderer-backend",
        "Renderer backend (only sdl_gl is implemented; wgl/egl are TODO)",
    ) orelse default_renderer_backend;
    if (!std.mem.eql(u8, renderer_backend, "sdl_gl")) {
        std.debug.panic(
            "renderer backend '{s}' is not implemented (use -Drenderer-backend=sdl_gl)",
            .{renderer_backend},
        );
    }

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "renderer_backend", renderer_backend);
    build_options.addOption([]const u8, "dependency_path", dep_path_raw);

    const use_vcpkg = (target_os == .windows);
    const vcpkg_root_opt = b.option([]const u8, "vcpkg-root", "Path to vcpkg root") orelse std.process.getEnvVarOwned(b.allocator, "VCPKG_ROOT") catch null;
    const vcpkg_triplet_opt = b.option([]const u8, "vcpkg-triplet", "vcpkg triplet (e.g. x64-windows)") orelse std.process.getEnvVarOwned(b.allocator, "VCPKG_DEFAULT_TRIPLET") catch null;

    const resolved_vcpkg_paths = resolveVcpkgPaths(
        b,
        target,
        target_os,
        vcpkg_root_opt,
        vcpkg_triplet_opt,
    );

    const deps = dependency_resolver.resolveDependencies(
        b,
        target,
        optimize,
        dep_path,
        use_vcpkg,
        build_mode != .terminal,
    );

    const app_link_ctx = AppLinkContext{
        .dep_path = dep_path,
        .target_os = target_os,
        .use_vcpkg = use_vcpkg,
        .vcpkg_lib = resolved_vcpkg_paths.lib,
        .vcpkg_include = resolved_vcpkg_paths.include,
        .treesitter = deps.treesitter,
        .sdl_lib = deps.sdl_lib,
        .lua_lib = deps.lua_lib,
        .freetype_lib = deps.freetype_lib,
        .harfbuzz_lib = deps.harfbuzz_lib,
    };

    return .{
        .target = target,
        .optimize = optimize,
        .build_mode = build_mode,
        .target_os = target_os,
        .build_options = build_options,
        .use_vcpkg = use_vcpkg,
        .vcpkg_bin = resolved_vcpkg_paths.bin,
        .treesitter = deps.treesitter,
        .zlua_module = deps.zlua_module,
        .app_link_ctx = app_link_ctx,
    };
}
