const std = @import("std");
const app_types = @import("app_types.zig");
const mode_specs = @import("mode_specs.zig");
const target_profile = @import("target_profile.zig");
const ide_workflow = @import("ide_workflow.zig");
const ide_extended_artifacts = @import("ide_extended_artifacts.zig");

const AppLinkContext = app_types.AppLinkContext;
const ExtendedBuildGraphSteps = ide_extended_artifacts.ExtendedBuildGraphSteps;
const planExtendedArtifacts = ide_extended_artifacts.planExtendedArtifacts;

pub fn planIdeExtendedBuildGraph(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    target_os: std.Target.Os.Tag,
    treesitter: ?*std.Build.Step.Compile,
    app_link_ctx: AppLinkContext,
    build_options: *std.Build.Step.Options,
    zlua_module: *std.Build.Module,
    zlua_portable_module: ?*std.Build.Module,
) void {
    const windows_shell_extension_install = ide_workflow.addWindowsShellExtension(b, target, optimize);
    const extended_steps: ExtendedBuildGraphSteps = planExtendedArtifacts(
        b,
        target,
        optimize,
        target_os,
        treesitter,
        app_link_ctx,
        build_options,
        zlua_module,
        zlua_portable_module,
    );

    if (windows_shell_extension_install) |step| {
        b.getInstallStep().dependOn(step);
    }

    ide_workflow.addModeGateAndBundleSteps(
        b,
        target_os,
        b.getInstallStep(),
        extended_steps.test_step,
        extended_steps.terminal_import_check_step,
        extended_steps.app_import_check_step,
        extended_steps.input_import_check_step,
        extended_steps.editor_import_check_step,
        extended_steps.build_dep_policy_step,
        extended_steps.build_profile_report_step,
        extended_steps.terminal_replay_all_step,
        extended_steps.gui_smokes_manual_step,
    );

    ide_workflow.addGrammarUpdateStep(b, b.args);
}
