const std = @import("std");
const step_utils = @import("step_utils.zig");
const bootstrap_graph = @import("bootstrap_graph.zig");
const app_graph = @import("app_graph.zig");
const ide_graph = @import("ide_graph.zig");

pub fn build(b: *std.Build) void {
    const boot = bootstrap_graph.initBuildBootstrap(b);

    const main_mode_run_steps: step_utils.MainModeRunSteps = app_graph.planAppModeGraphAndInstallRuntime(
        b,
        boot.target,
        boot.optimize,
        boot.build_options,
        boot.zlua_module,
        boot.app_link_ctx,
        boot.build_mode,
        b.args,
        boot.target_os,
        boot.use_vcpkg,
        boot.vcpkg_bin,
    ) orelse return;

    ide_graph.planIdeExtendedBuildGraph(
        b,
        boot.target,
        boot.optimize,
        boot.target_os,
        boot.treesitter,
        boot.app_link_ctx,
        boot.build_options,
        main_mode_run_steps,
    );
}
