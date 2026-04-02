const std = @import("std");
const app_types = @import("app_types.zig");
const bootstrap_policy = @import("bootstrap_policy.zig");
const dependency_resolver = @import("dependency_resolver.zig");
const mode_specs = @import("mode_specs.zig");
const step_reports = @import("step_reports.zig");

const AppLinkContext = app_types.AppLinkContext;

pub const BootstrapOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_mode: mode_specs.BuildMode,
    target_os: std.Target.Os.Tag,
    build_options: *std.Build.Step.Options,
};

pub const BootstrapDeps = struct {
    treesitter: ?*std.Build.Step.Compile,
    zlua_module: *std.Build.Module,
    zlua_portable_module: *std.Build.Module,
    app_link_ctx: AppLinkContext,
};

pub fn initBootstrapOptions(b: *std.Build) BootstrapOptions {
    const target = b.standardTargetOptions(.{
        .default_target = bootstrap_policy.defaultTargetQuery(),
    });
    const optimize = b.standardOptimizeOption(.{});

    const build_mode_raw = bootstrap_policy.readBuildModeOptionRaw(b);
    const build_mode = bootstrap_policy.parseBuildModeRaw(build_mode_raw);
    const target_os = target.result.os.tag;

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "build_mode", build_mode_raw);
    build_options.addOption([]const u8, "target_arch", @tagName(target.result.cpu.arch));
    build_options.addOption([]const u8, "target_os", @tagName(target_os));
    build_options.addOption([]const u8, "target_abi", @tagName(target.result.abi));
    build_options.addOption([]const u8, "optimize_mode", @tagName(optimize));

    return .{
        .target = target,
        .optimize = optimize,
        .build_mode = build_mode,
        .target_os = target_os,
        .build_options = build_options,
    };
}

pub fn resolveBootstrapDeps(
    b: *std.Build,
    options: BootstrapOptions,
) BootstrapDeps {
    const deps = dependency_resolver.resolveDependencies(
        b,
        options.target,
        options.optimize,
        options.build_mode != .terminal,
    );
    if (options.build_mode == .terminal and deps.treesitter != null) {
        @panic("dependency policy violation: terminal mode must not resolve tree-sitter");
    }
    if (options.build_mode != .terminal and deps.treesitter == null) {
        @panic("dependency policy violation: non-terminal modes must resolve tree-sitter");
    }
    options.build_options.addOption(bool, "treesitter_enabled", deps.treesitter != null);

    return .{
        .treesitter = deps.treesitter,
        .zlua_module = deps.zlua_module,
        .zlua_portable_module = deps.zlua_portable_module,
        .app_link_ctx = .{
            .target_os = options.target_os,
            .treesitter = deps.treesitter,
            .sdl_lib = deps.sdl_lib,
            .lua_lib = deps.lua_lib,
            .freetype_lib = deps.freetype_lib,
            .harfbuzz_lib = deps.harfbuzz_lib,
        },
    };
}

pub fn addBootstrapReportSteps(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) void {
    _ = step_reports.addCoreBuildReportSuite(b, target, optimize, build_options);
}
