const std = @import("std");

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
    const exe = b.addExecutable(.{
        .name = "build-profile-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_profile_report.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addAnonymousImport("target_profile", .{
        .root_source_file = b.path("build_utils/target_profile.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run = b.addRunArtifact(exe);
    const step = b.step(
        "report-build-profiles",
        "Report active build dependency profiles",
    );
    step.dependOn(&run.step);
    return step;
}

pub fn addReportBuildModeStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    const exe = b.addExecutable(.{
        .name = "build-mode-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_mode_report.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addOptions("build_options", build_options);
    const run = b.addRunArtifact(exe);
    const step = b.step(
        "report-build-mode",
        "Report selected app build mode and graph path",
    );
    step.dependOn(&run.step);
    return step;
}

pub fn addReportBuildBootstrapStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    const exe = b.addExecutable(.{
        .name = "build-bootstrap-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_bootstrap_report.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addOptions("build_options", build_options);
    const run = b.addRunArtifact(exe);
    const step = b.step(
        "report-build-bootstrap",
        "Report resolved build bootstrap context",
    );
    step.dependOn(&run.step);
    return step;
}

pub fn addReportBuildFocusedPolicyStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    const exe = b.addExecutable(.{
        .name = "build-focused-mode-policy-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_focused_mode_policy_check.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addOptions("build_options", build_options);
    const run = b.addRunArtifact(exe);
    const step = b.step(
        "report-build-focused-policy",
        "Check focused mode dependency policy",
    );
    step.dependOn(&run.step);
    return step;
}

pub fn addReportBuildTargetStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    const exe = b.addExecutable(.{
        .name = "build-target-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_target_report.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addOptions("build_options", build_options);
    const run = b.addRunArtifact(exe);
    const step = b.step(
        "report-build-target",
        "Report resolved target and optimize settings",
    );
    step.dependOn(&run.step);
    return step;
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

    const mode_report = b.addExecutable(.{
        .name = "build-mode-report-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_mode_report.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    mode_report.root_module.addOptions("build_options", build_options);
    step.dependOn(&mode_report.step);

    const bootstrap_report = b.addExecutable(.{
        .name = "build-bootstrap-report-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_bootstrap_report.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    bootstrap_report.root_module.addOptions("build_options", build_options);
    step.dependOn(&bootstrap_report.step);

    const focused_policy = b.addExecutable(.{
        .name = "build-focused-policy-report-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_focused_mode_policy_check.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    focused_policy.root_module.addOptions("build_options", build_options);
    step.dependOn(&focused_policy.step);

    const target_report = b.addExecutable(.{
        .name = "build-target-report-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_target_report.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    target_report.root_module.addOptions("build_options", build_options);
    step.dependOn(&target_report.step);

    return step;
}
