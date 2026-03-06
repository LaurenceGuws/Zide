const std = @import("std");
const builtin = @import("builtin");
const dependency_path = @import("build_utils/dependency_path.zig");
const app_types = @import("build_utils/app_types.zig");
const target_config = @import("build_utils/target_config.zig");
const target_factory = @import("build_utils/target_factory.zig");
const step_utils = @import("build_utils/step_utils.zig");
const vcpkg_paths = @import("build_utils/vcpkg_paths.zig");
const windows_runtime = @import("build_utils/windows_runtime.zig");
const app_graph = @import("build_utils/app_graph.zig");
const ide_graph = @import("build_utils/ide_graph.zig");
const dependency_resolver = @import("build_utils/dependency_resolver.zig");
const target_profile = @import("build_utils/target_profile.zig");
const mode_specs = @import("build_utils/mode_specs.zig");
const DependencySource = dependency_path.DependencySource;
const AppLinkContext = app_types.AppLinkContext;
const parseDependencyPath = dependency_path.parseDependencyPath;
const resolveVcpkgPaths = vcpkg_paths.resolveVcpkgPaths;
const MainModeRunSteps = step_utils.MainModeRunSteps;
const installVcpkgRuntimeDlls = windows_runtime.installVcpkgRuntimeDlls;
const planIdePrimaryAppGraph = app_graph.planIdePrimaryAppGraph;
const planFocusedRuntimeAppGraph = app_graph.planFocusedRuntimeAppGraph;
const planIdeExtendedBuildGraph = ide_graph.planIdeExtendedBuildGraph;

pub fn build(b: *std.Build) void {
    target_profile.assertPolicy();

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

    // ─────────────────────────────────────────────────────────────────────────
    // Tree-sitter (for syntax highlighting)
    // ─────────────────────────────────────────────────────────────────────────
    // resolved in dependency_resolver below

    // Platform detection
    const target_os = target.result.os.tag;

    // Renderer backends (wgl/egl) are tracked as TODOs; SDL-managed GL is the
    // only implemented backend today across platforms.
    const default_renderer_backend = "sdl_gl";
    const renderer_backend = b.option(
        []const u8,
        "renderer-backend",
        "Renderer backend (only sdl_gl is implemented; wgl/egl are TODO)",
    ) orelse default_renderer_backend;

    if (!std.mem.eql(u8, renderer_backend, "sdl_gl")) {
        std.debug.panic("renderer backend '{s}' is not implemented (use -Drenderer-backend=sdl_gl)", .{renderer_backend});
    }
    const build_options = b.addOptions();
    build_options.addOption([]const u8, "renderer_backend", renderer_backend);
    build_options.addOption([]const u8, "dependency_path", dep_path_raw);

    // vcpkg support
    //
    // Windows builds currently rely on vcpkg for SDL3 + text stack.
    // This path is target-driven: enabled on Windows, disabled elsewhere.
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
    const vcpkg_include = resolved_vcpkg_paths.include;
    const vcpkg_lib = resolved_vcpkg_paths.lib;
    const vcpkg_bin = resolved_vcpkg_paths.bin;

    const deps = dependency_resolver.resolveDependencies(
        b,
        target,
        optimize,
        dep_path,
        use_vcpkg,
        build_mode != .terminal,
    );
    const treesitter = deps.treesitter;
    const sdl_lib = deps.sdl_lib;
    const zlua_module = deps.zlua_module;
    const lua_lib = deps.lua_lib;
    const freetype_lib = deps.freetype_lib;
    const harfbuzz_lib = deps.harfbuzz_lib;
    // ─────────────────────────────────────────────────────────────────────────
    // Main executable
    // ─────────────────────────────────────────────────────────────────────────
    const app_link_ctx = AppLinkContext{
        .dep_path = dep_path,
        .target_os = target_os,
        .use_vcpkg = use_vcpkg,
        .vcpkg_lib = vcpkg_lib,
        .vcpkg_include = vcpkg_include,
        .treesitter = treesitter,
        .sdl_lib = sdl_lib,
        .lua_lib = lua_lib,
        .freetype_lib = freetype_lib,
        .harfbuzz_lib = harfbuzz_lib,
    };

    const main_mode_run_steps: MainModeRunSteps = switch (build_mode) {
        .ide => planIdePrimaryAppGraph(
            b,
            target,
            optimize,
            build_options,
            zlua_module,
            app_link_ctx,
            b.args,
        ),
        .terminal, .editor => {
            // High-value compile-time isolation:
            // terminal/editor mode builds should only register the selected app
            // artifact + run step, and skip IDE-only build graph setup.
            planFocusedRuntimeAppGraph(
                b,
                target,
                optimize,
                build_options,
                zlua_module,
                app_link_ctx,
                build_mode,
                b.args,
            );
            return;
        },
    };

    // On Windows, vcpkg runtime DLLs are installed next to zide.exe.
    installVcpkgRuntimeDlls(b, target_os, use_vcpkg, vcpkg_bin);

    planIdeExtendedBuildGraph(
        b,
        target,
        optimize,
        target_os,
        treesitter,
        app_link_ctx,
        build_options,
        main_mode_run_steps,
    );
}
