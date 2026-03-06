const std = @import("std");
const step_utils = @import("build_utils/step_utils.zig");
const windows_runtime = @import("build_utils/windows_runtime.zig");
const bootstrap_graph = @import("build_utils/bootstrap_graph.zig");
const app_graph = @import("build_utils/app_graph.zig");
const ide_graph = @import("build_utils/ide_graph.zig");
const MainModeRunSteps = step_utils.MainModeRunSteps;
const installVcpkgRuntimeDlls = windows_runtime.installVcpkgRuntimeDlls;
const initBuildBootstrap = bootstrap_graph.initBuildBootstrap;
const addBuildModeReportStep = step_utils.addBuildModeReportStep;
const planIdePrimaryAppGraph = app_graph.planIdePrimaryAppGraph;
const planFocusedRuntimeAppGraph = app_graph.planFocusedRuntimeAppGraph;
const planIdeExtendedBuildGraph = ide_graph.planIdeExtendedBuildGraph;

pub fn build(b: *std.Build) void {
    const boot = initBuildBootstrap(b);
    _ = addBuildModeReportStep(
        b,
        boot.target,
        boot.optimize,
        boot.build_options,
    );

    const main_mode_run_steps: MainModeRunSteps = switch (boot.build_mode) {
        .ide => planIdePrimaryAppGraph(
            b,
            boot.target,
            boot.optimize,
            boot.build_options,
            boot.zlua_module,
            boot.app_link_ctx,
            b.args,
        ),
        .terminal, .editor => {
            // High-value compile-time isolation:
            // terminal/editor mode builds should only register the selected app
            // artifact + run step, and skip IDE-only build graph setup.
            planFocusedRuntimeAppGraph(
                b,
                boot.target,
                boot.optimize,
                boot.build_options,
                boot.zlua_module,
                boot.app_link_ctx,
                boot.build_mode,
                b.args,
            );
            return;
        },
    };

    // On Windows, vcpkg runtime DLLs are installed next to zide.exe.
    installVcpkgRuntimeDlls(b, boot.target_os, boot.use_vcpkg, boot.vcpkg_bin);

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
