const std = @import("std");
const builtin = @import("builtin");
const app_types = @import("app_types.zig");
const dependency_resolver = @import("dependency_resolver.zig");
const mode_specs = @import("mode_specs.zig");
const target_profile = @import("target_profile.zig");
const step_reports = @import("step_reports.zig");

const AppLinkContext = app_types.AppLinkContext;

pub const BuildBootstrap = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_mode: mode_specs.BuildMode,
    target_os: std.Target.Os.Tag,
    build_options: *std.Build.Step.Options,
    treesitter: ?*std.Build.Step.Compile,
    zlua_module: *std.Build.Module,
    app_link_ctx: AppLinkContext,
};

pub fn initBuildBootstrap(b: *std.Build) BuildBootstrap {
    target_profile.assertPolicy();

    const target = b.standardTargetOptions(.{
        .default_target = if (builtin.os.tag == .windows) .{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
            .abi = .msvc,
        } else .{},
    });
    const optimize = b.standardOptimizeOption(.{});

    const build_mode_raw = b.option(
        []const u8,
        "mode",
        "Build app mode: ide (default), terminal, editor",
    ) orelse "ide";

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
    build_options.addOption([]const u8, "build_mode", build_mode_raw);
    build_options.addOption([]const u8, "target_arch", @tagName(target.result.cpu.arch));
    build_options.addOption([]const u8, "target_os", @tagName(target_os));
    build_options.addOption([]const u8, "target_abi", @tagName(target.result.abi));
    build_options.addOption([]const u8, "optimize_mode", @tagName(optimize));
    const deps = dependency_resolver.resolveDependencies(
        b,
        target,
        optimize,
        build_mode != .terminal,
    );
    if (build_mode == .terminal and deps.treesitter != null) {
        @panic("dependency policy violation: terminal mode must not resolve tree-sitter");
    }
    if (build_mode != .terminal and deps.treesitter == null) {
        @panic("dependency policy violation: non-terminal modes must resolve tree-sitter");
    }
    build_options.addOption(bool, "treesitter_enabled", deps.treesitter != null);

    const build_mode_report_step = step_reports.addReportBuildModeStep(
        b,
        target,
        optimize,
        build_options,
    );
    const build_bootstrap_report_step = step_reports.addReportBuildBootstrapStep(
        b,
        target,
        optimize,
        build_options,
    );
    const build_focused_policy_report_step = step_reports.addReportBuildFocusedPolicyStep(
        b,
        target,
        optimize,
        build_options,
    );
    const build_target_report_step = step_reports.addReportBuildTargetStep(
        b,
        target,
        optimize,
        build_options,
    );
    const build_report_tools_check_step = step_reports.addCheckBuildReportToolsStep(
        b,
        target,
        optimize,
        build_options,
    );
    _ = step_reports.addReportBuildAllStep(
        b,
        &.{
            build_mode_report_step,
            build_bootstrap_report_step,
            build_focused_policy_report_step,
            build_target_report_step,
            build_report_tools_check_step,
        },
    );

    const app_link_ctx = AppLinkContext{
        .target_os = target_os,
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
        .treesitter = deps.treesitter,
        .zlua_module = deps.zlua_module,
        .app_link_ctx = app_link_ctx,
    };
}
