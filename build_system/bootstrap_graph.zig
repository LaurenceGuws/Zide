const std = @import("std");
const bootstrap_setup = @import("bootstrap_setup.zig");
const target_profile = @import("target_profile.zig");
const mode_specs = @import("mode_specs.zig");
const AppLinkContext = @import("app_types.zig").AppLinkContext;
const BootstrapOptions = bootstrap_setup.BootstrapOptions;
const BootstrapDeps = bootstrap_setup.BootstrapDeps;

pub const BuildBootstrap = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_mode: mode_specs.BuildMode,
    target_os: std.Target.Os.Tag,
    build_options: *std.Build.Step.Options,
    treesitter: ?*std.Build.Step.Compile,
    zlua_module: *std.Build.Module,
    zlua_portable_module: *std.Build.Module,
    app_link_ctx: AppLinkContext,
};

pub fn initBuildBootstrap(b: *std.Build) BuildBootstrap {
    target_profile.assertPolicy();
    const options: BootstrapOptions = bootstrap_setup.initBootstrapOptions(b);
    const deps: BootstrapDeps = bootstrap_setup.resolveBootstrapDeps(b, options);
    bootstrap_setup.addBootstrapReportSteps(
        b,
        options.target,
        options.optimize,
        options.build_options,
    );

    return .{
        .target = options.target,
        .optimize = options.optimize,
        .build_mode = options.build_mode,
        .target_os = options.target_os,
        .build_options = options.build_options,
        .treesitter = deps.treesitter,
        .zlua_module = deps.zlua_module,
        .zlua_portable_module = deps.zlua_portable_module,
        .app_link_ctx = deps.app_link_ctx,
    };
}
