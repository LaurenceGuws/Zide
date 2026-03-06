const std = @import("std");
const step_utils = @import("build_utils/step_utils.zig");
const bootstrap_graph = @import("build_utils/bootstrap_graph.zig");
const app_graph = @import("build_utils/app_graph.zig");
const ide_graph = @import("build_utils/ide_graph.zig");
const MainModeRunSteps = step_utils.MainModeRunSteps;
const initBuildBootstrap = bootstrap_graph.initBuildBootstrap;
const planAppModeGraphAndInstallRuntime = app_graph.planAppModeGraphAndInstallRuntime;
const planIdeExtendedBuildGraph = ide_graph.planIdeExtendedBuildGraph;

pub fn build(b: *std.Build) void {
    const boot = initBuildBootstrap(b);

    const main_mode_run_steps: MainModeRunSteps = planAppModeGraphAndInstallRuntime(
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

    planIdeExtendedBuildGraph(
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
