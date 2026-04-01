const std = @import("std");
const compile_utils = @import("compile_utils.zig");

const ReportToolSpec = struct {
    exe_name: []const u8,
    root_source_file: []const u8,
    step_name: []const u8,
    description: []const u8,
    adds_build_options: bool = true,
    adds_target_profile_import: bool = false,
};

pub fn addReportBuildAllStep(
    b: *std.Build,
    deps: []const *std.Build.Step,
) *std.Build.Step {
    const step = b.step(
        "report-build-all",
        "Run all core build report/check steps",
    );
    for (deps) |dep| step.dependOn(dep);
    return step;
}

pub fn addReportBuildProfilesStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    return addReportToolRunStep(
        b,
        target,
        optimize,
        null,
        .{
            .exe_name = "build-profile-report",
            .root_source_file = "build_system/reports/build_profile_report.zig",
            .step_name = "report-build-profiles",
            .description = "Report active build dependency profiles",
            .adds_build_options = false,
            .adds_target_profile_import = true,
        },
    );
}

pub fn addReportBuildModeStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    return addReportToolRunStep(
        b,
        target,
        optimize,
        build_options,
        .{
            .exe_name = "build-mode-report",
            .root_source_file = "build_system/reports/build_mode_report.zig",
            .step_name = "report-build-mode",
            .description = "Report selected app build mode and graph path",
        },
    );
}

pub fn addReportBuildBootstrapStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    return addReportToolRunStep(
        b,
        target,
        optimize,
        build_options,
        .{
            .exe_name = "build-bootstrap-report",
            .root_source_file = "build_system/reports/build_bootstrap_report.zig",
            .step_name = "report-build-bootstrap",
            .description = "Report resolved build bootstrap context",
        },
    );
}

pub fn addReportBuildFocusedPolicyStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    return addReportToolRunStep(
        b,
        target,
        optimize,
        build_options,
        .{
            .exe_name = "build-focused-mode-policy-check",
            .root_source_file = "build_system/checks/build_focused_mode_policy_check.zig",
            .step_name = "report-build-focused-policy",
            .description = "Check focused mode dependency policy",
        },
    );
}

pub fn addReportBuildTargetStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    return addReportToolRunStep(
        b,
        target,
        optimize,
        build_options,
        .{
            .exe_name = "build-target-report",
            .root_source_file = "build_system/reports/build_target_report.zig",
            .step_name = "report-build-target",
            .description = "Report resolved target and optimize settings",
        },
    );
}

pub fn addReportBuildPolicyStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    return addReportToolRunStep(
        b,
        target,
        optimize,
        build_options,
        .{
            .exe_name = "build-policy-report",
            .root_source_file = "build_system/reports/build_policy_report.zig",
            .step_name = "report-build-policy",
            .description = "Report supported build options and hard constraints",
        },
    );
}

pub fn addReportBuildSurfaceStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    return addReportToolRunStep(
        b,
        target,
        optimize,
        null,
        .{
            .exe_name = "build-surface-report",
            .root_source_file = "build_system/reports/build_surface_report.zig",
            .step_name = "report-build-surface",
            .description = "Report operator-facing build step taxonomy",
            .adds_build_options = false,
        },
    );
}

pub fn addCheckBuildReportToolsStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    const step = b.step(
        "check-build-report-tools",
        "Compile-check all core build report tools",
    );
    for (core_build_report_tool_specs) |spec| {
        step.dependOn(&addReportToolExecutable(b, target, optimize, build_options, spec).step);
    }

    return step;
}

const core_build_report_tool_specs = [_]ReportToolSpec{
    .{
        .exe_name = "build-mode-report-check",
        .root_source_file = "build_system/reports/build_mode_report.zig",
        .step_name = "",
        .description = "",
    },
    .{
        .exe_name = "build-bootstrap-report-check",
        .root_source_file = "build_system/reports/build_bootstrap_report.zig",
        .step_name = "",
        .description = "",
    },
    .{
        .exe_name = "build-focused-policy-report-check",
        .root_source_file = "build_system/checks/build_focused_mode_policy_check.zig",
        .step_name = "",
        .description = "",
    },
    .{
        .exe_name = "build-target-report-check",
        .root_source_file = "build_system/reports/build_target_report.zig",
        .step_name = "",
        .description = "",
    },
    .{
        .exe_name = "build-surface-report-check",
        .root_source_file = "build_system/reports/build_surface_report.zig",
        .step_name = "",
        .description = "",
        .adds_build_options = false,
    },
    .{
        .exe_name = "build-policy-report-check",
        .root_source_file = "build_system/reports/build_policy_report.zig",
        .step_name = "",
        .description = "",
    },
};

fn addReportToolRunStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: ?*std.Build.Step.Options,
    spec: ReportToolSpec,
) *std.Build.Step {
    const exe = addReportToolExecutable(b, target, optimize, build_options, spec);
    const run = b.addRunArtifact(exe);
    const step = b.step(spec.step_name, spec.description);
    step.dependOn(&run.step);
    return step;
}

fn addReportToolExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: ?*std.Build.Step.Options,
    spec: ReportToolSpec,
) *std.Build.Step.Compile {
    const exe = compile_utils.addExecutable(b, spec.exe_name, b.createModule(.{
        .root_source_file = b.path(spec.root_source_file),
        .target = target,
        .optimize = optimize,
    }));
    if (spec.adds_build_options) {
        exe.root_module.addOptions("build_options", build_options.?);
    }
    if (spec.adds_target_profile_import) {
        exe.root_module.addAnonymousImport("target_profile", .{
            .root_source_file = b.path("build_system/target_profile.zig"),
            .target = target,
            .optimize = optimize,
        });
    }
    return exe;
}
